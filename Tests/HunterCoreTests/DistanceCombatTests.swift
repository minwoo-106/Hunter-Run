import Foundation
import XCTest
@testable import HunterCore

final class DistanceCombatTests: XCTestCase {
    func rulesData() throws -> Data {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return try Data(contentsOf: root.appendingPathComponent("Resources/combat-v3.json"))
    }
    func engine() throws -> RunEngine {
        let template = MissionTemplate(id: "beast", title: "잔향 늑대", kind: .ambush, startFraction: 0.3, duration: 25, hp: 180, audio: "wolf_intro")
        var session = RunSession(targetSeconds: 1800, simulated: false, allowPursuit: false, mode: .contract, loadout: CombatStats(attack: 2.915))
        session.activeSeconds = 180; session.phase = .moving; session.lastTimestamp = 0
        var event = RunEvent(template: template, hp: 180, startingHP: 180, baseline: 2.5)
        event.stage = .active; session.event = event
        var encoded = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(session)) as? [String: Any])
        encoded["combatRules"] = try JSONSerialization.jsonObject(with: rulesData())
        session = try JSONDecoder().decode(RunSession.self, from: JSONSerialization.data(withJSONObject: encoded))
        return RunEngine(session: session, content: GameContent(schema: 1, missionTitle: "거리 전투 검증", events: [template]))
    }
    func testFirstAttackOccursAt75MetersNotAt74() throws {
        var run = try engine()
        run.consume(SensorFrame(timestamp: 1, speed: 2.5, distance: 74, movement: .running, signal: .good, distanceDuration: 30))
        XCTAssertEqual(run.session.event?.hp, 180)
        run.consume(SensorFrame(timestamp: 2, speed: 2.5, distance: 1, movement: .running, signal: .good))
        XCTAssertEqual(run.session.event?.hp, 21, "75m에 첫 공격이 적용되어야 합니다.")
        XCTAssertTrue(run.session.records.isEmpty)
    }
    func testDefeatedWolfAwardsItsFixed25Experience() throws {
        var run = try engine()
        run.consume(SensorFrame(timestamp: 1, speed: 2.5, distance: 150, movement: .running, signal: .good, distanceDuration: 60))
        run.end()
        var profile = Profile()
        let summary = Settlement.apply(run.session, to: &profile)
        XCTAssertEqual(summary?.xp, 43, "운동181초의18EXP와 늑대25EXP만 지급해야 합니다.")
        XCTAssertNil(Settlement.apply(run.session, to: &profile))
        XCTAssertEqual(profile.xp, 43)
    }

    func testFinishedSessionCannotBeReopenedByResume() throws {
        var run = try engine(); run.end()
        run.pause(false); run.interrupt(false); run.restorePaused()
        run.consume(SensorFrame(timestamp: 1, speed: 2.5, distance: 150, movement: .running, signal: .good, distanceDuration: 60))
        XCTAssertEqual(run.session.phase, .finished)
        XCTAssertEqual(run.session.activeSeconds, 180)
    }
    func testGPSBatchSpanningManualPauseIsNotCredited() throws {
        var run = try engine()
        run.consume(SensorFrame(timestamp: 1, speed: 2.5, distance: 74, movement: .running, signal: .good, distanceDuration: 30))
        run.pause(true)
        run.consume(SensorFrame(timestamp: 100, speed: 2.5, distance: 0, movement: .running, signal: .good))
        run.pause(false)
        run.consume(SensorFrame(timestamp: 101, speed: 2.5, distance: 0, movement: .running, signal: .good))
        run.consume(SensorFrame(timestamp: 102, speed: 2.5, distance: 150, movement: .running, signal: .good, distanceDuration: 60))
        XCTAssertEqual(run.session.event?.hp, 180)
        XCTAssertTrue(run.session.records.isEmpty)
        run.consume(SensorFrame(timestamp: 103, speed: 2.5, distance: 1, movement: .running, signal: .good))
        XCTAssertEqual(run.session.event?.hp, 21)
    }

    func testFractionalGPSIncrementsDoNotDelayExact75MeterAttack() throws {
        var run = try V3Fixtures.engine()
        for i in 1...750 { run.consume(V3Fixtures.frame(Double(i), 0.1)) }
        XCTAssertEqual(run.session.event?.hp, 21)
        XCTAssertEqual(run.session.event?.battle?.attacks, 1)
    }

}
