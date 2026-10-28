import Foundation
import XCTest
@testable import HunterCore

private struct CombatGoldenRow: Decodable {
    var level: Int; var gear: String; var attack: Double; var wolfDamage: Int
    var wolfHits: Int; var wolfDistance: Int; var guardHits: Int; var representative: String; var representativeHits: Int
    init(from decoder: Decoder) throws {
        var c = try decoder.unkeyedContainer()
        level = try c.decode(Int.self); gear = try c.decode(String.self); attack = try c.decode(Double.self)
        wolfDamage = try c.decode(Int.self); wolfHits = try c.decode(Int.self); wolfDistance = try c.decode(Int.self)
        guardHits = try c.decode(Int.self); representative = try c.decode(String.self); representativeHits = try c.decode(Int.self)
    }
}
final class CombatGoldenTests: XCTestCase {
    func testAll72LegacySnapshotRowsThroughRealCatalogAndCombatKernel() throws {
        let rows: [CombatGoldenRow] = try V3Fixtures.load("Tests/HunterCoreTests/Fixtures/combat-v3-golden.json",as:[CombatGoldenRow].self)
        let rules: CombatRules = try V3Fixtures.load("Tests/HunterCoreTests/Fixtures/combat-v3-legacy-1.9.1.json", as: CombatRules.self)
        let catalog: ProgressionCatalog = try V3Fixtures.load("Resources/progression.json",as:ProgressionCatalog.self)
        let sets: [String:[String]] = [
            "무장 없음":[], "기본":["field-blade","field-vest","field-shoes","field-compass"],
            "현재 E급":["resonance-blade","barrier-coat","trace-shoes","archive-lens"],
            "첫 코어":["core-spear","core-armor","core-shoes","core-orbit"],
            "월영":["moon-blade","moon-wardplate","moon-wardboots","moon-compass"],
            "몽환":["dream-staff","dream-wardcloak","dream-wardsteps","dream-mirror"],
            "거울결":["glass-rapier","mirror-coat","echo-striders","glass-compass"],
            "철갑":["ash-mallet","ash-cuirass","ash-treads","hollow-seal"],
            "귀환":["return-blade","return-jacket","anchor-boots","return-badge"]]
        XCTAssertEqual(rows.count,72)
        for row in rows {
            var profile = Profile()
            profile.growthEconomy = GrowthEconomyState(level:row.level,progress:0,accountedXP:0,legacyBaseAttack:1)
            var growth = profile.growth
            for id in try XCTUnwrap(sets[row.gear]) {
                let item = try XCTUnwrap(catalog.equipment.first { $0.id == id })
                growth.owned.insert(id); growth.equipped[item.slot.rawValue] = id
            }
            profile.growth = growth
            let attack = catalog.stats(for:profile).attack
            let label = "\(row.gear) · Lv\(row.level)"
            XCTAssertEqual(attack,row.attack,accuracy:0.000051,label)
            var wolf = DistanceBattle(monster:try XCTUnwrap(rules.monsters.first { $0.id == "echo-wolf" }))
            let first = wolf.advance(distance:75,attack:attack)
            XCTAssertEqual(first,Double(min(180,row.wolfDamage)),label)
            if row.wolfHits > 1 { wolf.advance(distance:Double(row.wolfHits-1)*75,attack:attack) }
            XCTAssertEqual(wolf.remainingHP,0,label)
            XCTAssertEqual(wolf.attacks,row.wolfHits,label)
            XCTAssertEqual(wolf.attacks*75,row.wolfDistance,label)
            for (id,hits) in [("iron-guard",row.guardHits),(rules.monsters.first { $0.name == row.representative }!.id,row.representativeHits)] {
                var battle = DistanceBattle(monster:try XCTUnwrap(rules.monsters.first { $0.id == id }))
                battle.advance(distance:Double(hits)*75-1,attack:attack)
                XCTAssertGreaterThan(battle.remainingHP,0,label)
                battle.advance(distance:1,attack:attack)
                XCTAssertEqual(battle.remainingHP,0,label)
                XCTAssertEqual(battle.attacks,hits,label)
            }
        }
    }
    func testCatalogCoversEveryFieldMonsterAndAllThreeStoryBosses() throws {
        let rules = try V3Fixtures.rules()
        let world: WorldContent = try V3Fixtures.load("Resources/world.json",as:WorldContent.self)
        let encounters: EncounterCatalog = try V3Fixtures.load("Resources/encounters.json",as:EncounterCatalog.self)
        XCTAssertTrue(rules.isValid)
        XCTAssertEqual(rules.monsters.count,26)
        for monster in world.monsters {
            XCTAssertNotNil(rules.monsters.first { $0.id == monster.id },monster.name)
            if monster.bossID == nil {
                for id in monster.eventIDs { XCTAssertNotNil(rules.monster(for:id),id) }
            }
        }
        for entry in encounters.encounters { XCTAssertNotNil(rules.monster(for:entry.event.id),entry.name) }
    }
}
