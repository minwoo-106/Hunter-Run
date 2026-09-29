import XCTest
@testable import HunterCore

final class GateOverhaulTests: XCTestCase {
    private func finished(_ mode: RunMode = .contract) -> RunSession {
        var run = RunSession(targetSeconds: 300, simulated: false, allowPursuit: false, mode: mode)
        run.rulesVersion = 2
        run.environment = .outdoor
        run.activeSeconds = 300
        run.phase = .finished
        return run
    }

    private func world() throws -> WorldContent {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return try JSONDecoder().decode(WorldContent.self, from: Data(contentsOf: root.appendingPathComponent("Resources/world.json")))
    }

    func testSecondEligibleHuntGuaranteesGateAndPaysOnce() {
        var profile = Profile()
        profile.gateProgress?.tracking = true
        var balance = GateBalance()
        balance.firstEncounterChance = 0

        var first = finished()
        GateTracking.prepare(&first, profile: profile, balance: balance)
        XCTAssertEqual(first.gateScheduled, false)
        first.gateOpportunityQualified = true
        XCTAssertNil(Settlement.apply(first, to: &profile)?.completion)
        XCTAssertEqual(profile.gateProgress?.missedEligibleSessions, 1)

        var second = finished()
        GateTracking.prepare(&second, profile: profile, balance: balance)
        XCTAssertEqual(second.gateScheduled, true)
        let base = GameContent(schema: 1, missionTitle: "hunt", events: [
            MissionTemplate(id: "trace", title: "trace", kind: .discovery, startFraction: 0.13, duration: 20, hp: 0, audio: "investigate")
        ])
        let content = GateTracking.content(base, session: second, balance: balance)
        XCTAssertEqual(content.events.filter { $0.id == GateTracking.eventID }.count, 1)
        XCTAssertEqual(content.events.last?.hp, 60)
        second.gatePresented = true
        second.records = [EventRecord(id: GateTracking.eventID, title: "gate", outcome: .success,
                                      damage: 60, defeated: true, kind: .boss, encounterKind: .normalGate)]
        let summary = Settlement.apply(second, to: &profile)
        XCTAssertEqual(summary?.completion, .normalGateClear)
        XCTAssertEqual(summary?.cores, 1)
        XCTAssertEqual(Progression.gateClears(profile), 1)
        XCTAssertEqual(profile.gateProgress?.missedEligibleSessions, 0)
        XCTAssertEqual(profile.gateProgress?.pending, false)
        XCTAssertNil(Settlement.apply(second, to: &profile))
        XCTAssertEqual(profile.growth.cores, 1)
    }

    func testOutdoorDirectorActuallyOffersTrackedGate() {
        var profile = Profile()
        profile.gateProgress?.tracking = true
        var balance = GateBalance(); balance.firstEncounterChance = 1
        var run = RunSession(targetSeconds: 300, simulated: false, allowPursuit: false, mode: .contract)
        run.environment = .outdoor; run.rulesVersion = 2; run.directorVersion = 2
        GateTracking.prepare(&run, profile: profile, balance: balance)
        let base = GameContent(schema: 1, missionTitle: "hunt", events: [
            MissionTemplate(id: "trace", title: "trace", kind: .discovery,
                            startFraction: 0.13, duration: 20, hp: 0, audio: "investigate")
        ])
        let mission = GateTracking.content(base, session: run, balance: balance)
        var engine = RunEngine(session: run, content: mission)
        for second in 0...300 {
            _ = engine.consume(SensorFrame(timestamp: Double(second), speed: 2.5, distance: 2.5,
                                           movement: .running, signal: .good))
            engine.instructionFinished()
        }
        engine.end()
        XCTAssertEqual(engine.session.gatePresented, true)
        XCTAssertTrue(engine.session.records.contains { $0.catalogID == GateTracking.eventID && $0.defeated == true })
        XCTAssertEqual(Settlement.apply(engine.session, to: &profile)?.completion, .normalGateClear)
        XCTAssertEqual(Progression.gateClears(profile), 1)
    }

