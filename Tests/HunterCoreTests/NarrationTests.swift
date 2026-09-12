import XCTest
@testable import HunterCore

final class NarrationTests: XCTestCase {
    private func catalog() throws -> NarrationCatalog {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return try JSONDecoder().decode(NarrationCatalog.self, from: Data(contentsOf: root.appendingPathComponent("Resources/narration.json")))
    }
    private func record(_ id: String = "beast", outcome: Outcome = .perfect, defeated: Bool = false, kind: EventKind = .ambush, damage: Double = 60) -> EventRecord {
        EventRecord(id: id, title: "Test", outcome: outcome, damage: damage, defeated: defeated, kind: kind)
    }
    func testDefeatRequiresActualDefeatAndPositiveDamage() throws {
        let c = try catalog(); try c.validate()
        XCTAssertEqual(c.result(record(defeated: true), bossID: nil), "wolf_defeated")
        XCTAssertEqual(c.result(record(), bossID: nil), "wolf_hit")
        XCTAssertNotEqual(c.result(record(defeated: true, damage: 0), bossID: nil), "wolf_defeated")
    }
    func testInvestigationDoesNotClaimKillWithSameMonsterIdentity() throws {
        let c = try catalog()
        for id in ["beast", "trail#2", "gate-core", "major-strike-a"] {
            XCTAssertEqual(c.result(record(id, defeated: true, kind: .discovery), bossID: "boundary-lord"), "survey_done")
        }
    }
    func testNeutralPartialAndRecoveryAvoidVictory() throws {
        let c = try catalog()
        XCTAssertEqual(c.result(record(outcome: .neutral, defeated: true), bossID: nil), "partial")
        XCTAssertEqual(c.result(record(outcome: .partial), bossID: nil), "partial")
        XCTAssertEqual(c.result(record(outcome: .fail), bossID: nil), "combat_withdraw")
        XCTAssertEqual(c.result(record(defeated: true), bossID: nil, recovering: true), "recovery")
    }
    func testBossIdentityDisambiguatesSharedStrikeID() throws {
        let c = try catalog(); let strike = record("major-strike-a#1", defeated: true, kind: .boss)
        XCTAssertEqual(c.result(strike, bossID: "boundary-lord"), "lord_defeated")
        XCTAssertEqual(c.result(strike, bossID: "void-librarian"), "librarian_defeated")
        XCTAssertEqual(c.result(strike, bossID: nil), "combat_hit")
        XCTAssertEqual(c.result(record("major-strike-b", kind: .boss), bossID: "boundary-lord"), "lord_hit")
    }
    func testPatrolSuffixAndLegacyKindAreSafe() throws {
        let c = try catalog()
        XCTAssertEqual(c.result(record("beast#3", defeated: true), bossID: nil), "wolf_defeated")
        var legacy = record(defeated: true); legacy.kind = nil
        XCTAssertEqual(c.result(legacy, bossID: nil), "partial")
    }
    func testInstructionKeysNeverBecomeResults() throws {
        let c = try catalog(); var run = RunSession(targetSeconds: 300, simulated: true, allowPursuit: false)
        run.records = [record(defeated: true)]
        for key in ["wolf_intro", "resume", "run_end", "signal"] { XCTAssertEqual(c.response(to: key, session: run), key) }
        XCTAssertEqual(c.response(to: "success", session: run), "wolf_defeated")
    }
    func testNamedIntroductionsMatchActionAndBossPhase() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let missions = try JSONDecoder().decode(MissionCatalog.self, from: Data(contentsOf: root.appendingPathComponent("Resources/missions.json")))
        let content = missions.content(for: .contract, extended: false)
        XCTAssertEqual(content.events.first { $0.id == "beast" }?.audio, "wolf_intro")
        let run = RunSession(targetSeconds: 300, simulated: true, allowPursuit: false)
        let hold = RunDirector.events(content, session: run, cycle: 0).first { $0.id == "contract-endurance" }
        XCTAssertEqual(hold?.kind, .maintain); XCTAssertEqual(hold?.audio, "guard_hold")
        let world = try JSONDecoder().decode(WorldContent.self, from: Data(contentsOf: root.appendingPathComponent("Resources/world.json")))
        for (boss, prefix) in zip(world.bosses, ["lord", "librarian"]) {
            for (index, phase) in boss.phases.enumerated() {
                XCTAssertTrue(phase.events.filter { $0.id.hasPrefix("major-strike") }.allSatisfy { $0.audio == "\(prefix)_phase\(index + 1)" })
            }
        }
    }
}
