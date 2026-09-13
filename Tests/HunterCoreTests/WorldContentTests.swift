import XCTest
@testable import HunterCore

final class WorldContentTests: XCTestCase {
    private func world() throws -> WorldContent {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return try JSONDecoder().decode(WorldContent.self, from: Data(contentsOf: root.appendingPathComponent("Resources/world.json")))
    }
    private func run(_ boss: BossDefinition, state: BossState? = nil, seconds: Int = 600, speed: Double = 2.5, simulated: Bool = false) -> RunSession {
        var session = RunSession(targetSeconds: Double(seconds), simulated: simulated, allowPursuit: false, mode: .gate)
        session.boss = BossEncounter(definition: boss, state: state ?? BossState(maximumHP: boss.maximumHP))
        var engine = RunEngine(session: session, content: session.boss!.content)
        for t in 0...seconds {
            engine.consume(SensorFrame(timestamp: Double(t), speed: speed, distance: speed, movement: speed < 2 ? .walking : .running, signal: .good))
            engine.instructionFinished()
        }
        engine.end()
        return engine.session
    }
    func testWorldCatalogAndStageThresholds() throws {
        let world = try world(); XCTAssertNoThrow(try world.validate())
        XCTAssertEqual(world.monsters.count, 17); XCTAssertEqual(world.bosses.count, 2)
        var profile = Profile(); XCTAssertEqual(AssociationStage.level(profile), 0)
        var growth = profile.growth; growth.departments["observation"] = 2; profile.growth = growth
        XCTAssertEqual(AssociationStage.level(profile), 0)
        growth.departments["research"] = 2; profile.growth = growth; XCTAssertEqual(AssociationStage.level(profile), 1)
        growth.departments["equipment"] = 2; growth.departments["contracts"] = 2; profile.growth = growth
        XCTAssertEqual(AssociationStage.level(profile), 2)
    }
    func testDamageCarriesAcrossActivitiesAndAwardsClearOnce() throws {
        let boss = try world().bosses[0]; var profile = Profile()
        var previous = boss.maximumHP
        var clearCount = 0
        for _ in 0..<8 {
            let state = BossCampaign.state(boss, profile: profile)
            if state.remainingHP == 0 { break }
            let session = run(boss, state: state)
            let summary = try XCTUnwrap(Settlement.apply(session, to: &profile))
            let report = try XCTUnwrap(summary.majorBoss)
            XCTAssertLessThan(report.remainingHP, previous)
            previous = report.remainingHP
            if report.cleared { clearCount += 1; XCTAssertEqual(summary.cores, 2) }
            let total = profile.growth.cores
            XCTAssertNil(Settlement.apply(session, to: &profile)); XCTAssertEqual(total, profile.growth.cores)
        }
        XCTAssertEqual(previous, 0); XCTAssertEqual(clearCount, 1)
        XCTAssertEqual(profile.growth.cores, 2); XCTAssertEqual(Progression.gateClears(profile), 1)
        XCTAssertEqual(profile.bosses?[boss.id]?.clears, 1)
    }
    func testWalkingAndSimulationDoNotDamageRealBoss() throws {
        let boss = try world().bosses[0]; var profile = Profile()
        let walk = run(boss, speed: 1.2)
        Settlement.apply(walk, to: &profile)
        XCTAssertEqual(profile.bosses?[boss.id]?.remainingHP, boss.maximumHP)
        XCTAssertEqual(walk.boss?.damage, 0)
        let before = profile.bosses
        XCTAssertNil(Settlement.apply(run(boss, simulated: true), to: &profile))
        XCTAssertEqual(before, profile.bosses); XCTAssertEqual(profile.growth.cores, 0)
    }
    func testBossSnapshotRecoveryKeepsDamageAndPhase() throws {
        let boss = try world().bosses[0]
        let completed = run(boss)
        let decoded = try JSONDecoder().decode(RunSession.self, from: JSONEncoder().encode(completed))
        XCTAssertEqual(decoded.boss?.damage, completed.boss?.damage)
        XCTAssertEqual(decoded.boss?.phase, completed.boss?.phase)
        var recovery = RunEngine(session: decoded, content: boss.phases[0]); recovery.restorePaused()
        let hp = recovery.session.boss?.remainingHP
        recovery.consume(SensorFrame(timestamp: 100000, speed: 3, distance: 1000, movement: .running, signal: .good))
        XCTAssertEqual(recovery.session.boss?.remainingHP, hp)
    }
    func testStaleSnapshotCannotDamageAnotherCampaignRound() throws {
        let boss = try world().bosses[0]; var profile = Profile()
        let old = run(boss)
        var newer = BossState(maximumHP: boss.maximumHP); newer.round = 2
        profile.bosses = [boss.id: newer]
        let result = Settlement.apply(old, to: &profile)
        XCTAssertNil(result?.majorBoss); XCTAssertEqual(profile.bosses?[boss.id], newer)
    }
    func testForgedDamageWithoutCombatRecordIsIgnored() throws {
        let boss = try world().bosses[0]; var profile = Profile()
        var session = run(boss, speed: 1.2)
        session.boss?.damage = boss.maximumHP
        let result = Settlement.apply(session, to: &profile)
        XCTAssertEqual(result?.majorBoss?.damage, 0)
        XCTAssertEqual(profile.growth.cores, 0)
    }
    func testNewRoundRequiresClearUnlockAndNoActiveRun() throws {
        let boss = try world().bosses[0]
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let catalog = try JSONDecoder().decode(ProgressionCatalog.self, from: Data(contentsOf: root.appendingPathComponent("Resources/progression.json")))
        var save = SaveState()
        var completed = BossState(maximumHP: boss.maximumHP); completed.remainingHP = 0; completed.clears = 1
        save.profile.bosses = [boss.id: completed]
        XCTAssertThrowsError(try BossCampaign.restart(boss, save: &save, catalog: catalog))
        var growth = save.profile.growth; growth.rank = "D"; growth.departments["observation"] = 2; save.profile.growth = growth
        save.active = RunSession(targetSeconds: 600, simulated: false, allowPursuit: false)
        XCTAssertThrowsError(try BossCampaign.restart(boss, save: &save, catalog: catalog))
        save.active = nil
        try BossCampaign.restart(boss, save: &save, catalog: catalog)
        XCTAssertEqual(save.profile.bosses?[boss.id]?.round, 2)
        XCTAssertEqual(save.profile.bosses?[boss.id]?.clears, 1)
        XCTAssertEqual(save.profile.bosses?[boss.id]?.remainingHP, boss.maximumHP)
        XCTAssertThrowsError(try BossCampaign.restart(boss, save: &save, catalog: catalog))
    }
    func testPhaseChangesContentWithoutChangingPaceThreshold() throws {
        let boss = try world().bosses[0]
        var state = BossState(maximumHP: boss.maximumHP)
        XCTAssertEqual(BossEncounter(definition: boss, state: state).phase, 0)
        state.remainingHP = 200
        let second = BossEncounter(definition: boss, state: state)
        XCTAssertEqual(second.phase, 1)
        XCTAssertNotEqual(second.content.events.first { $0.kind == .boss }?.startFraction, boss.phases[0].events.first { $0.kind == .boss }?.startFraction)
        state.remainingHP = 100
        let final = BossEncounter(definition: boss, state: state)
        XCTAssertEqual(final.phase, 2); XCTAssertEqual(final.content.events.filter { $0.kind == .boss }.count, 2)
    }
    func testLegacyProfileAndInvalidBossSave() throws {
        let data = try JSONEncoder().encode(SaveState())
        let old = try JSONDecoder().decode(SaveState.self, from: data)
        XCTAssertNil(old.profile.bosses)
        var save = old; var state = BossState(maximumHP: 300); state.remainingHP = -1
        save.profile.bosses = ["boundary-lord": state]
        XCTAssertThrowsError(try SaveRepository(directory: FileManager.default.temporaryDirectory).validate(save))
    }
    func testArchiveKeepsBossIdentitiesSeparate() throws {
        let world = try world(); var profile = Profile()
        Settlement.apply(run(world.bosses[0]), to: &profile)
        XCTAssertFalse(world.monsters.first { $0.id == "boundary-lord" }!.records(in: profile).isEmpty)
        XCTAssertTrue(world.monsters.first { $0.id == "void-librarian" }!.records(in: profile).isEmpty)
    }
}
