import XCTest
@testable import HunterCore

/// Exercise actual run settlement and purchased progression, never grant story gates or currency.
final class CampaignTests: XCTestCase {
    func load<T: Decodable>(_ name: String, _ type: T.Type) throws -> T {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return try JSONDecoder().decode(type, from: Data(contentsOf: root.appendingPathComponent("Resources/" + name + ".json")))
    }
    func testFreshAccountCanReachAllMainChaptersAndFinalRankThroughEarnedProgress() throws {
        let narrative = try load("narrative", NarrativeCatalog.self)
        let growth = try load("progression", ProgressionCatalog.self)
        let missions = try load("missions", MissionCatalog.self)
        let world = try load("world", WorldContent.self)
        let encounters = try load("encounters", EncounterCatalog.self)
        var save = SaveState()
        try narrative.register(hunter: "새 헌터", operatorName: "하나", profile: &save.profile)
        var reached: [String: Int] = [:]
        for activity in 0..<180 {
            narrative.refresh(&save.profile)
            for scene in narrative.main where save.profile.journey!.unlocked.contains(scene.id) {
                if reached[scene.id] == nil { reached[scene.id] = Progression.activityMinutes(save.profile) }
            }
            for quest in Quests.entries where save.profile.journey!.completedQuests.contains(quest.id) && !save.profile.journey!.claimedQuests.contains(quest.id) && quest.available(save.profile) {
                try Quests.claim(quest.id, save: &save)
            }
            if Progression.canPromote(save.profile) { try Progression.promote(save: &save) }
            for department in Department.allCases {
                if let upgrade = growth.upgrades.first(where: { $0.department == department && $0.level == save.profile.growth.level(department) + 1 }),
                   upgrade.available(to: save.profile), save.profile.crystals >= upgrade.crystals, save.profile.research >= upgrade.research {
                    try Progression.upgrade(department, save: &save, catalog: growth)
                }
            }
            // Modest real purchases; no artificial max-level loadout.
            for item in growth.equipment.filter({ ["field-blade", "field-vest", "resonance-blade"].contains($0.id) }) {
                if item.available(to: save.profile), !save.profile.growth.owned.contains(item.id),
                   save.profile.crystals >= item.crystals, save.profile.research >= item.research, save.profile.growth.cores >= item.cores {
                    try Progression.buy(item.id, save: &save, catalog: growth)
                    try Progression.equip(item.id, save: &save, catalog: growth)
                }
            }
            narrative.refresh(&save.profile)
            if save.profile.growth.rank == "S" && save.profile.journey!.unlocked.contains("M16") { break }
            let pending = Quests.entries.filter { $0.available(save.profile) && !save.profile.journey!.completedQuests.contains($0.id) }
            let quest = pending.first(where: { $0.promotion != nil }) ?? pending.first(where: { $0.id != "wolf-ten" })
            let boss = quest?.boss ?? (quest == nil ? world.bosses.first(where: { $0.available(to: save.profile, catalog: growth) && BossCampaign.state($0, profile: save.profile).clears == 0 }) : nil)
            let mode: RunMode = boss != nil || quest == nil && Progression.allows(.gate, profile: save.profile, catalog: growth) ? .gate : .contract
            var content = missions.content(for: mode, extended: true)
            content = quest?.mission(from: content) ?? encounters.populate(content, mode: mode, profile: save.profile, catalog: growth)
            try content.validate()
            var session = RunSession(targetSeconds: 1200, simulated: false, allowPursuit: false, mode: mode)
            session.questID = quest?.id; session.loadout = growth.stats(for: save.profile)
            if let boss { session.boss = BossEncounter(definition: boss, state: BossCampaign.state(boss, profile: save.profile)) }
            session.missionSnapshot = content
            var engine = RunEngine(session: session, content: content)
            for t in 0...1200 {
                engine.consume(SensorFrame(timestamp: Double(t), speed: 2.8, distance: 2.8, movement: .running, signal: .good))
                engine.instructionFinished()
            }
            engine.end()
            XCTAssertNotNil(Settlement.apply(engine.session, to: &save.profile))
            try SaveRepository(directory: FileManager.default.temporaryDirectory).validate(save)
            if activity == 179 { XCTFail("Campaign stalled at rank " + save.profile.growth.rank + " chapters " + String(reached.count)) }
        }
        narrative.refresh(&save.profile)
        XCTAssertEqual(save.profile.growth.rank, "S")
        XCTAssertEqual(narrative.main.filter { save.profile.journey!.unlocked.contains($0.id) }.count, 16)
        XCTAssertEqual(AssociationStage.level(save.profile), 4)
        XCTAssertGreaterThanOrEqual(reached["M06"] ?? 0, 60)
        XCTAssertGreaterThanOrEqual(reached["M13"] ?? 0, 300)
        print("CAMPAIGN milestone minutes: " + reached.keys.sorted().map { $0 + "=" + String(reached[$0]!) }.joined(separator: ", "))
    }
}
