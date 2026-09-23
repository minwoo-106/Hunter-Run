import XCTest
@testable import HunterCore

final class OutdoorDistanceAccumulatorTests: XCTestCase {
    func testNormalWalkingUpdatesSixSecondsApartRetainDistance() {
        var accumulator = OutdoorDistanceAccumulator()
        var distance = accumulator.observe(timestamp: 0, horizontalAccuracy: 10, distanceFromPrevious: nil)
        for sample in 1...560 {
            distance += accumulator.observe(
                timestamp: Double(sample * 6),
                horizontalAccuracy: 10,
                distanceFromPrevious: 8.1
            )
        }
        XCTAssertEqual(distance, 4_536, accuracy: 0.001,
                       "normal batched walking fixes must not collapse a multi-kilometer activity")
    }

    func testImplausibleJumpIsRejectedAndNextNormalSegmentRecovers() {
        var accumulator = OutdoorDistanceAccumulator()
        _ = accumulator.observe(timestamp: 0, horizontalAccuracy: 10, distanceFromPrevious: nil)
        XCTAssertEqual(accumulator.observe(timestamp: 6, horizontalAccuracy: 10, distanceFromPrevious: 500), 0)
        XCTAssertEqual(accumulator.observe(timestamp: 12, horizontalAccuracy: 10, distanceFromPrevious: 8.1), 8.1, accuracy: 0.001)
    }

    func testLongDeliveryGapIsNotInventedAndNextSegmentRecovers() {
        var accumulator = OutdoorDistanceAccumulator()
        _ = accumulator.observe(timestamp: 0, horizontalAccuracy: 10, distanceFromPrevious: nil)
        XCTAssertEqual(accumulator.observe(timestamp: 31, horizontalAccuracy: 10, distanceFromPrevious: 42), 0)
        XCTAssertEqual(accumulator.observe(timestamp: 37, horizontalAccuracy: 10, distanceFromPrevious: 8.1), 8.1, accuracy: 0.001)
    }
}
