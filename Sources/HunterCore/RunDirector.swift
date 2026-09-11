import Foundation

/// Reproducible timing variation: recovery never rerolls an in-flight patrol.
public enum RunDirector {
    public static func events(_ content: GameContent, session: RunSession, cycle: Int) -> [MissionTemplate] {
        content.events.map { template in
            var event = template
            if session.directorVersion == 1 {
                let key = session.id.uuidString + ":\(cycle):" + template.id
                let hash = key.utf8.reduce(UInt64(14695981039346656037)) { ($0 ^ UInt64($1)) &* 1099511628211 }
                let shift = (Double(hash % 1001) / 1000 - 0.5) * 0.03
                event.startFraction = min(0.86, max(0.12, template.startFraction + shift))
            }
            let short = session.activityGoal.kind == .time && session.activityGoal.value < 1200
                || session.activityGoal.kind == .distance && session.activityGoal.value <= 1000
            if event.kind == .endurance && short {
                event.kind = .maintain; event.duration = 30; event.targetDistance = nil
                event.title = "전방 개체 견제"; event.audio = "maintain"
            }
            if cycle > 0 { event.id += "#\(cycle)" }
            return event
        }.sorted { $0.startFraction < $1.startFraction }
    }
}
