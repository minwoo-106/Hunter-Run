import Foundation

public struct EquipmentMemory: Codable {
    public var acquiredAt: Date?
    public var trackingSince: Date
    public var outdoorDistance: Double = 0
    public var activities: Int = 0
    public var firstBossName: String?
    public init(acquiredAt: Date? = nil, trackingSince: Date) {
        self.acquiredAt = acquiredAt; self.trackingSince = trackingSince
    }
}
public struct EquipmentPreset: Codable, Identifiable {
    public var id: Int
    public var name: String
    public var slots: [String: String]
    public init(id: Int, name: String, slots: [String: String]) {
        self.id = id; self.name = name; self.slots = slots
    }
}
public struct EquipmentJournal: Codable {
    public var targetID: String?
    public var presets: [EquipmentPreset] = []
    public var memories: [String: EquipmentMemory] = [:]
    public init() {}
    public var isValid: Bool {
        (targetID.map { !$0.isEmpty && $0.count <= 200 } ?? true)
        && presets.count <= 3 && Set(presets.map(\.id)).count == presets.count
        && presets.allSatisfy { (0..<3).contains($0.id) && !$0.name.isEmpty && $0.name.count <= 24
            && $0.slots.count <= 4 && $0.slots.allSatisfy { EquipmentSlot(rawValue: $0.key) != nil && !$0.value.isEmpty && $0.value.count <= 200 } }
        && memories.count <= 500 && memories.allSatisfy { !$0.key.isEmpty && $0.key.count <= 200
            && $0.value.outdoorDistance.isFinite && $0.value.outdoorDistance >= 0 && $0.value.activities >= 0
            && $0.value.trackingSince.timeIntervalSince1970.isFinite
            && ($0.value.acquiredAt?.timeIntervalSince1970.isFinite ?? true) }
    }
}
public struct UnlockNotice: Codable, Identifiable, Equatable {
    public var id: String
    public var title: String
    public var detail: String
    public init(id: String, title: String, detail: String) { self.id = id; self.title = title; self.detail = detail }
}
public struct ActivityGrowthReport: Codable {
    public var levelBefore: Int
    public var levelAfter: Int
    public var firstDefeats: [String]
    public var equipmentIDs: [String]
    public var targetID: String?
    public var targetBefore: [Int]
    public var targetAfter: [Int]
    public var unlocks: [UnlockNotice] = []
    public var isValid: Bool {
        levelBefore > 0 && levelAfter >= levelBefore && firstDefeats.count <= 1000 && equipmentIDs.count <= 4
        && targetBefore.count == 3 && targetAfter.count == 3
        && targetBefore.allSatisfy { $0 >= 0 } && targetAfter.allSatisfy { $0 >= 0 } && unlocks.count <= 500
    }
}
public struct GearRequirement: Identifiable {
    public var id: String
    public var title: String
    public var met: Bool
}
public struct CombatEstimate: Equatable {
    public let attack: Double
    public let damage: Double
    public let hits: Int
    public var distance: Double { Double(hits) * 75 }
    public init(stats: CombatStats, monster: CombatMonster) {
        attack = stats.attack
        damage = DistanceBattle.damagePerAttack(attack: stats.attack, defense: monster.defense)
        hits = damage > 0 ? Int(ceil(monster.maximumHP / damage)) : 0
    }
}
public enum EquipmentExperience {
    public static func preview(_ item: EquipmentDefinition, profile: Profile, catalog: ProgressionCatalog) -> CombatStats {
        var copy = profile
        copy.growth.owned.insert(item.id); copy.growth.equipped[item.slot.rawValue] = item.id
        return catalog.stats(for: copy)
    }
    public static func requirements(_ item: EquipmentDefinition, profile: Profile) -> [GearRequirement] {
        var result = [GearRequirement(id: "support", title: "장비지원부 Lv.\(item.supportLevel)", met: profile.growth.level(.equipment) >= item.supportLevel)]
        if let rank = item.requiredRank {
            result.append(GearRequirement(id: "rank", title: "\(rank)급 승급", met: (Progression.ranks.firstIndex(of: profile.growth.rank) ?? 0) >= (Progression.ranks.firstIndex(of: rank) ?? Int.max)))
        }
        if let event = item.requiredEvent {
            result.append(GearRequirement(id: "event", title: "관련 현장 조사 완료", met: FieldDiscovery.events(in: profile).contains(event)))
        }
        if let defeat = item.requiredDefeat {
            result.append(GearRequirement(id: "defeat", title: "관련 토벌 의뢰 완료", met: FieldDiscovery.defeated(defeat, in: profile)))
        }
        let values = resources(profile), costs = [item.crystals, item.research, item.cores]
        for (i, name) in ["마정석", "조사 데이터", "코어"].enumerated() {
            result.append(GearRequirement(id: "resource-\(i)", title: "\(name) \(values[i]) / \(costs[i])", met: values[i] >= costs[i]))
        }
        return result
    }
    public static func resources(_ profile: Profile) -> [Int] { [profile.crystals, profile.research, profile.growth.cores] }
    public static func applyPreset(_ id: Int, save: inout SaveState, catalog: ProgressionCatalog) throws {
        guard save.active == nil, save.profile.defense?.active == nil else { throw ProgressionError.activeRun }
        guard let preset = save.profile.equipmentJournal?.presets.first(where: { $0.id == id }),
              preset.slots.allSatisfy({ slot, id in save.profile.growth.owned.contains(id) && catalog.equipment.contains { $0.id == id && $0.slot.rawValue == slot } }) else { throw ProgressionError.unavailable }
        save.profile.growth.equipped = preset.slots
    }
    /// 정산의 활동 ID 중복 방지 안에서만 호출한다.
    public static func record(_ session: RunSession, summary: RunSummary, before: Profile, profile: inout Profile) -> ActivityGrowthReport {
        let ids = Array(Set(session.equipmentIDs ?? [])).filter { before.growth.owned.contains($0) }.sorted()
        if !ids.isEmpty {
            var journal = profile.equipmentJournal ?? EquipmentJournal()
            for id in ids {
                var memory = journal.memories[id] ?? EquipmentMemory(trackingSince: session.startedAt)
                memory.activities += 1
                if !session.isIndoor { memory.outdoorDistance += session.distance }
                if memory.firstBossName == nil, summary.majorBoss?.cleared == true { memory.firstBossName = summary.majorBoss?.name }
                journal.memories[id] = memory
            }
            profile.equipmentJournal = journal
        }
        let old = Set(before.runs.flatMap { run in run.records.filter { $0.defeated == true && $0.outcome != .neutral }.map {
            $0.monsterID ?? session.combatRules?.monster(for: $0.catalogID, bossID: run.majorBoss?.bossID)?.id ?? $0.catalogID
        } })
        var seen = old
        let first = summary.records.filter { $0.defeated == true && $0.outcome != .neutral && seen.insert($0.monsterID ?? $0.catalogID).inserted }.map(\.title)
        return ActivityGrowthReport(levelBefore: before.level, levelAfter: profile.level, firstDefeats: first,
            equipmentIDs: ids, targetID: before.equipmentJournal?.targetID, targetBefore: resources(before), targetAfter: resources(profile))
    }
}

