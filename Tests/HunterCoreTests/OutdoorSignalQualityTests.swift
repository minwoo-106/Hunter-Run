import XCTest
@testable import HunterCore

final class OutdoorSignalQualityTests: XCTestCase {
    func testPrecisePositionStaysGoodWhenVelocityCannotProducePace() {
        var velocity = GPSVelocityWindow()
        velocity.observe(time: 10, speed: 2.4, accuracy: 1.0)
        XCTAssertNil(velocity.speed(at: 10))
        XCTAssertEqual(OutdoorSignalQuality.classify(fixAge: 1, horizontalAccuracy: 12, precise: true), .good)
        XCTAssertTrue(OutdoorSignalQuality.credibleRunningSpeed(2.4, accuracy: 1.0))
    }

    func testReducedAccuracyAndStalePositionCannotQualifyCombat() {
        XCTAssertEqual(OutdoorSignalQuality.classify(fixAge: 1, horizontalAccuracy: 12, precise: false), .degraded)
        XCTAssertEqual(OutdoorSignalQuality.classify(fixAge: 1, horizontalAccuracy: 45, precise: true), .degraded)
        XCTAssertEqual(OutdoorSignalQuality.classify(fixAge: 6, horizontalAccuracy: 12, precise: true), .unavailable)
        XCTAssertFalse(OutdoorSignalQuality.credibleRunningSpeed(2.4, accuracy: 2.0))
        XCTAssertFalse(OutdoorSignalQuality.credibleRunningSpeed(1.2, accuracy: 0.1))
    }
}
