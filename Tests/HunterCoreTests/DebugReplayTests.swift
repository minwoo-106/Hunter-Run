import Foundation
import XCTest
@testable import HunterCore

final class DebugReplayTests: XCTestCase {
    func fixture() throws -> ReplayScenario {
        let engine = try V3Fixtures.engine()
        return ReplayScenario(name:"검증용 늑대", note:"실제 계산부 재생", profile:V3Fixtures.actualSave().profile,
            session:engine.session, content:engine.content,
            operations:[.init(.frame,frame:V3Fixtures.frame(1,150)),.init(.finish),.init(.settle),.init(.settle)],
            expected:[.init("attacks",2),.init("damage",180),.init("gainedXP",43),.init("settlements",1)])
    }
    func testUsesActualEngineAndNeverMutatesCallerProfile() throws {
        let scenario = try fixture()
        let encoder = JSONEncoder(); encoder.outputFormatting = .sortedKeys
        let original = try encoder.encode(scenario.profile)
        let result = try DebugReplayRunner.run(scenario)
        XCTAssertTrue(result.passed)
        XCTAssertEqual(result.steps.count,5)
        XCTAssertEqual(result.steps[1].cues,["success","저장 시점"])
        XCTAssertEqual(scenario.profile.xp,4250)
        XCTAssertEqual(try encoder.encode(scenario.profile),original)
    }
    func testExportedInputsProduceExactlyTheSameReplay() throws {
        let original = try fixture()
        let copy = try JSONDecoder().decode(ReplayScenario.self,from:JSONEncoder().encode(original))
        let encoder = JSONEncoder(); encoder.outputFormatting = .sortedKeys
        XCTAssertEqual(try encoder.encode(DebugReplayRunner.run(original)),try encoder.encode(DebugReplayRunner.run(copy)))
    }
    func testPoorGPSAndWalkingInputsChangeActualCombatResults() throws {
        for (movement,signal) in [(Movement.running,Signal.degraded),(.walking,.good),(.stationary,.good)] {
            var scenario = try fixture()
            scenario.operations[0].frame = V3Fixtures.frame(1,150,movement:movement,signal:signal)
            scenario.expected = [.init("attacks",0),.init("enemyHP",180)]
            XCTAssertTrue(try DebugReplayRunner.run(scenario).passed)
        }
    }
    func testMissingInputsInvalidSchemaAndOverlappingSessionsAreRejected() throws {
        var scenario = try fixture(); scenario.schema = 99
        XCTAssertThrowsError(try DebugReplayRunner.run(scenario))
        scenario.schema = 1; scenario.operations = [.init(.frame)]
        XCTAssertThrowsError(try DebugReplayRunner.run(scenario))
        scenario.operations = [.init(.beginSession,session:scenario.session,content:scenario.content)]
        XCTAssertThrowsError(try DebugReplayRunner.run(scenario))
        scenario.operations = []; scenario.expected = [.init("unknown",0)]
        XCTAssertFalse(try DebugReplayRunner.run(scenario).passed)
    }
    func testSaveRecoveryKeepsAttackRemainderWithoutCountingOfflineDistance() throws {
        var scenario = try fixture()
        scenario.operations = [.init(.frame,frame:V3Fixtures.frame(1,74)),.init(.recover),.init(.resume),
            .init(.frame,frame:V3Fixtures.frame(10000,150)),.init(.instructionFinished),
            .init(.frame,frame:V3Fixtures.frame(10001,1)),.init(.finish),.init(.settle)]
        scenario.expected = [.init("attacks",1),.init("enemyHP",21),.init("gainedXP",18),.init("settlements",1)]
        XCTAssertTrue(try DebugReplayRunner.run(scenario).passed)
    }
    func testSeededDistancePartitionsMatchSingleBatchForEveryMonster() throws {
        var seed: UInt64 = 20261008
        for monster in try V3Fixtures.rules().monsters {
            for attack in [1.0,2.915,5.0,12.0] {
                var split = DistanceBattle(monster:monster)
                var total = 0.0
                for _ in 0..<500 {
                    seed = seed &* 6364136223846793005 &+ 1442695040888963407
                    let distance = Double(seed % 3000) / 100
                    total += distance; split.advance(distance:distance,attack:attack)
                }
                var batch = DistanceBattle(monster:monster); batch.advance(distance:total,attack:attack)
                XCTAssertEqual(split.attacks,batch.attacks,monster.id)
                XCTAssertEqual(split.remainingHP,batch.remainingHP,accuracy:1e-8,monster.id)
                XCTAssertEqual(split.remainder,batch.remainder,accuracy:1e-8,monster.id)
                XCTAssertTrue(split.isValid)
            }
        }
    }
}
