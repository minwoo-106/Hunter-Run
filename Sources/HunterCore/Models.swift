import Foundation

public enum Movement: String, Codable, CaseIterable { case unknown, stationary, walking, running, vehicle }
public enum Signal: String, Codable { case good, degraded, unavailable }
public enum RunPhase: String, Codable { case calibrating, moving, paused, interrupted, finished }
public enum EventKind: String, Codable { case discovery, maintain, pursuit, boss }
public enum EventStage: String, Codable { case briefing, armed, active }
public enum Outcome: String, Codable { case perfect, success, partial, fail, neutral }
public struct SensorFrame {
    public var timestamp: TimeInterval
    public var speed: Double
    public var distance: Double
    public var movement: Movement
    public var signal: Signal
    public init(timestamp: TimeInterval, speed: Double, distance: Double, movement: Movement, signal: Signal) {
        self.timestamp = timestamp; self.speed = speed; self.distance = distance; self.movement = movement; self.signal = signal
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
}
public struct GameContent: Codable {
    public var schema: Int
    public var missionTitle: String
    public var events: [MissionTemplate]
    public func validate() throws {
        guard schema == 1, !events.isEmpty, Set(events.map(\.id)).count == events.count,
              events.allSatisfy({ !$0.id.isEmpty && $0.duration > 0 && $0.hp >= 0 && $0.startFraction > 0 && $0.startFraction < 0.9 }) else { throw ContentError.invalid }
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
}
public struct EventRecord: Codable, Identifiable {
    public var id: String
    public var title: String
    public var outcome: Outcome
    public var damage: Double
    public var defeated: Bool? = nil
    public var kind: EventKind? = nil
}
public struct RunSession: Codable, Identifiable {
    public var id = UUID()
    public var startedAt = Date()
    public var targetSeconds: Double
    public var simulated: Bool
    public var allowPursuit: Bool
    public var activeSeconds: Double = 0
    public var runningSeconds: Double = 0
    public var distance: Double = 0
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
    public var calibrationSeconds: Double { activityGoal.kind == .time ? min(180, targetSeconds * 0.1) : 60 }
    public init(targetSeconds: Double, simulated: Bool, allowPursuit: Bool, mode: RunMode? = nil, loadout: CombatStats? = nil) {
        self.targetSeconds = max(60, targetSeconds); self.simulated = simulated; self.allowPursuit = allowPursuit
        self.mode = mode; self.loadout = loadout; self.hp = loadout?.hp ?? 100
    }
}
public struct RunSummary: Codable, Identifiable {
    public var id: UUID
    public var date: Date
    public var seconds: Double
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
}
public struct Profile: Codable {
    public var name = "헌터"
    public var xp = 0
    public var crystals = 0
    public var research = 0
    public var observationLevel = 1
    public var settled: Set<UUID> = []
    public var runs: [RunSummary] = []
    public var progression: GrowthState? = nil
    public var bosses: [String: BossState]? = nil
    public var growth: GrowthState {
        get { progression ?? { var initial = GrowthState(); initial.departments[Department.observation.rawValue] = min(2, max(1, observationLevel)); return initial }() }
        set { progression = newValue }
    }
    public var level: Int { 1 + xp / 300 }
    public var attack: Double { 1 + Double(level - 1) * 0.08 }
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
    case checkpoint
    case goalReached
}
