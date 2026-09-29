import Foundation

/// Reproducible timing variation: recovery never rerolls an in-flight patrol.
public enum RunDirector {
    public static func events(_ content: GameContent, session: RunSession, cycle: Int) -> [MissionTemplate] {
        content.events.compactMap { template -> MissionTemplate? in
            if cycle > 0 && template.id == GateTracking.eventID { return nil }
            var event = template
            if session.directorVersion == 2, template.id != session.priorityEncounterID,
               let pool = content.encounterPools?.first(where: { $0.slotID == template.id }) {
                let key = session.id.uuidString + ":" + template.id
                let hash = key.utf8.reduce(UInt64(14695981039346656037)) { ($0 ^ UInt64($1)) &* 1099511628211 }
                let options = [template] + pool.alternatives
                event = options[(Int(hash % UInt64(options.count)) + cycle) % options.count]
                event.startFraction = template.startFraction
            }
            if session.directorVersion == 1 || session.directorVersion == 2 {
                let key = session.id.uuidString + ":\(cycle):" + template.id
                let hash = key.utf8.reduce(UInt64(14695981039346656037)) { ($0 ^ UInt64($1)) &* 1099511628211 }
                let shift = (Double(hash % 1001) / 1000 - 0.5) * 0.03
                event.startFraction = min(0.86, max(0.12, template.startFraction + shift))
            }
            let short = session.activityGoal.kind == .time && session.activityGoal.value < 1200
                || session.activityGoal.kind == .distance && session.activityGoal.value <= 1000
            if event.kind == .endurance && short {
                event.kind = .maintain; event.duration = 30; event.targetDistance = nil
                event.audio = event.shortAudio ?? "maintain"
            }
            if cycle > 0 { event.id += "#\(cycle)" }
            return event
        }.sorted { $0.startFraction < $1.startFraction }
    }
}
