import Foundation

/// Value-only seam for Core Location velocity quality. Coordinates are not retained.
public struct GPSVelocityWindow {
    private var samples: [(time: Double, speed: Double)] = []
    private var latestTime: Double?
    public init() {}
    public mutating func reset() { samples = []; latestTime = nil }
    public mutating func observe(time: Double, speed: Double, accuracy: Double) {
        guard time.isFinite, latestTime.map({ time > $0 }) ?? true else { return }
        latestTime = time
        if let last = samples.last, time - last.time > 3 { samples = [] }
        // At walking speeds a 1.5 m/s error is larger than the measurement itself.
        // Hide uncertain pace rather than presenting a precise-looking number.
        let permittedError = min(0.75, max(0.25, speed * 0.25))
        if speed.isFinite && accuracy.isFinite && speed >= 0 && speed <= 8 && accuracy >= 0 && accuracy <= permittedError {
            samples.append((time, speed))
        }
        samples.removeAll { time - $0.time > 7 }
    }
    public func speed(at time: Double) -> Double? {
        guard time.isFinite, let last = samples.last, (0...3).contains(time - last.time) else { return nil }
        let fresh = samples.filter { (0...7).contains(time - $0.time) }.map { $0.speed }.sorted()
        return fresh.isEmpty ? nil : fresh[fresh.count / 2]
    }
}
