import XCTest
@testable import HunterCore

final class Release136Tests: XCTestCase {
    private func load<T: Decodable>(_ name: String, as type: T.Type) throws -> T {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return try JSONDecoder().decode(type, from: Data(contentsOf: root.appendingPathComponent("Resources/" + name + ".json")))
    }

    private func advancedProfile() -> Profile {
        var profile = Profile()
        var growth = profile.growth
        growth.rank = "A"
        growth.departments[Department.equipment.rawValue] = 3
        growth.departments[Department.observation.rawValue] = 3
        profile.growth = growth
        var journey = JourneyState()
        journey.unlocked.insert("M16")
        profile.journey = journey
        return profile
    }

    private func settleDefeats(_ ids: [String], in profile: inout Profile) {
        var run = RunSession(targetSeconds: 300, simulated: false, allowPursuit: false, mode: .contract)
        run.activeSeconds = 300
        run.phase = .finished
        run.records = ids.map { EventRecord(id: $0, title: "정화", outcome: .success, damage: 250, defeated: true, kind: .maintain) }
        XCTAssertNotNil(Settlement.apply(run, to: &profile))
    }

    func testBossGearNeedsRealDefeatButExistingOwnedGearStillEquips() throws {
        let catalog = try load("progression", as: ProgressionCatalog.self)
        var save = SaveState(); save.profile = advancedProfile()
        save.profile.crystals = 200; save.profile.research = 100; save.profile.growth.cores = 10
        let blade = try XCTUnwrap(catalog.equipment.first { $0.id == "moon-blade" })
        save.profile.discoveredEvents = ["dark-elf-captain"]
        XCTAssertFalse(blade.available(to: save.profile))
        XCTAssertThrowsError(try Progression.buy(blade.id, save: &save, catalog: catalog))
        settleDefeats(["dark-elf-captain"], in: &save.profile)
        XCTAssertTrue(blade.available(to: save.profile))
        try Progression.buy(blade.id, save: &save, catalog: catalog)
        try Progression.equip(blade.id, save: &save, catalog: catalog)
        XCTAssertEqual(save.profile.growth.equipped["weapon"], blade.id)
        // Save compatibility: owned items remain usable even if a future catalog tightens unlocks.
        save.profile.runs = []
        try Progression.equip(blade.id, save: &save, catalog: catalog)
        try Progression.equip(blade.id, save: &save, catalog: catalog)
        XCTAssertEqual(save.profile.growth.equipped["weapon"], blade.id)
    }

    func testFourDistinctVanguardsGateFinalBoss() throws {
        let world = try load("world", as: WorldContent.self)
        let catalog = try load("progression", as: ProgressionCatalog.self)
        let boss = try XCTUnwrap(world.bosses.first { $0.id == "corrupted-hunter" })
        var profile = advancedProfile()
        XCTAssertFalse(boss.available(to: profile, catalog: catalog))
        let team = try XCTUnwrap(boss.requiredDefeats)
        XCTAssertEqual(team.count, 4)
        settleDefeats(Array(team.dropLast()), in: &profile)
        XCTAssertFalse(boss.available(to: profile, catalog: catalog))
        settleDefeats([team[3]], in: &profile)
        XCTAssertTrue(boss.available(to: profile, catalog: catalog))
    }

    func testEquipmentProgressesBeyondOldLevelCap() throws {
        let catalog = try load("progression", as: ProgressionCatalog.self)
        var profile = advancedProfile()
        profile.xp = 25 * 300
        var growth = profile.growth; growth.owned.insert("core-spear"); growth.equipped["weapon"] = "core-spear"; profile.growth = growth
        XCTAssertGreaterThan(catalog.stats(for: profile).attack, 3)
        let items = Dictionary(uniqueKeysWithValues: catalog.equipment.map { ($0.id, $0) })
        for path in [
            ["core-spear", "moon-blade", "dream-staff", "glass-rapier", "ash-mallet", "return-blade"],
            ["core-armor", "moon-wardplate", "dream-wardcloak", "mirror-coat", "ash-cuirass", "return-jacket"],
            ["core-shoes", "moon-wardboots", "dream-wardsteps", "echo-striders", "ash-treads", "anchor-boots"]
        ] {
            let tiers = path.compactMap { items[$0]?.tier }
            XCTAssertEqual(tiers, [3, 4, 5, 6, 7, 8])
        }
        let weapons = ["core-spear", "moon-blade", "dream-staff", "glass-rapier", "ash-mallet", "return-blade"].compactMap { items[$0]?.attack }
        XCTAssertEqual(weapons, weapons.sorted())
    }
}
