import Foundation

public enum ReplayCommand: String, Codable {
    case frame, pause, resume, instructionFinished, recover, finish, settle, beginSession
}
public struct ReplayOperation: Codable {
    public var command: ReplayCommand
    public var frame: SensorFrame?
    public var session: RunSession?
    public var content: GameContent?
    public init(_ command: ReplayCommand, frame: SensorFrame? = nil, session: RunSession? = nil, content: GameContent? = nil) {
        self.command = command; self.frame = frame; self.session = session; self.content = content
    }
}
public struct ReplayExpectation: Codable {
    public var metric: String
    public var equals: Double
    public init(_ metric: String, _ equals: Double) { self.metric = metric; self.equals = equals }
}
public struct ReplayScenario: Codable {
    public var schema: Int = 1
    public var name: String
    public var note: String
    public var profile: Profile
    public var session: RunSession
    public var content: GameContent
    public var operations: [ReplayOperation]
    public var expected: [ReplayExpectation]
    public init(name: String, note: String, profile: Profile, session: RunSession, content: GameContent,
                operations: [ReplayOperation], expected: [ReplayExpectation]) {
        self.name = name; self.note = note; self.profile = profile; self.session = session
        self.content = content; self.operations = operations; self.expected = expected
    }
}
public struct ReplaySnapshot: Codable {
    public var operation: String
    public var timestamp: Double?
    public var phase: RunPhase
    public var movement: Movement?
    public var signal: Signal?
    public var activeSeconds: Double
    public var workoutSeconds: Double
    public var distance: Double
    public var enemyHP: Double?
    public var remainder: Double
    public var attacks: Int
    public var damage: Double
    public var records: Int
    public var gainedXP: Int
    public var level: Int
    public var settlements: Int
    public var cues: [String]
    public func value(_ metric: String) -> Double? {
        switch metric {
        case "attacks": return Double(attacks)
        case "enemyHP": return enemyHP
        case "damage": return damage
        case "records": return Double(records)
        case "gainedXP": return Double(gainedXP)
        case "level": return Double(level)
        case "settlements": return Double(settlements)
        case "remainder": return remainder
        case "activeSeconds": return activeSeconds
        case "workoutSeconds": return workoutSeconds
        case "distance": return distance
        case "finished": return phase == .finished ? 1 : 0
        default: return nil
        }
    }
}
public struct ReplayCheck: Codable {
    public var metric: String
    public var expected: Double
    public var actual: Double?
    public var passed: Bool
}
public struct ReplayResult: Codable {
    public var name: String
    public var note: String
    public var steps: [ReplaySnapshot]
    public var checks: [ReplayCheck]
    public var passed: Bool { !checks.isEmpty && checks.allSatisfy(\.passed) }
}
public enum ReplayError: LocalizedError {
    case invalidScenario, missingPayload, activeSession
    public var errorDescription: String? {
        switch self {
        case .invalidScenario: return "재생 자료의 형식이나 규칙을 확인할 수 없습니다."
        case .missingPayload: return "재생 명령에 필요한 입력이 없습니다."
        case .activeSession: return "현재 세션을 종료한 뒤 다음 세션을 시작해야 합니다."
        }
    }
}

