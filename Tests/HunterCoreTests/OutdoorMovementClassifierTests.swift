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

    func testSustainedAccurateRunningOverridesStaleWalkingVerdict() {
        var evidence = OutdoorRunningEvidence()
        evidence.observe(time: 0, speed: 2.3, speedAccuracy: 0.2, horizontalAccuracy: 8, precise: true)
        XCTAssertFalse(evidence.confirmed(at: 0))
        for second in 1...6 {
            evidence.observe(time: Double(second), speed: 2.3, speedAccuracy: 0.2, horizontalAccuracy: 8, precise: true)
        }
        XCTAssertTrue(evidence.confirmed(at: 6))
        XCTAssertEqual(OutdoorMovementClassifier.classify(motion: .walking, rawSpeed: 2.3,
            speed: 2.3, credibleRunning: true, hasRecentFix: true, hasRecentSteps: true,
            sustainedRunning: evidence.confirmed(at: 6)), .running)
        evidence.observe(time: 7, speed: 2.3, speedAccuracy: 3, horizontalAccuracy: 8, precise: true)
        XCTAssertFalse(evidence.confirmed(at: 7))
        XCTAssertEqual(OutdoorMovementClassifier.classify(motion: .walking, rawSpeed: 2.3,
            speed: 2.3, credibleRunning: false, hasRecentFix: true, hasRecentSteps: true,
            sustainedRunning: evidence.confirmed(at: 7)), .walking)
    }
}
