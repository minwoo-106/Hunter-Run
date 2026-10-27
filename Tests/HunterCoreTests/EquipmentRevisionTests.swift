import XCTest
@testable import HunterCore

final class EquipmentRevisionTests: XCTestCase {
    private func catalog() throws -> ProgressionCatalog { try V3Fixtures.load("Resources/progression.json", as: ProgressionCatalog.self) }
    private func migrated(level: Int = 15) throws -> SaveState {
        var save = V3Fixtures.actualSave(level: level)
        try CombatRelease.migrate(&save); try EquipmentRevision.migrate(&save, catalog: catalog())
        return save
    }
    private func encoded<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]; return try encoder.encode(value)
    }
    func testActualSaveCompensationPreservesProgressAndIsExactlyOnce() throws {
        var save = V3Fixtures.actualSave(); try CombatRelease.migrate(&save)
        let before = save.profile, catalog = try catalog()
        XCTAssertTrue(try EquipmentRevision.migrate(&save, catalog: catalog))
        XCTAssertEqual(save.profile.level, 15); XCTAssertEqual(save.profile.xp, 4250)
        XCTAssertEqual(save.profile.growth.rank, before.growth.rank)
        XCTAssertEqual(save.profile.growth.departments, before.growth.departments)
        XCTAssertEqual(try encoded(save.profile.journey), try encoded(before.journey))
        XCTAssertEqual(save.profile.growth.owned, before.growth.owned)
        XCTAssertNil(save.profile.growth.equipped["armor"]); XCTAssertEqual(save.profile.growth.equipped.count, 3)
        XCTAssertEqual(save.profile.crystals, 223); XCTAssertEqual(save.profile.research, 204)
        XCTAssertEqual(save.profile.equipmentRevision?.retiredIDs, ["barrier-coat"])
        let stable = try encoded(save)
        XCTAssertFalse(try EquipmentRevision.migrate(&save, catalog: catalog)); XCTAssertEqual(try encoded(save), stable)
        var restored = try JSONDecoder().decode(SaveState.self, from: stable)
        XCTAssertFalse(try EquipmentRevision.migrate(&restored, catalog: catalog))
        try SaveRepository(directory: FileManager.default.temporaryDirectory).validate(restored)
    }
    func testAllArmorCompensatedAndOldTargetsRetiredWithoutDeletingMemories() throws {
        var save = V3Fixtures.actualSave(); let catalog = try catalog()
        let retired = catalog.equipment.filter { $0.slot == .armor }
        save.profile.growth.owned.formUnion(retired.map(\.id))
        var journal = EquipmentJournal(); journal.targetID = "barrier-coat"
        journal.memories["barrier-coat"] = EquipmentMemory(trackingSince: Date())
        journal.presets = [EquipmentPreset(id: 0, name: "이전 조합", slots: save.profile.growth.equipped)]
        save.profile.equipmentJournal = journal
        try EquipmentRevision.migrate(&save, catalog: catalog)
        XCTAssertEqual(save.profile.crystals, 203 + retired.reduce(0) { $0 + $1.crystals })
        XCTAssertEqual(save.profile.research, 200 + retired.reduce(0) { $0 + $1.research })
        XCTAssertEqual(save.profile.growth.cores, retired.reduce(0) { $0 + $1.cores })
        XCTAssertNil(save.profile.equipmentJournal?.targetID)
        XCTAssertNotNil(save.profile.equipmentJournal?.memories["barrier-coat"])
        try EquipmentExperience.applyPreset(0, save: &save, catalog: catalog)
        XCTAssertNil(save.profile.growth.equipped["armor"])
        XCTAssertThrowsError(try Progression.equip("barrier-coat", save: &save, catalog: catalog))
        XCTAssertThrowsError(try Progression.buy("field-vest", save: &save, catalog: catalog))
        XCTAssertFalse(ContentUnlocks.available(profile: save.profile, catalog: catalog, encounters: nil, world: nil).contains { $0.id == "gear:barrier-coat" })
    }
    func testMigrationDefersOutdoorAndDefenseAndResourceOverflowAtomically() throws {
        var save = V3Fixtures.actualSave(); save.active = try V3Fixtures.engine().session
        let before = try encoded(save)
        XCTAssertFalse(try EquipmentRevision.migrate(&save, catalog: catalog())); XCTAssertEqual(try encoded(save), before)
        save.active = nil; save.profile.defense = DefenseProgress()
        save.profile.defense?.active = DefenseSession(episode: 1, intensity: .light)
        XCTAssertFalse(try EquipmentRevision.migrate(&save, catalog: catalog()))
        save.profile.defense?.active = nil; save.profile.crystals = 100_000_000
        let full = try encoded(save)
        XCTAssertThrowsError(try EquipmentRevision.migrate(&save, catalog: catalog())); XCTAssertEqual(try encoded(save), full)
        save.profile.crystals = 203
        XCTAssertTrue(try EquipmentRevision.migrate(&save, catalog: catalog()))
    }
    func testCurrentAndHighLevelAttackNeverFallsAndMonsterResultsStayStable() throws {
        let catalog = try catalog(), rules = try V3Fixtures.rules()
        for level in [1, 15, 30, 60, 100] {
            var save = V3Fixtures.actualSave(level: level); try CombatRelease.migrate(&save)
            for shoes in catalog.equipment.filter({ $0.slot == .shoes }) {
                var trial = save; trial.profile.growth.owned.insert(shoes.id); trial.profile.growth.equipped["shoes"] = shoes.id
                let before = catalog.stats(for: trial.profile)
                try EquipmentRevision.migrate(&trial, catalog: catalog)
                XCTAssertEqual(catalog.stats(for: trial.profile).attack, before.attack, accuracy: 1e-9)
            }
        }
        let stats = catalog.stats(for: try migrated().profile)
        XCTAssertEqual(stats.attack, 2.915, accuracy: 1e-9)
        for (id, damage, hits) in [("echo-wolf", 159.0, 2), ("iron-guard", 139.0, 3), ("signal-heart", 152.0, 2)] {
            let monster = try XCTUnwrap(rules.monsters.first { $0.id == id })
            let estimate = CombatEstimate(stats: stats, monster: monster)
            XCTAssertEqual(estimate.damage, damage); XCTAssertEqual(estimate.hits, hits)
        }
    }
    func testWeaponUpgradeChangesRealDistanceDamageAndKillsNotJustPreview() throws {
        let catalog = try catalog()
        for (weapon, expectedDamage, expectedHits) in [("field-blade", 136.0, 2), ("resonance-blade", 159.0, 2), ("core-spear", 185.0, 1)] {
            var save = try migrated(); save.profile.growth.owned.insert(weapon); save.profile.growth.equipped["weapon"] = weapon
            let source = try V3Fixtures.engine(); var run = source.session; run.loadout = catalog.stats(for: save.profile)
            var engine = RunEngine(session: run, content: source.content)
            engine.consume(V3Fixtures.frame(1, 74)); XCTAssertEqual(engine.session.event?.battle?.attacks, 0)
            engine.consume(V3Fixtures.frame(2, 1))
            XCTAssertEqual(engine.session.event?.hp ?? 0, max(0, 180 - expectedDamage))
            if expectedHits == 2 { engine.consume(V3Fixtures.frame(3, 75)) }
            XCTAssertEqual(engine.session.records.first?.attacks, expectedHits)
            engine.consume(V3Fixtures.frame(4, 75)); XCTAssertEqual(engine.session.records.count, 1)
        }
    }
    func testShoeContractIsTimingNotMissingDamageBonus() throws {
        let catalog = try catalog(), stats = catalog.stats(for: try migrated().profile)
        XCTAssertEqual(stats.eventBonus, 0); XCTAssertEqual(stats.encounterHaste, 0.08)
        XCTAssertEqual(stats.hp, 100); XCTAssertEqual(stats.defense, 0)
        let shoe = try XCTUnwrap(catalog.equipment.first { $0.id == "trace-shoes" })
        XCTAssertFalse(shoe.detail.contains("피해")); XCTAssertTrue(shoe.detail.contains("대기 -8%"))
        let source = try V3Fixtures.engine(); var run = source.session; run.loadout = stats
        var engine = RunEngine(session: run, content: source.content)
        engine.consume(V3Fixtures.frame(1, 75)); XCTAssertEqual(engine.session.event?.hp, 21)
    }
    private func timingRun(haste: Double) -> RunSession {
        var run = RunSession(targetSeconds: 1800, simulated: false, allowPursuit: false, mode: .contract,
            loadout: CombatStats(equipmentRevision: 1, encounterHaste: haste))
        run.activeSeconds = 300; run.lastEncounterEndedAt = 300; return run
    }
    private func event(_ kind: EventKind = .maintain, fraction: Double = 0.3) -> MissionTemplate {
        MissionTemplate(id: "next", title: "다음 사건", kind: kind, startFraction: fraction, duration: 20, hp: 20, audio: "maintain")
    }
    func testShoeTimingCapMinimumGapFirstEventAndBossExclusions() {
        var run = timingRun(haste: 0.08)
        XCTAssertEqual(EncounterTiming.scheduledAt(event(), session: run, cycle: 0), 520.8, accuracy: 0.001)
        run.loadout?.encounterHaste = 0.25
        XCTAssertEqual(EncounterTiming.scheduledAt(event(), session: run, cycle: 0), 510)
        XCTAssertEqual(EncounterTiming.scheduledAt(event(fraction: 0.19), session: run, cycle: 0), 331.5)
        XCTAssertEqual(EncounterTiming.scheduledAt(event(fraction: 0.18), session: run, cycle: 0), 324)
        XCTAssertEqual(EncounterTiming.scheduledAt(event(.boss), session: run, cycle: 0), 540)
        run.lastEncounterEndedAt = nil
        XCTAssertEqual(EncounterTiming.scheduledAt(event(), session: run, cycle: 0), 540)
        run.lastEncounterEndedAt = 300; run.loadout?.equipmentRevision = nil
        XCTAssertEqual(EncounterTiming.scheduledAt(event(), session: run, cycle: 0), 540)
    }
    func testShoeActuallyStartsNextEventEarlierWithoutInventingEvents() {
        func replay(_ haste: Double) -> (Double, Int) {
            var run = timingRun(haste: haste); run.activeSeconds = 500; run.lastTimestamp = 0; run.movingStreak = 20
            let content = GameContent(schema: 1, missionTitle: "조우 검증", events: [event()])
            var engine = RunEngine(session: run, content: content)
            for t in 1...60 {
                engine.consume(V3Fixtures.frame(Double(t), 2.5))
                if engine.session.event != nil { return (engine.session.activeSeconds, engine.session.consumed.count) }
            }
            return (-1, 0)
        }
        XCTAssertEqual(replay(0).0, 540); XCTAssertEqual(replay(0.08).0, 521)
        XCTAssertEqual(replay(0.25).0, 510); XCTAssertEqual(replay(0.25).1, 1)
    }
    func testPauseStationaryAndPoorGPSCannotAttackWithNewEquipment() throws {
        let source = try V3Fixtures.engine(); var run = source.session
        run.loadout = try catalog().stats(for: migrated().profile)
        var engine = RunEngine(session: run, content: source.content)
        engine.consume(V3Fixtures.frame(1, 75, signal: .degraded))
        engine.consume(V3Fixtures.frame(2, 75, movement: .stationary))
        engine.pause(true); engine.consume(V3Fixtures.frame(3, 75)); engine.consume(V3Fixtures.frame(4, 75))
        XCTAssertEqual(engine.session.event?.battle?.attacks, 0)
        engine.pause(false); engine.consume(V3Fixtures.frame(5))
        for t in 6...35 { engine.consume(V3Fixtures.frame(Double(t), 2.5)) }
        XCTAssertEqual(engine.session.event?.battle?.attacks, 1)
    }
    func testLegacyHealthDoesNotBlockOrPenalizeNewSessions() {
        var run = timingRun(haste: 0.08); run.hp = 0; run.withdrawn = true; run.recoveryUntil = 9999
        XCTAssertFalse(run.legacyHealthBlocked); XCTAssertFalse(run.legacyWithdrawn)
        let template = event(); run.event = RunEvent(template: template, stage: .active, hp: 20, startingHP: 20, baseline: 5)
        run.hp = 100; run.lastTimestamp = 0
        var engine = RunEngine(session: run, content: GameContent(schema: 1, missionTitle: "구간", events: [template]))
        for t in 1...21 { engine.consume(V3Fixtures.frame(Double(t), 2.5)) }
        XCTAssertEqual(engine.session.records.first?.outcome, .fail)
        XCTAssertEqual(engine.session.hp, 100); XCTAssertFalse(engine.session.legacyHealthBlocked)
    }
    func testRelicResearchStillAppliesOnceWithNewEquipment() throws {
        var save = try migrated()
        var run = RunSession(targetSeconds: 600, simulated: false, allowPursuit: false, mode: .exploration, loadout: try catalog().stats(for: save.profile))
        run.activeSeconds = 600; run.phase = .finished
        run.records = [EventRecord(id: "trace", title: "조사", outcome: .success, damage: 0, kind: .discovery)]
        let summary = try XCTUnwrap(Settlement.apply(run, to: &save.profile))
        XCTAssertEqual(summary.research, 4); XCTAssertNil(Settlement.apply(run, to: &save.profile))
    }
    func testInvalidRevisionAndTimingAreRejected() throws {
        var save = try migrated(); save.profile.equipmentRevision?.version = 2
        let repository = SaveRepository(directory: FileManager.default.temporaryDirectory)
        XCTAssertThrowsError(try repository.validate(save))
        save = try migrated(); save.active = timingRun(haste: 0.5)
        XCTAssertThrowsError(try repository.validate(save))
        save.active?.loadout?.encounterHaste = 0.08; save.active?.lastEncounterEndedAt = 9999
        XCTAssertThrowsError(try repository.validate(save))
    }
}
