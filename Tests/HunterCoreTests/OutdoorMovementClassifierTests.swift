import XCTest
@testable import HunterCore

final class OutdoorMovementClassifierTests: XCTestCase {
    func testMotionWalkingIsNotOverriddenByNoisyGPSRunningSpeed() {
        XCTAssertEqual(OutdoorMovementClassifier.classify(motion: .walking, rawSpeed: 2.1,
            speed: 1.4, credibleRunning: true, hasRecentFix: true, hasRecentSteps: true), .walking)
    }

    func testExplicitRunningAndMotionFallbackRemainUsable() {
        XCTAssertEqual(OutdoorMovementClassifier.classify(motion: .running, rawSpeed: 2.3,
            speed: 2.3, credibleRunning: true, hasRecentFix: true, hasRecentSteps: true), .running)
        XCTAssertEqual(OutdoorMovementClassifier.classify(motion: nil, rawSpeed: 2.3,
            speed: 2.3, credibleRunning: true, hasRecentFix: true, hasRecentSteps: false), .running)
    }

    func testSlowPositionOrVehicleCannotCreateRunning() {
        XCTAssertEqual(OutdoorMovementClassifier.classify(motion: .walking, rawSpeed: 0.2,
            speed: 0.2, credibleRunning: false, hasRecentFix: true, hasRecentSteps: true), .stationary)
        XCTAssertEqual(OutdoorMovementClassifier.classify(motion: .vehicle, rawSpeed: 3,
            speed: 3, credibleRunning: true, hasRecentFix: true, hasRecentSteps: false), .vehicle)
    }
}