/// 실제 RunEngine·Settlement를 사용한다. 프로필은 메모리 복사본이며 실사용 저장소를 열지 않는다.
public struct DebugReplayRunner {
    public private(set) var engine: RunEngine
    public private(set) var profile: Profile
    private let initialXP: Int
    private let initialSettlements: Int
    public init(profile: Profile, session: RunSession, content: GameContent) {
        self.profile = profile; engine = RunEngine(session: session, content: content)
        initialXP = profile.xp; initialSettlements = profile.settled.count
    }
    @discardableResult public mutating func apply(_ operation: ReplayOperation) throws -> ReplaySnapshot {
        var cues: [GameCue] = []
        switch operation.command {
        case .frame:
            guard let frame = operation.frame else { throw ReplayError.missingPayload }
            cues = engine.consume(frame)
        case .pause: engine.pause(true)
        case .resume: engine.pause(false)
        case .instructionFinished: engine.instructionFinished()
        case .recover:
            let restored = try JSONDecoder().decode(RunSession.self, from: JSONEncoder().encode(engine.session))
            profile = try JSONDecoder().decode(Profile.self, from: JSONEncoder().encode(profile))
            engine = RunEngine(session: restored, content: engine.content); engine.restorePaused()
        case .finish: engine.end(at: engine.session.startedAt.addingTimeInterval(engine.session.workoutSeconds ?? engine.session.activeSeconds))
        case .settle: Settlement.apply(engine.session, to: &profile)
        case .beginSession:
            guard engine.session.phase == .finished else { throw ReplayError.activeSession }
            guard let session = operation.session, let content = operation.content else { throw ReplayError.missingPayload }
            try Self.validate(session: session, content: content)
            engine = RunEngine(session: session, content: content)
        }
        return snapshot(operation: operation.command.rawValue, frame: operation.frame, cues: cues)
    }
    public func snapshot(operation: String = "준비", frame: SensorFrame? = nil, cues: [GameCue] = []) -> ReplaySnapshot {
        let run = engine.session
        let last = run.records.last
        let lastMonster = run.combatRules?.monsters.first { $0.id == last?.monsterID }
        let hp = run.event?.hp ?? run.boss?.remainingHP ?? lastMonster.map { max(0, $0.maximumHP - (last?.damage ?? 0)) }
        return ReplaySnapshot(operation: operation, timestamp: frame.flatMap { $0.timestamp.isFinite ? $0.timestamp : nil },
            phase: run.phase, movement: frame?.movement, signal: frame?.signal,
            activeSeconds: run.activeSeconds, workoutSeconds: run.workoutSeconds ?? run.activeSeconds, distance: run.distance,
            enemyHP: hp, remainder: run.event?.battle?.remainder ?? 0,
            attacks: run.records.reduce(0) { $0 + ($1.attacks ?? 0) } + (run.event?.battle?.attacks ?? 0),
            damage: run.records.reduce(0) { $0 + $1.damage } + (run.event.map { max(0, $0.startingHP - $0.hp) } ?? 0),
            records: run.records.count, gainedXP: profile.xp - initialXP, level: profile.level,
            settlements: profile.settled.count - initialSettlements,
            cues: cues.map { cue in
                switch cue {
                case .voice(let key): return key
                case .checkpoint: return "저장 시점"
                case .goalReached: return "목표 완료"
                case .distanceMilestone(let km): return "\(km)km 안내"
                }
            })
    }
    private static func validate(session: RunSession, content: GameContent) throws {
        try content.validate()
        let repository = SaveRepository(directory: FileManager.default.temporaryDirectory)
        var temporary = SaveState(); temporary.active = session
        try repository.validate(temporary)
    }
    public static func run(_ scenario: ReplayScenario) throws -> ReplayResult {
        guard scenario.schema == 1, !scenario.name.isEmpty, scenario.operations.count <= 100_000 else { throw ReplayError.invalidScenario }
        try validate(session: scenario.session, content: scenario.content)
        var save = SaveState(); save.profile = scenario.profile
        try SaveRepository(directory: FileManager.default.temporaryDirectory).validate(save)
        var runner = DebugReplayRunner(profile: scenario.profile, session: scenario.session, content: scenario.content)
        var steps = [runner.snapshot()]
        for operation in scenario.operations { steps.append(try runner.apply(operation)) }
        let last = steps.last!
        let checks = scenario.expected.map { expectation -> ReplayCheck in
            let actual = last.value(expectation.metric)
            return ReplayCheck(metric: expectation.metric, expected: expectation.equals, actual: actual,
                passed: actual.map { abs($0 - expectation.equals) < 0.000001 } ?? false)
        }
        return ReplayResult(name: scenario.name, note: scenario.note, steps: steps, checks: checks)
    }
}
