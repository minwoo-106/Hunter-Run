import XCTest
@testable import HunterCore

final class DefenseCampaignTests: XCTestCase {
    func catalog() throws -> DefenseCatalog {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return try JSONDecoder().decode(DefenseCatalog.self, from: Data(contentsOf: root.appendingPathComponent("Resources/defense-campaign.json")))
    }
    func testAllThirtyEpisodesHaveCompleteContentAndEqualDurations() throws {
        let c = try catalog(); try c.validate()
        for e in c.episodes { for level in DefenseIntensity.allCases {
            XCTAssertEqual(DefenseTimeline.moment(at: 1440, intensity: level, episode: e).phase, .complete)
            var battle=0, recovery=0, warm=0, cool=0, work=0
            for second in 0..<1440 {
                let m=DefenseTimeline.moment(at: Double(second), intensity: level, episode: e)
                switch m.phase { case .battle: battle+=1; if !m.preparing { work+=1 }; case .recovery: recovery+=1; case .warmup: warm+=1; case .cooldown: cool+=1; case .complete: XCTFail("early end") }
            }
            XCTAssertEqual([warm,battle,recovery,cool],[240,900,120,180])
            XCTAssertEqual(work,level.workSeconds*15)
        }}
    }
    func testPauseResumeSuspensionAndRelaunchDoNotAwardClosedTime() {
        var clock=DefenseClock(DefenseSession(episode: 1, intensity: .standard))
        clock.resume(at: 100); clock.advance(to: 101); clock.pause(at: 102)
        clock.advance(to: 600); XCTAssertEqual(clock.session.elapsed,2)
        clock.resume(at: 600); clock.advance(to: 601); XCTAssertEqual(clock.session.elapsed,3)
        clock.advance(to: 1000); XCTAssertTrue(clock.session.paused); XCTAssertEqual(clock.session.elapsed,3)
        var restored=DefenseClock(clock.session); restored.advance(to: 5000)
        XCTAssertTrue(restored.session.paused); XCTAssertEqual(restored.session.elapsed,3)
    }
    func testThirtyCompletionsRewardOnceAndDoNotTouchOutdoorProgress() throws {
        var save=SaveState()
        for n in 1...30 {
            try DefenseCampaign.begin(episode:n,intensity:DefenseIntensity.allCases[(n-1)%3],in:&save)
            var session=try XCTUnwrap(save.profile.defense?.active)
            XCTAssertThrowsError(try DefenseCampaign.complete(session,at:Date(),in:&save))
            session.elapsed=1440
            XCTAssertTrue(try DefenseCampaign.complete(session,at:Date(),in:&save))
            XCTAssertFalse(try DefenseCampaign.complete(session,at:Date(),in:&save))
            XCTAssertEqual(save.profile.defense?.pendingReport,n)
            XCTAssertThrowsError(try DefenseCampaign.begin(episode:n+1,intensity:.light,in:&save))
            save.profile.defense?.pendingReport=nil
            XCTAssertTrue(save.profile.defense?.isValid == true)
        }
        XCTAssertNil(save.profile.defense?.nextEpisode)
        XCTAssertEqual(save.profile.xp,300); XCTAssertEqual(save.profile.crystals,60)
        XCTAssertEqual(save.profile.defense?.totalSeconds,43_200)
        XCTAssertTrue(save.profile.runs.isEmpty); XCTAssertNil(save.profile.journey)
        XCTAssertThrowsError(try DefenseCampaign.begin(episode:31,intensity:.standard,in:&save))
    }
    func testExistingSaveAndInProgressCampaignRoundTrip() throws {
        let directory=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at:directory) }
        let repository=SaveRepository(directory:directory)
        var legacy=SaveState(); legacy.profile.xp=339
        try repository.write(legacy)
        XCTAssertNil(try repository.load().profile.defense)
        try DefenseCampaign.begin(episode:1,intensity:.light,in:&legacy)
        var s=try XCTUnwrap(legacy.profile.defense?.active); s.elapsed=123
        try DefenseCampaign.checkpoint(s,in:&legacy); try repository.write(legacy)
        let loaded=try repository.load()
        XCTAssertEqual(loaded.profile.xp,339); XCTAssertEqual(loaded.profile.defense?.active?.elapsed,123)
        var conflict=loaded; conflict.active=RunSession(targetSeconds:1200,simulated:false,allowPursuit:false)
        XCTAssertThrowsError(try repository.validate(conflict))
        s.elapsed=100; XCTAssertThrowsError(try DefenseCampaign.checkpoint(s,in:&legacy))
    }
    func testInvalidProgressAndSkippingEpisodesAreRejected() throws {
        var save=SaveState()
        XCTAssertThrowsError(try DefenseCampaign.begin(episode:2,intensity:.light,in:&save))
        try DefenseCampaign.begin(episode:1,intensity:.light,in:&save)
        save.profile.defense?.active?.elapsed = .infinity
        XCTAssertFalse(save.profile.defense?.isValid ?? true)
        save.profile.defense?.active?.elapsed = 0
        save.profile.defense?.pendingReport = 30
        XCTAssertFalse(save.profile.defense?.isValid ?? true)
    }
    func testLegacyIndoorHistorySurvivesCampaignCompletionAndReload() throws {
        var save = SaveState()
        var old = RunSession(targetSeconds: 1200, simulated: false, allowPursuit: false)
        old.environment = .indoorTreadmill; old.activeSeconds = 1200; old.phase = .finished
        XCTAssertNotNil(Settlement.apply(old, to: &save.profile))
        let encoder = JSONEncoder(); encoder.outputFormatting = .sortedKeys
        let prior = try encoder.encode(save.profile.runs)
        let xp = save.profile.xp, crystals = save.profile.crystals
        try DefenseCampaign.begin(episode: 1, intensity: .light, in: &save)
        var session = try XCTUnwrap(save.profile.defense?.active); session.elapsed = 1440
        try DefenseCampaign.complete(session, at: Date(), in: &save)
        let restored = try JSONDecoder().decode(SaveState.self, from: encoder.encode(save))
        XCTAssertEqual(try encoder.encode(restored.profile.runs), prior)
        XCTAssertEqual(restored.profile.xp, xp + 10)
        XCTAssertEqual(restored.profile.crystals, crystals + 2)
        XCTAssertEqual(restored.profile.defense?.records.count, 1)
    }
}
