import Foundation

/// Shared opt-in and recovery budget for pursuits and boss barrier attacks.
public enum AccelerationRules {
    public static let duration: Double = 10
    public static let cooldown: Double = 180
    public static func canOffer(_ run: RunSession, frame: SensorFrame) -> Bool {
        run.allowPursuit && run.baselineSamples.count >= 30
            && (run.simulated || run.learnedReference != nil || (run.paceObservation?.stableSeconds ?? 0) >= 300)
            && run.intensityCount < 2 && run.activeSeconds - run.lastIntensityAt >= cooldown
            && frame.signal == .good && frame.movement == .running
            && !run.withdrawn && run.hp > 0 && run.activeSeconds >= run.recoveryUntil
    }
    public static func isRecovering(_ run: RunSession) -> Bool {
        run.intensityCount > 0 && run.event?.burstStarted != true && run.activeSeconds - run.lastIntensityAt < cooldown
    }
    public static func needsEasyMovement(_ run: RunSession) -> Bool {
        run.intensityCount > 0 && run.activeSeconds - run.lastIntensityAt < 60
    }
}
