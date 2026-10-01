import XCTest
@testable import HunterCore

final class OperatorChatTests: XCTestCase {
    private func catalog() throws -> OperatorChatCatalog {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return try JSONDecoder().decode(OperatorChatCatalog.self, from: Data(contentsOf: root.appendingPathComponent("Resources/operator-chat.json")))
    }
    func testEveryConversationBranchEndsAndHasNoMissingReplies() throws {
        try catalog().validate()
    }
    func testEarlyRelationshipCannotSeePersonalOrUnrecordedActivityTopics() throws {
        let catalog = try catalog()
        let ids = catalog.episodes.map(\.id)
        for activity in ["idle", "coffee", "tablet", "postRun"] {
            let shown = catalog.suggestions(tier: 1, activity: activity, hasRecentActivity: false, recent: [], deck: Array(ids.reversed()))
            XCTAssertEqual(shown.count, 3)
            XCTAssertTrue(shown.allSatisfy { $0.minimumTier == 1 && !$0.requiresRecentActivity })
        }
    }
    func testActualHomeActivityGetsOneRelevantTopicAndRecentTopicsRotate() throws {
        let catalog = try catalog()
        let ids = catalog.episodes.map(\.id)
        let first = catalog.suggestions(tier: 1, activity: "coffee", hasRecentActivity: false, recent: [], deck: ids)
        XCTAssertEqual(first.first?.id, "coffee-aroma")
        let next = catalog.suggestions(tier: 1, activity: "coffee", hasRecentActivity: false, recent: first.map(\.id), deck: ids)
        XCTAssertTrue(Set(next.map(\.id)).isDisjoint(with: first.map(\.id)))
        let friendly = catalog.suggestions(tier: 3, activity: "idle", hasRecentActivity: true, recent: [], deck: ["welcome-back", "nickname", "field-chat"])
        XCTAssertEqual(friendly.map(\.id), ["welcome-back", "nickname", "field-chat"])
    }
    func testEmptyOrDuplicateDeckStillProvidesThreeUniqueChoices() throws {
        let catalog = try catalog()
        let all = catalog.episodes.map(\.id)
        for deck in [[], ["coffee-aroma", "coffee-aroma", "missing"]] {
            let shown = catalog.suggestions(tier: 1, activity: "idle", hasRecentActivity: false, recent: all, deck: deck)
            XCTAssertEqual(shown.count, 3)
            XCTAssertEqual(Set(shown.map(\.id)).count, 3)
        }
    }
    func testOptionalActivityContextHonorsFortyEightHourBoundaryWithoutMutatingSave() throws {
        let now = Date(timeIntervalSince1970: 2_000_000)
        var profile = Profile()
        profile.runs = [RunSummary(id: UUID(), date: now.addingTimeInterval(-30), seconds: 300, distance: 400,
                                  xp: 10, crystals: 1, records: [], completedGoal: true)]
        let encoder = JSONEncoder(); encoder.outputFormatting = .sortedKeys
        let before = try encoder.encode(profile)
        XCTAssertNotNil(OperatorChatCatalog.recentActivity(profile, now: now))
        _ = try catalog().suggestions(tier: 1, activity: "postRun", hasRecentActivity: true, recent: [], deck: [])
        XCTAssertEqual(try encoder.encode(profile), before)
        profile.runs[0].date = now.addingTimeInterval(-48 * 3600)
        XCTAssertNil(OperatorChatCatalog.recentActivity(profile, now: now))
        profile.runs[0].date = now.addingTimeInterval(1)
        XCTAssertNil(OperatorChatCatalog.recentActivity(profile, now: now))
    }
    func testInvalidGraphCannotBeUsedAsConversationContent() throws {
        var catalog = try catalog()
        catalog.episodes[0].nodes[0].replies[0].next = "missing"
        XCTAssertThrowsError(try catalog.validate())
        catalog = try self.catalog()
        catalog.episodes[0].nodes[1].replies = [OperatorChatReply(id: "loop", text: "다시", next: "start")]
        XCTAssertThrowsError(try catalog.validate())
    }
}
