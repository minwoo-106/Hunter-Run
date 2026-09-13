import Foundation

/// KST calendar days, independent of the device's selected time zone.
/// Completed records are the source of truth; a session snapshots its remaining allowance.
public enum IndoorDailyLimit {
    public static let seconds: Double = 3600
    private static var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(secondsFromGMT: 9 * 3600)!
        return value
    }
    public static func start(of date: Date) -> Date { calendar.startOfDay(for: date) }
    public static func end(of date: Date) -> Date { start(of: date).addingTimeInterval(86400) }
    public static func used(in profile: Profile, on date: Date, excluding id: UUID? = nil) -> Double {
        let lower = start(of: date), upper = end(of: date)
        var total: Double = 0
        var counted: Set<UUID> = []
        for run in profile.runs where run.id != id && run.activityEnvironment.isIndoor && run.date >= lower && run.date < upper {
            guard run.seconds.isFinite, run.seconds > 0, counted.insert(run.id).inserted else { continue }
            total += min(seconds, run.seconds)
            if total >= seconds { return seconds }
        }
        return total
    }
    public static func remaining(in profile: Profile, on date: Date, excluding id: UUID? = nil) -> Double {
        max(0, seconds - used(in: profile, on: date, excluding: id))
    }
    public static func prepare(_ session: inout RunSession, profile: Profile) {
        guard session.isIndoor else { return }
        let remaining = remaining(in: profile, on: session.startedAt, excluding: session.id)
        session.indoorAllowance = min(session.indoorAllowance ?? seconds, remaining)
    }
}
