import Foundation

public struct EncounterNarration: Codable {
    public var id: String
    public var eventIDs: [String]
    public var bossID: String?
    public var defeated: String
    public var hit: String
}

public struct NarrationCatalog: Codable {
    public var schema: Int
    public var encounters: [EncounterNarration]
    public func validate() throws {
        guard schema == 1, Set(encounters.map(\.id)).count == encounters.count,
              encounters.allSatisfy({ !$0.id.isEmpty && !$0.eventIDs.isEmpty && !$0.defeated.isEmpty && !$0.hit.isEmpty }) else { throw GameContent.ContentError.invalid }
    }
    public func response(to key: String, session: RunSession) -> String {
        guard key == "success" || key == "partial", let record = session.records.last else { return key }
        return result(record, bossID: session.boss?.definition.id, recovering: !session.usesThreeSlotEquipment && session.hp <= 0)
    }
    public func result(_ record: EventRecord, bossID: String?, recovering: Bool = false) -> String {
        // A converted pursuit or boss is an investigation, even if its catalog ID is unchanged.
        if record.outcome == .neutral { return "partial" }
        if record.kind == .discovery { return "survey_done" }
        if recovering { return "recovery" }
        guard record.kind != nil else { return "partial" }
        let match = encounters.first { rule in
            rule.eventIDs.contains(record.catalogID) && (rule.bossID == nil || rule.bossID == bossID)
        }
        if record.defeated == true && record.damage > 0 { return match?.defeated ?? "combat_hit" }
        if record.accelerated == true {
            return record.outcome == .partial || record.outcome == .fail || record.damage <= 0 ? "burst_partial" : "burst_hit"
        }
        if record.outcome == .fail { return "combat_withdraw" }
        if record.outcome == .partial { return "partial" }
        if record.damage > 0 { return match?.hit ?? "combat_hit" }
        return "partial"
    }
}
