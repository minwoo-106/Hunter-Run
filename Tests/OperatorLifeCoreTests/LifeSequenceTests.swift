import XCTest
@testable import OperatorLifeCore

final class LifeSequenceTests: XCTestCase {
    func testMalformedSequenceCannotDriveTheRuntime() throws {
        var invalid = LifeSequence.standby
        invalid.idleSeconds = 0
        XCTAssertThrowsError(try LifeSequence.decode(JSONEncoder().encode(invalid)))
        invalid = .standby
        invalid.activities = [.idle]
        XCTAssertThrowsError(try LifeSequence.decode(JSONEncoder().encode(invalid)))
        invalid = .standby
        invalid.cues = [LifeCue(phase: .cola, at: -1, text: "invalid")]
        XCTAssertThrowsError(try LifeSequence.decode(JSONEncoder().encode(invalid)))
        XCTAssertThrowsError(try LifeSequence.decode(Data("{}".utf8)))
        var fallback = LifeStateMachine(sequence: .standby, initialPhase: .idle)
        fallback.configure(available: true, motionEnabled: false, reducedMotion: false)
        fallback.advance(3600)
        XCTAssertEqual(fallback.phase, .idle)
        XCTAssertFalse(fallback.consumeTap()) // ordinary conversation remains available
    }
    private func machine() throws -> LifeStateMachine {
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Resources/operator-life-cues.json")
        var m = LifeStateMachine(sequence: try JSONDecoder().decode(LifeSequence.self, from: Data(contentsOf: url)))
        m.configure(available: true, motionEnabled: true, reducedMotion: false)
        return m
    }
    func testWholeSequenceWaitsForTapAndReturnsToIdle() throws {
        var m = try machine(); XCTAssertEqual(m.phase, .stretching)
        m.advance(2.6); XCTAssertEqual(m.phase, .idle)
        m.advance(7.5); XCTAssertEqual(m.phase, .dozing)
        m.advance(3600); XCTAssertEqual(m.phase, .dozing)
        XCTAssertTrue(m.consumeTap()); XCTAssertEqual(m.phase, .surprised); XCTAssertEqual(m.cue, "어…?!")
        m.advance(1); XCTAssertEqual(m.phase, .embarrassed); XCTAssertEqual(m.cue, "아, 오셨어요?")
        m.advance(1.8); XCTAssertEqual(m.cue, "저 안 잤어요. 잠깐 눈만 감고 있었어요…")
        m.advance(4.4); XCTAssertEqual(m.phase, .idle); XCTAssertNil(m.cue)
        m.advance(13); XCTAssertEqual(m.phase, .idle)
    }
    func testOrdinaryTapAndRepeatedWakeTap() throws {
        var m = try machine(); XCTAssertFalse(m.consumeTap())
        m.advance(15); XCTAssertTrue(m.consumeTap()); m.advance(0.4)
        XCTAssertTrue(m.consumeTap()); XCTAssertEqual(m.elapsed, 0.4, accuracy: 0.001)
        m.advance(1); XCTAssertTrue(m.consumeTap()); XCTAssertEqual(m.phase, .embarrassed)
    }
    func testBackgroundDoesNotAdvanceOrConsumeTouch() throws {
        var m = try machine(); m.advance(15)
        let before = m.elapsed
        m.configure(available: false, motionEnabled: true, reducedMotion: false)
        m.advance(500); XCTAssertEqual(m.elapsed, before); XCTAssertFalse(m.consumeTap())
        m.configure(available: true, motionEnabled: true, reducedMotion: false)
        XCTAssertTrue(m.consumeTap()); m.advance(0.4)
        m.configure(available: false, motionEnabled: true, reducedMotion: false)
        m.advance(500); XCTAssertEqual(m.phase, .surprised); XCTAssertEqual(m.elapsed, 0.4, accuracy: 0.001)
    }
    func testReduceMotionSkipsStretchButStillAllowsStaticWakeSequence() throws {
        var m = try machine(); m.configure(available: true, motionEnabled: true, reducedMotion: true)
        XCTAssertEqual(m.phase, .idle); m.advance(12)
        XCTAssertTrue(m.frame.reducedMotion); XCTAssertEqual(m.phase, .dozing); XCTAssertTrue(m.consumeTap())
    }
    func testMotionOffClearsReactionAndKeepsNormalConversation() throws {
        var m = try machine(); m.advance(15); XCTAssertTrue(m.consumeTap())
        m.configure(available: true, motionEnabled: false, reducedMotion: false)
        m.advance(500); XCTAssertEqual(m.phase, .idle); XCTAssertNil(m.cue); XCTAssertFalse(m.consumeTap())
    }
    func testDozeProgressAndInvalidTime() throws {
        var m = try machine(); m.advance(10.1); m.advance(1.75)
        XCTAssertEqual(m.frame.dozeProgress, 0.5, accuracy: 0.001)
        let before = m.elapsed
        m.advance(.infinity); m.advance(.nan); m.advance(-1)
        XCTAssertEqual(m.elapsed, before)
    }
    func testLunchTapConsumesReactionThenReturnsToIdle() throws {
        var m = try machine()
        m = LifeStateMachine(sequence: m.sequence, initialPhase: .burger)
        m.configure(available: true, motionEnabled: true, reducedMotion: false)
        m.advance(90); XCTAssertEqual(m.phase, .burger)
        XCTAssertTrue(m.consumeTap()); XCTAssertEqual(m.phase, .burgerSurprised)
        m.advance(0.5); XCTAssertTrue(m.consumeTap())
        XCTAssertEqual(m.elapsed, 0.5, accuracy: 0.001)
        m.advance(0.91); XCTAssertEqual(m.phase, .burgerFlustered)
        XCTAssertTrue(m.consumeTap()); XCTAssertLessThan(m.elapsed, 0.02)
        m.advance(3.2); XCTAssertEqual(m.phase, .cola)
        XCTAssertTrue(m.consumeTap()); XCTAssertLessThan(m.elapsed, 0.02)
        m.advance(2.7); XCTAssertTrue(m.cue?.contains("삼킬 뻔") == true)
        m.advance(2.1); XCTAssertEqual(m.phase, .idle); XCTAssertNil(m.cue)
        XCTAssertFalse(m.consumeTap())
    }
    func testActivitiesRotateBetweenIdlePeriodsAfterWake() throws {
        var m = try machine(); m.advance(11); XCTAssertTrue(m.consumeTap())
        m.advance(7.21); XCTAssertEqual(m.phase, .idle)
        for (phase, duration) in [(LifePhase.coffee, 4.5), (.tablet, 6.0), (.spacingOut, 5.0), (.hairSweep, 3.5)] {
            m.advance(14); XCTAssertEqual(m.phase, phase)
            m.advance(duration); XCTAssertEqual(m.phase, .idle)
        }
        m.advance(14); XCTAssertEqual(m.phase, .burger)
        XCTAssertTrue(m.consumeTap()); m.advance(9.41)
        XCTAssertEqual(m.phase, .idle); m.advance(14); XCTAssertEqual(m.phase, .dozing)
    }
    func testLunchFreezesInBackgroundAndWorksWithReducedMotion() throws {
        var m = try machine()
        m = LifeStateMachine(sequence: m.sequence, initialPhase: .burger)
        m.configure(available: true, motionEnabled: true, reducedMotion: true)
        XCTAssertTrue(m.consumeTap()); m.advance(0.5)
        m.configure(available: false, motionEnabled: true, reducedMotion: true)
        m.advance(600); XCTAssertEqual(m.phase, .burgerSurprised)
        XCTAssertEqual(m.elapsed, 0.5, accuracy: 0.001); XCTAssertFalse(m.consumeTap())
        m.configure(available: true, motionEnabled: true, reducedMotion: true)
        m.advance(9); XCTAssertEqual(m.phase, .idle); XCTAssertTrue(m.frame.reducedMotion)
    }

    func testChestPatFreezesWithoutRestartAndResumesIntoCola() throws {
        var m = try machine()
        m = LifeStateMachine(sequence: m.sequence, initialPhase: .burgerFlustered, initialElapsed: 1)
        m.configure(available: true, motionEnabled: true, reducedMotion: false)
        XCTAssertTrue(m.consumeTap()); XCTAssertEqual(m.elapsed, 1)
        m.configure(available: false, motionEnabled: true, reducedMotion: false)
        m.advance(600); XCTAssertEqual(m.phase, .burgerFlustered); XCTAssertEqual(m.elapsed, 1)
        XCTAssertFalse(m.consumeTap())
        m.configure(available: true, motionEnabled: true, reducedMotion: true)
        m.advance(2.21); XCTAssertEqual(m.phase, .cola)
        XCTAssertTrue(m.frame.reducedMotion); XCTAssertTrue(m.consumeTap())
        m.advance(4.8); XCTAssertEqual(m.phase, .idle)
    }

}
