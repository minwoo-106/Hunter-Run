import XCTest
@testable import HunterCore

final class RunEngineTests: XCTestCase {
    func content(kind: EventKind = .maintain, start: Double = 0.15, duration: Double = 20) -> GameContent {
        GameContent(schema: 1, missionTitle: "Test", events: [MissionTemplate(id: "first", title: "First", kind: kind, startFraction: start, duration: duration, hp: 100, audio: "maintain")])
    }
    func make(kind: EventKind = .maintain, simulated: Bool = false) -> RunEngine {
        RunEngine(session: RunSession(targetSeconds: 600, simulated: simulated, allowPursuit: true), content: content(kind: kind))
    }
    @discardableResult func step(_ engine: inout RunEngine, _ t: Double, movement: Movement = .running, signal: Signal = .good, speed: Double = 2.5) -> [GameCue] {
        engine.consume(SensorFrame(timestamp: t, speed: speed, distance: speed, movement: movement, signal: signal))
    }
    func testStationaryCandidateNeverLowersEventScore() {
        var e = make()
        for t in 0...95 { step(&e, Double(t)) }
        e.instructionFinished()
        for t in 96...100 { step(&e, Double(t)) }
        let elapsed = e.session.event!.elapsed
        let activity = e.session.activeSeconds
        for t in 101...113 { step(&e, Double(t), movement: .stationary, speed: 0) }
        XCTAssertEqual(e.session.event!.elapsed, elapsed)
        XCTAssertEqual(e.session.activeSeconds, activity)
        XCTAssertEqual(e.session.phase, .paused)
        for t in 114...118 { step(&e, Double(t)) }
        XCTAssertEqual(e.session.phase, .moving)
        XCTAssertTrue(e.session.records.isEmpty)
    }
    func testManualPauseDoesNotResumeFromMovement() {
        var e = make(); step(&e, 0); step(&e, 1); e.pause(true)
        for t in 2...30 { step(&e, Double(t)) }
        XCTAssertTrue(e.session.manualPause)
        XCTAssertEqual(e.session.activeSeconds, 1)
        XCTAssertEqual(e.session.phase, .paused)
    }
    func testSensorDeliveryGapAddsNoDistanceOrTime() {
        var e = make(); step(&e, 0); step(&e, 1)
        let distance = e.session.distance
        step(&e, 60)
        XCTAssertEqual(e.session.activeSeconds, 1)
        XCTAssertEqual(e.session.distance, distance)
    }
    func testVehicleAddsNoProgress() {
        var e = make(); step(&e, 0)
        for t in 1...30 { step(&e, Double(t), movement: .vehicle, speed: 15) }
        XCTAssertEqual(e.session.distance, 0)
        XCTAssertEqual(e.session.activeSeconds, 0)
    }
    func testInstructionMustFinishBeforeScoring() {
        var e = make()
        for t in 0...105 { step(&e, Double(t)) }
        XCTAssertEqual(e.session.event!.elapsed, 0)
        e.instructionFinished(); step(&e, 106)
        XCTAssertEqual(e.session.event!.elapsed, 1)
    }
    func testBadGPSClosesCombatNeutrally() {
        var e = make()
        for t in 0...95 { step(&e, Double(t)) }
        e.instructionFinished()
        step(&e, 96, signal: .unavailable)
        XCTAssertNil(e.session.event)
        XCTAssertEqual(e.session.records.first?.outcome, .neutral)
        XCTAssertEqual(e.session.hp, 100)
    }
    func testPursuitDeclineChangesToInvestigationWithoutDamage() {
        var e = make(kind: .pursuit)
        for t in 0...95 { step(&e, Double(t)) }
        e.instructionFinished()
        for t in 96...111 { step(&e, Double(t)) }
        XCTAssertEqual(e.session.event?.template.kind, .discovery)
        XCTAssertEqual(e.session.hp, 100)
        XCTAssertEqual(e.session.intensityCount, 0)
    }
    func testWalkingCountsActivityButDoesNotScoreMaintain() {
        var e = make()
        for t in 0...95 { step(&e, Double(t)) }
        e.instructionFinished()
        let running = e.session.runningSeconds
        step(&e, 96, movement: .walking, speed: 1.2)
        XCTAssertEqual(e.session.activeSeconds, 96)
        XCTAssertEqual(e.session.runningSeconds, running)
        XCTAssertEqual(e.session.event?.elapsed, 0)
    }
    func testGoalEndsRunAndSettlementIsIdempotent() {
        var e = make()
        for t in 0...605 { step(&e, Double(t)); e.instructionFinished() }
        XCTAssertEqual(e.session.phase, .finished)
        XCTAssertEqual(e.session.activeSeconds, 600)
        var p = Profile()
        XCTAssertNotNil(Settlement.apply(e.session, to: &p))
        let xp = p.xp
        XCTAssertNil(Settlement.apply(e.session, to: &p))
        XCTAssertEqual(p.xp, xp)
        XCTAssertEqual(p.runs.count, 1)
    }
    func testSimulationCannotAwardRealProgress() {
        var e = make(simulated: true); step(&e, 0); step(&e, 1); e.end()
        var p = Profile()
        XCTAssertNil(Settlement.apply(e.session, to: &p))
        XCTAssertEqual(p.xp, 0)
    }
    func testRecoveryRebriefsAndDoesNotCountOfflineGap() throws {
        var e = make()
        for t in 0...95 { step(&e, Double(t)) }; e.instructionFinished(); step(&e, 96)
        let data = try JSONEncoder().encode(e.session)
        var restored = RunEngine(session: try JSONDecoder().decode(RunSession.self, from: data), content: content())
        restored.restorePaused()
        step(&restored, 10000)
        XCTAssertEqual(restored.session.activeSeconds, 96)
        XCTAssertEqual(restored.session.event?.stage, .briefing)
        XCTAssertTrue(restored.session.manualPause)
    }
    func testReplayTimestampAndNonFiniteInputAreIgnored() {
        var e = make(); step(&e, 10); step(&e, 11)
        step(&e, 10); step(&e, .nan); step(&e, 11)
        XCTAssertEqual(e.session.activeSeconds, 1)
    }
    func testSaveRoundtripAndCorruptCurrentFallback() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let repo = SaveRepository(directory: dir)
        var save = SaveState(); save.profile.xp = 20
        try repo.write(save)
        save.profile.xp = 40; try repo.write(save)
        XCTAssertEqual(try repo.load().profile.xp, 40)
        try Data("corrupt".utf8).write(to: dir.appendingPathComponent("save.json"))
        XCTAssertEqual(try repo.load().profile.xp, 20)
    }
    func testBothCorruptDoNotSilentlyResetProgress() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let repo = SaveRepository(directory: dir); try repo.write(SaveState())
        try Data("bad".utf8).write(to: dir.appendingPathComponent("save.json"))
        XCTAssertThrowsError(try repo.load())
    }
}

