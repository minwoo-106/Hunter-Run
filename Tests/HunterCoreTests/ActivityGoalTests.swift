import XCTest
@testable import HunterCore

final class ActivityGoalTests: XCTestCase {
    private func engine(_ goal: ActivityGoal) -> RunEngine {
        var session = RunSession(targetSeconds: 1200, simulated: false, allowPursuit: false, mode: .exploration)
        session.goal = goal
        return RunEngine(session: session, content: GameContent(schema: 1, missionTitle: "Patrol", events: [
            MissionTemplate(id: "trace", title: "Trace", kind: .discovery, startFraction: 0.13, duration: 10, hp: 0, audio: "investigate")
        ]))
    }
    @discardableResult private func step(_ engine: inout RunEngine, _ time: Int, speed: Double = 2.5, movement: Movement = .running) -> [GameCue] {
        engine.consume(SensorFrame(timestamp: Double(time), speed: speed, distance: speed, movement: movement, signal: .good))
    }
    func testDistanceEndsExactlyAtGoalAndSettlesOnce() throws {
        var e = engine(ActivityGoal(kind: .distance, value: 1000))
        var endings = 0
        for t in 0...450 { endings += step(&e, t, speed: 3).filter { $0 == .goalReached }.count; e.instructionFinished() }
        XCTAssertEqual(e.session.phase, .finished)
        XCTAssertEqual(e.session.distance, 1000, accuracy: 0.0001)
        XCTAssertEqual(e.session.activeSeconds, 1000 / 3, accuracy: 0.0001)
        XCTAssertEqual(endings, 1)
        var profile = Profile()
        let summary = try XCTUnwrap(Settlement.apply(e.session, to: &profile))
        XCTAssertTrue(summary.completedGoal)
        XCTAssertEqual(summary.goal?.kind, .distance)
        XCTAssertNil(Settlement.apply(e.session, to: &profile))
    }
    func testDistanceDoesNotEndAtOldTimeLimit() throws {
        var e = engine(ActivityGoal(kind: .distance, value: 5000))
        for t in 0...1250 { step(&e, t, speed: 1, movement: .walking); e.instructionFinished() }
        XCTAssertNotEqual(e.session.phase, .finished)
        XCTAssertGreaterThan(e.session.activeSeconds, e.session.targetSeconds)
        var save = SaveState(); save.active = e.session
        XCTAssertNoThrow(try SaveRepository(directory: FileManager.default.temporaryDirectory).validate(save))
    }
    func testFreePatrolRepeatsWithoutDuplicateRecordIDsAndRequiresManualEnd() throws {
        var e = engine(ActivityGoal(kind: .free))
        for t in 0...2600 { step(&e, t); e.instructionFinished() }
        XCTAssertNotEqual(e.session.phase, .finished)
        XCTAssertEqual(e.session.records.count, 3)
        XCTAssertEqual(Set(e.session.records.map(\.id)).count, 3)
        XCTAssertEqual(Set(e.session.records.map(\.catalogID)), ["trace"])
        e.end()
        var profile = Profile()
        let summary = try XCTUnwrap(Settlement.apply(e.session, to: &profile))
        XCTAssertFalse(summary.completedGoal)
        XCTAssertGreaterThan(summary.crystals, 0)
        XCTAssertEqual(summary.goal?.kind, .free)
    }
    func testDistancePauseVehicleAndGapCannotCompleteGoal() {
        var e = engine(ActivityGoal(kind: .distance, value: 1000))
        for t in 0...10 { step(&e, t) }
        let original = e.session.distance
        e.pause(true)
        for t in 11...500 { step(&e, t) }
        XCTAssertEqual(e.session.distance, original)
        e.pause(false)
        step(&e, 501); step(&e, 600)
        step(&e, 601, speed: 20, movement: .vehicle)
        XCTAssertEqual(e.session.distance, original)
        XCTAssertFalse(e.session.reachedGoal)
    }
    func testGoalSurvivesEncodingAndRecoveryWithoutProgressJump() throws {
        var e = engine(ActivityGoal(kind: .distance, value: 1000))
        for t in 0...100 { step(&e, t) }
        let decoded = try JSONDecoder().decode(RunSession.self, from: JSONEncoder().encode(e.session))
        var recovered = RunEngine(session: decoded, content: e.content)
        recovered.restorePaused()
        step(&recovered, 10000)
        XCTAssertEqual(recovered.session.distance, 250)
        XCTAssertEqual(recovered.session.goal, e.session.goal)
        recovered.pause(false); step(&recovered, 10001); step(&recovered, 10002)
        XCTAssertEqual(recovered.session.distance, 252.5)
    }
    func testLegacySessionRemainsTimeGoal() throws {
        let session = RunSession(targetSeconds: 300, simulated: false, allowPursuit: false)
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(session)) as? [String: Any])
        json.removeValue(forKey: "goal")
        let decoded = try JSONDecoder().decode(RunSession.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertEqual(decoded.activityGoal, ActivityGoal(kind: .time, value: 300))
    }
    func testInvalidGoalImportRejected() {
        for goal in [ActivityGoal(kind: .distance, value: -1), ActivityGoal(kind: .distance, value: .infinity), ActivityGoal(kind: .free, value: 100), ActivityGoal(kind: .time, value: 0)] {
            var save = SaveState(); save.active = engine(goal).session
            XCTAssertThrowsError(try SaveRepository(directory: FileManager.default.temporaryDirectory).validate(save))
        }
    }
    func testRepeatedGateCoreCountsAsOneGateClearAndOneCore() {
        var session = engine(ActivityGoal(kind: .free)).session
        session.mode = .gate; session.phase = .finished
        session.records = [EventRecord(id: "gate-core#1", title: "Core", outcome: .success, damage: 85, defeated: true, kind: .boss), EventRecord(id: "gate-core#2", title: "Core", outcome: .success, damage: 85, defeated: true, kind: .boss)]
        var profile = Profile()
        Settlement.apply(session, to: &profile)
        XCTAssertEqual(profile.growth.cores, 1)
        XCTAssertEqual(Progression.gateClears(profile), 1)
    }
}
