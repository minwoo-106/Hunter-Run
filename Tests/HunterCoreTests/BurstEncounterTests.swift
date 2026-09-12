import XCTest
@testable import HunterCore

final class BurstEncounterTests: XCTestCase {
    private func content() throws -> GameContent {
        let data = #"{"schema":1,"missionTitle":"Burst","events":[{"id":"major-strike-a","title":"Barrier","kind":"boss","startFraction":0.15,"duration":10,"hp":300,"audio":"burst_prompt","burstSeconds":10,"steadyAudio":"steady_prompt"}]}"#.data(using: .utf8)!
        return try JSONDecoder().decode(GameContent.self, from: data)
    }
    private func engine(allow: Bool = true, count: Int = 0, last: Double = -1000) throws -> RunEngine {
        var run = RunSession(targetSeconds: 1200, simulated: false, allowPursuit: allow, mode: .gate)
        run.activeSeconds = 300; run.baseline = 2.5; run.baselineSamples = Array(repeating: 2.5, count: 60)
        run.learnedReference = 2.5; run.movingStreak = 12; run.intensityCount = count; run.lastIntensityAt = last
        var e = RunEngine(session: run, content: try content())
        step(&e, 0); step(&e, 1); return e
    }
    @discardableResult private func step(_ e: inout RunEngine, _ time: Double, speed: Double = 2.5, signal: Signal = .good, movement: Movement = .running) -> [GameCue] {
        e.consume(SensorFrame(timestamp: time, speed: speed, distance: speed, movement: movement, signal: signal))
    }
    func testBossBurstWaitsForUserAcceleration() throws {
        var e = try engine(); e.instructionFinished()
        XCTAssertEqual(e.session.event?.stage, .armed)
        for t in 2...5 { step(&e, Double(t)) }
        XCTAssertEqual(e.session.intensityCount, 0); XCTAssertTrue(e.session.records.isEmpty)
    }
    func testDisabledBudgetAndCooldownUseSteadyBossAction() throws {
        for config in [(false, 0, -1000.0), (true, 2, -1000.0), (true, 0, 290.0)] {
            let e = try engine(allow: config.0, count: config.1, last: config.2)
            XCTAssertEqual(e.session.event?.template.audio, "steady_prompt")
            XCTAssertEqual(e.session.event?.template.kind, .boss)
            XCTAssertEqual(e.session.event?.template.duration, 30)
        }
    }
    func testDecliningBurstKeepsBossCombatWithoutPenalty() throws {
        var e = try engine(); e.instructionFinished()
        for t in 2...16 { step(&e, Double(t)) }
        XCTAssertEqual(e.session.event?.template.audio, "steady_prompt")
        XCTAssertEqual(e.session.event?.stage, .briefing)
        XCTAssertEqual(e.session.hp, 100); XCTAssertEqual(e.session.intensityCount, 0)
    }
    func testTenSecondsIncludeIntentAndWaitForInitialInstruction() throws {
        var e = try engine()
        for t in 2...5 { step(&e, Double(t), speed: 2.8) }
        XCTAssertEqual(e.session.event?.elapsed, 0)
        e.instructionFinished()
        var cues: [GameCue] = []
        for t in 6...9 { cues += step(&e, Double(t), speed: 2.8) }
        XCTAssertTrue(cues.contains(.voice("burst_start")))
        XCTAssertEqual(e.session.event?.stage, .active); XCTAssertEqual(e.session.event?.elapsed, 4)
        XCTAssertFalse(AccelerationRules.isRecovering(e.session))
        for t in 10...14 { step(&e, Double(t), speed: 2.8) }
        XCTAssertTrue(e.session.records.isEmpty)
        step(&e, 15, speed: 2.8)
        XCTAssertEqual(e.session.records.count, 1); XCTAssertEqual(e.session.intensityCount, 1)
        XCTAssertEqual(e.session.lastIntensityAt, e.session.activeSeconds)
        XCTAssertEqual(e.session.records.first?.accelerated, true)
    }
    func testPauseGapAndRestoreKeepRemainingEffortAndBudget() throws {
        var e = try engine(); e.instructionFinished()
        for t in 2...6 { step(&e, Double(t), speed: 2.8) }
        XCTAssertEqual(e.session.event?.elapsed, 5)
        e.pause(true); step(&e, 7, speed: 2.8)
        XCTAssertEqual(e.session.event?.elapsed, 5)
        let saved = try JSONDecoder().decode(RunSession.self, from: JSONEncoder().encode(e.session))
        e = RunEngine(session: saved, content: try content()); e.restorePaused(); e.pause(false)
        XCTAssertEqual(e.session.event?.instructionAudio, "burst_resume")
        step(&e, 100, speed: 2.8); step(&e, 101, speed: 2.8)
        XCTAssertEqual(e.session.event?.elapsed, 5)
        e.instructionFinished(); step(&e, 160, speed: 2.8)
        XCTAssertEqual(e.session.event?.elapsed, 5)
        for t in 161...165 { step(&e, Double(t), speed: 2.8) }
        XCTAssertEqual(e.session.records.count, 1); XCTAssertEqual(e.session.intensityCount, 1)
    }
    func testBadGPSCancelsBurstWithoutPenaltyAndStartsRecovery() throws {
        var e = try engine(); e.instructionFinished()
        for t in 2...5 { step(&e, Double(t), speed: 2.8) }
        step(&e, 6, signal: .degraded)
        XCTAssertNil(e.session.event); XCTAssertEqual(e.session.records.first?.outcome, .neutral)
        XCTAssertEqual(e.session.records.first?.damage, 0); XCTAssertEqual(e.session.hp, 100)
        XCTAssertTrue(AccelerationRules.needsEasyMovement(e.session))
    }
    func testLearningWalkingAndSignalBlockAcceleration() throws {
        let valid = try engine().session
        let frame = SensorFrame(timestamp: 1, speed: 2.8, distance: 2.8, movement: .running, signal: .good)
        XCTAssertTrue(AccelerationRules.canOffer(valid, frame: frame))
        var first = valid; first.learnedReference = nil
        XCTAssertFalse(AccelerationRules.canOffer(first, frame: frame))
        first = valid; first.withdrawn = true
        XCTAssertFalse(AccelerationRules.canOffer(first, frame: frame))
        var uncertain = frame; uncertain.signal = .degraded
        XCTAssertFalse(AccelerationRules.canOffer(valid, frame: uncertain))
        uncertain = frame; uncertain.movement = .walking
        XCTAssertFalse(AccelerationRules.canOffer(valid, frame: uncertain))
    }
    func testCooldownUsesCompletedBurstAndPersistsAcrossRecovery() throws {
        var e = try engine(); e.instructionFinished()
        for t in 2...11 { step(&e, Double(t), speed: 2.8) }
        let end = e.session.activeSeconds
        var run = e.session; let frame = SensorFrame(timestamp: 1, speed: 2.8, distance: 2.8, movement: .running, signal: .good)
        run.activeSeconds = end + 59; XCTAssertTrue(AccelerationRules.needsEasyMovement(run))
        run.activeSeconds = end + 60; XCTAssertFalse(AccelerationRules.needsEasyMovement(run))
        run.activeSeconds = end + 179; XCTAssertFalse(AccelerationRules.canOffer(run, frame: frame))
        run.activeSeconds = end + 180; XCTAssertTrue(AccelerationRules.canOffer(run, frame: frame))
        run.intensityCount = 2; run.activeSeconds += 600
        XCTAssertFalse(AccelerationRules.canOffer(run, frame: frame))
    }
    func testBurstContentRejectsWrongDurationAndOldSaveDecodes() throws {
        var c = try content(); c.events[0].burstSeconds = 30
        XCTAssertThrowsError(try c.validate())
        c.events[0].burstSeconds = nil; c.events[0].steadyAudio = nil
        XCTAssertNoThrow(try c.validate())
        let encoded = try JSONEncoder().encode(RunSession(targetSeconds: 300, simulated: true, allowPursuit: false))
        XCTAssertNoThrow(try JSONDecoder().decode(RunSession.self, from: encoded))
    }
}
