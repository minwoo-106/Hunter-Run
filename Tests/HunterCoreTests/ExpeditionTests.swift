import XCTest
@testable import HunterCore

final class ExpeditionTests: XCTestCase {
    private let monday = ISO8601DateFormatter().date(from: "2026-09-14T10:00:00+09:00")!
    private func makeActivity(day: Int = 0, seconds: Double = 1200, indoor: Bool = false, distance: Double = 800) -> RunSession {
        var run = RunSession(targetSeconds: seconds, simulated: false, allowPursuit: false)
        run.startedAt = monday.addingTimeInterval(Double(day) * 86400)
        run.activeSeconds = seconds; run.distance = distance; run.environment = indoor ? .indoor : .outdoor; run.phase = .finished
        run.records = ["discovery", "trail"].map { EventRecord(id: $0, title: "단서", outcome: .success, damage: 0, kind: .discovery) }
        return run
    }
    private func ready() -> SaveState {
        var save = SaveState()
        for day in 0..<3 { _ = Settlement.apply(makeActivity(day: day), to: &save.profile) }
        return save
    }
    func testOrdinaryAssignmentsProgressWithoutSelectionAcrossModes() {
        var profile = Profile(); var journey = JourneyState(); journey.unlocked = ["M03", "M04"]; profile.journey = journey
        for mode in [RunMode.exploration, .contract, .gate] {
            var activity = makeActivity(seconds: 600); activity.mode = mode
            XCTAssertNil(activity.questID); XCTAssertNotNil(Settlement.apply(activity, to: &profile))
        }
        XCTAssertTrue(profile.journey!.completedQuests.contains("compare-signals"))
        XCTAssertTrue(profile.journey!.completedQuests.contains("basic-survey"))
        XCTAssertNil(profile.journey!.questRecords["moon-mark"])
        XCTAssertFalse(profile.journey!.completedQuests.contains("exam-D"))
    }
    func testPinnedAssignmentDoesNotExcludeOtherOpenAssignments() throws {
        var save = SaveState(); var journey = JourneyState(); journey.unlocked = ["M03", "M04"]; save.profile.journey = journey
        try Quests.select("compare-signals", save: &save)
        let activity = makeActivity(seconds: 1800)
        _ = Settlement.apply(activity, to: &save.profile)
        XCTAssertEqual(save.profile.journey?.selectedQuest, "compare-signals")
        XCTAssertTrue(save.profile.journey!.completedQuests.contains("basic-survey"))
        let record = Quests.entry("basic-survey")!.progress(save.profile)
        _ = Settlement.apply(activity, to: &save.profile)
        XCTAssertEqual(Quests.entry("basic-survey")!.progress(save.profile), record)
    }
    func testWeeklyRequiresThreeDaysAndAllowsSplitSessions() {
        var profile = Profile()
        for day in 0..<3 { for _ in 0..<2 { _ = Settlement.apply(makeActivity(day: day, seconds: 600), to: &profile) } }
        let survey = Expeditions.survey(profile, at: monday.addingTimeInterval(3 * 86400))
        XCTAssertTrue(survey.complete); XCTAssertEqual(survey.days, 3); XCTAssertEqual(survey.seconds, 3600); XCTAssertEqual(survey.beacons, 3)
        var oneDay = Profile(); _ = Settlement.apply(makeActivity(seconds: 7200), to: &oneDay)
        XCTAssertFalse(Expeditions.survey(oneDay, at: monday).complete)
    }
    func testIndoorStationaryNoTraceAndFutureRunsDoNotContribute() {
        var profile = Profile()
        _ = Settlement.apply(makeActivity(indoor: true), to: &profile)
        _ = Settlement.apply(makeActivity(distance: 0), to: &profile)
        _ = Settlement.apply(makeActivity(day: 1), to: &profile)
        var fake = makeActivity(); fake.simulated = true; XCTAssertNil(Settlement.apply(fake, to: &profile))
        let survey = Expeditions.survey(profile, at: monday)
        XCTAssertEqual(survey.seconds, 0); XCTAssertEqual(survey.clues, 0)
    }
    func testWeeklyIgnoresDuplicateSummaryAndNeutralDiscoveries() {
        var profile = Profile(); var activity = makeActivity()
        activity.records[0].outcome = .neutral
        _ = Settlement.apply(activity, to: &profile); profile.runs.append(profile.runs[0])
        let survey = Expeditions.survey(profile, at: monday)
        XCTAssertEqual(survey.seconds, 1200); XCTAssertEqual(survey.clues, 1)
    }
    func testMondayKoreanMidnightStartsNewWeek() {
        let boundary = ISO8601DateFormatter().date(from: "2026-09-20T15:00:00Z")!
        XCTAssertEqual(Expeditions.weekStart(boundary), boundary)
        let save = ready()
        XCTAssertTrue(Expeditions.survey(save.profile, at: boundary.addingTimeInterval(-1)).complete)
        XCTAssertEqual(Expeditions.survey(save.profile, at: boundary).seconds, 0)
    }
    func testWeeklyClaimPersistsAndCannotRepeatOrClaimDuringActivity() throws {
        var save = ready(); let now = monday.addingTimeInterval(3 * 86400)
        save.active = makeActivity(); XCTAssertThrowsError(try Expeditions.claim(in: &save, at: now)); save.active = nil
        let xp = save.profile.xp
        try Expeditions.claim(in: &save, at: now)
        XCTAssertEqual(save.profile.xp, xp + 80)
        save = try JSONDecoder().decode(SaveState.self, from: JSONEncoder().encode(save))
        XCTAssertTrue(Expeditions.survey(save.profile, at: now).claimed)
        XCTAssertThrowsError(try Expeditions.claim(in: &save, at: now))
        XCTAssertEqual(save.profile.xp, xp + 80)
    }
    func testReturnReportAcknowledgementAndSettlementRetryAreStable() {
        var save = SaveState(); let activity = makeActivity()
        _ = Settlement.apply(activity, to: &save.profile)
        XCTAssertTrue(save.profile.expeditions!.isValid)
        XCTAssertEqual(save.profile.expeditions?.briefing?.id, activity.id)
        Expeditions.acknowledge(UUID(), in: &save); XCTAssertFalse(save.profile.expeditions!.briefing!.acknowledged)
        Expeditions.acknowledge(activity.id, in: &save)
        XCTAssertNil(Settlement.apply(activity, to: &save.profile)); XCTAssertTrue(save.profile.expeditions!.briefing!.acknowledged)
        _ = Settlement.apply(makeActivity(day: 1), to: &save.profile)
        XCTAssertFalse(save.profile.expeditions!.briefing!.acknowledged)
    }
    func testMutationPatternsValidateAndRequireOriginalClear() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let world = try JSONDecoder().decode(WorldContent.self, from: Data(contentsOf: root.appendingPathComponent("Resources/world.json")))
        let catalog = try JSONDecoder().decode(ProgressionCatalog.self, from: Data(contentsOf: root.appendingPathComponent("Resources/progression.json")))
        let variants = BossMutations.all(world)
        XCTAssertEqual(variants.count, world.bosses.filter(BossCampaign.allowsReplay).count * 2)
        XCTAssertEqual(Set(variants.map(\.id)).count, variants.count)
        var profile = Profile(); var growth = profile.growth; growth.rank = "S"; growth.departments["observation"] = 2; profile.growth = growth
        var journey = JourneyState(); journey.unlocked = Set((1...19).map { String(format: "M%02d", $0) }); profile.journey = journey
        for variant in variants {
            try variant.validate(); XCTAssertFalse(variant.available(to: profile, catalog: catalog))
            var parent = BossState(maximumHP: 800); parent.remainingHP = 0; parent.clears = 1
            profile.bosses = [variant.requiredBossClear!: parent]
            XCTAssertTrue(variant.available(to: profile, catalog: catalog))
            XCTAssertEqual(BossCampaign.state(variant, profile: profile).remainingHP, variant.maximumHP)
            XCTAssertEqual(BossCampaign.state(variant, profile: profile).clears, 0)
            let burst = variant.phases[0].events.compactMap(\.burstSeconds)
            XCTAssertEqual(burst, variant.id.hasSuffix("-seal") ? [10] : [])
            profile.bosses = [:]
        }
    }
}

