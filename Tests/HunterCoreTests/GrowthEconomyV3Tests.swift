import Foundation
import XCTest
@testable import HunterCore

final class GrowthEconomyV3Tests: XCTestCase {
    func testPreservedLevel15UsesIncreasingCurveForFutureExperience() throws {
        let data = Data(#"{"name":"기존 헌터","xp":4250,"crystals":203,"research":200,"observationLevel":1,"settled":[],"runs":[],"growthEconomy":{"version":3,"level":15,"progress":50,"accountedXP":4250,"legacyBaseAttack":2.12}}"#.utf8)
        var profile = try JSONDecoder().decode(Profile.self, from: data)
        XCTAssertEqual(profile.level, 15)
        profile.xp += 610
        XCTAssertEqual(profile.level, 16, "기존 진행50과 추가610으로16레벨이 되어야 합니다.")
        XCTAssertEqual(profile.attack, 2.132, accuracy: 0.000001)
    }
    func testActualLegacySaveKeepsLevelXPItemsRankStoryAndFacilities() throws {
        var save = V3Fixtures.actualSave()
        let before = save.profile
        try GrowthEconomy.enable(in:&save)
        XCTAssertEqual(save.profile.level,15)
        XCTAssertEqual(save.profile.xp,4250)
        XCTAssertEqual(save.profile.growthEconomy?.progress,50)
        XCTAssertEqual(save.profile.growth.rank,before.growth.rank)
        XCTAssertEqual(save.profile.growth.owned,before.growth.owned)
        XCTAssertEqual(save.profile.growth.equipped,before.growth.equipped)
        XCTAssertEqual(save.profile.growth.departments,before.growth.departments)
        XCTAssertEqual(save.profile.journey?.unlocked,before.journey?.unlocked)
        XCTAssertEqual(save.profile.journey?.completedQuests,before.journey?.completedQuests)
        let stats = try V3Fixtures.load("Resources/progression.json",as:ProgressionCatalog.self).stats(for:save.profile)
        XCTAssertEqual(stats.attack,2.915,accuracy:0.000001)
        XCTAssertEqual(stats.hp,180)
        XCTAssertEqual(stats.defense,0.29,accuracy:0.000001)
        save = try JSONDecoder().decode(SaveState.self,from:JSONEncoder().encode(save))
        try GrowthEconomy.enable(in:&save)
        XCTAssertEqual(save.profile.level,15)
        XCTAssertEqual(save.profile.xp,4250)
    }
    func testEveryPossibleLegacyLevel15RemainderIsPreserved() throws {
        for progress in 0..<300 {
            var save = V3Fixtures.actualSave(progress:progress)
            try GrowthEconomy.enable(in:&save)
            XCTAssertEqual(save.profile.level,15)
            XCTAssertEqual(save.profile.growthEconomy?.progress,progress)
            XCTAssertEqual(save.profile.xp,4200+progress)
        }
    }
    func testExistingLevel100AttackFloorIsNotLost() throws {
        var save = V3Fixtures.actualSave(level:100)
        let catalog: ProgressionCatalog = try V3Fixtures.load("Resources/progression.json",as:ProgressionCatalog.self)
        XCTAssertEqual(catalog.stats(for:save.profile).attack,9.17,accuracy:0.000001)
        try GrowthEconomy.enable(in:&save)
        XCTAssertEqual(save.profile.level,100)
        XCTAssertEqual(catalog.stats(for:save.profile).attack,9.17,accuracy:0.000001)
        XCTAssertEqual(save.profile.growth.rank,"E")
    }
    func testActiveLegacySessionCannotBeMigratedMidCombat() throws {
        var save = V3Fixtures.actualSave()
        save.active = RunSession(targetSeconds:1800,simulated:false,allowPursuit:false)
        XCTAssertThrowsError(try GrowthEconomy.enable(in:&save))
        XCTAssertNil(save.profile.growthEconomy)
        XCTAssertNil(save.active?.combatRules)
        XCTAssertEqual(save.profile.xp,4250)
    }
    func testCurveAndSoftcapMatchApprovedCheckpoints() {
        let expected = [(1,275,1.0),(10,525,1.72),(15,660,2.12),(20,800,2.18),(30,965,2.30),(45,1210,2.39),(60,1460,2.48),(100,2010,2.557853260)]
        for (level,xp,atk) in expected {
            XCTAssertEqual(GrowthEconomy.requiredExperience(level),xp)
            XCTAssertEqual(GrowthEconomy.baseAttack(level),atk,accuracy:0.00000001)
        }
        XCTAssertLessThan(GrowthEconomy.baseAttack(1000),2.64)
    }
    func testFutureQuestOrWeeklyXPIsAccountedOnceAcrossRepeatedReadsAndSave() throws {
        var save = V3Fixtures.actualSave(); try GrowthEconomy.enable(in:&save)
        save.profile.xp += 80
        XCTAssertEqual(GrowthEconomy.resolved(try XCTUnwrap(save.profile.growthEconomy),totalXP:save.profile.xp).progress,130)
        for _ in 0..<20 { XCTAssertEqual(save.profile.level,15) }
        save = try JSONDecoder().decode(SaveState.self,from:JSONEncoder().encode(save))
        save.profile.xp += 530
        XCTAssertEqual(save.profile.level,16)
        XCTAssertEqual(save.profile.xp,4860)
        XCTAssertEqual(save.profile.growth.rank,"E")
    }

}
