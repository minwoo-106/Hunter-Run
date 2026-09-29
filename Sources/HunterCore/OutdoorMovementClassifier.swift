import Foundation

/// Keeps a recent Core Motion walking classification from being promoted to
/// running by one noisy GPS velocity sample.
public enum OutdoorMovementClassifier {
    public static func classify(motion: Movement?, rawSpeed: Double, speed: Double,
                                credibleRunning: Bool, hasRecentFix: Bool, hasRecentSteps: Bool,
                                sustainedRunning: Bool = false) -> Movement {
        if motion == .vehicle || rawSpeed > 8 { return .vehicle }
        if motion == .stationary && rawSpeed < 0.8 { return .stationary }
        if rawSpeed >= 0 && rawSpeed < 0.35 { return .stationary }
        if speed >= 0.5 && (hasRecentFix || hasRecentSteps) {
            if motion == .walking { return sustainedRunning ? .running : .walking }
            if motion == .running || credibleRunning { return .running }
            return .walking
        }
        return hasRecentFix || motion != nil ? .stationary : .unknown
    }
}
