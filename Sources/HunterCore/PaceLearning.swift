import Foundation

/// Fixed-size, time-weighted histogram. No route coordinates or raw sample stream.
public struct PaceObservation: Codable {
    public var bins = Array(repeating: 0.0, count: 51)
    public var goodSeconds = 0.0
    public var uncertainSeconds = 0.0
    public init() {}
    public var stableSeconds: Double { bins.reduce(0, +) }
    public var median: Double? {
        guard stableSeconds > 0 else { return nil }
        var cumulative = 0.0
        for (index, weight) in bins.enumerated() {
            cumulative += weight
            if cumulative >= stableSeconds / 2 { return 1 + Double(index) / 10 }
        }
        return nil
    }
    public mutating func observe(speed: Double, seconds: Double, goodSignal: Bool, eligible: Bool) {
        guard seconds.isFinite, seconds > 0, seconds <= 5 else { return }
        if goodSignal { goodSeconds += seconds } else { uncertainSeconds += seconds }
        guard eligible, goodSignal, speed.isFinite, (1...6).contains(speed) else { return }
        let weight = min(seconds, max(0, 1800 - stableSeconds))
        bins[Int(((speed - 1) * 10).rounded())] += weight
    }
    public var isValid: Bool {
        bins.count == 51 && bins.allSatisfy { $0.isFinite && $0 >= 0 } && stableSeconds <= 1800.001
            && goodSeconds.isFinite && (0...1_000_000_000).contains(goodSeconds) && uncertainSeconds.isFinite && (0...1_000_000_000).contains(uncertainSeconds)
            && stableSeconds <= goodSeconds + 0.001
    }
}
public struct PaceMemory: Codable {
    public var recent: [Double] = []
    public var reference: Double?
    public init() {}
    public var isValid: Bool {
        recent.count <= 5 && recent.allSatisfy(PaceLearning.validSpeed)
            && (reference.map(PaceLearning.validSpeed) ?? recent.isEmpty)
            && (recent.isEmpty == (reference == nil))
    }
    public mutating func include(_ speed: Double) {
        guard PaceLearning.validSpeed(speed) else { return }
        recent.append(speed); recent = Array(recent.suffix(5))
        let sorted = recent.sorted(); let middle = sorted[(sorted.count - 1) / 2]
        reference = reference.map { min($0 * 1.05, max($0 * 0.95, middle)) } ?? middle
    }
}
public struct PaceReport: Codable {
    public var stableSeconds: Double
    public var medianSpeed: Double?
    public var goodSignalFraction: Double
    public var referenceUsed: Double?
    public var referenceAfter: Double?
    public var learned: Bool
    public var isValid: Bool {
        stableSeconds.isFinite && (0...1800.001).contains(stableSeconds)
            && goodSignalFraction.isFinite && (0...1).contains(goodSignalFraction)
            && [medianSpeed, referenceUsed, referenceAfter].allSatisfy { $0.map(PaceLearning.validSpeed) ?? true }
            && (!learned || (stableSeconds >= 300 && medianSpeed != nil && referenceAfter != nil))
    }
}
public enum PaceLearning {
    public static func validSpeed(_ value: Double) -> Bool { value.isFinite && (1...6).contains(value) }
    public static func report(_ session: RunSession, memory: PaceMemory?) -> PaceReport? {
        guard let sample = session.paceObservation, sample.isValid else { return nil }
        return PaceReport(stableSeconds: sample.stableSeconds, medianSpeed: sample.median,
            goodSignalFraction: sample.goodSeconds / max(1, sample.goodSeconds + sample.uncertainSeconds),
            referenceUsed: session.learnedReference, referenceAfter: memory?.reference,
            learned: session.phase == .finished && !session.simulated && sample.stableSeconds >= 300 && memory?.reference != nil)
    }
    /// Settlement owns the run-ID idempotence guard.
    public static func settle(_ session: RunSession, profile: inout Profile) -> PaceReport? {
        guard session.phase == .finished, !session.simulated, !session.isIndoor else { return nil }
        if let sample = session.paceObservation, sample.isValid, sample.stableSeconds >= 300, let speed = sample.median {
            var memory = profile.paceMemory ?? PaceMemory(); memory.include(speed); profile.paceMemory = memory
        }
        return report(session, memory: profile.paceMemory)
    }
    public static func effectiveBaseline(current: Double, learned: Double?, fallback: Double) -> Double {
        let today = validSpeed(current) ? current : min(6, max(1, fallback.isFinite ? fallback : 1))
        return learned.flatMap { validSpeed($0) ? min(today, $0) : nil } ?? today
    }
}

public extension RunMode {
    func activityTitle(boss: Bool = false) -> String {
        switch self { case .exploration: return "현장 탐험"; case .contract: return "현장 사냥"; case .gate: return boss ? "보스 토벌" : "게이트 조사" }
    }
    func startTitle(boss: Bool = false) -> String { activityTitle(boss: boss) + " 시작" }
}