    func testIneligibleHuntDoesNotSpendPityAndRetreatPreservesAccess() {
        var profile = Profile()
        profile.gateProgress?.tracking = true
        var balance = GateBalance(); balance.firstEncounterChance = 0
        var ineligible = finished()
        GateTracking.prepare(&ineligible, profile: profile, balance: balance)
        _ = Settlement.apply(ineligible, to: &profile)
        XCTAssertEqual(profile.gateProgress?.missedEligibleSessions, 0)

        var retreat = finished()
        retreat.gateTracking = true; retreat.gateScheduled = true; retreat.gatePresented = true
        _ = Settlement.apply(retreat, to: &profile)
        XCTAssertEqual(profile.gateProgress?.pending, true)
        var retry = finished()
        GateTracking.prepare(&retry, profile: profile, balance: balance)
        XCTAssertEqual(retry.gateScheduled, true)
        XCTAssertEqual(GateTracking.content(GameContent(schema: 1, missionTitle: "hunt", events: []),
                                           session: retry, balance: balance).events.first?.hp, balance.coreHP)
    }

    func testFirstBossClearAndReplayHaveDifferentCreditsAndCores() throws {
        let boss = try XCTUnwrap(world().bosses.first { $0.id == "boundary-lord" })
        var profile = Profile()
        var state = BossState(maximumHP: boss.maximumHP)
        state.remainingHP = 50
        profile.bosses = [boss.id: state]

        func bossRun(_ state: BossState) -> RunSession {
            var run = finished(.gate)
            var encounter = BossEncounter(definition: boss, state: state)
            encounter.damage = state.remainingHP
            run.boss = encounter
            run.records = [EventRecord(id: "major-strike-test", title: "boss", outcome: .success,
                                       damage: state.remainingHP, defeated: true, kind: .boss)]
            return run
        }

        let first = bossRun(state)
        let firstSummary = Settlement.apply(first, to: &profile)
        XCTAssertEqual(firstSummary?.completion, .storyBossFirstClear)
        XCTAssertEqual(firstSummary?.cores, 2)
        XCTAssertEqual(Progression.gateClears(profile), 1)

        state = try XCTUnwrap(profile.bosses?[boss.id])
        state.round += 1; state.remainingHP = state.maximumHP
        profile.bosses?[boss.id] = state
        let replay = bossRun(state)
        let replaySummary = Settlement.apply(replay, to: &profile)
        XCTAssertEqual(replaySummary?.completion, .echoReplayClear)
        XCTAssertEqual(replaySummary?.cores, 0)
        XCTAssertEqual(Progression.gateClears(profile), 1)
        XCTAssertNil(Settlement.apply(replay, to: &profile))
    }

    func testExamCannotGrantNewGateCreditAndFinalRescueCannotReplay() throws {
        var profile = Profile()
        let exam = try XCTUnwrap(Quests.entry("exam-D")?.boss)
        var run = finished(.gate)
        var encounter = BossEncounter(definition: exam, state: BossState(maximumHP: exam.maximumHP))
        encounter.damage = exam.maximumHP
        run.boss = encounter
        run.records = [EventRecord(id: "major-strike-exam-a", title: "exam", outcome: .success,
                                   damage: exam.maximumHP, defeated: true, kind: .boss)]
        let summary = Settlement.apply(run, to: &profile)
        XCTAssertEqual(summary?.completion, .rankExamClear)
        XCTAssertEqual(summary?.cores, 0)
        XCTAssertEqual(Progression.gateClears(profile), 0)
        let world = try world()
        let finalBoss = try XCTUnwrap(world.bosses.first { $0.id == "corrupted-hunter" })
        XCTAssertFalse(BossCampaign.allowsReplay(finalBoss))
        XCTAssertFalse(BossMutations.all(world).contains { $0.requiredBossClear == finalBoss.id })
    }

