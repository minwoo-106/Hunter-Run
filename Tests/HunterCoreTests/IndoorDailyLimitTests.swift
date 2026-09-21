import XCTest
@testable import HunterCore

final class IndoorDailyLimitTests: XCTestCase {
    private let day = ISO8601DateFormatter().date(from: "2026-09-13T10:00:00+09:00")!
    private let content = GameContent(schema: 1, missionTitle: "Indoor", events: [])
    private func session(_ seconds: Double = 0, environment: ActivityEnvironment = .indoor, date: Date? = nil) -> RunSession {
        var run = RunSession(targetSeconds: 1200, simulated: false, allowPursuit: false)
        run.environment = environment; run.goal = ActivityGoal(kind: .free); run.activeSeconds = seconds
        run.startedAt = date ?? day; return run
    }
    private func settle(_ seconds: Double, profile: inout Profile, environment: ActivityEnvironment = .indoor, date: Date? = nil) {
        var run = session(seconds, environment: environment, date: date); run.phase = .finished
        XCTAssertNotNil(Settlement.apply(run, to: &profile))
    }
    private func frame(_ date: Date, moving: Bool = true) -> SensorFrame {
        SensorFrame(timestamp: date.timeIntervalSince1970, speed: 2, distance: 2, movement: moving ? .running : .stationary, signal: .good)
    }
    func testSeparateSessionsShareRemainingBudgetAndSettleOnlyOnce() throws {
        var profile = Profile()
        settle(1200, profile: &profile); settle(1200, profile: &profile)
        XCTAssertEqual(IndoorDailyLimit.remaining(in: profile, on: day), 1200)
        var run = session(1198.5); IndoorDailyLimit.prepare(&run, profile: profile)
        XCTAssertEqual(run.activeTimeLimit, 1200)
        var engine = RunEngine(session: run, content: content)
        engine.consume(frame(day)); let cues = engine.consume(frame(day.addingTimeInterval(5)))
        XCTAssertEqual(engine.session.activeSeconds, 1200); XCTAssertEqual(engine.session.phase, .finished)
        XCTAssertEqual(cues.filter { $0 == .goalReached }.count, 1)
        XCTAssertNotNil(Settlement.apply(engine.session, to: &profile))
        XCTAssertNil(Settlement.apply(engine.session, to: &profile))
        XCTAssertEqual(IndoorDailyLimit.remaining(in: profile, on: day), 0)
        var blocked = session(); IndoorDailyLimit.prepare(&blocked, profile: profile)
        XCTAssertEqual(blocked.activeTimeLimit, 0); XCTAssertTrue(blocked.reachedGoal)
    }
    func testLegacyTreadmillAndStationaryShareQuotaButOutdoorAndPreviousDayDoNot() throws {
        var profile = Profile()
        settle(1000, profile: &profile, environment: .indoorStationary)
        settle(900, profile: &profile, environment: .indoorTreadmill)
        settle(7200, profile: &profile, environment: .outdoor)
        settle(3600, profile: &profile, date: day.addingTimeInterval(-86400))
        profile = try JSONDecoder().decode(Profile.self, from: JSONEncoder().encode(profile))
        XCTAssertEqual(IndoorDailyLimit.remaining(in: profile, on: day), 1700)
        XCTAssertEqual(ActivityEnvironment.allCases, [.outdoor, .indoor])
        XCTAssertEqual(try JSONDecoder().decode(ActivityEnvironment.self, from: Data("\"indoorTreadmill\"".utf8)).title, "실내 러닝")
    }
    func testRemainingSecondsSurvivePauseRelaunchAndLegacyRecovery() throws {
        var profile = Profile(); settle(3590, profile: &profile)
        var run = session(8); IndoorDailyLimit.prepare(&run, profile: profile)
        let saved = try JSONEncoder().encode(run)
        var recovered = try JSONDecoder().decode(RunSession.self, from: saved)
        IndoorDailyLimit.prepare(&recovered, profile: profile)
        var engine = RunEngine(session: recovered, content: content); engine.restorePaused()
        engine.consume(frame(day)); engine.consume(frame(day.addingTimeInterval(4)))
        XCTAssertEqual(engine.session.activeSeconds, 8); XCTAssertEqual(engine.session.indoorAllowance, 10)
        engine.pause(false); engine.consume(frame(day.addingTimeInterval(10))); engine.consume(frame(day.addingTimeInterval(15)))
        XCTAssertEqual(engine.session.activeSeconds, 10); XCTAssertEqual(engine.session.phase, .finished)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: saved) as? [String: Any]); object.removeValue(forKey: "indoorAllowance")
        var legacy = try JSONDecoder().decode(RunSession.self, from: JSONSerialization.data(withJSONObject: object))
        IndoorDailyLimit.prepare(&legacy, profile: profile); XCTAssertEqual(legacy.activeTimeLimit, 10)
    }
    func testKoreanMidnightResetsAllowanceAndEndsPausedPreviousDayRun() {
        let midnight = ISO8601DateFormatter().date(from: "2026-09-13T15:00:00Z")!
        XCTAssertEqual(IndoorDailyLimit.end(of: day), midnight)
        var profile = Profile(); settle(1800, profile: &profile)
        var run = session(300); IndoorDailyLimit.prepare(&run, profile: profile)
        var engine = RunEngine(session: run, content: content); engine.restorePaused()
        let cues = engine.consume(frame(midnight))
        XCTAssertEqual(engine.session.phase, .finished); XCTAssertEqual(engine.session.activeSeconds, 300)
        XCTAssertTrue(cues.contains(.goalReached)); XCTAssertTrue(engine.consume(frame(midnight.addingTimeInterval(1))).isEmpty)
        XCTAssertNotNil(Settlement.apply(engine.session, to: &profile))
        XCTAssertEqual(IndoorDailyLimit.used(in: profile, on: midnight.addingTimeInterval(-1)), 2100)
        XCTAssertEqual(IndoorDailyLimit.remaining(in: profile, on: midnight), 3600)
        var next = session(date: midnight); IndoorDailyLimit.prepare(&next, profile: profile)
        XCTAssertEqual(next.activeTimeLimit, 3600)
    }
    func testStoppedExerciseDoesNotSpendDailyBudgetAndOutdoorHasNoNewLimit() {
        var profile = Profile(); settle(1200, profile: &profile)
        var run = session(); IndoorDailyLimit.prepare(&run, profile: profile)
        var engine = RunEngine(session: run, content: content)
        for second in 0...4000 { engine.consume(frame(day.addingTimeInterval(Double(second)), moving: false)) }
        engine.end(); XCTAssertNil(Settlement.apply(engine.session, to: &profile))
        XCTAssertEqual(IndoorDailyLimit.remaining(in: profile, on: day), 2400)
        var outdoor = session(7199, environment: .outdoor); IndoorDailyLimit.prepare(&outdoor, profile: profile)
        XCTAssertNil(outdoor.indoorAllowance); XCTAssertNil(outdoor.activeTimeLimit)
        var outside = RunEngine(session: outdoor, content: content)
        outside.consume(frame(day)); outside.consume(frame(day.addingTimeInterval(3)))
        XCTAssertEqual(outside.session.activeSeconds, 7202); XCTAssertNotEqual(outside.session.phase, .finished)
    }
    func testShorterGoalAndExhaustedLegacyDayCannotGainAdditionalTime() {
        var profile = Profile(); settle(2400, profile: &profile)
        var run = session(); run.goal = ActivityGoal(kind: .time, value: 300)
        IndoorDailyLimit.prepare(&run, profile: profile); XCTAssertEqual(run.activeTimeLimit, 300)
        settle(1200, profile: &profile)
        var recovered = session(100, environment: .indoorTreadmill)
        IndoorDailyLimit.prepare(&recovered, profile: profile)
        var engine = RunEngine(session: recovered, content: content)
        engine.consume(frame(day)); engine.consume(frame(day.addingTimeInterval(1)))
        XCTAssertEqual(engine.session.activeSeconds, 100); XCTAssertEqual(engine.session.phase, .finished)
    }
}
