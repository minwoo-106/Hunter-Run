import Foundation

public struct RunEngine {
    public private(set) var session: RunSession
    public let content: GameContent
    public var attack: Double
    public init(session: RunSession, content: GameContent, attack: Double = 1) {
        self.session = session; self.content = content; self.attack = min(3, max(0.5, session.loadout?.attack ?? attack))
    }
    public mutating func restorePaused() {
        session.lastTimestamp = nil; session.manualPause = true; session.interruption = false
        session.phase = .paused; session.movingStreak = 0
        // An unheard or interrupted instruction must be delivered before scoring resumes.
        if session.event != nil { session.event?.stage = .briefing }
    }
    public mutating func pause(_ paused: Bool) {
        session.manualPause = paused; session.lastTimestamp = nil; session.movingStreak = 0
        session.phase = paused ? .paused : .moving
    }
    public mutating func interrupt(_ value: Bool) {
        session.interruption = value; session.lastTimestamp = nil; session.movingStreak = 0
        session.phase = value ? .interrupted : .paused
        if !value { session.manualPause = true; if session.event != nil { session.event?.stage = .briefing } }
    }
    public mutating func instructionFinished() {
        guard var event = session.event, event.stage == .briefing else { return }
        event.stage = event.template.requestsAcceleration && event.burstStarted != true ? .armed : .active
        session.event = event
    }
    public mutating func end() {
        guard session.phase != .finished else { return }
        closeEvent(.neutral)
        session.phase = .finished; session.lastTimestamp = nil
    }
    @discardableResult public mutating func consume(_ frame: SensorFrame) -> [GameCue] {
        guard session.phase != .finished, frame.timestamp.isFinite else { return [] }
        // Settle the prior day before accepting new-day frames, including a paused/recovered run.
        if session.isIndoor && frame.timestamp >= IndoorDailyLimit.end(of: session.startedAt).timeIntervalSince1970 {
            end(); return [.voice("run_end"), .checkpoint, .goalReached]
        }
        let previous = session.lastTimestamp
        if let previous, frame.timestamp <= previous { return [] }
        session.lastTimestamp = frame.timestamp
        guard let previous else { return [] }
        let rawDT = frame.timestamp - previous
        // Never invent activity through delivery gaps, reboot, or suspension.
        guard rawDT > 0, rawDT <= 5, frame.speed.isFinite, frame.distance.isFinite else {
            session.movingStreak = 0; return []
        }
        guard !session.manualPause, !session.interruption else { return [] }
        // Also end an older restored session already at the new environment limit.
        if let limit = session.activeTimeLimit, session.activeSeconds >= limit {
            end(); return [.voice("run_end"), .checkpoint, .goalReached]
        }
        let moving = (frame.movement == .walking || frame.movement == .running) && (!session.isIndoor || frame.signal == .good)
        guard moving else {
            session.movingStreak = 0
            session.stationarySeconds += rawDT
            if frame.movement == .vehicle { session.phase = .paused }
            if session.stationarySeconds >= 8, session.phase != .paused {
                session.phase = .paused; return [.voice("pause"), .checkpoint]
            }
            return []
        }
        session.stationarySeconds = 0
        session.movingStreak += rawDT
        if session.phase == .paused {
            guard session.movingStreak >= 5 else { return [] }
            session.phase = .moving
            return [.voice("resume"), .checkpoint]
        }
        var dt = min(rawDT, max(0, (session.activeTimeLimit ?? .greatestFiniteMagnitude) - session.activeSeconds))
        var distance = session.isIndoor ? 0 : max(0, min(frame.distance, 8 * dt))
        if session.isIndoor { session.steps = (session.steps ?? 0) + min(30, max(0, frame.steps)) }
        if session.activityGoal.kind == .distance {
            let remaining = max(0, session.activityGoal.value - session.distance)
            if distance > remaining { dt *= remaining / distance; distance = remaining }
        }
        session.activeSeconds += dt
        if frame.movement == .running { session.runningSeconds += dt }
        session.distance += distance
        let stable = !session.isIndoor && frame.movement == .running && frame.signal == .good && frame.speed >= 1 && frame.speed <= 6
        let outdoorSignal = !session.isIndoor && frame.signal == .good
        session.paceObservation?.observe(speed: frame.speed, seconds: dt, goodSignal: outdoorSignal,
            eligible: stable && session.event == nil && session.activeSeconds >= (session.paceCooldownUntil ?? 0))
        if stable && session.event == nil && session.activeSeconds < session.calibrationSeconds {
            session.baselineSamples.append(frame.speed)
            if session.baselineSamples.count > 180 { session.baselineSamples.removeFirst() }
            let sorted = session.baselineSamples.sorted()
            session.baseline = sorted[sorted.count / 2]
        }
        if let observation = session.paceObservation, observation.stableSeconds >= 300, let median = observation.median {
            session.baseline = median
        }
        session.phase = session.activeSeconds < session.calibrationSeconds ? .calibrating : .moving
        var cues: [GameCue] = []
        if session.reachedGoal {
            end(); return [.voice("run_end"), .checkpoint, .goalReached]
        }
        if session.hp <= 0, session.activeSeconds >= session.recoveryUntil { session.hp = 50 }

        if var event = session.event {
            if event.stage == .briefing { return cues }
            let requiresRunning = event.template.kind != .discovery
            if frame.signal != .good && requiresRunning {
                // No evaluation under uncertain sensor evidence. Switch to a neutral route.
                closeEvent(.neutral); return [.voice("signal"), .checkpoint]
            }
            if requiresRunning && !session.isIndoor && frame.movement != .running { return cues }
            if event.stage == .armed {
                event.elapsed += dt
                if frame.speed >= event.baseline * 1.08 { event.pushing += dt } else { event.pushing = 0 }
                if event.pushing >= 4 {
                    event.elapsed = 0; session.intensityCount += 1
                    session.lastIntensityAt = session.activeSeconds
                    if event.template.burstSeconds != nil {
                        // The four-second intent confirmation is part of the ten-second effort.
                        event.burstStarted = true; event.stage = .active
                        event.elapsed = event.pushing; event.evaluatedSeconds = event.pushing; event.qualified = event.pushing
                        event.template.audio = "burst_start"
                        cues.append(.voice("burst_start"))
                    } else {
                        event.stage = .active; cues.append(.voice("pursuit_started"))
                    }
                } else if event.elapsed >= 15 {
                    let timedBurst = event.template.burstSeconds != nil
                    event.template.useSteadyAlternative(); event.elapsed = 0; event.pushing = 0
                    event.stage = timedBurst ? .briefing : .active
                    cues.append(.voice(event.template.audio))
                }
                session.event = event; return cues
            }
            let eventDT = event.template.burstSeconds.map { min(dt, max(0, $0 - event.elapsed)) } ?? dt
            event.elapsed += eventDT; event.evaluatedSeconds += eventDT
            let threshold = event.template.requestsAcceleration ? 1.08 : event.template.kind == .endurance ? 0.75 : 0.85
            let qualified = session.isIndoor || event.template.kind == .discovery || event.template.kind == .ambush || frame.speed >= event.baseline * threshold
            if qualified { event.qualified += eventDT }
            if event.template.kind == .endurance { event.traveledDistance = (event.traveledDistance ?? 0) + distance }
            session.event = event
            if event.progress >= 1 {
                let ratio = event.qualified / max(1, event.evaluatedSeconds)
                let outcome: Outcome = ratio >= 0.9 ? .perfect : ratio >= 0.7 ? .success : ratio >= 0.4 ? .partial : .fail
                let multiplier: Double = [.perfect: 1.2, .success: 1.0, .partial: 0.55, .fail: 0.15][outcome] ?? 0
                let bonus = event.template.kind == .maintain || event.template.kind == .pursuit ? session.loadout?.eventBonus ?? 0 : 0
                let damage = event.template.kind == .discovery ? 0 : min(event.hp, 60 * attack * multiplier * (1 + bonus))
                session.event?.hp = max(0, event.hp - damage)
                if event.template.id.hasPrefix("major-strike"), event.template.kind == .boss, var boss = session.boss {
                    boss.damage += min(damage, boss.remainingHP); session.boss = boss
                }
                let defense = min(0.65, max(0, session.loadout?.defense ?? 0))
                let incoming = (session.mode == .gate ? 1.3 : 1) * (1 - defense)
                if outcome == .partial { session.hp = max(0, session.hp - 12 * incoming) }
                if outcome == .fail { session.hp = max(0, session.hp - 25 * incoming) }
                if session.hp == 0 { session.withdrawn = true; session.recoveryUntil = session.activeSeconds + 120 }
                if event.template.kind == .pursuit { session.lastIntensityAt = session.activeSeconds }
                closeEvent(outcome)
                cues += [.voice(outcome == .fail || outcome == .partial ? "partial" : "success"), .checkpoint]
            }
            return cues
        }
        guard session.phase != .calibrating, session.movingStreak >= 10 else { return cues }
        let cycle = session.patrolCycle
        let offset = Double(cycle) * session.patrolDuration
        let patrolContent = session.boss?.content ?? content
        let candidates = RunDirector.events(patrolContent, session: session, cycle: cycle)
        if var next = candidates.first(where: { !session.consumed.contains($0.id) && session.activeSeconds >= offset + session.patrolDuration * $0.startFraction }) {
            if session.isIndoor { next = IndoorRules.event(next) }
            session.consumed.insert(next.id)
            let remaining = (session.activeTimeLimit ?? .greatestFiniteMagnitude) - session.activeSeconds
            if remaining < next.duration + 30 { return [.checkpoint] }
            if next.requestsAcceleration && !AccelerationRules.canOffer(session, frame: frame) {
                next.useSteadyAlternative()
            }
            if (session.hp <= 0 || session.activeSeconds < session.recoveryUntil || AccelerationRules.needsEasyMovement(session) || session.withdrawn && next.kind == .boss) && next.kind != .discovery {
                next.kind = .discovery; next.burstSeconds = nil; next.title = "회복 구간 흔적 조사"; next.duration = min(45, next.duration); next.audio = "investigate"
            }
            if next.kind != .discovery && ((!session.isIndoor && frame.movement != .running) || frame.signal != .good) {
                next.kind = .discovery; next.burstSeconds = nil; next.audio = "investigate"; next.title = "주변 흔적 조사"; next.duration = min(45, next.duration)
            }
            if next.id.hasPrefix("major-strike"), let boss = session.boss {
                if boss.remainingHP <= 0 { return [.checkpoint] }
                next.hp = boss.remainingHP
            }
            session.event = RunEvent(template: next, hp: next.hp, startingHP: next.hp, baseline: PaceLearning.effectiveBaseline(current: session.baseline, learned: session.learnedReference, fallback: frame.speed))
            cues += [.voice(next.audio), .checkpoint]
        }
        return cues
    }
    private mutating func closeEvent(_ outcome: Outcome) {
        guard let event = session.event else { return }
        if event.template.kind != .discovery { session.paceCooldownUntil = session.activeSeconds + 60 }
        if event.burstStarted == true { session.lastIntensityAt = session.activeSeconds }
        session.records.append(EventRecord(id: event.template.id, title: event.template.title, outcome: outcome, damage: max(0, event.startingHP - event.hp), defeated: event.startingHP > 0 && event.hp <= 0, kind: event.template.kind, accelerated: event.burstStarted))
        session.event = nil
    }
}
public enum Settlement {
    @discardableResult public static func apply(_ session: RunSession, to profile: inout Profile) -> RunSummary? {
        guard session.phase == .finished, !session.simulated, !profile.settled.contains(session.id) else { return nil }
        FieldDiscovery.record(session, profile: &profile)
        let completed = session.records.filter { $0.outcome != .neutral }.count
        let bossReport = BossCampaign.settle(session, to: &profile)
        let percent = session.activityEnvironment.rewardPercent
        // Round once per currency after totaling the activity. One-time quest claims are separate.
        let xp = (Int(session.activeSeconds / 10) + completed * 20 + (bossReport?.cleared == true ? 120 : 0)) * percent / 100
        let crystals = (Int(session.activeSeconds / 120) + completed * (session.mode == .gate ? 3 : 2) + (bossReport?.cleared == true ? 15 : 0)) * percent / 100
        let discoveries = session.records.filter { $0.kind == .discovery && $0.outcome != .neutral }.count
        let research = (completed + (session.mode == .exploration ? discoveries : 0) + discoveries * (session.loadout?.researchBonus ?? 0)) * percent / 100
        let regularCores = session.mode == .gate && session.records.contains { $0.catalogID == "gate-core" && $0.defeated == true } ? 1 : 0
        let cores = bossReport?.cleared == true ? 2 : regularCores
        let paceReport = PaceLearning.settle(session, profile: &profile)
        let summary = RunSummary(id: session.id, date: session.startedAt, seconds: session.activeSeconds, distance: session.distance, xp: xp, crystals: crystals, records: session.records, goal: session.activityGoal, runningSeconds: session.runningSeconds, completedGoal: session.reachedGoal, mode: session.mode, research: research, cores: cores, majorBoss: bossReport, paceReport: paceReport, questID: session.questID, environment: session.environment, steps: session.steps, rewardPercent: percent)
        profile.xp += xp; profile.crystals += crystals; profile.research += research
        if cores > 0 { var growth = profile.growth; growth.cores += cores; profile.growth = growth }
        profile.settled.insert(session.id); profile.runs.insert(summary, at: 0)
        let previousQuests = profile.journey?.completedQuests ?? []
        Quests.settle(session, profile: &profile)
        Expeditions.returned(session, profile: &profile, previousQuests: previousQuests)
        return summary
    }
}
