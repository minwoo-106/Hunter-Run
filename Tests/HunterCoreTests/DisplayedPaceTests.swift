import XCTest
@testable import HunterCore

final class DisplayedPaceTests: XCTestCase {
    func frame(_ time: Double, _ speed: Double, movement: Movement = .running, signal: Signal = .good) -> SensorFrame {
        SensorFrame(timestamp: time, speed: speed, distance: speed, movement: movement, signal: signal)
    }
    func testAlternatingSensorSpeedDoesNotSwingDisplayedPaceByMinutes() {
        var display = DisplayedPace()
        var paces: [Double] = []
        for t in 0...40 {
            display.update(frame(Double(t), t.isMultiple(of: 2) ? 1.6 : 2.8))
            if t >= 12, let speed = display.speed { paces.append(1000 / speed) }
        }
        XCTAssertGreaterThan(paces.count, 20)
        XCTAssertLessThan((paces.max() ?? 0) - (paces.min() ?? 0), 45, "steady movement with noisy GPS must not jump by minutes/km")
    }
    func testStopPauseAndUnreliableSignalsClearOldPace() {
        let invalid = [frame(11, 0, movement: .stationary), frame(11, 3, movement: .vehicle),
                       frame(11, 3, movement: .unknown), frame(11, 3, signal: .degraded),
                       frame(11, 3, signal: .unavailable), frame(11, .nan), frame(11, 20)]
        for bad in invalid {
            var display = DisplayedPace()
            for t in 0...10 { display.update(frame(Double(t), 3)) }
            XCTAssertEqual(display.speed, 3)
            display.update(bad)
            XCTAssertNil(display.speed)
            for t in 12...15 { display.update(frame(Double(t), 1.2, movement: .walking)) }
            XCTAssertEqual(display.speed ?? 0, 1.2, accuracy: 0.001)
            display.update(frame(16, 3), paused: true)
            XCTAssertNil(display.speed)
        }
    }
    func testGapAndResetRequireFreshWarmup() {
        var display = DisplayedPace()
        for t in 0...10 { display.update(frame(Double(t), 3)) }
        display.update(frame(30, 1.2))
        XCTAssertNil(display.speed)
        for t in 31...33 { display.update(frame(Double(t), 1.2)) }
        XCTAssertEqual(display.speed ?? 0, 1.2, accuracy: 0.001)
        display.reset()
        XCTAssertNil(display.speed)
    }
    func testDuplicateAndReplaySamplesCannotBiasDisplay() {
        var display = DisplayedPace()
        for t in 0...12 { display.update(frame(Double(t), 2)) }
        for _ in 0..<100 {
            display.update(frame(12, 6))
            display.update(frame(11, 6))
        }
        XCTAssertEqual(display.speed, 2)
        display.update(frame(13, 2))
        XCTAssertEqual(display.speed, 2)
    }
    func testSustainedSpeedChangeConvergesWithoutPermanentLag() {
        var display = DisplayedPace()
        for t in 0...15 { display.update(frame(Double(t), 2)) }
        var previous = display.speed ?? 0
        for t in 16...60 {
            display.update(frame(Double(t), 3.5))
            let current = display.speed ?? 0
            XCTAssertLessThanOrEqual(abs(current - previous), 0.150001)
            previous = current
        }
        XCTAssertEqual(display.speed ?? 0, 3.5, accuracy: 0.001)
    }
    func testCallbackFrequencyDoesNotWeightRecentSpeedMoreHeavily() {
        var regular = DisplayedPace(), frequent = DisplayedPace()
        for t in 0...20 { regular.update(frame(Double(t), t <= 10 ? 2 : 3)) }
        for step in 0...200 {
            let velocity = step <= 100 ? 2.0 : 3.0
            frequent.update(SensorFrame(timestamp: Double(step) / 10, speed: velocity,
                                        distance: velocity / 10, movement: .running, signal: .good))
        }
        XCTAssertEqual(regular.speed ?? 0, frequent.speed ?? 0, accuracy: 0.001)
    }

    func testSteadyWalkWithOscillatingGPSVelocityKeepsReadablePace() {
        var display = DisplayedPace()
        var paces: [Double] = []
        for second in 0...180 {
            // A fix every six seconds reports the same distance traveled, while
            // CLLocation.speed swings between 8 and 20 minutes per kilometer.
            let distance = second > 0 && second.isMultiple(of: 6) ? 8.4 : 0
            let velocity = (second / 24).isMultiple(of: 2) ? 2.08 : 0.83
            display.update(SensorFrame(timestamp: Double(second), speed: velocity,
                                       distance: distance, movement: .walking, signal: .good,
                                       distanceDuration: distance > 0 ? 6 : nil))
            if second >= 60, let speed = display.speed { paces.append(1000 / speed) }
        }
        XCTAssertGreaterThan(paces.count, 100)
        XCTAssertLessThan((paces.max() ?? 0) - (paces.min() ?? 0), 90,
                          "steady 1.4 m/s distance must not display 8–20 min/km swings")
        XCTAssertEqual((paces.last ?? 0) / 60, 11.9, accuracy: 0.75)
    }
}
