import Foundation
import XCTest
@testable import HunterCore

final class DistanceCombatRegressionTests: XCTestCase {
    func testThreeAttacksInOneGPSBatchAndOverkillClampsToHP() throws {
        var run = try V3Fixtures.engine(eventID: "contract-endurance")
        run.consume(V3Fixtures.frame(1, 225))
        XCTAssertNil(run.session.event)
        XCTAssertEqual(run.session.records.count, 1)
        XCTAssertEqual(run.session.records.first?.attacks, 3)
        XCTAssertEqual(run.session.records.first?.damage, 320)
        XCTAssertEqual(run.session.records.first?.defeated, true)
    }
    func testInsufficientDistanceRemainderCarriesAcrossFrames() throws {
        var run = try V3Fixtures.engine()
        for (t,d) in [(1.0,25.0),(2,24),(3,25)] { run.consume(V3Fixtures.frame(t,d)) }
        XCTAssertEqual(run.session.event?.hp, 180)
        run.consume(V3Fixtures.frame(4,1))
        XCTAssertEqual(run.session.event?.hp, 21)
        XCTAssertEqual(run.session.event?.battle?.remainder, 0)
    }
    func testHPZeroDoesNotCreateMoreRecordsOrMoreExperience() throws {
        var run = try V3Fixtures.engine()
        run.consume(V3Fixtures.frame(1, 600))
        for i in 2...20 { run.consume(V3Fixtures.frame(Double(i), 75)) }
        XCTAssertEqual(run.session.records.count, 1)
        XCTAssertEqual(run.session.records.first?.attacks, 2)
        XCTAssertEqual(run.session.records.first?.damage, 180)
        run.end(); var profile = Profile()
        XCTAssertEqual(Settlement.apply(run.session, to: &profile)?.xp, 45)
        XCTAssertNil(Settlement.apply(run.session, to: &profile))
        XCTAssertEqual(profile.xp, 45)
    }
    func testDuplicateEventRecordCannotAwardMonsterExperienceTwice() throws {
        var run = try V3Fixtures.engine(); run.consume(V3Fixtures.frame(1,150)); run.end()
        var session = run.session
        session.records.append(try XCTUnwrap(session.records.first))
        var profile = Profile()
        let result = Settlement.apply(session, to: &profile)
        XCTAssertEqual(result?.xp, 43)
        XCTAssertEqual(result?.crystals, 3)
        XCTAssertEqual(result?.records.count, 1)
    }
    func testIncompleteNormalMonsterGetsNoKillExperienceAndNextSessionStartsFull() throws {
        var first = try V3Fixtures.engine(); first.consume(V3Fixtures.frame(1,75)); first.end()
        var profile = Profile()
        XCTAssertEqual(Settlement.apply(first.session, to: &profile)?.xp, 18)
        XCTAssertEqual(first.session.records.first?.damage, 159)
        XCTAssertEqual(first.session.records.first?.defeated, false)
        let next = try V3Fixtures.engine()
        XCTAssertEqual(next.session.event?.hp, 180)
        XCTAssertEqual(next.session.event?.battle?.attacks, 0)
        XCTAssertEqual(next.session.event?.battle?.remainder, 0)
    }
    func testMajorBossDamageSurvivesSaveAndNextSessionAndRewardsOnlyAtKill() throws {
        let boss = try V3Fixtures.boss()
        var first = try V3Fixtures.engine(eventID: "major-strike-a", boss: BossEncounter(definition: boss, state: BossState(maximumHP:2200)))
        first.consume(V3Fixtures.frame(1,75)); first.end()
        var save = V3Fixtures.actualSave()
        XCTAssertEqual(Settlement.apply(first.session, to: &save.profile)?.xp, 18)
        XCTAssertEqual(save.profile.bosses?[boss.id]?.remainingHP, 2066)
        save = try JSONDecoder().decode(SaveState.self, from: JSONEncoder().encode(save))
        var next = try V3Fixtures.engine(eventID: "major-strike-a", boss: BossEncounter(definition: boss, state: BossCampaign.state(boss, profile:save.profile)))
        XCTAssertEqual(next.session.event?.hp, 2066)
        next.consume(V3Fixtures.frame(1,1200)); next.end()
        let result = Settlement.apply(next.session, to:&save.profile)
        XCTAssertEqual(result?.xp, 258)
        XCTAssertEqual(result?.majorBoss?.damage, 2066)
        XCTAssertEqual(save.profile.bosses?[boss.id]?.remainingHP, 0)
        XCTAssertEqual(save.profile.bosses?[boss.id]?.clears, 1)
        XCTAssertNil(Settlement.apply(next.session, to:&save.profile))
        XCTAssertEqual(save.profile.bosses?[boss.id]?.clears, 1)
    }
    func testStaleBossSessionCannotClaimBossReward() throws {
        let boss = try V3Fixtures.boss()
        var a = try V3Fixtures.engine(eventID: "major-strike-a", boss: BossEncounter(definition:boss,state:BossState(maximumHP:2200)))
        var b = try V3Fixtures.engine(eventID: "major-strike-a", boss: BossEncounter(definition:boss,state:BossState(maximumHP:2200)))
        a.consume(V3Fixtures.frame(1,1275)); a.end()
        b.consume(V3Fixtures.frame(1,1275)); b.end()
        var profile = Profile()
        XCTAssertEqual(Settlement.apply(a.session,to:&profile)?.xp,258)
        let stale = Settlement.apply(b.session,to:&profile)
        XCTAssertNil(stale?.majorBoss)
        XCTAssertEqual(stale?.xp,18)
        XCTAssertEqual(profile.bosses?[boss.id]?.clears,1)
    }
    func testPoorGPSNeverAttacksAndDoesNotEraseActiveEncounter() throws {
        var run = try V3Fixtures.engine()
        run.consume(V3Fixtures.frame(1,74))
        for i in 2...150 { run.consume(V3Fixtures.frame(Double(i),5,signal:.unavailable)) }
        XCTAssertEqual(run.session.event?.hp,180)
        XCTAssertEqual(run.session.event?.battle?.remainder,74)
        XCTAssertTrue(run.session.records.isEmpty)
        run.consume(V3Fixtures.frame(151,1))
        XCTAssertEqual(run.session.event?.hp,21)
    }
    func testWalkingOrStationaryOrVehicleCannotAttack() throws {
        for movement in [Movement.walking,.stationary,.vehicle] {
            var run = try V3Fixtures.engine()
            for i in 1...10 { run.consume(V3Fixtures.frame(Double(i),75,movement:movement)) }
            XCTAssertEqual(run.session.event?.hp,180)
            XCTAssertTrue(run.session.records.isEmpty)
            if movement != .walking { XCTAssertEqual(run.session.activeSeconds,180) }
        }
    }
    func testAutoPauseResumeDoesNotAddStoppedDistance() throws {
        var run = try V3Fixtures.engine(); run.consume(V3Fixtures.frame(1,74))
        for i in 2...10 { run.consume(V3Fixtures.frame(Double(i),0,movement:.stationary)) }
        XCTAssertEqual(run.session.phase,.paused)
        for i in 11...15 { run.consume(V3Fixtures.frame(Double(i),1)) }
        XCTAssertEqual(run.session.event?.hp,180)
        run.consume(V3Fixtures.frame(16,1))
        XCTAssertEqual(run.session.event?.hp,21)
    }
    func testInstructionAndRecoveryMustFinishBeforeAttack() throws {
        var run = try V3Fixtures.engine(); run.consume(V3Fixtures.frame(1,74))
        let restored = try JSONDecoder().decode(RunSession.self,from:JSONEncoder().encode(run.session))
        run = RunEngine(session:restored,content:run.content); run.restorePaused()
        run.consume(V3Fixtures.frame(1000,75)); run.pause(false)
        run.consume(V3Fixtures.frame(1001)); run.consume(V3Fixtures.frame(1002,1))
        XCTAssertEqual(run.session.event?.hp,180)
        run.instructionFinished(); run.consume(V3Fixtures.frame(1003,1))
        XCTAssertEqual(run.session.event?.hp,21)
    }
    func testDuplicateReorderedInvalidAndGappedFramesDoNotAttack() throws {
        var run = try V3Fixtures.engine(); run.consume(V3Fixtures.frame(1,74))
        run.consume(V3Fixtures.frame(1,75)); run.consume(V3Fixtures.frame(0,75))
        run.consume(SensorFrame(timestamp:.nan,speed:2.5,distance:75,movement:.running,signal:.good))
        run.consume(SensorFrame(timestamp:2,speed:2.5,distance:.infinity,movement:.running,signal:.good))
        run.consume(V3Fixtures.frame(100,75))
        XCTAssertEqual(run.session.event?.hp,180)
        run.consume(V3Fixtures.frame(101,1))
        XCTAssertEqual(run.session.event?.hp,21)
    }
    func testBattleRemainderAndSettlementLedgerSurviveRepositoryRoundtrip() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at:directory) }
        let repository = SaveRepository(directory:directory)
        var run = try V3Fixtures.engine(); run.consume(V3Fixtures.frame(1,74))
        var save = V3Fixtures.actualSave(); save.active = run.session
        try repository.write(save); save = try repository.load()
        run = RunEngine(session:try XCTUnwrap(save.active),content:run.content)
        run.consume(V3Fixtures.frame(2,76)); run.end(); save.active = nil
        XCTAssertEqual(Settlement.apply(run.session,to:&save.profile)?.xp,43)
        try repository.write(save); save = try repository.load()
        XCTAssertNil(Settlement.apply(run.session,to:&save.profile))
        XCTAssertEqual(save.profile.xp,4293)
        XCTAssertEqual(save.profile.runs.count,1)
    }
    func testSimulationStillCannotCreditRealProfile() throws {
        let run = try V3Fixtures.engine(); var session = run.session
        session.simulated = true; session.phase = .finished
        var profile = Profile()
        XCTAssertNil(Settlement.apply(session,to:&profile))
        XCTAssertEqual(profile.xp,0)
    }
    func testVerySmallFractionalSegmentsReachTheSameBoundary() throws {
        var battle = DistanceBattle(monster:try XCTUnwrap(V3Fixtures.rules().monsters.first { $0.id == "echo-wolf" }))
        for _ in 0..<1500 { battle.advance(distance:0.05,attack:2.915) }
        XCTAssertEqual(battle.attacks,1)
        XCTAssertEqual(battle.remainingHP,21)
    }

}
