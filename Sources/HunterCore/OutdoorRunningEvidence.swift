import Foundation

/// Requires several distinct good GPS fixes before overriding a stale Core Motion
/// walking verdict. A single fast or replayed location can never start combat.
public struct OutdoorRunningEvidence {
    private var lastFixAt: TimeInterval?
    private var consecutiveSeconds: TimeInterval = 0

    public init() {}

    public mutating func reset() {
        lastFixAt = nil
        consecutiveSeconds = 0
    }

    public mutating func observe(time: TimeInterval, speed: Double, speedAccuracy: Double,
                                 horizontalAccuracy: Double, precise: Bool) {
        guard time.isFinite, lastFixAt.map({ time > $0 }) ?? true else { return }
        let credible = precise && horizontalAccuracy.isFinite && horizontalAccuracy >= 0 && horizontalAccuracy <= 35
            && speed >= 2.1 && OutdoorSignalQuality.credibleRunningSpeed(speed, accuracy: speedAccuracy)
        guard credible else { reset(); return }
        if let lastFixAt, time - lastFixAt <= 3 {
            consecutiveSeconds += time - lastFixAt
        } else {
            consecutiveSeconds = 0
        }
        lastFixAt = time
    }

    public func confirmed(at time: TimeInterval) -> Bool {
        consecutiveSeconds >= 6 && lastFixAt.map { (0...3).contains(time - $0) } == true
    }
}
