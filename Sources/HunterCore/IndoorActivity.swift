import Foundation

public enum ActivityEnvironment: String, Codable, CaseIterable {
    case outdoor, indoor, indoorStationary, indoorTreadmill
    // Legacy raw values remain readable, but only the unified choice is offered.
    public static var allCases: [Self] { [.outdoor, .indoor] }
    public var isIndoor: Bool { self != .outdoor }
    public var rewardPercent: Int { isIndoor ? 50 : 100 }
    public var maximumActiveSeconds: Double? { isIndoor ? IndoorDailyLimit.seconds : nil }
    public var title: String {
        isIndoor ? "실내 러닝" : "야외"
    }
}

/// Evidence expires independently of the UI timer. Never manufactures distance or steps.
/// Rhythmic device motion supports hand-held exercise when the pedometer reports late.
public struct IndoorMovementTracker {
    private var peaks: [Double] = []
    private var above = false
    private var lastSample: Double?
    private var stepAt: Double?
    private var stepCadence: Double = 0
    public init() {}
    public mutating func reset() { self = Self() }
    public mutating func observeSteps(count: Int, elapsed: Double, at time: Double) {
        guard count >= 2, elapsed > 0, elapsed <= 10, time.isFinite else { return }
        let cadence = Double(count) / elapsed
        guard (0.5...4).contains(cadence) else { return }
        stepAt = time; stepCadence = cadence
    }
    public mutating func observeAcceleration(_ magnitude: Double, at time: Double) {
        guard time.isFinite, magnitude.isFinite, magnitude >= 0 else { return }
        if let previous = lastSample, time <= previous { return }
        if let previous = lastSample, time - previous > 0.5 { peaks = []; above = false }
        lastSample = time
        peaks.removeAll { time - $0 > 6 }
        if magnitude < 0.055 { above = false }
        if magnitude >= 0.13 && !above {
            above = true
            if peaks.last.map({ time - $0 >= 0.27 }) ?? true { peaks.append(time) }
        }
    }
    public func isMoving(at time: Double) -> Bool {
        if let stepAt, (0...3).contains(time - stepAt), stepCadence >= 0.5 { return true }
        guard let lastSample, (0...0.5).contains(time - lastSample), let last = peaks.last,
              (0...1.5).contains(time - last), peaks.count >= 5 else { return false }
        let recent = Array(peaks.suffix(5))
        let intervals = zip(recent.dropFirst(), recent).map(-)
        let mean = intervals.reduce(0, +) / Double(intervals.count)
        guard (0.27...1.5).contains(mean) else { return false }
        let deviation = intervals.map { abs($0 - mean) }.reduce(0, +) / Double(intervals.count)
        return deviation / mean < 0.35
    }
}

public extension RunSession {
    var activityEnvironment: ActivityEnvironment { environment ?? .outdoor }
    var isIndoor: Bool { activityEnvironment.isIndoor }
}
public extension RunSummary {
    var activityEnvironment: ActivityEnvironment { environment ?? .outdoor }
    var activityMeasure: String {
        activityEnvironment.isIndoor ? "\(steps ?? 0)걸음 · 실내" : String(format: "%.2f km", distance / 1000)
    }
}

public enum IndoorRules {
    public static func event(_ source: MissionTemplate) -> MissionTemplate {
        var event = source
        event.burstSeconds = nil; event.targetDistance = nil
        if event.kind == .endurance || event.kind == .pursuit { event.kind = .maintain }
        event.duration = event.kind == .discovery ? min(45, event.duration) : 30
        // Existing approved recordings, without outdoor distance / acceleration instructions.
        event.audio = event.kind == .discovery ? "investigate" : "indoor_hold"
        return event
    }
}
