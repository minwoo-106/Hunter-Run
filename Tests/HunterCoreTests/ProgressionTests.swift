import XCTest
@testable import HunterCore

final class ProgressionTests: XCTestCase {
    func load<T: Decodable>(_ name: String, as type: T.Type) throws -> T {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return try JSONDecoder().decode(type, from: Data(contentsOf: root.appendingPathComponent("Resources/" + name)))
    }
    func catalog() throws -> ProgressionCatalog { try load("progression.json", as: ProgressionCatalog.self) }
    func testCatalogsAndUnlocksAreValid() throws {
        let catalog = try catalog(); try catalog.validate()
        let missions = try load("missions.json", as: MissionCatalog.self); try missions.validate()
        XCTAssertEqual(catalog.equipment.count, 32)
        XCTAssertEqual(missions.content(for: .exploration, extended: false).events.filter { $0.kind != .discovery }.count, 0)
        XCTAssertEqual(missions.content(for: .contract, extended: true).events.count, 6)
    }
    func testLegacySavePreservesProgressAndCanBeWritten() throws {
        let data = Data(#"{"schema":1,"profile":{"name":"기존 헌터","xp":450,"crystals":25,"research":6,"observationLevel":2,"settled":[],"runs":[]}}"#.utf8)
        var save = try JSONDecoder().decode(SaveState.self, from: data)
        XCTAssertEqual(save.profile.level, 2)
        XCTAssertEqual(save.profile.growth.level(.observation), 2)
        XCTAssertEqual(save.profile.growth.rank, "E")
        try Progression.buy("field-blade", save: &save, catalog: catalog())
        let restored = try JSONDecoder().decode(SaveState.self, from: JSONEncoder().encode(save))
        XCTAssertEqual(restored.profile.name, "기존 헌터")
        XCTAssertEqual(restored.profile.crystals, 21)
        XCTAssertTrue(restored.profile.growth.owned.contains("field-blade"))
    }
    func testPurchaseCannotOverspendOrChargeTwice() throws {
        let catalog = try catalog(); var save = SaveState()
        XCTAssertThrowsError(try Progression.buy("field-blade", save: &save, catalog: catalog))
        XCTAssertEqual(save.profile.crystals, 0)
        save.profile.crystals = 10
        try Progression.buy("field-blade", save: &save, catalog: catalog)
        XCTAssertEqual(save.profile.crystals, 6)
        XCTAssertThrowsError(try Progression.buy("field-blade", save: &save, catalog: catalog))
        XCTAssertEqual(save.profile.crystals, 6)
        XCTAssertThrowsError(try Progression.buy("resonance-blade", save: &save, catalog: catalog))
    }
    func testAllGrowthChangesAreBlockedDuringRecoverableRun() throws {
        let catalog = try catalog(); var save = SaveState(); save.profile.crystals = 100; save.profile.research = 100
        try Progression.buy("field-blade", save: &save, catalog: catalog)
        save.active = RunSession(targetSeconds: 300, simulated: false, allowPursuit: false)
        let before = save.profile.crystals
        XCTAssertThrowsError(try Progression.equip("field-blade", save: &save, catalog: catalog))
        XCTAssertThrowsError(try Progression.buy("field-vest", save: &save, catalog: catalog))
        XCTAssertThrowsError(try Progression.upgrade(.observation, save: &save, catalog: catalog))
        XCTAssertThrowsError(try Progression.promote(save: &save))
        XCTAssertEqual(save.profile.crystals, before)
    }
    func testDepartmentsUnlockActualContentAndChargeOnce() throws {
        let catalog = try catalog(); var save = SaveState(); save.profile.crystals = 100; save.profile.research = 100
        XCTAssertFalse(catalog.unlocked("analysis", profile: save.profile))
        try Progression.upgrade(.research, save: &save, catalog: catalog)
        XCTAssertTrue(catalog.unlocked("analysis", profile: save.profile))
        XCTAssertThrowsError(try Progression.upgrade(.research, save: &save, catalog: catalog))
        var qualified = save.profile.growth; qualified.rank = "C"; save.profile.growth = qualified
        try Progression.upgrade(.research, save: &save, catalog: catalog)
        XCTAssertTrue(catalog.unlocked("tactical-analysis", profile: save.profile))
        let remaining = save.profile.research
        XCTAssertThrowsError(try Progression.upgrade(.research, save: &save, catalog: catalog))
        XCTAssertEqual(save.profile.research, remaining)
        try Progression.upgrade(.observation, save: &save, catalog: catalog)
        var entryRank = save.profile.growth; entryRank.rank = "E"; save.profile.growth = entryRank
        XCTAssertFalse(Progression.allows(.gate, profile: save.profile, catalog: catalog))
        var growth = save.profile.growth; growth.rank = "D"; save.profile.growth = growth
        XCTAssertTrue(Progression.allows(.gate, profile: save.profile, catalog: catalog))
    }
    func testExperienceAloneDoesNotPromote() throws {
        var save = SaveState(); save.profile.xp = 9000
        XCTAssertFalse(Progression.canPromote(save.profile))
        for _ in 0..<3 {
            var run = RunSession(targetSeconds: 1200, simulated: false, allowPursuit: false)
            run.activeSeconds = 1200; run.phase = .finished
            Settlement.apply(run, to: &save.profile)
        }
        XCTAssertTrue(Progression.qualifiesForExam(save.profile))
        XCTAssertThrowsError(try Progression.promote(save: &save))
        var journey = save.profile.journey ?? JourneyState(); journey.completedQuests.insert("exam-D"); save.profile.journey = journey
        try Progression.promote(save: &save)
        XCTAssertEqual(save.profile.growth.rank, "D")
        XCTAssertFalse(Progression.canPromote(save.profile))
    }
    func testExplorationRewardsAndCoreSettlementAreIdempotent() {
        var profile = Profile()
        var run = RunSession(targetSeconds: 300, simulated: false, allowPursuit: false, mode: .exploration, loadout: CombatStats(researchBonus: 1))
        run.activeSeconds = 300; run.phase = .finished
        run.records = [EventRecord(id: "trace", title: "조사", outcome: .perfect, damage: 0, kind: .discovery)]
        let summary = Settlement.apply(run, to: &profile)
        XCTAssertEqual(summary?.research, 3)
        XCTAssertNil(Settlement.apply(run, to: &profile))
        XCTAssertEqual(profile.research, 3)
        var gate = RunSession(targetSeconds: 300, simulated: false, allowPursuit: false, mode: .gate)
        gate.phase = .finished; gate.records = [EventRecord(id: "gate-core", title: "보스", outcome: .perfect, damage: 85, defeated: true, kind: .boss)]
        Settlement.apply(gate, to: &profile); Settlement.apply(gate, to: &profile)
        XCTAssertEqual(profile.growth.cores, 1)
        XCTAssertEqual(Progression.gateClears(profile), 1)
        gate.id = UUID(); gate.simulated = true
        XCTAssertNil(Settlement.apply(gate, to: &profile)); XCTAssertEqual(profile.growth.cores, 1)
    }
    func testEquipmentChangesDamageNotRequiredPaceAndSurvivesRecovery() throws {
        let catalog = try catalog(); var save = SaveState(); save.profile.crystals = 20
        try Progression.buy("field-blade", save: &save, catalog: catalog)
        try Progression.equip("field-blade", save: &save, catalog: catalog)
        let powered = catalog.stats(for: save.profile)
        func combat(_ stats: CombatStats) -> RunSession {
            let content = GameContent(schema: 1, missionTitle: "Test", events: [MissionTemplate(id: "test", title: "Test", kind: .maintain, startFraction: 0.13, duration: 20, hp: 500, audio: "maintain")])
            var engine = RunEngine(session: RunSession(targetSeconds: 600, simulated: false, allowPursuit: false, loadout: stats), content: content)
            for t in 0...95 { engine.consume(SensorFrame(timestamp: Double(t), speed: 2.5, distance: 2.5, movement: .running, signal: .good)) }
            engine.instructionFinished()
            for t in 96...116 { engine.consume(SensorFrame(timestamp: Double(t), speed: 2.5, distance: 2.5, movement: .running, signal: .good)) }
            return engine.session
        }
        let normal = combat(CombatStats()); let upgraded = combat(powered)
        XCTAssertEqual(normal.baseline, upgraded.baseline)
        XCTAssertEqual(normal.records.first?.outcome, upgraded.records.first?.outcome)
        XCTAssertGreaterThan(upgraded.records.first!.damage, normal.records.first!.damage)
        let restored = try JSONDecoder().decode(RunSession.self, from: JSONEncoder().encode(upgraded))
        XCTAssertEqual(restored.loadout, powered)
        try Progression.equip("field-blade", save: &save, catalog: catalog)
        XCTAssertEqual(catalog.stats(for: save.profile).attack, 1)
        XCTAssertEqual(restored.loadout?.attack, powered.attack)
    }
    func testWalkingInvestigationCannotAwardBossCore() throws {
        let missions = try load("missions.json", as: MissionCatalog.self)
        var engine = RunEngine(session: RunSession(targetSeconds: 300, simulated: false, allowPursuit: false, mode: .gate), content: missions.content(for: .gate, extended: false))
        for t in 0...300 {
            engine.consume(SensorFrame(timestamp: Double(t), speed: 1.2, distance: 1.2, movement: .walking, signal: .good))
            engine.instructionFinished()
        }
        var profile = Profile(); Settlement.apply(engine.session, to: &profile)
        XCTAssertTrue(engine.session.records.contains { $0.id == "gate-core" })
        XCTAssertEqual(profile.growth.cores, 0)
        XCTAssertEqual(engine.session.records.reduce(0) { $0 + $1.damage }, 0)
    }
}
