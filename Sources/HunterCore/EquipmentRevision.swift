import Foundation

/// 보유 방어구는 과거 기록용으로 남기고, 단종 보상은 세이브마다 한 번만 지급한다.
public struct EquipmentRevisionState: Codable, Equatable {
    public var version = 1
    public var retiredIDs: [String]
    public var crystals: Int
    public var research: Int
    public var cores: Int
    public var acknowledged = false
    public var isValid: Bool {
        version == 1 && retiredIDs.count <= 100 && Set(retiredIDs).count == retiredIDs.count
        && retiredIDs.allSatisfy { !$0.isEmpty && $0.count <= 200 }
        && (0...100_000_000).contains(crystals) && (0...100_000_000).contains(research)
        && (0...1_000_000).contains(cores)
    }
}

public enum EquipmentRevision {
    @discardableResult public static func migrate(_ save: inout SaveState, catalog: ProgressionCatalog) throws -> Bool {
        guard save.active == nil, save.profile.defense?.active == nil, save.profile.equipmentRevision == nil else { return false }
        try catalog.validate()
        var candidate = save
        let retired = catalog.equipment.filter { $0.slot == .armor && candidate.profile.growth.owned.contains($0.id) }
        let crystals = retired.reduce(0) { $0 + $1.crystals }
        let research = retired.reduce(0) { $0 + $1.research }
        let cores = retired.reduce(0) { $0 + $1.cores }
        // 저장 상한을 초과하면 일부 보상을 버리는 대신 원본을 보존한다.
        guard candidate.profile.crystals <= 100_000_000 - crystals,
              candidate.profile.research <= 100_000_000 - research,
              candidate.profile.growth.cores <= 1_000_000 - cores else { throw ProgressionError.invalid }
        candidate.profile.crystals += crystals; candidate.profile.research += research
        candidate.profile.growth.cores += cores
        candidate.profile.growth.equipped.removeValue(forKey: EquipmentSlot.armor.rawValue)
        if let target = candidate.profile.equipmentJournal?.targetID,
           catalog.equipment.contains(where: { $0.id == target && $0.slot == .armor }) {
            candidate.profile.equipmentJournal?.targetID = nil
        }
        candidate.profile.equipmentRevision = EquipmentRevisionState(retiredIDs: retired.map(\.id).sorted(),
            crystals: crystals, research: research, cores: cores)
        save = candidate
        return true
    }
}

public extension RunSession {
    var usesThreeSlotEquipment: Bool { loadout?.equipmentRevision == 1 }
    /// 이전 활동 복구 때만 종전 플레이어 HP 규칙을 유지한다.
    var legacyHealthBlocked: Bool { !usesThreeSlotEquipment && (hp <= 0 || activeSeconds < recoveryUntil) }
    var legacyWithdrawn: Bool { !usesThreeSlotEquipment && withdrawn }
}

public enum EncounterTiming {
    /// 첫 사건과 보스는 원래 시각 유지. 일반 사건 대기만 최대 30초 단축한다.
    public static func scheduledAt(_ event: MissionTemplate, session: RunSession, cycle: Int) -> Double {
        let original = Double(cycle) * session.patrolDuration + session.patrolDuration * event.startFraction
        guard session.usesThreeSlotEquipment, !session.isIndoor, session.boss == nil,
              event.kind != .boss, event.id.components(separatedBy: "#").first != GateTracking.eventID,
              let ended = session.lastEncounterEndedAt else { return original }
        let haste = min(0.25, max(0, session.loadout?.encounterHaste ?? 0))
        let saving = min(30, max(0, original - ended) * haste)
        return min(original, max(ended + 30, original - saving))
    }
}
