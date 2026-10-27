import XCTest
@testable import HunterCore

final class FieldExpansionTests: XCTestCase {
    func load<T: Decodable>(_ file: String, _ type: T.Type) throws -> T {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return try JSONDecoder().decode(type, from: Data(contentsOf: root.appendingPathComponent("Resources/" + file + ".json")))
    }
    func unlocked() -> Profile {
        var p = Profile(); var g = p.growth; g.rank = "B"
        for d in Department.allCases { g.departments[d.rawValue] = 3 }; p.growth = g; var journey = JourneyState(); journey.unlocked = Set((1...16).map { String(format: "M%02d", $0) }); p.journey = journey; return p
    }
    func testEncounterUnlocksRequireBothRankAndDepartment() throws {
        let c = try load("encounters", EncounterCatalog.self), g = try load("progression", ProgressionCatalog.self)
        try c.validate(); var p = Profile()
        XCTAssertTrue(c.encounters.filter { $0.available(to: p, catalog: g) }.isEmpty)
        p = unlocked(); XCTAssertEqual(c.encounters.filter { $0.available(to: p, catalog: g) }.count, 18)
        var growth = p.growth; growth.rank = "E"; p.growth = growth
        XCTAssertEqual(c.encounters.filter { $0.available(to: p, catalog: g) }.count, 2)
    }
    func testPoolsPreserveGateCoreAndExplorationRemainsInvestigation() throws {
        let c = try load("encounters", EncounterCatalog.self), g = try load("progression", ProgressionCatalog.self), m = try load("missions", MissionCatalog.self)
        for mode in RunMode.allCases {
            let base = m.content(for: mode, extended: true), content = c.populate(base, mode: mode, profile: unlocked(), catalog: g)
            try content.validate(); XCTAssertEqual(content.events.count, base.events.count)
            XCTAssertFalse(content.encounterPools!.contains { $0.slotID == "gate-core" })
            if mode == .exploration { XCTAssertTrue(content.encounterPools!.flatMap(\.alternatives).allSatisfy { $0.kind == .discovery }) }
        }
    }
    func testPatrolRotatesAlternativesAndRestoresIdentically() throws {
        let c = try load("encounters", EncounterCatalog.self), g = try load("progression", ProgressionCatalog.self), m = try load("missions", MissionCatalog.self)
        let content = c.populate(m.content(for: .contract, extended: true), mode: .contract, profile: unlocked(), catalog: g)
        var run = RunSession(targetSeconds: 1800, simulated: false, allowPursuit: true); run.directorVersion = 2; run.missionSnapshot = content
        let restored = try JSONDecoder().decode(RunSession.self, from: JSONEncoder().encode(run))
        var seen: Set<String> = []
        for cycle in 0..<12 {
            let events = RunDirector.events(content, session: run, cycle: cycle)
            XCTAssertEqual(events.map(\.id), RunDirector.events(restored.missionSnapshot!, session: restored, cycle: cycle).map(\.id))
            seen.formUnion(events.map { $0.id.components(separatedBy: "#")[0] })
        }
        XCTAssertTrue(seen.contains("dark-elf-scout")); XCTAssertTrue(seen.contains("dark-elf-captain"))
        run.directorVersion = 1
        XCTAssertEqual(RunDirector.events(content, session: run, cycle: 0).map(\.id), content.events.map(\.id))
    }
    func testShortCaptainUsesItsOwnInstruction() throws {
        let c = try load("encounters", EncounterCatalog.self)
        let content = c.encounters.first { $0.id == "dark-elf-captain" }!.preview
        let run = RunSession(targetSeconds: 600, simulated: true, allowPursuit: false)
        let event = RunDirector.events(content, session: run, cycle: 0)[0]
        XCTAssertEqual(event.kind, .maintain); XCTAssertEqual(event.audio, "captain_hold"); XCTAssertNil(event.targetDistance)
    }
    func testInvalidPoolCannotEnterSaveSnapshot() throws {
        let c = try load("encounters", EncounterCatalog.self); var content = c.encounters[0].preview
        content.encounterPools = [EncounterPool(slotID: "missing", alternatives: [c.encounters[1].event])]
        XCTAssertThrowsError(try content.validate())
        content.encounterPools = [EncounterPool(slotID: content.events[0].id, alternatives: [content.events[0]])]
        XCTAssertThrowsError(try content.validate())
    }
    func testOnlyRealNonNeutralDiscoveryUnlocksEquipmentAndPersists() throws {
        var p = unlocked(); let c = try load("progression", ProgressionCatalog.self)
        let item = c.equipment.first { $0.id == "moon-boots" }!
        var run = RunSession(targetSeconds: 300, simulated: true, allowPursuit: false)
        run.phase = .finished; run.activeSeconds = 300
        run.records = [EventRecord(id: "dark-elf-scout#2", title: "조사", outcome: .perfect, damage: 0, kind: .discovery)]
        XCTAssertNil(Settlement.apply(run, to: &p)); XCTAssertFalse(item.available(to: p))
        run.simulated = false; run.records[0].outcome = .neutral
        Settlement.apply(run, to: &p); XCTAssertFalse(item.available(to: p))
        run.id = UUID(); run.records[0].outcome = .perfect
        Settlement.apply(run, to: &p); XCTAssertTrue(item.available(to: p))
        p.runs = []; let restored = try JSONDecoder().decode(Profile.self, from: JSONEncoder().encode(p))
        XCTAssertTrue(item.available(to: restored))
    }
    func testDiscoveryGearCannotChargeBeforeUnlockOrTwice() throws {
        let c = try load("progression", ProgressionCatalog.self); var save = SaveState()
        save.profile = unlocked(); save.profile.crystals = 200; save.profile.research = 100
        XCTAssertThrowsError(try Progression.buy("moon-boots", save: &save, catalog: c)); XCTAssertEqual(save.profile.crystals, 200)
        save.profile.discoveredEvents = ["dark-elf-scout"]
        try Progression.buy("moon-boots", save: &save, catalog: c); let remaining = save.profile.crystals
        XCTAssertThrowsError(try Progression.buy("moon-boots", save: &save, catalog: c)); XCTAssertEqual(save.profile.crystals, remaining)
    }
    func testAllDepartmentsUpgradeThroughThreeOnce() throws {
        let c = try load("progression", ProgressionCatalog.self); var save = SaveState()
        save.profile = unlocked(); var entry = save.profile.growth; entry.departments = [:]; save.profile.growth = entry
        save.profile.crystals = 1000; save.profile.research = 1000
        for d in Department.allCases {
            try Progression.upgrade(d, save: &save, catalog: c); XCTAssertEqual(save.profile.growth.level(d), 2)
            try Progression.upgrade(d, save: &save, catalog: c); XCTAssertEqual(save.profile.growth.level(d), 3)
            let remaining = save.profile.crystals
            XCTAssertThrowsError(try Progression.upgrade(d, save: &save, catalog: c)); XCTAssertEqual(save.profile.crystals, remaining)
        }
    }
}
