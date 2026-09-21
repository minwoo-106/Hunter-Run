import XCTest
@testable import HunterCore

final class PaceLearningTests: XCTestCase {
    private let content = GameContent(schema: 1, missionTitle: "Pace test", events: [MissionTemplate(id: "late", title: "Late", kind: .maintain, startFraction: 0.8, duration: 20, hp: 50, audio: "maintain")])
    private func session(simulated: Bool = false, reference: Double? = nil) -> RunSession {
        var session = RunSession(targetSeconds: 600, simulated: simulated, allowPursuit: true)
        session.learnedReference = reference; return session
    }
    @discardableResult private func step(_ engine: inout RunEngine, _ t: Double, speed: Double = 2.5, movement: Movement = .running, signal: Signal = .good) -> [GameCue] {
        engine.consume(SensorFrame(timestamp: t, speed: speed, distance: speed, movement: movement, signal: signal))
    }
    func testTimeWeightedMedianAndBoundedStorage() {
        var observation = PaceObservation()
        for _ in 0..<100 { observation.observe(speed: 2.5, seconds: 5, goodSignal: true, eligible: true) }
        for _ in 0..<100 { observation.observe(speed: 5, seconds: 1, goodSignal: true, eligible: true) }
        XCTAssertEqual(observation.median, 2.5)
        for _ in 0..<400 { observation.observe(speed: 2.5, seconds: 5, goodSignal: true, eligible: true) }
        XCTAssertEqual(observation.stableSeconds, 1800); XCTAssertEqual(observation.bins.count, 51); XCTAssertTrue(observation.isValid)
    }
    func testSensorUncertaintyPauseVehicleAndGapsDoNotTrain() {
        var engine = RunEngine(session: session(), content: content)
        step(&engine, 0); step(&engine, 1)
        step(&engine, 2, signal: .degraded); step(&engine, 3, movement: .walking)
        step(&engine, 4, movement: .vehicle); step(&engine, 60)
        engine.pause(true); for t in 61...70 { step(&engine, Double(t)) }
        XCTAssertEqual(engine.session.paceObservation?.stableSeconds, 1)
        XCTAssertEqual(engine.session.paceObservation?.uncertainSeconds, 1)
    }
    func testBriefingCombatAndRecoveryWindowAreExcluded() {
        let early = GameContent(schema: 1, missionTitle: "Early", events: [MissionTemplate(id: "early", title: "Early", kind: .maintain, startFraction: 0.15, duration: 20, hp: 50, audio: "maintain")])
        var engine = RunEngine(session: session(), content: early)
        for t in 0...100 { step(&engine, Double(t)) }
        XCTAssertEqual(engine.session.paceObservation?.stableSeconds, 90)
        engine.instructionFinished()
        for t in 101...170 { step(&engine, Double(t)) }
        XCTAssertEqual(engine.session.paceObservation?.stableSeconds, 90)
        for t in 171...190 { step(&engine, Double(t)) }
        XCTAssertGreaterThan(engine.session.paceObservation!.stableSeconds, 90)
    }
    func testSettledRealSamplesTrainOnceAndMocksNeverTrain() {
        var engine = RunEngine(session: session(), content: content)
        for t in 0...350 { step(&engine, Double(t)) }; engine.end()
        var profile = Profile()
        let report = Settlement.apply(engine.session, to: &profile)?.paceReport
        XCTAssertTrue(report?.learned == true); XCTAssertEqual(profile.paceMemory?.reference, 2.5)
        XCTAssertNil(Settlement.apply(engine.session, to: &profile)); XCTAssertEqual(profile.paceMemory?.recent.count, 1)
        var mock = engine.session; mock.id = UUID(); mock.simulated = true
        XCTAssertNil(Settlement.apply(mock, to: &profile)); XCTAssertEqual(profile.paceMemory?.recent.count, 1)
    }
    func testShortSamplesGiveFeedbackWithoutLearning() {
        var engine = RunEngine(session: session(), content: content)
        for t in 0...200 { step(&engine, Double(t)) }; engine.end()
        var profile = Profile()
        let report = Settlement.apply(engine.session, to: &profile)?.paceReport
        XCTAssertEqual(report?.stableSeconds, 200); XCTAssertFalse(report?.learned ?? true); XCTAssertNil(profile.paceMemory)
    }
    func testRecentMedianLimitsEachChangeToFivePercent() {
        var memory = PaceMemory(); memory.include(2.5)
        for speed in [6.0, 6, 6, 6, 6, 1, 1, 1, 1, 1] {
            let before = memory.reference!; memory.include(speed)
            XCTAssertLessThanOrEqual(memory.reference!, before * 1.05 + 0.00001)
            XCTAssertGreaterThanOrEqual(memory.reference!, before * 0.95 - 0.00001)
            XCTAssertLessThanOrEqual(memory.recent.count, 5); XCTAssertTrue(memory.isValid)
        }
    }
    func testHistoryDoesNotRaiseTodaysObservedBaseline() {
        var engine = RunEngine(session: session(reference: 4), content: content)
        for t in 0...481 { step(&engine, Double(t)) }
        XCTAssertEqual(engine.session.event?.baseline, 2.5)
        XCTAssertEqual(PaceLearning.effectiveBaseline(current: 2.5, learned: 2, fallback: 3), 2)
    }
    func testObservationAndReferenceSurviveRecoveryAndInvalidSaveIsRejected() throws {
        var engine = RunEngine(session: session(reference: 2.3), content: content)
        for t in 0...100 { step(&engine, Double(t)) }
        let saved = try JSONDecoder().decode(RunSession.self, from: JSONEncoder().encode(engine.session))
        var restored = RunEngine(session: saved, content: content); restored.restorePaused(); step(&restored, 10000)
        XCTAssertEqual(restored.session.paceObservation?.stableSeconds, 100); XCTAssertEqual(restored.session.learnedReference, 2.3)
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let repo = SaveRepository(directory: folder)
        var save = SaveState(); save.active = saved
        XCTAssertNoThrow(try repo.validate(save))
        save.active?.paceObservation?.bins = [-1]
        XCTAssertThrowsError(try repo.validate(save))
        save.active = nil; var memory = PaceMemory(); memory.reference = .infinity; save.profile.paceMemory = memory
        XCTAssertThrowsError(try repo.validate(save))
    }
    func testLegacyActivityHasNoInventedPaceAnalysis() throws {
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(session())) as? [String: Any])
        json.removeValue(forKey: "paceObservation")
        let old = try JSONDecoder().decode(RunSession.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertNil(old.paceObservation); XCTAssertNil(PaceLearning.report(old, memory: nil))
    }
    func testInvalidHistoricalPaceReportIsRejected() throws {
        var engine = RunEngine(session: session(), content: content)
        for t in 0...350 { step(&engine, Double(t)) }; engine.end()
        var save = SaveState(); Settlement.apply(engine.session, to: &save.profile)
        let repo = SaveRepository(directory: FileManager.default.temporaryDirectory)
        XCTAssertNoThrow(try repo.validate(save))
        save.profile.runs[0].paceReport?.goodSignalFraction = 1e300
        XCTAssertThrowsError(try repo.validate(save))
    }
    func testModeSpecificStartTitles() {
        XCTAssertEqual(RunMode.exploration.startTitle(), "현장 탐험 시작")
        XCTAssertEqual(RunMode.contract.startTitle(), "현장 사냥 시작")
        XCTAssertEqual(RunMode.gate.startTitle(), "게이트 조사 시작")
        XCTAssertEqual(RunMode.gate.startTitle(boss: true), "보스 토벌 시작")
    }
}
