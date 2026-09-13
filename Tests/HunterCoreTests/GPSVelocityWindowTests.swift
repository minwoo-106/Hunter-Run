import XCTest
@testable import HunterCore

final class GPSVelocityWindowTests: XCTestCase {
    func testUncertainWalkingVelocityCannotAppearAsPrecisePace() {
        var window = GPSVelocityWindow()
        for t in 0...12 { window.observe(time: Double(t), speed: t < 6 ? 0.7 : 2.3, accuracy: 1.4) }
        XCTAssertNil(window.speed(at: 12))
    }
    func testFreshBadFixCannotKeepOldVelocityAlive() {
        var window = GPSVelocityWindow()
        window.observe(time: 0, speed: 3, accuracy: 0.1)
        window.observe(time: 5, speed: 1.2, accuracy: 3)
        XCTAssertNil(window.speed(at: 5))
    }
    func testDuplicateReplayAndFutureQueriesDoNotBiasMedian() {
        var window = GPSVelocityWindow()
        for t in 0...6 { window.observe(time: Double(t), speed: 1.2, accuracy: 0.1) }
        for _ in 0..<20 { window.observe(time: 6, speed: 4, accuracy: 0.1) }
        window.observe(time: 2, speed: 5, accuracy: 0.1)
        XCTAssertEqual(window.speed(at: 6) ?? 0, 1.2, accuracy: 0.001)
        XCTAssertNil(window.speed(at: -1))
    }
    func testGoodWalkingAndRealAccelerationRemainAvailable() {
        var window = GPSVelocityWindow()
        for t in 0...10 { window.observe(time: Double(t), speed: 1.2, accuracy: 0.1) }
        XCTAssertEqual(window.speed(at: 10) ?? 0, 1.2, accuracy: 0.001)
        for t in 11...18 { window.observe(time: Double(t), speed: 3, accuracy: 0.15) }
        XCTAssertEqual(window.speed(at: 18) ?? 0, 3, accuracy: 0.001)
        window.reset(); XCTAssertNil(window.speed(at: 18))
    }
}
