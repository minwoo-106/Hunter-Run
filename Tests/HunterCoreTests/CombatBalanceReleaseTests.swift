import Foundation
import XCTest
@testable import HunterCore

final class CombatBalanceReleaseTests: XCTestCase {
    private func stats(level: Int = 30, gear: [String]) throws -> CombatStats {
        let catalog: ProgressionCatalog = try V3Fixtures.load("Resources/progression.json", as: ProgressionCatalog.self)
        var save = SaveState()
        save.profile.growthEconomy = GrowthEconomyState(level: level, progress: 0, accountedXP: 0, legacyBaseAttack: 1)
        for id in gear {
            let item = try XCTUnwrap(catalog.equipment.first { $0.id == id })
            save.profile.growth.owned.insert(id); save.profile.growth.equipped[item.slot.rawValue] = id
        }
        try EquipmentRevision.migrate(&save, catalog: catalog)
        return catalog.stats(for: save.profile)
    }
    func testFinalBossTakes67AttacksWithObtainablePreClearGear() throws {
        let monster = try XCTUnwrap(V3Fixtures.rules().monsters.first { $0.id == "corrupted-hunter" })
        let attack = try stats(gear: ["ash-mallet", "ash-treads", "hollow-seal"]).attack
        var battle = DistanceBattle(monster: monster)
        battle.advance(distance: 5024, attack: attack)
        XCTAssertGreaterThan(battle.remainingHP, 0)
        battle.advance(distance: 1, attack: attack)
        XCTAssertEqual(battle.remainingHP, 0)
        XCTAssertEqual(battle.attacks, 67)
    }

    func testAllExistingBossKindsKeepSavedHPAndSettleOnceAfterUpgrade() throws {
        let oldRules: CombatRules = try V3Fixtures.load("Tests/HunterCoreTests/Fixtures/combat-v3-legacy-1.9.1.json", as: CombatRules.self)
        let rules = try V3Fixtures.rules()
        var oldWorld: WorldContent = try V3Fixtures.load("Resources/world.json", as: WorldContent.self)
        oldWorld.bosses = oldWorld.bosses.map { CombatRelease.boss($0, rules: oldRules) }
        var world = oldWorld; world.bosses = world.bosses.map { CombatRelease.boss($0, rules: rules) }
        let oldExamHP = [200.0, 420, 650, 900, 1400]
        let exams = Quests.entries.compactMap(\.boss)
        let oldExams = exams.enumerated().map { i, boss in var old = boss; old.maximumHP = oldExamHP[i]; return old }
        let oldBosses = oldWorld.bosses + BossMutations.all(oldWorld) + oldExams
        let newBosses = world.bosses + BossMutations.all(world) + exams
        XCTAssertEqual(newBosses.count, 12)
        for (old, boss) in zip(oldBosses, newBosses) {
            XCTAssertEqual(old.id, boss.id)
            for fraction in [0.01, 0.5, 1.0] {
                var save = V3Fixtures.actualSave(); try CombatRelease.migrate(&save)
                var saved = BossState(maximumHP: old.maximumHP); saved.remainingHP = old.maximumHP * fraction
                save.profile.bosses = [boss.id: saved]
                save = try JSONDecoder().decode(SaveState.self, from: JSONEncoder().encode(save))
                let state = BossCampaign.state(boss, profile: save.profile)
                XCTAssertEqual(state.maximumHP, old.maximumHP, boss.id)
                XCTAssertEqual(state.remainingHP, saved.remainingHP, boss.id)
                var fixture = try V3Fixtures.engine(eventID: "major-strike-test", boss: BossEncounter(definition: boss, state: state))
                var session = fixture.session; session.event?.battle = nil
                try CombatRelease.prepare(&session, rules: rules)
                fixture = RunEngine(session: session, content: fixture.content)
                XCTAssertEqual(fixture.session.event?.battle?.monster.maximumHP, old.maximumHP, boss.id)
                XCTAssertEqual(fixture.session.event?.hp, state.remainingHP, boss.id)
                fixture.consume(V3Fixtures.frame(1, 75000)); fixture.end()
                let report = Settlement.apply(fixture.session, to: &save.profile)
                XCTAssertEqual(report?.majorBoss?.cleared, true, boss.id)
                XCTAssertEqual(report?.majorBoss?.damage ?? -1, saved.remainingHP, accuracy: 1e-6, boss.id)
                XCTAssertNil(Settlement.apply(fixture.session, to: &save.profile), boss.id)
                XCTAssertEqual(BossCampaign.state(boss, profile: save.profile).remainingHP, 0, boss.id)
                XCTAssertEqual(BossCampaign.state(boss, profile: save.profile).clears, 1, boss.id)
                XCTAssertEqual(BossCampaign.state(boss, profile: Profile()).maximumHP, boss.maximumHP, boss.id)
            }
        }
    }

