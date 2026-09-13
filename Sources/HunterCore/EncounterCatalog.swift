import Foundation

/// Alternatives are resolved before a run and saved with its mission snapshot.
public struct EncounterPool: Codable {
    public var slotID: String
    public var alternatives: [MissionTemplate]
}

public struct FieldEncounter: Codable, Identifiable {
    public var id: String
    public var monsterID: String
    public var name: String
    public var elite: Bool
    public var requiredRank: String
    public var requiredAction: String?
    public var unlockHint: String
    public var tactic: String
    public var slots: [String: String]
    public var event: MissionTemplate
    public var survey: MissionTemplate?
    public var requiredMain: String? = nil

    public func available(to profile: Profile, catalog: ProgressionCatalog) -> Bool {
        let rank = Progression.ranks.firstIndex(of: profile.growth.rank) ?? -1
        return rank >= (Progression.ranks.firstIndex(of: requiredRank) ?? Int.max)
            && (requiredAction.map { catalog.unlocked($0, profile: profile) } ?? true)
            && (requiredMain.map { profile.journey?.unlocked.contains($0) == true || FieldDiscovery.events(in: profile).contains(event.id) } ?? true)
    }

    public var preview: GameContent {
        var event = event; event.startFraction = 0.35
        return GameContent(schema: 1, missionTitle: name + " · 모의 조사", events: [event])
    }
}

public struct EncounterCatalog: Codable {
    public var schema: Int
    public var encounters: [FieldEncounter]
    public func validate() throws {
        guard schema == 1, !encounters.isEmpty, Set(encounters.map(\.id)).count == encounters.count,
              Set(encounters.map { $0.event.id }).count == encounters.count else { throw GameContent.ContentError.invalid }
        for entry in encounters {
            guard !entry.monsterID.isEmpty, !entry.slots.isEmpty,
                  Progression.ranks.contains(entry.requiredRank),
                  entry.slots.keys.allSatisfy({ RunMode(rawValue: $0) != nil }),
                  entry.survey == nil || entry.survey?.kind == .discovery else { throw GameContent.ContentError.invalid }
            try entry.preview.validate()
            if let survey = entry.survey { try GameContent(schema: 1, missionTitle: entry.name, events: [survey]).validate() }
        }
    }

    public func populate(_ content: GameContent, mode: RunMode, profile: Profile, catalog: ProgressionCatalog) -> GameContent {
        var result = content
        result.encounterPools = content.events.compactMap { slot in
            let alternatives = encounters.filter { $0.slots[mode.rawValue] == slot.id && $0.available(to: profile, catalog: catalog) }
                .compactMap { mode == .exploration ? $0.survey : $0.event }
            return alternatives.isEmpty ? nil : EncounterPool(slotID: slot.id, alternatives: alternatives)
        }
        return result
    }
}

public enum FieldDiscovery {
    public static func events(in profile: Profile) -> Set<String> {
        (profile.discoveredEvents ?? []).union(profile.runs.flatMap { $0.records.filter { $0.outcome != .neutral }.map(\.catalogID) })
    }
    static func record(_ session: RunSession, profile: inout Profile) {
        profile.discoveredEvents = events(in: profile).union(session.records.filter { $0.outcome != .neutral }.map(\.catalogID))
    }
}
