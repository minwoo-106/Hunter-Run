import Foundation

public struct ActivityDay: Identifiable {
    public var id: Date { date }
    public let date: Date
    public var distance: Double = 0
    public var seconds: Double = 0
    public var indoorSeconds: Double = 0
}
public struct ActivityInsights {
    public let days: [ActivityDay]
    public let outdoorDistance: Double
    public let outdoorSeconds: Double
    public let indoorSeconds: Double
    public let previousDistance: Double
    public let activityCount: Int
    public let activeDays: Int
    public let runningSeconds: Double
    public let movementSeconds: Double
    public let gpsFraction: Double?
    public let experience: Int
    public let defeats: Int
    public var averagePaceSeconds: Double? { outdoorDistance >= 100 ? outdoorSeconds / outdoorDistance * 1000 : nil }
    public init(profile: Profile, now: Date = Date(), calendar: Calendar = .current) {
        let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))!
        let start = calendar.date(byAdding: .day, value: -7, to: end)!
        let previous = calendar.date(byAdding: .day, value: -7, to: start)!
        let runs = profile.runs.filter { $0.date >= start && $0.date < end && $0.date <= now }
        let outside = runs.filter { !$0.activityEnvironment.isIndoor }
        let defense = (profile.defense?.records ?? []).filter { $0.date >= start && $0.date < end && $0.date <= now }
        outdoorDistance = outside.reduce(0) { $0 + $1.distance }
        outdoorSeconds = outside.reduce(0) { $0 + ($1.elapsedSeconds ?? $1.seconds) }
        indoorSeconds = runs.filter { $0.activityEnvironment.isIndoor }.reduce(0) { $0 + $1.seconds } + defense.reduce(0) { $0 + $1.seconds }
        previousDistance = profile.runs.filter { !$0.activityEnvironment.isIndoor && $0.date >= previous && $0.date < start }.reduce(0) { $0 + $1.distance }
        runningSeconds = outside.reduce(0) { $0 + ($1.runningSeconds ?? 0) }
        movementSeconds = outside.reduce(0) { $0 + $1.seconds }
        let measured = outside.filter { $0.paceReport != nil && $0.seconds > 0 }
        let weight = measured.reduce(0) { $0 + $1.seconds }
        gpsFraction = weight > 0 ? measured.reduce(0) { $0 + ($1.paceReport?.goodSignalFraction ?? 0) * $1.seconds } / weight : nil
        activityCount = runs.count + defense.count
        experience = runs.reduce(0) { $0 + $1.xp }
        defeats = runs.reduce(0) { $0 + $1.records.filter { $0.defeated == true && $0.outcome != .neutral }.count }
        var values: [ActivityDay] = []
        for index in 0..<7 {
            let date = calendar.date(byAdding: .day, value: index, to: start)!
            let daily = runs.filter { calendar.isDate($0.date, inSameDayAs: date) }
            var day = ActivityDay(date: date)
            day.distance = daily.filter { !$0.activityEnvironment.isIndoor }.reduce(0) { $0 + $1.distance }
            day.seconds = daily.filter { !$0.activityEnvironment.isIndoor }.reduce(0) { $0 + $1.seconds }
            day.indoorSeconds = daily.filter { $0.activityEnvironment.isIndoor }.reduce(0) { $0 + $1.seconds }
                + defense.filter { calendar.isDate($0.date, inSameDayAs: date) }.reduce(0) { $0 + $1.seconds }
            values.append(day)
        }
        days = values; activeDays = values.filter { $0.seconds > 0 || $0.indoorSeconds > 0 }.count
    }
}
