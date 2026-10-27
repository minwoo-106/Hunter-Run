import Foundation

public enum Movement: String, Codable, CaseIterable { case unknown, stationary, walking, running, vehicle }
public enum Signal: String, Codable { case good, degraded, unavailable }
public enum RunPhase: String, Codable { case calibrating, moving, paused, interrupted, finished }
public enum EventKind: String, Codable { case discovery, maintain, pursuit, endurance, ambush, boss }
public enum EventStage: String, Codable { case briefing, armed, active }
public enum Outcome: String, Codable { case perfect, success, partial, fail, neutral }
public struct SensorFrame: Codable {
    public var timestamp: TimeInterval
    public var speed: Double
    public var distance: Double
    /// Time represented by the accumulated distance. GPS callbacks may arrive
    /// between the one-second engine ticks and can contain several seconds of
    /// already validated travel.
    public var distanceDuration: TimeInterval?
    public var movement: Movement
    public var signal: Signal
    public var steps: Int
    public init(timestamp: TimeInterval, speed: Double, distance: Double, movement: Movement, signal: Signal, steps: Int = 0, distanceDuration: TimeInterval? = nil) {
        self.timestamp = timestamp; self.speed = speed; self.distance = distance; self.movement = movement; self.signal = signal
        self.steps = steps; self.distanceDuration = distanceDuration
    }
}
public struct MissionTemplate: Codable, Identifiable {
    public var id: String
    public var title: String
    public var kind: EventKind
    public var startFraction: Double
    public var duration: Double
    public var hp: Double
    public var audio: String
    public var targetDistance: Double? = nil
    public var shortAudio: String? = nil
    public var burstSeconds: Double? = nil
    public var steadyAudio: String? = nil
    public var encounterKind: EncounterKind? = nil
    public init(id: String, title: String, kind: EventKind, startFraction: Double, duration: Double, hp: Double, audio: String,
                targetDistance: Double? = nil, shortAudio: String? = nil, burstSeconds: Double? = nil,
                steadyAudio: String? = nil, encounterKind: EncounterKind? = nil) {
        self.id = id; self.title = title; self.kind = kind; self.startFraction = startFraction
        self.duration = duration; self.hp = hp; self.audio = audio; self.targetDistance = targetDistance
        self.shortAudio = shortAudio; self.burstSeconds = burstSeconds; self.steadyAudio = steadyAudio; self.encounterKind = encounterKind
    }
    public var requestsAcceleration: Bool { kind == .pursuit || burstSeconds != nil }
    public mutating func useSteadyAlternative() {
        burstSeconds = nil
        if kind == .pursuit {
            kind = .discovery; duration = min(60, duration); audio = "investigate"; title = "도주 흔적 조사"
        } else {
            duration = 30; audio = steadyAudio ?? "boss"; title = title.replacingOccurrences(of: "가속", with: "유지")
        }
    }
}
public struct GameContent: Codable {
    public var schema: Int
    public var missionTitle: String
    public var events: [MissionTemplate]
    public var encounterPools: [EncounterPool]? = nil
    public init(schema: Int, missionTitle: String, events: [MissionTemplate], encounterPools: [EncounterPool]? = nil) {
        self.schema = schema; self.missionTitle = missionTitle; self.events = events; self.encounterPools = encounterPools
    }
    public func validate() throws {
        guard schema == 1, !events.isEmpty, Set(events.map(\.id)).count == events.count,
              events.allSatisfy({ !$0.id.isEmpty && $0.duration.isFinite && $0.duration > 0 && $0.hp.isFinite && $0.hp >= 0 && $0.startFraction > 0 && $0.startFraction < 0.9 && ($0.burstSeconds == nil || ($0.burstSeconds == 10 && ($0.kind == .boss || $0.kind == .pursuit) && $0.steadyAudio?.isEmpty == false)) && ($0.kind != .endurance || ($0.targetDistance.map { $0.isFinite && (400...800).contains($0) } ?? false)) }) else { throw ContentError.invalid }
        guard Set((encounterPools ?? []).map(\.slotID)).count == (encounterPools ?? []).count else { throw ContentError.invalid }
        let alternativeIDs = (encounterPools ?? []).flatMap { $0.alternatives.map(\.id) }
        guard Set(alternativeIDs).count == alternativeIDs.count, Set(alternativeIDs).isDisjoint(with: events.map(\.id)) else { throw ContentError.invalid }
        for pool in encounterPools ?? [] {
            guard events.contains(where: { $0.id == pool.slotID }), !pool.alternatives.isEmpty else { throw ContentError.invalid }
            try GameContent(schema: 1, missionTitle: missionTitle, events: pool.alternatives).validate()
        }
    }
    public enum ContentError: Error { case invalid }
}
public struct RunEvent: Codable {
    public var template: MissionTemplate
    public var stage: EventStage = .briefing
    public var elapsed: Double = 0
    public var qualified: Double = 0
    public var pushing: Double = 0
    public var hp: Double
    public var startingHP: Double
    public var baseline: Double
    public var evaluatedSeconds: Double = 0
    public var traveledDistance: Double? = nil
    public var burstStarted: Bool? = nil
    /// Active workout time when a non-accelerating encounter first lost GPS.
    public var signalDegradedSince: Double? = nil
    public var battle: DistanceBattle? = nil
    public init(template: MissionTemplate, stage: EventStage = .briefing, elapsed: Double = 0, qualified: Double = 0,
                pushing: Double = 0, hp: Double, startingHP: Double, baseline: Double, evaluatedSeconds: Double = 0,
                traveledDistance: Double? = nil, burstStarted: Bool? = nil, signalDegradedSince: Double? = nil,
                battle: DistanceBattle? = nil) {
        self.template = template; self.stage = stage; self.elapsed = elapsed; self.qualified = qualified; self.pushing = pushing
        self.hp = hp; self.startingHP = startingHP; self.baseline = baseline; self.evaluatedSeconds = evaluatedSeconds
        self.traveledDistance = traveledDistance; self.burstStarted = burstStarted; self.signalDegradedSince = signalDegradedSince; self.battle = battle
    }
    public var instructionAudio: String {
        burstStarted == true && elapsed > 0 ? "burst_resume" : template.audio
    }
    public var progress: Double {
        if battle != nil { return min(1, max(0, (startingHP - hp) / max(1, startingHP))) }
        if template.burstSeconds != nil && stage == .armed { return 0 }
        if template.kind == .endurance { return min(1, (traveledDistance ?? 0) / max(1, template.targetDistance ?? 400)) }
        return min(1, elapsed / max(1, template.burstSeconds ?? template.duration))
    }
}
public struct EventRecord: Codable, Identifiable {
    public var id: String
    public var title: String
    public var outcome: Outcome
    public var damage: Double
    public var defeated: Bool? = nil
    public var kind: EventKind? = nil
    public var accelerated: Bool? = nil
    public var encounterKind: EncounterKind? = nil
    public var monsterID: String? = nil
    public var attacks: Int? = nil
}
public struct RunSession: Codable, Identifiable {
    public var id = UUID()
    public var startedAt = Date()
    public var targetSeconds: Double
    public var simulated: Bool
    public var allowPursuit: Bool
    public var activeSeconds: Double = 0
    /// Unpaused workout time, including safe stops. Nil identifies an older save.
    public var workoutSeconds: Double? = nil
    /// Workout time from start to finish for new runs; older records retain
    /// their original wall-clock elapsed time.
    public var elapsedSeconds: Double? = nil
    public var runningSeconds: Double = 0
    public var distance: Double = 0
    /// Last spoken outdoor kilometer; nil only for saves created before distance announcements.
    public var announcedKilometers: Int? = nil
    public var phase: RunPhase = .calibrating
    public var manualPause = false
    public var interruption = false
    public var baseline: Double = 0
    public var baselineSamples: [Double] = []
    public var hp: Double = 100
    public var event: RunEvent?
    public var records: [EventRecord] = []
    public var consumed: Set<String> = []
    public var lastIntensityAt: Double = -1000
    public var intensityCount = 0
    public var withdrawn = false
    public var recoveryUntil: Double = 0
    public var lastTimestamp: Double?
    public var movingStreak: Double = 0
    public var stationarySeconds: Double = 0
    public var mode: RunMode? = nil
    public var loadout: CombatStats? = nil
    public var missionSnapshot: GameContent? = nil
    public var goal: ActivityGoal? = nil
    public var boss: BossEncounter? = nil
    public var paceObservation: PaceObservation? = nil
    public var learnedReference: Double? = nil
    public var paceCooldownUntil: Double? = nil
    public var directorVersion: Int? = nil
    public var questID: String? = nil
    /// Nil means this activity was saved before the completion-based rules.
    public var rulesVersion: Int? = nil
    public var purpose: ActivityPurpose? = nil
    public var gateTracking: Bool? = nil
    public var gateScheduled: Bool? = nil
    public var gateOpportunityQualified: Bool? = nil
    public var gatePresented: Bool? = nil
    public var gateWindowFraction: Double? = nil
    /// An actively tracked hunting quest keeps its required encounter available.
    public var priorityEncounterID: String? = nil
    public var environment: ActivityEnvironment? = nil
    public var steps: Int? = nil
    /// Recent pedometer evidence for the final rescue's GPS-safe observation route.
    public var lastVerifiedStepAt: Double? = nil
    /// Remaining KST daily active-time budget at the start; nil supports older saves.
    public var indoorAllowance: Double? = nil
    /// 검증 실행기에서만 명시적으로 켠다. 기존 진행 중인 활동은 nil을 유지한다.
    public var combatRules: CombatRules? = nil
    public var needsDistanceBaseline: Bool? = nil
    public var distanceBarrierTimestamp: Double? = nil
    public var combatBarrierTimestamp: Double? = nil
    /// 활동 시작 시 고정. 이전 기록에는 착용 장비를 소급해서 넣지 않는다.
    public var equipmentIDs: [String]? = nil
    public var lastEncounterEndedAt: Double? = nil
    public var calibrationSeconds: Double { activityGoal.kind == .time ? min(180, targetSeconds * 0.1) : 60 }
    public init(targetSeconds: Double, simulated: Bool, allowPursuit: Bool, mode: RunMode? = nil, loadout: CombatStats? = nil) {
        self.targetSeconds = max(60, targetSeconds); self.simulated = simulated; self.allowPursuit = allowPursuit
        self.announcedKilometers = 0
        self.paceObservation = PaceObservation()
        self.mode = mode; self.loadout = loadout; self.hp = loadout?.hp ?? 100
    }
}
public struct RunSummary: Codable, Identifiable {
    public var id: UUID
    public var date: Date
    public var seconds: Double
    /// Nil for records created before elapsed time was saved.
    public var elapsedSeconds: Double? = nil
    public var distance: Double
    public var xp: Int
    public var crystals: Int
    public var records: [EventRecord]
    public var goal: ActivityGoal? = nil
    public var runningSeconds: Double? = nil
    public var completedGoal: Bool
    public var mode: RunMode? = nil
    public var research: Int? = nil
    public var cores: Int? = nil
    public var majorBoss: BossReport? = nil
    public var paceReport: PaceReport? = nil
    public var questID: String? = nil
    public var environment: ActivityEnvironment? = nil
    public var steps: Int? = nil
    // Nil preserves the full-rate meaning of previously settled activity records.
    public var rewardPercent: Int? = nil
    public var completion: CompletionKind? = nil
    public var foundGifts: [OperatorGift]? = nil
    public var growthReport: ActivityGrowthReport? = nil
}
public struct Profile: Codable {
    public var name = "헌터"
    public var xp = 0
    public var crystals = 0
    public var research = 0
    public var observationLevel = 1
    public var settled: Set<UUID> = []
    public var runs: [RunSummary] = []
    public var expeditions: ExpeditionState? = nil
    public var progression: GrowthState? = nil
    public var bosses: [String: BossState]? = nil
    public var readStories: Set<String>? = nil
    public var introductionSeen: Bool? = nil
    public var discoveredEvents: Set<String>? = nil
    public var paceMemory: PaceMemory? = nil
    public var journey: JourneyState? = nil
    /// Optional so pre-campaign profiles decode without changing their progression.
    public var defense: DefenseProgress? = nil
    public var growthEconomy: GrowthEconomyState? = nil
    public var equipmentJournal: EquipmentJournal? = nil
    public var equipmentRevision: EquipmentRevisionState? = nil
    /// Nil identifies a profile that still needs its historical gate count frozen.
    public var gateProgress: GateProgress? = GateProgress()
    public var growth: GrowthState {
        get { progression ?? { var initial = GrowthState(); initial.departments[Department.observation.rawValue] = min(2, max(1, observationLevel)); return initial }() }
        set { progression = newValue }
    }
    public var level: Int { growthEconomy.map { GrowthEconomy.resolved($0, totalXP: xp).level } ?? (1 + xp / 300) }
    public var attack: Double { growthEconomy == nil ? 1 + Double(level - 1) * 0.08 : GrowthEconomy.baseAttack(level) }
    public init() {}
}
public struct SaveState: Codable {
    public var schema = 1
    public var profile = Profile()
    public var active: RunSession?
    public init() {}
}
public enum GameCue: Equatable {
    case voice(String)
    case distanceMilestone(Int)
    case checkpoint
    case goalReached
}
