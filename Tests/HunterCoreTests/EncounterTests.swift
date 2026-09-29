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

    func testEarlyOutdoorHuntReachesWolfButWalkingInvestigates() throws {
        let resource = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Resources")
        let missions = try JSONDecoder().decode(MissionCatalog.self, from: Data(contentsOf: resource.appendingPathComponent("missions.json")))
        let encounters = try JSONDecoder().decode(EncounterCatalog.self, from: Data(contentsOf: resource.appendingPathComponent("encounters.json")))
        let progression = try JSONDecoder().decode(ProgressionCatalog.self, from: Data(contentsOf: resource.appendingPathComponent("progression.json")))
        let content = encounters.populate(missions.content(for: .contract, extended: false), mode: .contract, profile: Profile(), catalog: progression)
        for (movement, expectedKind) in [(Movement.running, EventKind.ambush), (.walking, .discovery)] {
            var run = RunSession(targetSeconds: 1800, simulated: false, allowPursuit: true, mode: .contract)
            run.goal = ActivityGoal(kind: .time, value: 1800)
            run.directorVersion = 2
            var engine = RunEngine(session: run, content: content)
            var wolfIntroduction = false
            for second in 0...650 {
                _ = engine.consume(SensorFrame(timestamp: Double(second), speed: movement == .running ? 2.6 : 1.2, distance: movement == .running ? 2.6 : 1.2, movement: movement, signal: .good))
                if engine.session.event?.template.audio == "wolf_intro" { wolfIntroduction = true }
                if engine.session.event?.stage == .briefing { engine.instructionFinished() }
            }
            XCTAssertEqual(wolfIntroduction, movement == .running)
            XCTAssertEqual(engine.session.records.first { $0.catalogID == "beast" }?.kind, expectedKind)
        }
    }
    func testTrackedFirstWolfWaitsForRunningAndGoodSignal() {
        let wolf = MissionTemplate(id: "beast", title: "잔향 늑대", kind: .ambush,
            startFraction: 0.3, duration: 25, hp: 70, audio: "wolf_intro")
        let rival = MissionTemplate(id: "rival", title: "다른 개체", kind: .ambush,
            startFraction: 0.3, duration: 25, hp: 70, audio: "rival_intro")
        var content = GameContent(schema: 1, missionTitle: "Hunt", events: [wolf])
        content.encounterPools = [EncounterPool(slotID: "beast", alternatives: [rival])]
        var run = RunSession(targetSeconds: 1200, simulated: false, allowPursuit: false, mode: .contract)
        run.activeSeconds = 400; run.phase = .moving; run.movingStreak = 20
        run.priorityEncounterID = "beast"; run.directorVersion = 2
        XCTAssertEqual(RunDirector.events(content, session: run, cycle: 0).first?.id, "beast")
        var engine = RunEngine(session: run, content: content)
        engine.consume(frame(0))
        engine.consume(frame(1, movement: .walking))
        XCTAssertNil(engine.session.event)
        XCTAssertFalse(engine.session.consumed.contains("beast"))
        engine.consume(frame(2))
        XCTAssertEqual(engine.session.event?.template.id, "beast")
        engine.instructionFinished()
        engine.consume(frame(3, signal: .degraded))
        XCTAssertEqual(engine.session.event?.template.id, "beast")
        for t in 4...28 { engine.consume(frame(Double(t))) }
        XCTAssertEqual(engine.session.records.first?.catalogID, "beast")
        XCTAssertEqual(engine.session.records.first?.defeated, true)
    }
}
