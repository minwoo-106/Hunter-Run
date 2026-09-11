import XCTest
@testable import HunterCore

final class EncounterTests: XCTestCase {
    private func battle(_ kind: EventKind) -> RunEngine {
        let event = MissionTemplate(id: "test", title: "Test", kind: kind, startFraction: 0.3, duration: 25, hp: 90, audio: kind.rawValue, targetDistance: kind == .endurance ? 400 : nil)
        let content = GameContent(schema: 1, missionTitle: "Test", events: [event])
        var run = RunSession(targetSeconds: 1200, simulated: false, allowPursuit: false)
        run.activeSeconds = 200; run.phase = .moving; run.baseline = 3
        run.event = RunEvent(template: event, stage: .active, hp: 90, startingHP: 90, baseline: 3)
        return RunEngine(session: run, content: content)
    }
    private func frame(_ time: Double, speed: Double = 3, distance: Double = 3, movement: Movement = .running, signal: Signal = .good) -> SensorFrame {
        SensorFrame(timestamp: time, speed: speed, distance: distance, movement: movement, signal: signal)
    }
    func testEnduranceUsesDistanceNotLegacyDuration() {
        var engine = battle(.endurance)
        for t in 0...100 { engine.consume(frame(Double(t))) }
        XCTAssertEqual(engine.session.event?.traveledDistance, 300)
        XCTAssertEqual(engine.session.event?.progress ?? 0, 0.75, accuracy: 0.001)
        XCTAssertTrue(engine.session.records.isEmpty)
        for t in 101...134 { engine.consume(frame(Double(t))) }
        XCTAssertNil(engine.session.event)
        XCTAssertEqual(engine.session.records.first?.outcome, .perfect)
    }
    func testStopPauseAndDeliveryGapDoNotAdvanceEndurance() {
        var engine = battle(.endurance)
        engine.consume(frame(0)); engine.consume(frame(1))
        for t in 2...5 { engine.consume(frame(Double(t), movement: .stationary)) }
        engine.consume(frame(20))
        XCTAssertEqual(engine.session.event?.traveledDistance, 3)
        engine.pause(true)
        for t in 21...30 { engine.consume(frame(Double(t))) }
        XCTAssertEqual(engine.session.event?.traveledDistance, 3)
    }
    func testEnduranceRecoveryKeepsDistanceAndRequiresRebrief() throws {
        var engine = battle(.endurance)
        for t in 0...50 { engine.consume(frame(Double(t))) }
        let saved = try JSONEncoder().encode(engine.session)
        let restored = try JSONDecoder().decode(RunSession.self, from: saved)
        var recovery = RunEngine(session: restored, content: engine.content)
        recovery.restorePaused(); recovery.pause(false)
        for t in 51...60 { recovery.consume(frame(Double(t))) }
        XCTAssertEqual(recovery.session.event?.traveledDistance, 150)
        recovery.instructionFinished(); recovery.consume(frame(61))
        XCTAssertEqual(recovery.session.event?.traveledDistance, 153)
    }
    func testWeakSignalEndsDistanceBattleNeutrally() {
        var engine = battle(.endurance)
        engine.consume(frame(0)); engine.consume(frame(1, signal: .degraded))
        XCTAssertEqual(engine.session.records.first?.outcome, .neutral)
        XCTAssertEqual(engine.session.records.first?.damage, 0)
    }
    func testAmbushRequiresRunningWithoutAcceleration() {
        var engine = battle(.ambush)
        for t in 0...25 { engine.consume(frame(Double(t), speed: 1.5, distance: 1.5)) }
        XCTAssertEqual(engine.session.records.first?.outcome, .perfect)
        var walking = battle(.ambush)
        for t in 0...25 { walking.consume(frame(Double(t), movement: .walking)) }
        XCTAssertEqual(walking.session.event?.elapsed, 0)
        XCTAssertTrue(walking.session.records.isEmpty)
    }
    func testDirectorTimingIsStableAcrossRecoveryAndDifferentAcrossPatrols() throws {
        var run = battle(.endurance).session; run.directorVersion = 1
        let content = battle(.endurance).content
        let first = RunDirector.events(content, session: run, cycle: 0)
        let restored = try JSONDecoder().decode(RunSession.self, from: JSONEncoder().encode(run))
        XCTAssertEqual(first.first?.startFraction, RunDirector.events(content, session: restored, cycle: 0).first?.startFraction)
        let next = RunDirector.events(content, session: run, cycle: 1)
        XCTAssertNotEqual(first.first?.startFraction, next.first?.startFraction)
        XCTAssertEqual(next.first?.id, "test#1")
        XCTAssertEqual(EventRecord(id: next[0].id, title: "Test", outcome: .neutral, damage: 0).catalogID, "test")
        run.directorVersion = nil
        XCTAssertEqual(RunDirector.events(content, session: run, cycle: 0).first?.startFraction, 0.3)
    }
    func testShortRunUsesBriefHoldAndRecoverySuppressesCombat() {
        var run = RunSession(targetSeconds: 300, simulated: true, allowPursuit: false)
        run.activeSeconds = 100; run.movingStreak = 20; run.recoveryUntil = 220; run.hp = 0
        let content = battle(.endurance).content
        XCTAssertEqual(RunDirector.events(content, session: run, cycle: 0).first?.kind, .maintain)
        var engine = RunEngine(session: run, content: content)
        engine.consume(frame(0)); engine.consume(frame(1))
        XCTAssertEqual(engine.session.event?.template.kind, .discovery)
        XCTAssertEqual(engine.session.event?.template.audio, "investigate")
    }
    func testEnduranceTemplateRejectsInvalidDistanceAndLegacyDecodes() throws {
        var content = battle(.endurance).content
        try content.validate()
        content.events[0].targetDistance = nil
        XCTAssertThrowsError(try content.validate())
        content.events[0].kind = .maintain
        let decoded = try JSONDecoder().decode(GameContent.self, from: JSONEncoder().encode(content))
        try decoded.validate()
    }
    func testVoiceRotationKeepsIndependentHistoryAndFallsBack() {
        var selector = VoiceVariants(); let catalog = ["success": ["success", "success_alt"], "discovery": ["discovery", "discovery_alt"]]
        XCTAssertEqual(selector.select("success", catalog: catalog), "success")
        XCTAssertEqual(selector.select("discovery", catalog: catalog), "discovery")
        XCTAssertEqual(selector.select("success", catalog: catalog), "success_alt")
        XCTAssertEqual(selector.select("success", catalog: catalog), "success")
        XCTAssertEqual(selector.select("endurance", catalog: catalog), "endurance")
    }
}
