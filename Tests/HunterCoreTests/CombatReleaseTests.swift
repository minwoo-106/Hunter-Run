import Foundation
import XCTest
@testable import HunterCore

final class CombatReleaseTests: XCTestCase {
    func testReleaseMigrationKeepsLv15AndDefersUntilOldSessionFinishes() throws {
        var save = V3Fixtures.actualSave()
        save.active = RunSession(targetSeconds:1200,simulated:false,allowPursuit:false)
        XCTAssertFalse(try CombatRelease.migrate(&save))
        XCTAssertNil(save.profile.growthEconomy)
        XCTAssertNil(save.active?.combatRules)
        save.active = nil
        XCTAssertTrue(try CombatRelease.migrate(&save))
        XCTAssertEqual(save.profile.level,15)
        XCTAssertEqual(save.profile.xp,4250)
        XCTAssertEqual(save.profile.levelProgress,50)
        XCTAssertEqual(save.profile.nextLevelExperience,660)
        XCTAssertFalse(try CombatRelease.migrate(&save))
    }
    func testDistanceCombatDoesNotUseOldTimedAccelerationInstruction() throws {
        var run = try V3Fixtures.engine()
        var session = run.session
        session.event?.stage = .briefing; session.event?.battle = nil
        session.event?.template.kind = .pursuit
        session.event?.template.burstSeconds = 10
        session.event?.template.audio = "burst_start"
        session.event?.template.steadyAudio = "maintain"
        run = RunEngine(session:session,content:run.content)
        XCTAssertFalse(try XCTUnwrap(run.session.event).template.requestsAcceleration)
        XCTAssertEqual(run.session.event?.instructionAudio,"maintain")
        run.instructionFinished()
        XCTAssertEqual(run.session.event?.stage,.active)
        run.consume(V3Fixtures.frame(1,75))
        XCTAssertEqual(run.session.event?.hp,21)
    }

    func testFinalRescueCanUseVerifiedWalkingWithoutGPS() throws {
        var boss = try V3Fixtures.boss(); boss.id = "corrupted-hunter"; boss.maximumHP = 6000
        let fixture = try V3Fixtures.engine(eventID:"major-strike-a",boss:BossEncounter(definition:boss,state:BossState(maximumHP:6000)))
        var session = fixture.session; session.event?.battle = nil
        try CombatRelease.prepare(&session,rules:V3Fixtures.rules())
        var run = RunEngine(session:session,content:fixture.content)
        for i in 1...30 {
            run.consume(SensorFrame(timestamp:Double(i),speed:1,distance:0,movement:.walking,signal:.unavailable,steps:2))
        }
        XCTAssertEqual(run.session.event?.battle?.attacks,1)
        XCTAssertLessThan(try XCTUnwrap(run.session.event?.hp),6000)
        XCTAssertEqual(run.session.distance,0)
    }

    func testEveryPromotionAndReplayBossUsesDistanceCombatAndSettles() throws {
        let rules = try V3Fixtures.rules()
        let catalog: ProgressionCatalog = try V3Fixtures.load("Resources/progression.json",as:ProgressionCatalog.self)
        var world: WorldContent = try V3Fixtures.load("Resources/world.json",as:WorldContent.self)
        world.bosses = world.bosses.map { CombatRelease.boss($0,rules:rules) }
        let bosses = world.bosses + BossMutations.all(world) + Quests.entries.compactMap(\.boss)
        XCTAssertEqual(bosses.count,12)
        for boss in bosses {
            var save = V3Fixtures.actualSave(); try CombatRelease.migrate(&save)
            let state = BossCampaign.state(boss,profile:save.profile)
            var session = RunSession(targetSeconds:1800,simulated:false,allowPursuit:false,mode:.gate,loadout:catalog.stats(for:save.profile))
            session.rulesVersion = 2; session.questID = boss.id.hasPrefix("exam-") ? boss.id : nil
            session.boss = BossEncounter(definition:boss,state:state)
            session.activeSeconds = 180; session.lastTimestamp = 0; session.phase = .moving
            let template = try XCTUnwrap(session.boss?.content.events.first { $0.kind == .boss })
            session.event = RunEvent(template:template,stage:.active,hp:state.remainingHP,startingHP:state.remainingHP,baseline:2.5)
            try CombatRelease.prepare(&session,rules:rules)
            var run = RunEngine(session:session,content:session.boss!.content)
            XCTAssertNotNil(run.session.event?.battle,boss.id)
            run.consume(V3Fixtures.frame(1,75000)); run.end()
            XCTAssertEqual(run.session.boss?.remainingHP,0,boss.id)
            let result = Settlement.apply(run.session,to:&save.profile)
            XCTAssertEqual(result?.majorBoss?.cleared,true,boss.id)
            if boss.id.hasPrefix("exam-") {
                XCTAssertTrue(save.profile.journey?.completedQuests.contains(boss.id) == true,boss.id)
            }
            XCTAssertNil(Settlement.apply(run.session,to:&save.profile),boss.id)
        }
    }
    func testAlreadyDamagedBossKeepsSavedHPWhenRulesChange() throws {
        let rules = try V3Fixtures.rules()
        let boss = CombatRelease.boss(try V3Fixtures.boss(),rules:rules)
        XCTAssertEqual(boss.maximumHP,2200)
        var state = BossState(maximumHP:4000); state.remainingHP = 900
        let fixture = try V3Fixtures.engine(eventID:"major-strike-a",boss:BossEncounter(definition:boss,state:state))
        var session = fixture.session; session.event?.battle = nil
        try CombatRelease.prepare(&session,rules:rules)
        let run = RunEngine(session:session,content:fixture.content)
        XCTAssertEqual(run.session.event?.hp,900)
        XCTAssertEqual(run.session.event?.battle?.monster.maximumHP,4000)
        XCTAssertEqual(run.session.boss?.remainingHP,900)
    }
    func testMissingMotionCannotAdvanceFinalRescueAndPausesSafely() throws {
        var boss = try V3Fixtures.boss(); boss.id = "corrupted-hunter"
        let fixture = try V3Fixtures.engine(eventID:"major-strike-a",boss:BossEncounter(definition:boss,state:BossState(maximumHP:2200)))
        var run = fixture
        for i in 1...30 { run.consume(SensorFrame(timestamp:Double(i),speed:0,distance:0,movement:.stationary,signal:.unavailable)) }
        XCTAssertEqual(run.session.event?.battle?.attacks,0)
        XCTAssertEqual(run.session.phase,.paused)
    }

}
