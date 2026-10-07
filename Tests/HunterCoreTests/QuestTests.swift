import XCTest
@testable import HunterCore

final class QuestTests: XCTestCase {
    func testRank15And434MinutesStillNeedDExamAndItsStoryAccess() throws {
        var save = SaveState()
        XCTAssertEqual(Progression.promotionReadiness(save.profile), .requirements)
        var run = RunSession(targetSeconds: 434 * 60, simulated: false, allowPursuit: false)
        run.activeSeconds = 434 * 60; run.phase = .finished
        Settlement.apply(run, to: &save.profile)
        save.profile.xp = 4200
        XCTAssertEqual(save.profile.level, 15)
        XCTAssertEqual(Progression.activityMinutes(save.profile), 434)
        XCTAssertTrue(Progression.qualifiesForExam(save.profile))
        XCTAssertFalse(Progression.canPromote(save.profile))
        XCTAssertFalse(Quests.entry("exam-D")!.available(save.profile))
        XCTAssertEqual(Progression.promotionReadiness(save.profile), .story)
        var journey = save.profile.journey ?? JourneyState()
        journey.unlocked.insert("M05"); save.profile.journey = journey
        XCTAssertTrue(Quests.entry("exam-D")!.available(save.profile))
        XCTAssertFalse(Progression.canPromote(save.profile))
        XCTAssertEqual(Progression.promotionReadiness(save.profile), .exam)
        save.profile.journey?.completedQuests.insert("exam-D")
        XCTAssertEqual(Progression.promotionReadiness(save.profile), .ready)
        XCTAssertNoThrow(try Progression.promote(save: &save))
        XCTAssertEqual(save.profile.growth.rank, "D")
        var growth = save.profile.growth; growth.rank = "S"; save.profile.growth = growth
        XCTAssertEqual(Progression.promotionReadiness(save.profile), .maximumRank)
    }
    func testOpenWolfQuestKeepsPriorityWithoutBeingSelected() {
        var profile = Profile()
        var journey = JourneyState()
        journey.unlocked.insert("M01")
        profile.journey = journey
        XCTAssertEqual(Quests.priorityEncounterID(for: profile), "beast")

        profile.journey?.completedQuests.insert("wolf-first")
        XCTAssertNil(Quests.priorityEncounterID(for: profile))

        profile.journey?.unlocked.insert("M03")
        XCTAssertEqual(Quests.priorityEncounterID(for: profile), "beast")
        profile.journey?.completedQuests.insert("wolf-ten")
        XCTAssertNil(Quests.priorityEncounterID(for: profile))
    }
    func testQuestCatalogMissionValidationAndSeparateExamAccess() throws {
        XCTAssertEqual(Set(Quests.entries.map(\.id)).count, Quests.entries.count)
        for quest in Quests.entries {
            try quest.mission(from: GameContent(schema: 1, missionTitle: "", events: [])).validate()
            if let boss = quest.boss { try boss.validate() }
        }
        var profile = Profile(); profile.xp = 600
        var journey = JourneyState(); journey.unlocked = ["M05"]; profile.journey = journey
        var run = RunSession(targetSeconds: 3600, simulated: false, allowPursuit: false)
        run.activeSeconds = 3600; run.phase = .finished; Settlement.apply(run, to: &profile)
        XCTAssertTrue(Quests.entry("exam-D")!.available(profile))
        XCTAssertEqual(profile.growth.rank, "E")
        XCTAssertFalse(Progression.canPromote(profile))
    }
    func testQuestEvidenceAndTimePersistAcrossRunsAndCannotSettleTwice() throws {
        let quest = Quests.entry("compare-signals")!
        var save = SaveState(); var state = JourneyState(); state.unlocked = ["M03"]; save.profile.journey = state
        try Quests.select(quest.id, save: &save)
        for i in 0..<2 {
            var run = RunSession(targetSeconds: 600, simulated: false, allowPursuit: false)
            run.questID = quest.id; run.phase = .finished; run.activeSeconds = 600
            run.records = [EventRecord(id: "evidence-compare-signals-\(i)", title: "표본", outcome: .success, damage: 0, kind: .discovery)]
            XCTAssertNotNil(Settlement.apply(run, to: &save.profile))
            XCTAssertNil(Settlement.apply(run, to: &save.profile))
            if i == 0 { XCTAssertFalse(save.profile.journey!.completedQuests.contains(quest.id)) }
        }
        XCTAssertEqual(quest.progress(save.profile).seconds, 1200)
        XCTAssertTrue(save.profile.journey!.completedQuests.contains(quest.id))
        let xp = save.profile.xp
        try Quests.claim(quest.id, save: &save)
        XCTAssertEqual(save.profile.xp, xp + quest.xp)
        XCTAssertNil(save.profile.journey?.selectedQuest)
        XCTAssertThrowsError(try Quests.claim(quest.id, save: &save))
    }
    func testNeutralAndSimulatedEvidenceDoNotCompleteQuests() {
        var profile = Profile()
        var run = RunSession(targetSeconds: 1800, simulated: true, allowPursuit: false)
        run.questID = "compare-signals"; run.phase = .finished; run.activeSeconds = 1800
        run.records = (0..<2).map { EventRecord(id: "evidence-compare-signals-\($0)", title: "표본", outcome: .neutral, damage: 0, kind: .discovery) }
        XCTAssertNil(Settlement.apply(run, to: &profile))
        XCTAssertNil(profile.journey)
        run.simulated = false; Settlement.apply(run, to: &profile)
        XCTAssertEqual(profile.journey?.questRecords[run.questID!]?.evidence.count, 0)
        XCTAssertFalse(profile.journey!.completedQuests.contains(run.questID!))
    }
    func testDefeatMissionIncludesPreviousRealKillsButNotDamageOnly() {
        var profile = Profile()
        for defeated in [false, true] {
            var run = RunSession(targetSeconds: 300, simulated: false, allowPursuit: false)
            run.phase = .finished; run.activeSeconds = 300
            run.records = [EventRecord(id: "beast", title: "늑대", outcome: .success, damage: 10, defeated: defeated)]
            Settlement.apply(run, to: &profile)
            XCTAssertEqual(Quests.defeats(profile), defeated ? 1 : 0)
        }
        XCTAssertTrue(profile.journey!.completedQuests.contains("wolf-first"))
        XCTAssertFalse(profile.journey!.completedQuests.contains("wolf-ten"))
    }
    func testSplittingActivitiesDoesNotAcceleratePromotionAndFreeTimeCounts() {
        var joined = Profile(), split = Profile()
        func record(_ seconds: Double, _ profile: inout Profile) {
            var run = RunSession(targetSeconds: seconds, simulated: false, allowPursuit: false)
            run.goal = ActivityGoal(kind: .free, value: 0); run.phase = .finished; run.activeSeconds = seconds
            Settlement.apply(run, to: &profile)
        }
        record(3600, &joined)
        for _ in 0..<12 { record(300, &split) }
        XCTAssertEqual(Progression.activityCredits(joined), Progression.activityCredits(split))
        XCTAssertEqual(Progression.activityCredits(joined), 3)
    }
    func testExamRewardStillClaimableAfterPromotion() throws {
        var save = SaveState(); var state = JourneyState()
        state.unlocked = ["M05", "M06"]; state.completedQuests = ["exam-D"]; save.profile.journey = state
        var growth = save.profile.growth; growth.rank = "D"; save.profile.growth = growth
        XCTAssertFalse(Quests.entry("exam-D")!.available(save.profile))
        XCTAssertNoThrow(try Quests.claim("exam-D", save: &save))
    }
}
