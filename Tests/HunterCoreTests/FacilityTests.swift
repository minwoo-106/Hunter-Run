import XCTest
@testable import HunterCore

final class FacilityTests: XCTestCase {
    func testConstructionRequiresBothRealClearAndStoryReturn() {
        var profile = Profile(); profile.journey = JourneyState()
        XCTAssertEqual(HaesolSanctum.stage(profile), .hidden)
        XCTAssertFalse(HaesolSanctum.build(&profile))
        profile.journey?.completed.insert("M20")
        XCTAssertFalse(HaesolSanctum.build(&profile))
        var boss = BossState(maximumHP: 3200); boss.remainingHP = 0; boss.clears = 1
        profile.bosses = ["corrupted-hunter": boss]
        XCTAssertFalse(HaesolSanctum.restore(&profile))
        XCTAssertTrue(HaesolSanctum.build(&profile))
        XCTAssertFalse(HaesolSanctum.build(&profile))
        XCTAssertTrue(HaesolSanctum.restore(&profile))
        XCTAssertFalse(HaesolSanctum.restore(&profile))
        XCTAssertEqual(HaesolSanctum.stage(profile), .restored)
    }
    func testConstructionSurvivesSaveWithoutSpendingOrGrantingRewards() throws {
        var save = SaveState(); save.profile.journey = JourneyState()
        save.profile.journey?.completed.insert("M20")
        var boss = BossState(maximumHP: 3200); boss.clears = 1
        save.profile.bosses = ["corrupted-hunter": boss]
        save.profile.crystals = 0; save.profile.research = 0
        XCTAssertTrue(HaesolSanctum.build(&save.profile))
        let loaded = try JSONDecoder().decode(SaveState.self, from: JSONEncoder().encode(save))
        XCTAssertEqual(HaesolSanctum.stage(loaded.profile), .operational)
        XCTAssertEqual(loaded.profile.crystals, 0)
        XCTAssertEqual(loaded.profile.research, 0)
        XCTAssertEqual(loaded.profile.xp, save.profile.xp)
    }
    func testLegacyRestoredProfileNeedsNoNewConstruction() throws {
        var profile = Profile(); profile.journey = JourneyState()
        profile.journey?.memories[HaesolSanctum.restorationKey] = "yes"
        let restored = try JSONDecoder().decode(Profile.self, from: JSONEncoder().encode(profile))
        XCTAssertNil(restored.journey?.memories[HaesolSanctum.constructionKey])
        XCTAssertEqual(HaesolSanctum.stage(restored), .restored)
        XCTAssertFalse(HaesolSanctum.build(&profile))
        XCTAssertFalse(HaesolSanctum.restore(&profile))
    }
}
