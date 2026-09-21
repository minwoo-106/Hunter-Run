import XCTest
@testable import HunterCore

final class IndoorActivityTests: XCTestCase {
    func testStationaryNoiseAndSingleShakeDoNotQualify() {
        var tracker = IndoorMovementTracker()
        for i in 0..<250 { tracker.observeAcceleration(0.02, at: Double(i) / 25) }
        XCTAssertFalse(tracker.isMoving(at: 9.96))
        tracker.observeAcceleration(0.5, at: 10)
        XCTAssertFalse(tracker.isMoving(at: 10))
    }
    func testRhythmicHandMotionQualifiesThenExpiresWhenStopped() {
        var tracker = IndoorMovementTracker()
        for i in 0..<125 { tracker.observeAcceleration(i % 12 == 0 ? 0.3 : 0.01, at: Double(i) / 25) }
        XCTAssertTrue(tracker.isMoving(at: 4.96))
        for i in 125..<175 { tracker.observeAcceleration(0.01, at: Double(i) / 25) }
        XCTAssertFalse(tracker.isMoving(at: 6.96))
    }
    func testPedometerDoesNotKeepActivityAliveForever() {
        var tracker = IndoorMovementTracker()
        tracker.observeSteps(count: 8, elapsed: 4, at: 10)
        XCTAssertTrue(tracker.isMoving(at: 11))
        XCTAssertFalse(tracker.isMoving(at: 14))
        tracker.observeSteps(count: 80, elapsed: 40, at: 15)
        XCTAssertFalse(tracker.isMoving(at: 15))
    }
    func engine(kind: EventKind = .boss) -> RunEngine {
        var session = RunSession(targetSeconds: 600, simulated: false, allowPursuit: false)
        session.environment = .indoorStationary
        let content = GameContent(schema: 1, missionTitle: "Indoor", events: [MissionTemplate(id: "beast", title: "Monster", kind: kind, startFraction: 0.15, duration: 60, hp: 60, audio: "boss", targetDistance: kind == .endurance ? 400 : nil)])
        return RunEngine(session: session, content: content)
    }
    func move(_ engine: inout RunEngine, _ t: Int, moving: Bool = true) {
        _ = engine.consume(SensorFrame(timestamp: Double(t), speed: 0, distance: 99, movement: moving ? .walking : .stationary, signal: moving ? .good : .unavailable, steps: 2))
    }
    func testIndoorCombatNeedsMovementButNoSpeedOrGPSDistance() {
        var run = engine()
        for t in 0...95 { move(&run, t) }
        XCTAssertEqual(run.session.event?.template.kind, .boss)
        XCTAssertEqual(run.session.event?.instructionAudio, "indoor_hold")
        run.instructionFinished()
        let before = run.session.activeSeconds
        for t in 96...106 { move(&run, t, moving: false) }
        XCTAssertEqual(run.session.activeSeconds, before)
        XCTAssertEqual(run.session.event?.elapsed, 0)
        for t in 107...150 { move(&run, t) }
        XCTAssertEqual(run.session.records.first?.defeated, true)
        XCTAssertEqual(run.session.distance, 0)
        XCTAssertGreaterThan(run.session.steps ?? 0, 0)
    }
    func testDistanceAndAccelerationEventsBecomeTimedCombat() {
        for kind in [EventKind.pursuit, .endurance] {
            var run = engine(kind: kind)
            for t in 0...95 { move(&run, t) }
            XCTAssertEqual(run.session.event?.template.kind, .maintain)
            XCTAssertEqual(run.session.event?.template.duration, 30)
            XCTAssertNil(run.session.event?.template.burstSeconds)
            XCTAssertNil(run.session.event?.template.targetDistance)
        }
    }
    func testIndoorSettlementPreservesPaceMemoryAndAwardsOnce() throws {
        var run = engine()
        for t in 0...95 { move(&run, t) }; run.instructionFinished()
        for t in 96...180 { move(&run, t) }; run.end()
        var profile = Profile()
        var pace = PaceMemory(); pace.include(2.5); profile.paceMemory = pace
        let before = profile.paceMemory?.reference
        let summary = try XCTUnwrap(Settlement.apply(run.session, to: &profile))
        XCTAssertGreaterThan(summary.xp, 0); XCTAssertEqual(summary.environment, .indoorStationary)
        XCTAssertEqual(summary.distance, 0); XCTAssertNil(summary.paceReport)
        XCTAssertEqual(profile.paceMemory?.reference, before)
        XCTAssertNil(Settlement.apply(run.session, to: &profile))
        let decoded = try JSONDecoder().decode(RunSummary.self, from: JSONEncoder().encode(summary))
        XCTAssertEqual(decoded.steps, summary.steps)
    }
    func testOldSavesDefaultToOutdoorAndIndoorRecoversPaused() throws {
        var run = engine(); for t in 0...95 { move(&run, t) }
        let data = try JSONEncoder().encode(run.session)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        object.removeValue(forKey: "environment"); object.removeValue(forKey: "steps")
        let old = try JSONDecoder().decode(RunSession.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertEqual(old.activityEnvironment, .outdoor)
        let restored = try JSONDecoder().decode(RunSession.self, from: data)
        var recovered = RunEngine(session: restored, content: run.content); recovered.restorePaused()
        move(&recovered, 200)
        XCTAssertEqual(recovered.session.activeSeconds, restored.activeSeconds)
        XCTAssertEqual(recovered.session.activityEnvironment, .indoorStationary)
        XCTAssertTrue(recovered.session.manualPause)
    }
    func testIndoorQuestEvidenceAndPromotionTimeUseExistingProgression() {
        var profile = Profile()
        var session = RunSession(targetSeconds: 1200, simulated: false, allowPursuit: false)
        session.environment = .indoorTreadmill; session.questID = "compare-signals"
        session.phase = .finished; session.activeSeconds = 1200
        session.records = (0..<2).map { EventRecord(id: "evidence-compare-signals-\($0)", title: "표본", outcome: .success, damage: 0, kind: .discovery) }
        Settlement.apply(session, to: &profile)
        XCTAssertTrue(profile.journey?.completedQuests.contains("compare-signals") == true)
        XCTAssertEqual(Progression.activityCredits(profile), 1)
    }
    func testIndoorExamDealsPersistentBossDamageWithoutAcceleration() throws {
        let definition = try XCTUnwrap(Quests.entry("exam-D")?.boss)
        var profile = Profile()
        var session = RunSession(targetSeconds: 1200, simulated: false, allowPursuit: false, mode: .gate)
        session.environment = .indoorStationary; session.questID = "exam-D"
        session.boss = BossEncounter(definition: definition, state: BossCampaign.state(definition, profile: profile))
        var run = RunEngine(session: session, content: session.boss!.content)
        for t in 0...1200 { run.instructionFinished(); move(&run, t) }
        run.end()
        XCTAssertGreaterThan(run.session.boss?.damage ?? 0, 0)
        XCTAssertFalse(run.session.records.contains { $0.accelerated == true })
        XCTAssertNotNil(Settlement.apply(run.session, to: &profile)?.majorBoss)
        XCTAssertLessThan(BossCampaign.state(definition, profile: profile).remainingHP, definition.maximumHP)
    }
}
