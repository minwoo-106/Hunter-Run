import Foundation

/// Validates successive Core Location segments before they are added to an
/// outdoor activity. Coordinates stay in the app layer; this type keeps the
/// timing and plausibility rules deterministic and testable.
public struct OutdoorDistanceAccumulator {
    public static let maximumSegmentDuration: TimeInterval = 30
    private var previousTimestamp: TimeInterval?
    private var previousAccuracy: Double?
    public private(set) var lastAcceptedDuration: TimeInterval = 0

    public init() {}

    public mutating func reset() {
        previousTimestamp = nil
        previousAccuracy = nil
        lastAcceptedDuration = 0
    }

    public mutating func observe(
        timestamp: TimeInterval,
        horizontalAccuracy: Double,
        distanceFromPrevious: Double?
    ) -> Double {
        lastAcceptedDuration = 0
        guard timestamp.isFinite, horizontalAccuracy.isFinite, horizontalAccuracy >= 0 else { return 0 }
        guard let previousTimestamp, let previousAccuracy else {
            self.previousTimestamp = timestamp
            self.previousAccuracy = horizontalAccuracy
            return 0
        }
        guard timestamp > previousTimestamp else { return 0 }
        defer {
            self.previousTimestamp = timestamp
            self.previousAccuracy = horizontalAccuracy
        }
        guard let distanceFromPrevious, distanceFromPrevious.isFinite else { return 0 }
        let elapsed = timestamp - previousTimestamp
        guard elapsed <= Self.maximumSegmentDuration,
              horizontalAccuracy <= 60, previousAccuracy <= 60,
              distanceFromPrevious >= 0, distanceFromPrevious <= 8 * elapsed else { return 0 }
        lastAcceptedDuration = elapsed
        return distanceFromPrevious
    }
}