public enum ContentUnlocks {
    /// 출현·구매 가능 조건을 그대로 사용한다. 등급으로 콘텐츠를 추정하지 않는다.
    public static func available(profile: Profile, catalog: ProgressionCatalog, encounters: EncounterCatalog?, world: WorldContent?) -> [UnlockNotice] {
        var result = catalog.equipment.filter { $0.available(to: profile) }.map { UnlockNotice(id: "gear:" + $0.id, title: $0.name, detail: "장비 확보 조건 해금 · 자원은 별도") }
        result += catalog.upgrades.filter { $0.available(to: profile) && $0.level == profile.growth.level($0.department) + 1 }.map { UnlockNotice(id: "facility:" + $0.id, title: $0.department.title + " Lv.\($0.level)", detail: "시설 확장 가능 · 자원은 별도") }
        result += (encounters?.encounters ?? []).filter { $0.available(to: profile, catalog: catalog) }.map { UnlockNotice(id: "monster:" + $0.id, title: $0.name, detail: "현장 출현 후보에 추가") }
        result += (world?.bosses ?? []).filter { $0.available(to: profile, catalog: catalog) }.map { UnlockNotice(id: "boss:" + $0.id, title: $0.name, detail: "고위험 게이트 공략 가능") }
        return result
    }
    public static func difference(before: [UnlockNotice], after: [UnlockNotice]) -> [UnlockNotice] {
        let previous = Set(before.map(\.id)); return after.filter { !previous.contains($0.id) }
    }
}
