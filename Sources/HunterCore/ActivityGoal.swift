import Foundation

public enum GoalKind: String, Codable, CaseIterable {
    case time, distance, free
    public var title: String {
        switch self { case .time: return "시간"; case .distance: return "거리"; case .free: return "자유" }
    }
}

public struct ActivityGoal: Codable, Equatable {
    public var kind: GoalKind
    public var value: Double
    public init(kind: GoalKind, value: Double = 0) { self.kind = kind; self.value = value }
    public var isValid: Bool {
        guard value.isFinite else { return false }
        switch kind {
        case .time: return (60...21600).contains(value)
        case .distance: return (500...42195).contains(value)
        case .free: return value == 0
        }
    }
    public var label: String {
        switch kind {
        case .time: return "\(Int(value / 60))분"
        case .distance: return String(format: "%g km", value / 1000)
        case .free: return "자유 활동"
        }
    }
}

public extension RunSession {
    var activityGoal: ActivityGoal { goal ?? ActivityGoal(kind: .time, value: targetSeconds) }
    var reachedGoal: Bool {
        switch activityGoal.kind {
        case .time: return activeSeconds >= activityGoal.value
        case .distance: return distance >= activityGoal.value
        case .free: return false
        }
    }
    var goalProgress: Double {
        switch activityGoal.kind {
        case .time: return min(1, activeSeconds / max(1, activityGoal.value))
        case .distance: return min(1, distance / max(1, activityGoal.value))
        case .free: return 0
        }
    }
    // Distance/free sessions schedule recurring patrols by active time, never speed.
    var patrolDuration: Double { activityGoal.kind == .time ? activityGoal.value : 1200 }
    var patrolCycle: Int { activityGoal.kind == .time ? 0 : Int(activeSeconds / patrolDuration) }
}

public extension EventRecord {
    var catalogID: String { id.components(separatedBy: "#").first ?? id }
}
