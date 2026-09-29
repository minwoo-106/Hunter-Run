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
    /// The shorter of the requested goal and the saved daily allowance. Pauses do not spend it.
    var activeTimeLimit: Double? {
        let target = activityGoal.kind == .time ? activityGoal.value : nil
        guard activityEnvironment.isIndoor else { return target }
        let maximum = min(IndoorDailyLimit.seconds, max(0, indoorAllowance ?? IndoorDailyLimit.seconds))
        return min(target ?? maximum, maximum)
    }
    var goalLabel: String {
        if isIndoor {
            let duration = Int(ceil(activeTimeLimit ?? IndoorDailyLimit.seconds))
            let limit = "\(duration / 60)분 \(duration % 60)초"
            return activityGoal.kind == .free ? "자유 · 남은 한도 " + limit : "목표 · " + limit
        }
        return activityGoal.label
    }
    var reachedGoal: Bool {
        if let limit = activeTimeLimit {
            return activityEnvironment.isIndoor ? activeSeconds >= limit : (workoutSeconds ?? activeSeconds) >= limit
        }
        switch activityGoal.kind {
        case .time: return activeSeconds >= activityGoal.value
        case .distance: return distance >= activityGoal.value
        case .free: return false
        }
    }
    var goalProgress: Double {
        if let limit = activeTimeLimit {
            return min(1, (activityEnvironment.isIndoor ? activeSeconds : workoutSeconds ?? activeSeconds) / max(1, limit))
        }
        switch activityGoal.kind {
        case .time: return min(1, activeSeconds / max(1, activityGoal.value))
        case .distance: return min(1, distance / max(1, activityGoal.value))
        case .free: return 0
        }
    }
    // Distance/free sessions schedule recurring patrols by active time, never speed.
    var patrolDuration: Double { activityGoal.kind == .time ? (activeTimeLimit ?? activityGoal.value) : 1200 }
    var patrolCycle: Int { activityGoal.kind == .time ? 0 : Int(activeSeconds / patrolDuration) }
}

public extension EventRecord {
    var catalogID: String { id.components(separatedBy: "#").first ?? id }
}