    func testLegacyCreditMigrationIsStableAcrossSaveReload() throws {
        var save = SaveState()
        var oldRun = finished(.gate)
        oldRun.rulesVersion = nil
        oldRun.records = [EventRecord(id: GateTracking.eventID, title: "old gate", outcome: .success,
                                      damage: 85, defeated: true, kind: .boss)]
        _ = Settlement.apply(oldRun, to: &save.profile)
        save.profile.gateProgress = nil // Missing key in a pre-upgrade profile.
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let repository = SaveRepository(directory: folder)
        try repository.write(save)
        let migrated = try repository.load()
        XCTAssertEqual(migrated.profile.gateProgress?.legacyCredits, 1)
        XCTAssertEqual(migrated.profile.gateProgress?.newCredits, 0)
        try repository.write(migrated)
        XCTAssertEqual(try repository.load().profile.gateProgress?.totalCredits, 1)
    }

    func testUntrackedIndoorAndStorySessionsCannotSpendGatePity() {
        var profile = Profile()
        var balance = GateBalance(); balance.firstEncounterChance = 1
        var untracked = finished()
        GateTracking.prepare(&untracked, profile: profile, balance: balance)
        XCTAssertNil(untracked.gateTracking)
        _ = Settlement.apply(untracked, to: &profile)

        profile.gateProgress?.tracking = true
        var indoor = finished()
        indoor.environment = .indoor
        GateTracking.prepare(&indoor, profile: profile, balance: balance)
        XCTAssertNil(indoor.gateTracking)
        _ = Settlement.apply(indoor, to: &profile)

        var story = finished(.exploration)
        story.purpose = .storyObjective
        GateTracking.prepare(&story, profile: profile, balance: balance)
        XCTAssertNil(story.gateTracking)
        _ = Settlement.apply(story, to: &profile)
        XCTAssertEqual(profile.gateProgress?.missedEligibleSessions, 0)
        XCTAssertEqual(Progression.gateClears(profile), 0)
    }

    func testFailedSignalAndShortSessionKeepTrackingPity() {
        var profile = Profile()
        profile.gateProgress?.tracking = true
        var balance = GateBalance(); balance.firstEncounterChance = 0
        let base = GameContent(schema: 1, missionTitle: "hunt", events: [])

        func observe(seconds: Int, signal: Signal) -> RunSession {
            var run = RunSession(targetSeconds: Double(seconds), simulated: false, allowPursuit: false, mode: .contract)
            run.rulesVersion = 2; run.environment = .outdoor
            GateTracking.prepare(&run, profile: profile, balance: balance)
            var engine = RunEngine(session: run, content: GateTracking.content(base, session: run, balance: balance))
            for second in 0...seconds {
                _ = engine.consume(SensorFrame(timestamp: Double(second), speed: 2.5, distance: 2.5,
                                               movement: .running, signal: signal))
                engine.instructionFinished()
            }
            engine.end()
            return engine.session
        }

        let failedSignal = observe(seconds: 300, signal: .degraded)
        XCTAssertFalse(failedSignal.gateOpportunityQualified == true)
        _ = Settlement.apply(failedSignal, to: &profile)
        XCTAssertEqual(profile.gateProgress?.missedEligibleSessions, 0)

        let short = observe(seconds: 90, signal: .good)
        XCTAssertFalse(short.gateOpportunityQualified == true)
        _ = Settlement.apply(short, to: &profile)
        XCTAssertEqual(profile.gateProgress?.missedEligibleSessions, 0)
    }

