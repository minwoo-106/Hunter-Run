import Foundation

public struct RunEngine {
    public private(set) var session: RunSession
    public let content: GameContent
    public var attack: Double
    public init(session: RunSession, content: GameContent, attack: Double = 1) {
        self.session = session; self.content = content; self.attack = min(12, max(0.5, session.loadout?.attack ?? attack))
        if let event = self.session.event { self.session.event = Self.preparedEvent(event, session: session) }
    }
    public mutating func restorePaused() {
        guard session.phase != .finished else { return }
        session.needsDistanceBaseline = true
        session.lastTimestamp = nil; session.manualPause = true; session.interruption = false
        session.phase = .paused; session.movingStreak = 0
        // An unheard or interrupted instruction must be delivered before scoring resumes.
        if session.event != nil { session.event?.stage = .briefing }
    }
    public mutating func pause(_ paused: Bool) {
        guard session.phase != .finished else { return }
        session.needsDistanceBaseline = true
        session.manualPause = paused; session.lastTimestamp = nil; session.movingStreak = 0
        session.phase = paused ? .paused : .moving
    }
    public mutating func interrupt(_ value: Bool) {
        guard session.phase != .finished else { return }
        session.needsDistanceBaseline = true
        session.interruption = value; session.lastTimestamp = nil; session.movingStreak = 0
        session.phase = value ? .interrupted : .paused
        if !value { session.manualPause = true; if session.event != nil { session.event?.stage = .briefing } }
    }
    public mutating func instructionFinished() {
        guard var event = session.event, event.stage == .briefing else { return }
        event.stage = event.template.requestsAcceleration && event.burstStarted != true ? .armed : .active
        session.event = event
    }
    public mutating func end(at date: Date = Date()) {
        if session.elapsedSeconds == nil {
            session.elapsedSeconds = max(session.activeSeconds, session.workoutSeconds ?? date.timeIntervalSince(session.startedAt))
        }
        guard session.phase != .finished else { return }
        let partialBattle = session.event?.battle != nil && (session.event?.battle?.attacks ?? 0) > 0
        closeEvent(partialBattle ? .partial : .neutral)
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
        guard let previous else {
            if session.needsDistanceBaseline == true {
                session.distanceBarrierTimestamp = frame.timestamp
                session.needsDistanceBaseline = false
            }
            return []
        }
        let rawDT = frame.timestamp - previous
        // Never invent activity through delivery gaps, reboot, or suspension.
        guard rawDT > 0, rawDT <= 5, frame.speed.isFinite, frame.distance.isFinite else {
            session.movingStreak = 0; session.combatBarrierTimestamp = frame.timestamp; return []
        }
        guard !session.manualPause, !session.interruption else { return [] }
        if session.reachedGoal && session.activityGoal.kind == .time {
            end(); return [.voice("run_end"), .checkpoint, .goalReached]
        }
        if !session.isIndoor {
            session.workoutSeconds = max(session.activeSeconds, session.workoutSeconds ?? session.activeSeconds) + rawDT
        }
        let finalRescue = session.boss?.definition.id == "corrupted-hunter" && !session.isIndoor
        if finalRescue && frame.steps > 0 && (frame.movement == .walking || frame.movement == .running) {
            session.lastVerifiedStepAt = frame.timestamp
        }
        let safeMotion = finalRescue && (frame.movement == .walking || frame.movement == .running)
            && session.lastVerifiedStepAt.map { frame.timestamp - $0 <= 6 } == true
        if finalRescue && frame.signal != .good && !safeMotion {
            // Keep the encounter intact. Motion evidence is required before time-based
            // observation resumes, and the player can resume after a safe pause.
            session.stationarySeconds += rawDT
            if session.stationarySeconds >= 8 {
                session.manualPause = true; session.phase = .paused
                return [.voice("pause"), .checkpoint]
            }
            return []
        }
        // Also end an older restored session already at the new environment limit.
        let moving = (frame.movement == .walking || frame.movement == .running) && (!session.isIndoor || frame.signal == .good)
        guard moving else {
            session.combatBarrierTimestamp = frame.timestamp
            session.movingStreak = 0
            session.stationarySeconds += rawDT
            if session.reachedGoal && session.activityGoal.kind == .time {
                end(); return [.voice("run_end"), .checkpoint, .goalReached]
            }
            if frame.movement == .vehicle { session.phase = .paused }
            if session.stationarySeconds >= 8, session.phase != .paused {
                session.phase = .paused; return [.voice("pause"), .checkpoint]
            }
            return []
        }
        session.stationarySeconds = 0
        session.movingStreak += rawDT
        if session.phase == .paused {
            session.combatBarrierTimestamp = frame.timestamp
            guard session.movingStreak >= 5 else { return [] }
            session.phase = .moving
            return [.voice("resume"), .checkpoint]
        }
        var dt = min(rawDT, max(0, (session.activeTimeLimit ?? .greatestFiniteMagnitude) - session.activeSeconds))
        let representedDistanceTime = frame.distanceDuration.flatMap {
            $0.isFinite && $0 > 0 ? $0 : nil
        } ?? dt
        var distance = session.isIndoor || (finalRescue && frame.signal != .good) ? 0 : max(0, min(frame.distance, 8 * max(dt, representedDistanceTime)))
        if let barrier = session.distanceBarrierTimestamp,
           frame.timestamp - representedDistanceTime < barrier - 1e-6 { distance = 0 }
        if session.isIndoor { session.steps = (session.steps ?? 0) + min(30, max(0, frame.steps)) }
        if session.activityGoal.kind == .distance {
            let remaining = max(0, session.activityGoal.value - session.distance)
            if distance > remaining { dt *= remaining / distance; distance = remaining }
        }
        let previousDistance = session.distance
        session.activeSeconds += dt
        if frame.movement == .running { session.runningSeconds += dt }
        session.distance += distance
        var cues: [GameCue] = []
        if !session.isIndoor && frame.signal == .good {
            let reported = session.announcedKilometers ?? Int(previousDistance / 1000)
            let first = reported + 1
            let last = Int(session.distance / 1000)
            if first <= last {
                for kilometer in first...last { cues.append(.distanceMilestone(kilometer)) }
            }
            session.announcedKilometers = max(reported, last)
        }
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
        if session.reachedGoal {
            if session.event?.battle != nil, session.event?.stage != .briefing, (stable || safeMotion),
               session.combatBarrierTimestamp.map({ frame.timestamp - representedDistanceTime >= $0 - 1e-6 }) ?? true {
                cues += advanceBattle(distance: stable ? distance : dt * 2.5, seconds: dt)
            }
            end(); return cues + [.voice("run_end"), .checkpoint, .goalReached]
        }
        if session.hp <= 0, session.activeSeconds >= session.recoveryUntil { session.hp = 50 }

        if session.gateTracking == true
            && session.patrolCycle == 0 && session.event == nil
            && frame.movement == .running && frame.signal == .good
            && session.activeSeconds >= session.patrolDuration * (session.gateWindowFraction ?? GateBalance().encounterFraction)
            && (session.activeTimeLimit ?? .greatestFiniteMagnitude) - session.activeSeconds >= 75 {
            session.gateOpportunityQualified = true
        }

        if var event = session.event {
            if event.stage == .briefing {
                if event.battle != nil { session.combatBarrierTimestamp = frame.timestamp }
                return cues
            }
            let requiresRunning = event.template.kind != .discovery
            if frame.signal != .good && requiresRunning && !safeMotion {
                if event.battle != nil { session.combatBarrierTimestamp = frame.timestamp; return cues }
                // A single poor fix must not erase a field encounter. An active
                // acceleration is cancelled immediately because its effort cannot
                // be judged safely without a reliable signal.
                if event.template.requestsAcceleration {
                    closeEvent(.neutral); return [.voice("signal"), .checkpoint]
                }
                if event.signalDegradedSince == nil { event.signalDegradedSince = session.activeSeconds }
                session.event = event
                if event.template.id.components(separatedBy: "#").first == session.priorityEncounterID
                    || session.boss != nil || session.activeSeconds - (event.signalDegradedSince ?? session.activeSeconds) < 60 {
                    return cues
                }
                closeEvent(.neutral); return [.voice("signal"), .checkpoint]
            }
            if event.signalDegradedSince != nil { event.signalDegradedSince = nil; session.event = event }
            if requiresRunning && !session.isIndoor && frame.movement != .running && !safeMotion {
                session.combatBarrierTimestamp = frame.timestamp; return cues
            }
            if event.battle != nil {
                guard (stable || safeMotion), !session.isIndoor else {
                    session.combatBarrierTimestamp = frame.timestamp; return cues
                }
                if let barrier = session.combatBarrierTimestamp,
                   frame.timestamp - representedDistanceTime < barrier - 1e-6 { return cues }
                return cues + advanceBattle(distance: stable ? distance : dt * 2.5, seconds: dt)
            }
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
            let qualified = session.isIndoor || safeMotion || event.template.kind == .discovery || event.template.kind == .ambush || frame.speed >= event.baseline * threshold
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
        let patrolContent = session.boss?.content ?? content
        let currentCycle = session.patrolCycle
        // A tracked quest encounter must remain pending when a free/distance
        // activity enters its next patrol before the signal permits combat.
        let pendingCycle = session.priorityEncounterID.flatMap { priority in
            (0..<currentCycle).first { earlier in
                RunDirector.events(patrolContent, session: session, cycle: earlier).contains {
                    $0.id.components(separatedBy: "#").first == priority && !session.consumed.contains($0.id)
                }
            }
        }
        let cycle = pendingCycle ?? currentCycle
        let offset = Double(cycle) * session.patrolDuration
        let candidates = RunDirector.events(patrolContent, session: session, cycle: cycle)
        if var next = candidates.first(where: { !session.consumed.contains($0.id) && session.activeSeconds >= offset + session.patrolDuration * $0.startFraction }) {
            let isNormalGate = next.id.components(separatedBy: "#").first == GateTracking.eventID
            if isNormalGate && (session.isIndoor || session.withdrawn || frame.movement != .running || frame.signal != .good
                || session.hp <= 0 || session.activeSeconds < session.recoveryUntil
                || AccelerationRules.needsEasyMovement(session)) { return cues }
            if next.id.components(separatedBy: "#").first == session.priorityEncounterID,
               !session.isIndoor && (frame.movement != .running || frame.signal != .good
                    || session.hp <= 0 || session.activeSeconds < session.recoveryUntil
                    || AccelerationRules.needsEasyMovement(session)) {
                return cues
            }
            let scheduledAt = offset + session.patrolDuration * next.startFraction
            let latestInvestigationStart = (session.activeTimeLimit ?? .greatestFiniteMagnitude)
                - min(45, next.duration) - 30
            if !session.isIndoor && (session.mode == .contract || session.boss != nil)
                && next.kind != .discovery && !safeMotion
                && (frame.movement != .running || frame.signal != .good)
                && (session.boss != nil || session.activeSeconds < min(scheduledAt + min(90, session.patrolDuration * 0.05), latestInvestigationStart)) {
                // Hold the unconsumed encounter through a crossing or a brief GPS
                // dropout. A sustained walk eventually becomes investigation.
                return cues
            }
            if session.isIndoor { next = IndoorRules.event(next) }
            if finalRescue && next.kind == .boss && next.burstSeconds != nil {
                // The final rescue never requires a speed surge to advance.
                next.useSteadyAlternative()
            }
            session.consumed.insert(next.id)
            if next.requestsAcceleration && !AccelerationRules.canOffer(session, frame: frame) {
                next.useSteadyAlternative()
            }
            if (session.hp <= 0 || session.activeSeconds < session.recoveryUntil || AccelerationRules.needsEasyMovement(session) || session.withdrawn && next.kind == .boss) && next.kind != .discovery {
                next.kind = .discovery; next.burstSeconds = nil; next.title = "회복 구간 흔적 조사"; next.duration = min(45, next.duration); next.audio = "investigate"
            }
            if next.kind != .discovery && !safeMotion && ((!session.isIndoor && frame.movement != .running) || frame.signal != .good) {
                next.kind = .discovery; next.burstSeconds = nil; next.audio = "investigate"; next.title = "주변 흔적 조사"; next.duration = min(45, next.duration)
            }
            let remaining = (session.activeTimeLimit ?? .greatestFiniteMagnitude) - session.activeSeconds
            if remaining < next.duration + 30 { return [.checkpoint] }
            if next.id.hasPrefix("major-strike"), let boss = session.boss {
                if boss.remainingHP <= 0 { return [.checkpoint] }
                next.hp = boss.remainingHP
            }
            session.event = RunEvent(template: next, hp: next.hp, startingHP: next.hp, baseline: PaceLearning.effectiveBaseline(current: session.baseline, learned: session.learnedReference, fallback: frame.speed))
            if let event = session.event { session.event = Self.preparedEvent(event, session: session) }
            if session.event?.battle != nil { session.combatBarrierTimestamp = frame.timestamp }
            if isNormalGate && next.kind == .boss { session.gatePresented = true }
            cues += [.voice(session.event?.instructionAudio ?? next.audio), .checkpoint]
        }
        return cues
    }
    private mutating func advanceBattle(distance: Double, seconds: Double) -> [GameCue] {
        guard var event = session.event, var battle = event.battle else { return [] }
        let damage = battle.advance(distance: distance, attack: attack)
        event.battle = battle; event.hp = battle.remainingHP
        event.elapsed += seconds; event.traveledDistance = (event.traveledDistance ?? 0) + distance
        session.event = event
        if battle.monster.persistent, var boss = session.boss {
            boss.damage += min(damage, boss.remainingHP); session.boss = boss
        }
        if battle.remainingHP == 0 {
            closeEvent(.success)
            return [.voice("success"), .checkpoint]
        }
        return damage > 0 ? [.voice("combat_hit"), .checkpoint] : []
    }
    private mutating func closeEvent(_ outcome: Outcome) {
        guard let event = session.event else { return }
        if event.template.kind != .discovery { session.paceCooldownUntil = session.activeSeconds + 60 }
        if event.burstStarted == true { session.lastIntensityAt = session.activeSeconds }
        session.records.append(EventRecord(id: event.template.id, title: event.template.title, outcome: outcome, damage: max(0, event.startingHP - event.hp), defeated: event.startingHP > 0 && event.hp <= 0, kind: event.template.kind, accelerated: event.burstStarted, encounterKind: event.template.encounterKind, monsterID: event.battle?.monster.id, attacks: event.battle?.attacks))
        session.event = nil
    }
}
public enum Settlement {
    @discardableResult public static func apply(_ session: RunSession, to profile: inout Profile) -> RunSummary? {
        guard session.phase == .finished, !session.simulated,
              ActivityRecordPolicy.qualifies(session.activeSeconds),
              !profile.settled.contains(session.id) else { return nil }
        var session = session
        let before = profile
        if session.combatRules != nil {
            var seen: Set<String> = []
            session.records = session.records.filter { seen.insert($0.id).inserted }
        }
        GateTracking.migrate(&profile)
        FieldDiscovery.record(session, profile: &profile)
        let completed = session.records.filter { $0.outcome != .neutral }.count
        let bossReport = BossCampaign.settle(session, to: &profile)
        let normalGateClear = session.records.contains {
            $0.catalogID == GateTracking.eventID && $0.kind == .boss
                && $0.defeated == true && $0.outcome != .neutral
                && ($0.encounterKind == .normalGate || session.rulesVersion == nil)
        } && (session.gatePresented == true || session.rulesVersion == nil && session.mode == .gate)
        let completion = bossReport?.completion ?? (normalGateClear ? CompletionKind.normalGateClear : nil)
        let percent = session.activityEnvironment.rewardPercent
        // Round once per currency after totaling the activity. One-time quest claims are separate.
        let oldRules = session.rulesVersion == nil
        let bonus = CompletionRewards.bonus(completion, oldRules: oldRules, bossCleared: bossReport?.cleared == true)
        let eventExperience = session.combatRules == nil ? completed * 20 : CombatExperience.reward(session, bossReport: bossReport)
        let xp = (Int(session.activeSeconds / 10) + eventExperience + bonus.xp) * percent / 100
        let crystals = (Int(session.activeSeconds / 120) + completed * (session.mode == .gate ? 3 : 2) + bonus.crystals) * percent / 100
        let discoveries = session.records.filter { $0.kind == .discovery && $0.outcome != .neutral }.count
        let research = (completed + (session.mode == .exploration ? discoveries : 0) + discoveries * (session.loadout?.researchBonus ?? 0)) * percent / 100
        let cores = bonus.cores
        let paceReport = PaceLearning.settle(session, profile: &profile)
        var summary = RunSummary(id: session.id, date: session.startedAt, seconds: session.activeSeconds, elapsedSeconds: session.elapsedSeconds, distance: session.distance, xp: xp, crystals: crystals, records: session.records, goal: session.activityGoal, runningSeconds: session.runningSeconds, completedGoal: session.reachedGoal, mode: session.mode, research: research, cores: cores, majorBoss: bossReport, paceReport: paceReport, questID: session.questID, environment: session.environment, steps: session.steps, rewardPercent: percent, completion: completion)
        profile.xp += xp; profile.crystals += crystals; profile.research += research
        if cores > 0 { var growth = profile.growth; growth.cores += cores; profile.growth = growth }
        GateTracking.settle(session, completion: completion, profile: &profile)
        let foundGifts = OperatorGifts.collect(session, profile: &profile)
        summary.foundGifts = foundGifts.isEmpty ? nil : foundGifts
        profile.settled.insert(session.id); profile.runs.insert(summary, at: 0)
        let previousQuests = profile.journey?.completedQuests ?? []
        Quests.settle(session, profile: &profile)
        Expeditions.returned(session, profile: &profile, previousQuests: previousQuests)
        summary.growthReport = EquipmentExperience.record(session, summary: summary, before: before, profile: &profile)
        if let index = profile.runs.firstIndex(where: { $0.id == summary.id }) { profile.runs[index] = summary }
        return summary
    }
}
