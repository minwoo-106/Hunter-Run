import XCTest
@testable import HunterCore

final class OperatorGiftTests: XCTestCase {
    private func run(_ seconds: Double, mode: RunMode = .exploration, indoor: Bool = false, simulated: Bool = false) -> RunSession {
        var run = RunSession(targetSeconds: 3600, simulated: simulated, allowPursuit: false, mode: mode)
        run.activeSeconds = seconds; run.phase = .finished
        if indoor { run.environment = .indoor }
        return run
    }
    func testSeveralShortWalksAccumulateAndSettlementRetryCannotDuplicateGift() throws {
        var profile = Profile()
        let first = run(900), second = run(900)
        XCTAssertNil(Settlement.apply(first, to: &profile)?.foundGifts)
        XCTAssertEqual(profile.journey?.gifts?.explorationSeconds, 900)
        let summary = try XCTUnwrap(Settlement.apply(second, to: &profile))
        XCTAssertEqual(summary.foundGifts?.count, 1)
        XCTAssertEqual(profile.journey?.gifts?.inventory.values.reduce(0, +), 1)
        XCTAssertEqual(profile.runs.first?.foundGifts, summary.foundGifts)
        XCTAssertNil(Settlement.apply(second, to: &profile))
        XCTAssertEqual(profile.journey?.gifts?.inventory.values.reduce(0, +), 1)
        XCTAssertEqual(profile.journey?.gifts?.explorationSeconds, 0)
    }
    func testIndoorOtherModesSimulationAndSubThreeMinutesDoNotProduceGifts() {
        for session in [run(3600, indoor: true), run(3600, mode: .contract), run(3600, mode: .gate), run(3600, simulated: true), run(179)] {
            var profile = Profile()
            XCTAssertTrue(Settlement.apply(session, to: &profile)?.foundGifts?.isEmpty ?? true)
            XCTAssertNil(profile.journey?.gifts)
        }
        var paused = run(3600); paused.phase = .paused
        var profile = Profile()
        XCTAssertNil(Settlement.apply(paused, to: &profile))
        XCTAssertNil(profile.journey?.gifts)
    }
    func testGivingConsumesOneGiftAndARepeatedTapCannotIncreaseAffinity() throws {
        var profile = Profile(); var state = JourneyState(); var gifts = OperatorGiftState()
        state.memories["drink"] = "warm"; gifts.inventory["warmLight"] = 1; state.gifts = gifts; profile.journey = state
        let response = try XCTUnwrap(OperatorGifts.give(.warmLight, profile: &profile))
        XCTAssertEqual(response.affinity, 2)
        XCTAssertTrue(response.text.contains("따뜻한 걸 좋아하신다고 했죠"))
        XCTAssertEqual(profile.journey?.gifts?.inventory["warmLight"], 0)
        XCTAssertEqual(profile.journey?.affinity, 2)
        XCTAssertNil(OperatorGifts.give(.warmLight, profile: &profile))
        XCTAssertEqual(profile.journey?.affinity, 2)
    }
    func testGiftsCannotSkipStoryRelationshipGate() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let catalog = try JSONDecoder().decode(NarrativeCatalog.self, from: Data(contentsOf: root.appendingPathComponent("Resources/narrative.json")))
        var profile = Profile(); var state = JourneyState(); var gifts = OperatorGiftState()
        gifts.inventory["flower"] = 40; state.gifts = gifts; state.unlocked = ["M01"]; profile.journey = state
        for _ in 0..<20 { _ = OperatorGifts.give(.flower, profile: &profile) }
        catalog.refresh(&profile)
        XCTAssertEqual(profile.journey?.affinity, 40)
        XCTAssertEqual(catalog.tier(profile), 1)
        XCTAssertFalse(profile.journey?.unlocked.contains("M03") ?? true)
        profile.journey?.unlocked.insert("M03")
        XCTAssertEqual(catalog.tier(profile), 2, "M06 must still be reached for tier 3")
    }
    func testOldJourneyAndRunSummaryDecodeWithoutGiftFieldsAndRoundTripNewGifts() throws {
        var state = JourneyState(); state.affinity = 12; state.completed = ["M01", "R01"]
        var raw = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(state)) as? [String: Any])
        raw.removeValue(forKey: "gifts")
        let old = try JSONDecoder().decode(JourneyState.self, from: JSONSerialization.data(withJSONObject: raw))
        XCTAssertEqual(old.affinity, 12); XCTAssertNil(old.gifts); XCTAssertEqual(old.completed, state.completed)
        var profile = Profile(); profile.journey = old
        let summary = try XCTUnwrap(Settlement.apply(run(1800), to: &profile))
        XCTAssertEqual(summary.foundGifts?.count, 1)
        let decoded = try JSONDecoder().decode(Profile.self, from: JSONEncoder().encode(profile))
        XCTAssertEqual(decoded.journey?.gifts, profile.journey?.gifts)
        XCTAssertEqual(decoded.journey?.affinity, 12)
        var summaryRaw = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(summary)) as? [String: Any])
        summaryRaw.removeValue(forKey: "foundGifts")
        XCTAssertNil(try JSONDecoder().decode(RunSummary.self, from: JSONSerialization.data(withJSONObject: summaryRaw)).foundGifts)
    }
    func testMalformedGiftInventoryIsRejectedAndAffinityCapsSafely() throws {
        var gifts = OperatorGiftState(); gifts.inventory["unknown"] = 1; XCTAssertFalse(gifts.isValid)
        gifts.inventory = ["flower": -1]; XCTAssertFalse(gifts.isValid)
        gifts.inventory = ["flower": 100]; XCTAssertFalse(gifts.isValid)
        gifts.inventory = ["flower": 1]; gifts.explorationSeconds = .infinity; XCTAssertFalse(gifts.isValid)
        gifts.explorationSeconds = 0
        var profile = Profile(); var state = JourneyState(); state.gifts = gifts; state.affinity = 99; profile.journey = state
        XCTAssertEqual(OperatorGifts.give(.flower, profile: &profile)?.affinity, 1)
        XCTAssertEqual(profile.journey?.affinity, NarrativeCatalog.affinityMaximum)
        XCTAssertTrue(profile.journey?.isValid ?? false)
    }
    func testStoryRewardsAtAffinityCapKeepSaveValidAndCannotRepeat() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let catalog = try JSONDecoder().decode(NarrativeCatalog.self, from: Data(contentsOf: root.appendingPathComponent("Resources/narrative.json")))
        var profile = Profile(); var state = JourneyState()
        state.affinity = NarrativeCatalog.affinityMaximum; state.unlocked = ["M01", "M02", "M03", "R01"]; profile.journey = state
        catalog.refresh(&profile)
        XCTAssertEqual(profile.journey?.affinity, NarrativeCatalog.affinityMaximum)
        XCTAssertTrue(profile.journey?.milestones.contains("M03") ?? false)
        let scene = try XCTUnwrap(catalog.scene("R01"))
        let ending = try XCTUnwrap(scene.nodes.first { $0.next == nil && ($0.choices ?? []).isEmpty })
        profile.journey?.cursor = DialogueCursor(sceneID: scene.id, nodeID: ending.id)
        XCTAssertTrue(try catalog.advance(profile: &profile))
        XCTAssertEqual(profile.journey?.affinity, NarrativeCatalog.affinityMaximum)
        XCTAssertTrue(profile.journey?.isValid ?? false)
        XCTAssertTrue(profile.journey?.completed.contains("R01") ?? false)
        catalog.refresh(&profile)
        XCTAssertEqual(profile.journey?.affinity, NarrativeCatalog.affinityMaximum)
        XCTAssertThrowsError(try catalog.begin("R01", profile: &profile))
    }
}