    func testPartialBossAndMutationDoNotChangeCanonicalCredit() throws {
        let world = try world()
        let parent = try XCTUnwrap(world.bosses.first { $0.id == "boundary-lord" })
        var profile = Profile()
        let parentState = BossState(maximumHP: parent.maximumHP)
        profile.bosses = [parent.id: parentState]
        var partial = finished(.gate)
        var partialEncounter = BossEncounter(definition: parent, state: parentState)
        partialEncounter.damage = 50
        partial.boss = partialEncounter
        partial.records = [EventRecord(id: "major-strike-partial", title: "partial", outcome: .partial,
                                       damage: 50, defeated: false, kind: .boss)]
        XCTAssertNil(Settlement.apply(partial, to: &profile)?.completion)
        XCTAssertEqual(profile.bosses?[parent.id]?.remainingHP, parent.maximumHP - 50)
        XCTAssertEqual(Progression.gateClears(profile), 0)

        var clearedParent = BossState(maximumHP: parent.maximumHP)
        clearedParent.remainingHP = 0; clearedParent.clears = 1
        profile.bosses?[parent.id] = clearedParent
        let mutation = try XCTUnwrap(BossMutations.all(world).first { $0.requiredBossClear == parent.id })
        var mutationState = BossState(maximumHP: mutation.maximumHP)
        mutationState.remainingHP = 40
        profile.bosses?[mutation.id] = mutationState
        var replay = finished(.gate)
        var encounter = BossEncounter(definition: mutation, state: mutationState)
        encounter.damage = 40
        replay.boss = encounter
        replay.records = [EventRecord(id: "major-strike-mutation", title: "mutation", outcome: .success,
                                      damage: 40, defeated: true, kind: .boss)]
        let result = Settlement.apply(replay, to: &profile)
        XCTAssertEqual(result?.completion, .mutatedReplayClear)
        XCTAssertEqual(result?.cores, 0)
        XCTAssertEqual(profile.bosses?[parent.id], clearedParent)
        XCTAssertEqual(Progression.gateClears(profile), 0)
        XCTAssertNil(Settlement.apply(replay, to: &profile))
    }

    func testOldExamCreditAndInProgressReplaySurviveMigration() throws {
        let exam = try XCTUnwrap(Quests.entry("exam-D")?.boss)
        let parent = try XCTUnwrap(world().bosses.first { $0.id == "boundary-lord" })
        var save = SaveState()
        var oldExam = finished(.gate)
        oldExam.rulesVersion = nil
        var examEncounter = BossEncounter(definition: exam, state: BossState(maximumHP: exam.maximumHP))
        examEncounter.damage = exam.maximumHP
        oldExam.boss = examEncounter
        oldExam.records = [EventRecord(id: "major-strike-old-exam", title: "exam", outcome: .success,
                                       damage: exam.maximumHP, defeated: true, kind: .boss)]
        _ = Settlement.apply(oldExam, to: &save.profile)
        XCTAssertEqual(Progression.legacyGateClears(save.profile), 1)

        var oldReplay = BossState(maximumHP: parent.maximumHP)
        oldReplay.round = 2; oldReplay.clears = 1; oldReplay.remainingHP = 40
        save.profile.bosses?[parent.id] = oldReplay
        save.profile.gateProgress = nil
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let repository = SaveRepository(directory: folder)
        try repository.write(save)
        let restored = try repository.load()
        XCTAssertEqual(restored.profile.gateProgress?.legacyCredits, 1)
        XCTAssertEqual(BossCampaign.state(parent, profile: restored.profile), oldReplay)
        XCTAssertEqual(try repository.load().profile.gateProgress?.totalCredits, 1)
    }

    func testInterruptedSettlementCanRecoverWithoutDuplicateReward() throws {
        var save = SaveState()
        var run = finished()
        run.records = [EventRecord(id: "trace", title: "trace", outcome: .success,
                                   damage: 0, defeated: false, kind: .discovery)]
        save.active = run
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let repository = SaveRepository(directory: folder)
        try repository.write(save)

        var candidate = save
        candidate.active = nil
        let expected = try XCTUnwrap(Settlement.apply(run, to: &candidate.profile))
        try repository.write(candidate)
        try Data("interrupted".utf8).write(to: folder.appendingPathComponent("save.json"))

        var recovered = try repository.load()
        XCTAssertEqual(recovered.active?.id, run.id)
        recovered.active = nil
        XCTAssertEqual(Settlement.apply(run, to: &recovered.profile)?.xp, expected.xp)
        try repository.write(recovered)
        let final = try repository.load()
        XCTAssertEqual(final.profile.runs.filter { $0.id == run.id }.count, 1)
        XCTAssertEqual(final.profile.xp, expected.xp)
        var retry = final.profile
        XCTAssertNil(Settlement.apply(run, to: &retry))
    }
}