    func testOldActiveMonsterSnapshotSurvivesSaveAndNewSessionUsesNewHP() throws {
        let oldRules: CombatRules = try V3Fixtures.load("Tests/HunterCoreTests/Fixtures/combat-v3-legacy-1.9.1.json", as: CombatRules.self)
        let rules = try V3Fixtures.rules()
        for monster in rules.monsters where !monster.persistent {
            let eventID = try XCTUnwrap(rules.eventMonsters.first { $0.value == monster.id }?.key)
            let old = try XCTUnwrap(oldRules.monsters.first { $0.id == monster.id })
            let fixture = try V3Fixtures.engine(eventID: eventID)
            var session = fixture.session; session.event?.battle = nil; session.combatRules = oldRules
            var run = RunEngine(session: session, content: fixture.content)
            run.consume(V3Fixtures.frame(1, 75))
            var save = V3Fixtures.actualSave(); save.active = run.session
            let beforeHP = run.session.event?.hp
            save = try JSONDecoder().decode(SaveState.self, from: JSONEncoder().encode(save))
            XCTAssertFalse(try CombatRelease.migrate(&save))
            XCTAssertEqual(save.active?.event?.hp, beforeHP, monster.id)
            XCTAssertEqual(save.active?.combatRules?.monsters.first { $0.id == monster.id }?.maximumHP, old.maximumHP)
            let fresh = try V3Fixtures.engine(eventID: eventID)
            XCTAssertEqual(fresh.session.event?.hp, monster.maximumHP, monster.id)
        }
    }

    func testAllFieldMonstersPayExactlyOneFixedEXPWithNewHP() throws {
        let rules = try V3Fixtures.rules()
        for monster in rules.monsters where !monster.persistent {
            let eventID = try XCTUnwrap(rules.eventMonsters.first { $0.value == monster.id }?.key)
            var run = try V3Fixtures.engine(eventID: eventID)
            let hits = Int(ceil(monster.maximumHP / DistanceBattle.damagePerAttack(attack: 2.915, defense: monster.defense)))
            run.consume(V3Fixtures.frame(1, Double(hits * 75 - 1)))
            XCTAssertGreaterThan(run.session.event?.hp ?? 0, 0, monster.id)
            run.consume(V3Fixtures.frame(2, 1)); run.consume(V3Fixtures.frame(3, 7500)); run.end()
            XCTAssertEqual(run.session.records.count, 1, monster.id)
            XCTAssertEqual(run.session.records.first?.damage, monster.maximumHP, monster.id)
            XCTAssertEqual(run.session.records.first?.attacks, hits, monster.id)
            XCTAssertEqual(CombatExperience.reward(run.session, bossReport: nil), monster.experience, monster.id)
            var save = V3Fixtures.actualSave(); try CombatRelease.migrate(&save)
            XCTAssertNotNil(Settlement.apply(run.session, to: &save.profile), monster.id)
            let xp = save.profile.xp
            XCTAssertNil(Settlement.apply(run.session, to: &save.profile), monster.id)
            XCTAssertEqual(save.profile.xp, xp, monster.id)
        }
    }

    func testClearedOldRoundStaysClearedUntilExplicitReplayUsesNewHP() throws {
        let rules = try V3Fixtures.rules()
        let catalog: ProgressionCatalog = try V3Fixtures.load("Resources/progression.json", as: ProgressionCatalog.self)
        var world: WorldContent = try V3Fixtures.load("Resources/world.json", as: WorldContent.self)
        world.bosses = world.bosses.map { CombatRelease.boss($0, rules: rules) }
        for boss in world.bosses {
            var save = V3Fixtures.actualSave()
            save.profile.growth.rank = "S"
            var old = BossState(maximumHP: boss.id == "void-librarian" ? 4800 : boss.id == "corrupted-hunter" ? 15000 : 2200)
            old.remainingHP = 0; old.clears = 1
            save.profile.bosses = [boss.id: old]
            if let ids = boss.requiredDefeats { XCTAssertFalse(ids.isEmpty) }
            XCTAssertEqual(BossCampaign.state(boss, profile: save.profile), old)
            if boss.id == "corrupted-hunter" {
                XCTAssertThrowsError(try BossCampaign.restart(boss, save: &save, catalog: catalog))
                XCTAssertEqual(save.profile.bosses?[boss.id], old)
            } else {
                try BossCampaign.restart(boss, save: &save, catalog: catalog)
                XCTAssertEqual(save.profile.bosses?[boss.id]?.maximumHP, boss.maximumHP)
                XCTAssertEqual(save.profile.bosses?[boss.id]?.remainingHP, boss.maximumHP)
                XCTAssertEqual(save.profile.bosses?[boss.id]?.round, 2)
                XCTAssertEqual(save.profile.bosses?[boss.id]?.clears, 1)
            }
        }
    }
}
