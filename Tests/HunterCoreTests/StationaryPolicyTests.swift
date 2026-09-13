import XCTest
@testable import HunterCore

final class StationaryPolicyTests: XCTestCase {
    private func engine(_ environment: ActivityEnvironment, goal: ActivityGoal = ActivityGoal(kind: .free), seconds: Double = 0) -> RunEngine {
        var session = RunSession(targetSeconds: 1200, simulated: false, allowPursuit: false)
        session.environment = environment; session.goal = goal; session.activeSeconds = seconds
        return RunEngine(session: session, content: GameContent(schema: 1, missionTitle: "Policy", events: []))
    }
    @discardableResult private func tick(_ run: inout RunEngine, _ time: Double, moving: Bool = true) -> [GameCue] {
        run.consume(SensorFrame(timestamp: time, speed: 2, distance: 2, movement: moving ? .running : .stationary, signal: .good))
    }
    func testOnlyStationaryRewardsAreHalvedAndCoreMaterialsArePreserved() throws {
        func settle(_ environment: ActivityEnvironment) throws -> RunSummary {
            var session = engine(environment).session
            session.phase = .finished; session.activeSeconds = 1210; session.mode = .gate
            session.records = [
                EventRecord(id: "trace", title: "Trace", outcome: .success, damage: 0, kind: .discovery),
                EventRecord(id: "gate-core", title: "Core", outcome: .success, damage: 85, defeated: true, kind: .boss),
                EventRecord(id: "neutral", title: "Neutral", outcome: .neutral, damage: 0, kind: .discovery)
            ]
            var profile = Profile()
            let summary = try XCTUnwrap(Settlement.apply(session, to: &profile))
            XCTAssertNil(Settlement.apply(session, to: &profile))
            XCTAssertEqual(profile.xp, summary.xp); XCTAssertEqual(profile.crystals, summary.crystals)
            return summary
        }
        let outdoor = try settle(.outdoor), treadmill = try settle(.indoorTreadmill), stationary = try settle(.indoorStationary)
        XCTAssertEqual(outdoor.xp, 161); XCTAssertEqual(outdoor.crystals, 16)
        XCTAssertEqual(treadmill.xp, outdoor.xp); XCTAssertEqual(treadmill.crystals, outdoor.crystals)
        XCTAssertEqual(treadmill.research, outdoor.research)
        XCTAssertEqual(stationary.xp, 80); XCTAssertEqual(stationary.crystals, 8)
        XCTAssertEqual(stationary.research, 1); XCTAssertEqual(stationary.cores, outdoor.cores)
        XCTAssertEqual(stationary.cores, 1); XCTAssertEqual(stationary.rewardPercent, 50)
        let encoded = try JSONEncoder().encode(stationary)
        XCTAssertEqual(try JSONDecoder().decode(RunSummary.self, from: encoded).rewardPercent, 50)
        var legacy = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        legacy.removeValue(forKey: "rewardPercent")
        XCTAssertNil(try JSONDecoder().decode(RunSummary.self, from: JSONSerialization.data(withJSONObject: legacy)).rewardPercent)
    }
    func testStationaryQuestClaimKeepsFullOneTimeReward() throws {
        let quest = try XCTUnwrap(Quests.entry("compare-signals"))
        var save = SaveState(); save.profile.journey = JourneyState()
        if quest.main > 0 { save.profile.journey?.unlocked.insert(String(format: "M%02d", quest.main)) }
        var session = engine(.indoorStationary).session
        session.phase = .finished; session.activeSeconds = 1200; session.questID = quest.id
        session.records = (0..<quest.samples).map { EventRecord(id: "evidence-\(quest.id)-\($0)", title: "Evidence", outcome: .success, damage: 0, kind: .discovery) }
        XCTAssertNotNil(Settlement.apply(session, to: &save.profile))
        let xp = save.profile.xp, crystals = save.profile.crystals, research = save.profile.research
        try Quests.claim(quest.id, save: &save)
        XCTAssertEqual(save.profile.xp - xp, quest.xp)
        XCTAssertEqual(save.profile.crystals - crystals, quest.crystals)
        XCTAssertEqual(save.profile.research - research, quest.research)
        XCTAssertThrowsError(try Quests.claim(quest.id, save: &save))
    }
    func testFreeStationaryEndsExactlyAtOneHourOnceWhileOtherEnvironmentsContinue() throws {
        for environment in ActivityEnvironment.allCases {
            var run = engine(environment, seconds: 3598.5)
            tick(&run, 0)
            let cues = tick(&run, 5)
            if environment == .indoorStationary {
                XCTAssertEqual(run.session.activeSeconds, 3600)
                XCTAssertEqual(run.session.phase, .finished); XCTAssertEqual(run.session.goalProgress, 1)
                XCTAssertEqual(cues.filter { $0 == .goalReached }.count, 1)
                XCTAssertTrue(tick(&run, 6).isEmpty)
                var profile = Profile()
                XCTAssertNotNil(Settlement.apply(run.session, to: &profile))
                XCTAssertNil(Settlement.apply(run.session, to: &profile))
            } else {
                XCTAssertEqual(run.session.activeSeconds, 3603.5)
                XCTAssertNotEqual(run.session.phase, .finished); XCTAssertFalse(cues.contains(.goalReached))
                XCTAssertNil(run.session.activeTimeLimit)
            }
        }
    }
    func testTimeGoalsRespectShorterTargetAndOnlyStationaryHasHardCap() {
        for minutes in [20.0, 60, 90] {
            for environment in ActivityEnvironment.allCases {
                let expected = environment == .indoorStationary ? min(minutes * 60, 3600) : minutes * 60
                var run = engine(environment, goal: ActivityGoal(kind: .time, value: minutes * 60), seconds: expected - 1)
                tick(&run, 0); tick(&run, 3)
                XCTAssertEqual(run.session.activeSeconds, expected); XCTAssertEqual(run.session.phase, .finished)
            }
        }
    }
    func testIdleAndPausedWallTimeCannotEarnRewardsOrSpendActiveLimit() {
        var run = engine(.indoorStationary)
        for t in 0...3700 { tick(&run, Double(t), moving: false) }
        XCTAssertEqual(run.session.activeSeconds, 0); XCTAssertFalse(run.session.reachedGoal)
        run.pause(true)
        for t in 3701...7400 { tick(&run, Double(t)) }
        XCTAssertEqual(run.session.activeSeconds, 0)
        run.end(); var profile = Profile()
        XCTAssertEqual(Settlement.apply(run.session, to: &profile)?.xp, 0)
        XCTAssertEqual(profile.crystals, 0)
    }
    func testRecoveryKeepsUsedTimeAndFinishesAtSameCap() throws {
        let original = engine(.indoorStationary, seconds: 3599)
        let decoded = try JSONDecoder().decode(RunSession.self, from: JSONEncoder().encode(original.session))
        var restored = RunEngine(session: decoded, content: original.content)
        restored.restorePaused(); tick(&restored, 5000); tick(&restored, 5001)
        XCTAssertEqual(restored.session.activeSeconds, 3599)
        restored.pause(false); tick(&restored, 10000); tick(&restored, 10002)
        XCTAssertEqual(restored.session.activeSeconds, 3600); XCTAssertEqual(restored.session.phase, .finished)
    }
}
