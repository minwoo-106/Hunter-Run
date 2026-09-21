import Foundation

/// Position quality is separate from velocity quality: an uncertain pace must not
/// turn an otherwise precise, fresh location into a failed GPS signal.
public enum OutdoorSignalQuality {
    public static func classify(fixAge: TimeInterval?, horizontalAccuracy: Double?, precise: Bool) -> Signal {
        guard let fixAge, fixAge.isFinite, (0...5).contains(fixAge),
              let horizontalAccuracy, horizontalAccuracy.isFinite, horizontalAccuracy >= 0 else { return .unavailable }
        if precise && horizontalAccuracy <= 35 { return .good }
        return horizontalAccuracy <= 60 ? .degraded : .unavailable
    }

    public static func credibleRunningSpeed(_ speed: Double, accuracy: Double) -> Bool {
        speed.isFinite && accuracy.isFinite && (1.8...8).contains(speed)
            && accuracy >= 0 && accuracy <= min(1.5, speed * 0.5)
    }
}
