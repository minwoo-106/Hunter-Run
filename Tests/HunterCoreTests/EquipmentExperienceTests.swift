import XCTest
@testable import HunterCore

final class EquipmentExperienceTests: XCTestCase {
    private func catalog() throws -> ProgressionCatalog { try V3Fixtures.load("Resources/progression.json", as: ProgressionCatalog.self) }
    func testPreviewUsesRealCombatAndDoesNotChangeSave() throws {
        var save = V3Fixtures.actualSave(); try CombatRelease.migrate(&save)
        let catalog = try catalog(), rules = try V3Fixtures.rules()
        let item = try XCTUnwrap(catalog.equipment.first { $0.id == "core-spear" })
        let before = try JSONEncoder().encode(save)
        let estimate = EquipmentExperience.preview(item, profile: save.profile, catalog: catalog)
        for monster in rules.monsters {
            let expected = CombatEstimate(stats: estimate, monster: monster)
            var battle = DistanceBattle(monster: monster)
            if expected.hits > 1 {
                battle.advance(distance: expected.distance - 75, attack: estimate.attack)
                XCTAssertGreaterThan(battle.remainingHP, 0)
            }
            battle.advance(distance: 75, attack: estimate.attack)
            XCTAssertEqual(battle.remainingHP, 0)
            XCTAssertEqual(battle.attacks, expected.hits)
        }
        XCTAssertEqual(try JSONDecoder().decode(SaveState.self, from: before).profile.xp, save.profile.xp)
        XCTAssertFalse(save.profile.growth.owned.contains(item.id))
        XCTAssertEqual(save.profile.growth.equipped["weapon"], "resonance-blade")
    }
    func testActualLv15WolfStillTwoAttacks() throws {
        var save = V3Fixtures.actualSave(); try CombatRelease.migrate(&save)
        let wolf = try XCTUnwrap(V3Fixtures.rules().monsters.first { $0.id == "echo-wolf" })
        let estimate = CombatEstimate(stats: try catalog().stats(for: save.profile), monster: wolf)
        XCTAssertEqual(estimate.hits, 2); XCTAssertEqual(estimate.damage, 159); XCTAssertEqual(estimate.distance, 150)
        XCTAssertEqual(save.profile.level, 15); XCTAssertEqual(save.profile.xp, 4250)
    }
    func testPresetIsAtomicAndRejectsUnownedOrWrongSlot() throws {
        var save = V3Fixtures.actualSave(); let original = save.profile.growth.equipped
        var journal = EquipmentJournal()
        journal.presets = [EquipmentPreset(id: 0, name: "탐색용", slots: ["weapon": "core-spear"])]
        save.profile.equipmentJournal = journal
        XCTAssertThrowsError(try EquipmentExperience.applyPreset(0, save: &save, catalog: catalog()))
        XCTAssertEqual(save.profile.growth.equipped, original)
        save.profile.equipmentJournal?.presets[0].slots = ["weapon": "barrier-coat"]
        XCTAssertThrowsError(try EquipmentExperience.applyPreset(0, save: &save, catalog: catalog()))
        XCTAssertEqual(save.profile.growth.equipped, original)
        save.profile.equipmentJournal?.presets[0].slots = ["weapon": "resonance-blade"]
        try EquipmentExperience.applyPreset(0, save: &save, catalog: catalog())
        XCTAssertEqual(save.profile.growth.equipped, ["weapon": "resonance-blade"])
    }
    func testPresetBlockedDuringOutdoorAndDefense() throws {
        var save = V3Fixtures.actualSave()
        save.active = RunSession(targetSeconds: 1200, simulated: false, allowPursuit: false)
        XCTAssertThrowsError(try EquipmentExperience.applyPreset(0, save: &save, catalog: catalog()))
        save.active = nil; save.profile.defense = DefenseProgress()
        save.profile.defense?.active = DefenseSession(episode: 1, intensity: .light)
        XCTAssertThrowsError(try EquipmentExperience.applyPreset(0, save: &save, catalog: catalog()))
    }
    func testSettlementRecordsGearOnceAndUsesStartSnapshot() throws {
        var save = V3Fixtures.actualSave(); try CombatRelease.migrate(&save)
        var engine = try V3Fixtures.engine()
        engine.consume(V3Fixtures.frame(1, 150)); engine.end()
        var session = engine.session; session.equipmentIDs = ["resonance-blade", "resonance-blade"]
        save.profile.growth.equipped = [:]
        let summary = try XCTUnwrap(Settlement.apply(session, to: &save.profile))
        XCTAssertEqual(summary.growthReport?.firstDefeats.count, 1)
        XCTAssertEqual(save.profile.equipmentJournal?.memories["resonance-blade"]?.activities, 1)
        XCTAssertEqual(save.profile.equipmentJournal?.memories["resonance-blade"]?.outdoorDistance, session.distance)
        XCTAssertNil(save.profile.equipmentJournal?.memories["resonance-blade"]?.acquiredAt)
        XCTAssertNil(Settlement.apply(session, to: &save.profile))
        XCTAssertEqual(save.profile.equipmentJournal?.memories["resonance-blade"]?.activities, 1)
        session.id = UUID()
        let second = Settlement.apply(session, to: &save.profile)
        XCTAssertTrue(second?.growthReport?.firstDefeats.isEmpty == true)
    }
    func testOldSaveAndOldSessionDoNotInventEquipmentHistory() throws {
        var save = V3Fixtures.actualSave()
        let data = try JSONEncoder().encode(save)
        save = try JSONDecoder().decode(SaveState.self, from: data)
        XCTAssertNil(save.profile.equipmentJournal)
        var run = RunSession(targetSeconds: 1200, simulated: false, allowPursuit: false)
        run.activeSeconds = 600; run.phase = .finished
        let summary = Settlement.apply(run, to: &save.profile)
        XCTAssertTrue(summary?.growthReport?.equipmentIDs.isEmpty == true)
        XCTAssertNil(save.profile.equipmentJournal)
    }
    func testSimulationAndTooShortActivityCreateNoGrowthRecords() throws {
        var profile = Profile()
        var run = RunSession(targetSeconds: 1200, simulated: true, allowPursuit: false)
        run.phase = .finished; run.activeSeconds = 1200
        XCTAssertNil(Settlement.apply(run, to: &profile))
        run.simulated = false; run.activeSeconds = 30
        XCTAssertNil(Settlement.apply(run, to: &profile)); XCTAssertNil(profile.equipmentJournal)
    }
    func testUnlocksUseActualFacilityAndStoryConditions() throws {
        let catalog = try catalog()
        let encounters: EncounterCatalog = try V3Fixtures.load("Resources/encounters.json", as: EncounterCatalog.self)
        let world: WorldContent = try V3Fixtures.load("Resources/world.json", as: WorldContent.self)
        var profile = Profile(); profile.growth.rank = "S"
        let notices = ContentUnlocks.available(profile: profile, catalog: catalog, encounters: encounters, world: world)
        XCTAssertFalse(notices.contains { $0.id == "boss:corrupted-hunter" })
        XCTAssertTrue(ContentUnlocks.difference(before: notices, after: notices).isEmpty)
        let encoded = try JSONEncoder().encode(profile)
        let old = try JSONDecoder().decode(Profile.self, from: encoded)
        XCTAssertEqual(old.growth.rank, "S")
    }
    func testWeeklyReportSeparatesIndoorAndUsesTotalTimeWeightedPace() {
        var profile = Profile(); let now = Date(timeIntervalSince1970: 1_800_000_000)
        var run = RunSummary(id: UUID(), date: now, seconds: 600, elapsedSeconds: 660, distance: 1000, xp: 60, crystals: 0, records: [], completedGoal: true)
        profile.runs = [run]
        run.id = UUID(); run.seconds = 1200; run.elapsedSeconds = 1200; run.distance = 1000
        profile.runs.append(run)
        let report = ActivityInsights(profile: profile, now: now)
        XCTAssertEqual(report.averagePaceSeconds, 930)
        XCTAssertEqual(report.outdoorDistance, 2000)
        XCTAssertEqual(report.days.count, 7); XCTAssertEqual(report.activeDays, 1)
        XCTAssertNil(report.gpsFraction)
    }
    func testJournalAndReportRoundTripAndValidation() throws {
        var save = V3Fixtures.actualSave(); var journal = EquipmentJournal()
        journal.targetID = "core-spear"; journal.presets = [EquipmentPreset(id: 0, name: "탐색용", slots: save.profile.growth.equipped)]
        save.profile.equipmentJournal = journal
        let decoded = try JSONDecoder().decode(SaveState.self, from: JSONEncoder().encode(save))
        XCTAssertTrue(try XCTUnwrap(decoded.profile.equipmentJournal).isValid)
        XCTAssertEqual(decoded.profile.level, 15); XCTAssertEqual(decoded.profile.xp, 4250)
        journal.presets.append(journal.presets[0]); XCTAssertFalse(journal.isValid)
    }
    func testLegacyKillIsNotAnnouncedAsFirstKillAgain() throws {
        var profile = Profile()
        let old = EventRecord(id: "beast", title: "잔향 늑대", outcome: .perfect, damage: 30, defeated: true, kind: .ambush)
        profile.runs = [RunSummary(id: UUID(), date: Date(), seconds: 600, distance: 1000, xp: 60, crystals: 2, records: [old], completedGoal: true)]
        var engine = try V3Fixtures.engine(); engine.consume(V3Fixtures.frame(1, 150)); engine.end()
        let result = Settlement.apply(engine.session, to: &profile)
        XCTAssertTrue(result?.growthReport?.firstDefeats.isEmpty == true)
    }
    func testIndoorAndDefenseNeverInflateOutdoorDistanceOrPace() {
        var profile = Profile(); let now = Date(timeIntervalSince1970: 1_800_000_000)
        var inside = RunSummary(id: UUID(), date: now, seconds: 600, distance: 0, xp: 30, crystals: 1, records: [], completedGoal: true)
        inside.environment = .indoor
        profile.runs = [inside]; profile.defense = DefenseProgress()
        profile.defense?.records = [DefenseRecord(id: UUID(), episode: 1, intensity: .light, seconds: 1440, date: now)]
        let report = ActivityInsights(profile: profile, now: now)
        XCTAssertEqual(report.outdoorDistance, 0); XCTAssertNil(report.averagePaceSeconds)
        XCTAssertEqual(report.indoorSeconds, 2040); XCTAssertEqual(report.activityCount, 2)
        XCTAssertEqual(report.activeDays, 1); XCTAssertEqual(report.days.reduce(0) { $0 + $1.seconds }, 0)
    }
}
