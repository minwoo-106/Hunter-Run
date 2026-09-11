import XCTest
@testable import HunterCore

final class StoryProgressTests: XCTestCase {
    private func settle(_ profile: inout Profile, seconds: Double = 300, simulated: Bool = false, goal: ActivityGoal? = nil) {
        var run = RunSession(targetSeconds: 300, simulated: simulated, allowPursuit: false)
        run.activeSeconds = seconds; run.phase = .finished; run.goal = goal
        Settlement.apply(run, to: &profile)
    }
    func testRealSettlementUnlocksButSimulationAndShortRunsDoNot() {
        var profile = Profile()
        XCTAssertEqual(StoryProgress.unread(profile).map(\.id), ["arrival"])
        settle(&profile, simulated: true)
        XCTAssertFalse(StoryProgress.available(StoryProgress.entries[1], profile: profile))
        settle(&profile, seconds: 299)
        XCTAssertFalse(StoryProgress.available(StoryProgress.entries[1], profile: profile))
        settle(&profile)
        XCTAssertTrue(StoryProgress.available(StoryProgress.entries[1], profile: profile))
        XCTAssertFalse(StoryProgress.available(StoryProgress.entries[2], profile: profile))
        settle(&profile)
        XCTAssertTrue(StoryProgress.available(StoryProgress.entries[2], profile: profile))
    }
    func testFreeActivityUnlocksFirstReportButNotGoalRequirement() {
        var profile = Profile()
        for _ in 0..<3 { settle(&profile, goal: ActivityGoal(kind: .free, value: 0)) }
        XCTAssertTrue(StoryProgress.available(StoryProgress.entries[1], profile: profile))
        XCTAssertFalse(StoryProgress.available(StoryProgress.entries[2], profile: profile))
    }
    func testFacilitiesAndBossProgressKeepStoryOrder() {
        var profile = Profile()
        var growth = profile.growth
        for department in Department.allCases { growth.departments[department.rawValue] = 2 }
        profile.growth = growth
        XCTAssertFalse(StoryProgress.available(StoryProgress.entries[5], profile: profile))
        settle(&profile); settle(&profile)
        XCTAssertTrue(StoryProgress.available(StoryProgress.entries[3], profile: profile))
        XCTAssertFalse(StoryProgress.available(StoryProgress.entries[5], profile: profile))
        var boss = BossState(maximumHP: 300); boss.clears = 1
        profile.bosses = ["boundary-lord": boss]
        XCTAssertTrue(StoryProgress.available(StoryProgress.entries[5], profile: profile))
        XCTAssertNil(StoryProgress.nextRequirement(profile))
    }
    func testReadingIsIdempotentAndCannotUnlockOrGrantResources() {
        var profile = Profile()
        XCTAssertFalse(StoryProgress.markRead("signal", profile: &profile))
        XCTAssertFalse(StoryProgress.markRead("missing", profile: &profile))
        XCTAssertTrue(StoryProgress.markRead("arrival", profile: &profile))
        XCTAssertTrue(StoryProgress.markRead("arrival", profile: &profile))
        XCTAssertEqual(profile.readStories, ["arrival"])
        XCTAssertTrue(StoryProgress.unread(profile).isEmpty)
        XCTAssertEqual(profile.xp, 0); XCTAssertEqual(profile.crystals, 0); XCTAssertEqual(profile.research, 0)
    }
    func testLegacyAndNewProgressSurviveSaveRoundTrip() throws {
        let encoder = JSONEncoder()
        let legacy = try JSONDecoder().decode(SaveState.self, from: encoder.encode(SaveState()))
        XCTAssertNil(legacy.profile.introductionSeen); XCTAssertNil(legacy.profile.readStories)
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let repository = SaveRepository(directory: folder)
        XCTAssertFalse(repository.hasStoredSave)
        var save = legacy; save.profile.introductionSeen = true
        StoryProgress.markRead("arrival", profile: &save.profile)
        try repository.write(save)
        XCTAssertTrue(repository.hasStoredSave)
        let loaded = try repository.load()
        XCTAssertEqual(loaded.profile.readStories, ["arrival"])
        XCTAssertEqual(loaded.profile.introductionSeen, true)
        XCTAssertEqual(loaded.profile.xp, legacy.profile.xp)
    }
}
