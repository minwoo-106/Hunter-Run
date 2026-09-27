import Foundation

public enum RunMode: String, Codable, CaseIterable {
    case exploration, contract, gate
    public var title: String { switch self { case .exploration: return "탐험"; case .contract: return "현장 사냥"; case .gate: return "고위험 게이트" } }
    public var detail: String { switch self {
    case .exploration: return "발견과 조사 중심 · 조사 데이터 보상"
    case .contract: return "조사와 전투를 함께 · 균형 잡힌 보상"
    case .gate: return "강한 개체와 보스 · 마정석과 코어 보상"
    } }
}
public enum EquipmentSlot: String, Codable, CaseIterable {
    case weapon, armor, shoes, relic
    public var title: String { switch self { case .weapon: return "무기"; case .armor: return "방어구"; case .shoes: return "신발"; case .relic: return "유물" } }
    public var symbol: String { switch self { case .weapon: return "bolt.shield"; case .armor: return "shield.lefthalf.filled"; case .shoes: return "shoeprints.fill"; case .relic: return "sparkles" } }
}
public enum Department: String, Codable, CaseIterable {
    case observation, research, equipment, contracts
    public var title: String { switch self { case .observation: return "관측부"; case .research: return "연구부"; case .equipment: return "장비지원부"; case .contracts: return "의뢰부" } }
    public var symbol: String { switch self { case .observation: return "antenna.radiowaves.left.and.right"; case .research: return "flask"; case .equipment: return "shippingbox"; case .contracts: return "list.clipboard" } }
}
public struct CombatStats: Codable, Equatable {
    public var hp: Double = 100
    public var attack: Double = 1
    public var defense: Double = 0
    public var eventBonus: Double = 0
    public var researchBonus: Int = 0
}
public struct GrowthState: Codable {
    public var rank = "E"
    public var departments: [String: Int] = [:]
    public var owned: Set<String> = []
    public var equipped: [String: String] = [:]
    public var cores = 0
    public init() {}
    public func level(_ department: Department) -> Int { departments[department.rawValue] ?? 1 }
}
public struct EquipmentDefinition: Codable, Identifiable {
    public var id: String
    public var name: String
    public var slot: EquipmentSlot
    public var detail: String
    public var crystals: Int
    public var research: Int
    public var cores: Int
    public var requiredEvent: String? = nil
    public var requiredDefeat: String? = nil
    public var discoveryHint: String? = nil
    public var requiredRank: String? = nil
    public func available(to profile: Profile) -> Bool {
        profile.growth.level(.equipment) >= supportLevel && (requiredEvent.map { FieldDiscovery.events(in: profile).contains($0) } ?? true)
        && (requiredDefeat.map { FieldDiscovery.defeated($0, in: profile) } ?? true)
        && (requiredRank.map { (Progression.ranks.firstIndex(of: profile.growth.rank) ?? 0) >= (Progression.ranks.firstIndex(of: $0) ?? Int.max) } ?? true)
    }
    public var supportLevel: Int
    public var tier: Int? = nil
    public var stageName: String {
        switch tier ?? 1 {
        case 1: return "기본 장비"
        case 2: return "고급 장비"
        case 3: return requiredEvent == nil ? "첫 코어 장비" : "현장 준비 장비"
        case 4: return "월영 장비"
        case 5: return "몽환 장비"
        case 6: return "거울결 장비"
        case 7: return "철갑 장비"
        default: return "귀환 장비"
        }
    }
    public var hp: Double
    public var attack: Double
    public var defense: Double
    public var eventBonus: Double
    public var researchBonus: Int
}
public struct DepartmentUpgrade: Codable, Identifiable {
    public var id: String
    public var department: Department
    public var level: Int
    public var crystals: Int
    public var research: Int
    public var playerHint: String
    public var reveal: String
    public var unlockActions: [String]
    public var requiredRank: String? = nil
    public func available(to profile: Profile) -> Bool {
        requiredRank.map { (Progression.ranks.firstIndex(of: profile.growth.rank) ?? 0) >= (Progression.ranks.firstIndex(of: $0) ?? Int.max) } ?? true
    }
}
public struct ProgressionCatalog: Codable {
    public var schema: Int
    public var equipment: [EquipmentDefinition]
    public var upgrades: [DepartmentUpgrade]
    public func validate() throws {
        guard schema == 1, !equipment.isEmpty, Set(equipment.map(\.id)).count == equipment.count,
              Set(upgrades.map(\.id)).count == upgrades.count,
              equipment.allSatisfy({ !$0.id.isEmpty && $0.crystals >= 0 && $0.research >= 0 && $0.cores >= 0 && (1...3).contains($0.supportLevel) && (1...8).contains($0.tier ?? 1) && $0.hp.isFinite && (0...120).contains($0.hp) && $0.attack.isFinite && (0...1.5).contains($0.attack) && $0.defense.isFinite && (0...0.45).contains($0.defense) && $0.eventBonus.isFinite && (0...0.45).contains($0.eventBonus) && (0...15).contains($0.researchBonus) }),
              upgrades.count == Department.allCases.count * 2,
              Set(upgrades.map(\.department)).count == Department.allCases.count,
              upgrades.allSatisfy({ (2...3).contains($0.level) && $0.crystals >= 0 && $0.research >= 0 }) else { throw ProgressionError.invalid }
        for department in Department.allCases {
            guard Set(upgrades.filter { $0.department == department }.map(\.level)) == Set([2, 3]) else { throw ProgressionError.invalid }
        }
    }
    public func unlocked(_ action: String, profile: Profile) -> Bool {
        upgrades.contains { profile.growth.level($0.department) >= $0.level && $0.unlockActions.contains(action) }
    }
    public func stats(for profile: Profile) -> CombatStats {
        var result = CombatStats(hp: 100 + Double(min(100, profile.level - 1)) * 4, attack: profile.attack, defense: min(0.2, Double(profile.level - 1) * 0.01))
        for slot in EquipmentSlot.allCases {
            guard let id = profile.growth.equipped[slot.rawValue], profile.growth.owned.contains(id),
                  let item = equipment.first(where: { $0.id == id && $0.slot == slot }) else { continue }
            result.hp += item.hp; result.attack += item.attack; result.defense += item.defense
            result.eventBonus += item.eventBonus; result.researchBonus += item.researchBonus
        }
        result.attack = min(12, result.attack); result.defense = min(0.8, result.defense)
        result.eventBonus = min(0.45, result.eventBonus)
        result.hp = min(1000, result.hp); result.researchBonus = min(15, result.researchBonus)
        return result
    }
}
public enum ProgressionError: LocalizedError {
    case activeRun, unavailable, insufficient, owned, invalid, promotion
    public var errorDescription: String? { switch self {
    case .activeRun: return "활동을 마친 뒤 장비와 협회를 변경할 수 있습니다."
    case .unavailable: return "아직 해금되지 않은 항목입니다."
    case .insufficient: return "필요한 자원이 부족합니다."
    case .owned: return "이미 보유한 장비입니다."
    case .invalid: return "성장 데이터를 확인할 수 없습니다."
    case .promotion: return "아직 다음 등급의 평가 조건을 충족하지 못했습니다."
    } }
}
public enum Progression {
    public static let ranks = ["E", "D", "C", "B", "A", "S"]
    public static func gateClears(_ profile: Profile) -> Int {
        profile.runs.filter { run in run.mode == .gate && (run.majorBoss?.cleared == true || run.records.contains { $0.catalogID == "gate-core" && $0.defeated == true }) }.count
    }
    public static func nextRank(_ profile: Profile) -> String? {
        guard let index = ranks.firstIndex(of: profile.growth.rank), index + 1 < ranks.count else { return nil }
        return ranks[index + 1]
    }
    public static func requirements(_ profile: Profile) -> (level: Int, runs: Int, gates: Int) {
        switch nextRank(profile) { case "D": return (2, 3, 0); case "C": return (8, 15, 1); case "B": return (18, 35, 4); case "A": return (30, 75, 10); default: return (45, 130, 25) }
    }
    public static func activityMinutes(_ profile: Profile) -> Int {
        Int(min(100_000_000, profile.runs.reduce(0) { $0 + ($1.seconds.isFinite ? max(0, $1.seconds) : 0) }) / 60)
    }
    public static func activityCredits(_ profile: Profile) -> Int { activityMinutes(profile) / 20 }
    public static func qualifiesForExam(_ profile: Profile) -> Bool {
        let goal = requirements(profile)
        return nextRank(profile) != nil && profile.level >= goal.level && activityCredits(profile) >= goal.runs && gateClears(profile) >= goal.gates
    }
    public static func canPromote(_ profile: Profile) -> Bool {
        guard qualifiesForExam(profile), let next = nextRank(profile) else { return false }
        return profile.journey?.completedQuests.contains("exam-" + next) == true
    }
    public static func allows(_ mode: RunMode, profile: Profile, catalog: ProgressionCatalog) -> Bool {
        mode != .gate || (profile.growth.rank != "E" && catalog.unlocked("gate", profile: profile))
    }
    public static func buy(_ id: String, save: inout SaveState, catalog: ProgressionCatalog) throws {
        guard save.active == nil else { throw ProgressionError.activeRun }
        guard let item = catalog.equipment.first(where: { $0.id == id }), item.available(to: save.profile) else { throw ProgressionError.unavailable }
        guard !save.profile.growth.owned.contains(id) else { throw ProgressionError.owned }
        guard save.profile.crystals >= item.crystals, save.profile.research >= item.research, save.profile.growth.cores >= item.cores else { throw ProgressionError.insufficient }
        save.profile.crystals -= item.crystals; save.profile.research -= item.research
        var growth = save.profile.growth; growth.cores -= item.cores; growth.owned.insert(id); save.profile.growth = growth
    }
    public static func equip(_ id: String, save: inout SaveState, catalog: ProgressionCatalog) throws {
        guard save.active == nil else { throw ProgressionError.activeRun }
        guard save.profile.growth.owned.contains(id), let item = catalog.equipment.first(where: { $0.id == id }) else { throw ProgressionError.unavailable }
        var growth = save.profile.growth
        if growth.equipped[item.slot.rawValue] == id { growth.equipped.removeValue(forKey: item.slot.rawValue) }
        else { growth.equipped[item.slot.rawValue] = id }
        save.profile.growth = growth
    }
    @discardableResult public static func upgrade(_ department: Department, save: inout SaveState, catalog: ProgressionCatalog) throws -> String {
        guard save.active == nil else { throw ProgressionError.activeRun }
        guard let upgrade = catalog.upgrades.first(where: { $0.department == department && $0.level == save.profile.growth.level(department) + 1 }) else { throw ProgressionError.unavailable }
        guard upgrade.available(to: save.profile) else { throw ProgressionError.unavailable }
        guard save.profile.crystals >= upgrade.crystals, save.profile.research >= upgrade.research else { throw ProgressionError.insufficient }
        save.profile.crystals -= upgrade.crystals; save.profile.research -= upgrade.research
        var growth = save.profile.growth; growth.departments[department.rawValue] = upgrade.level; save.profile.growth = growth
        return upgrade.reveal
    }
    public static func promote(save: inout SaveState) throws {
        guard save.active == nil else { throw ProgressionError.activeRun }
        guard canPromote(save.profile), let rank = nextRank(save.profile) else { throw ProgressionError.promotion }
        var growth = save.profile.growth; growth.rank = rank; save.profile.growth = growth
    }
}
public struct MissionCatalog: Codable {
    public var schema: Int
    public var modes: [String: GameContent]
    public var extendedContract: MissionTemplate
    public func validate() throws {
        guard schema == 1, Set(modes.keys) == Set(RunMode.allCases.map(\.rawValue)) else { throw ProgressionError.invalid }
        for content in modes.values { try content.validate() }
        var contract = modes[RunMode.contract.rawValue]!
        contract.events.append(extendedContract); try contract.validate()
    }
    public func content(for mode: RunMode, extended: Bool) -> GameContent {
        var content = modes[mode.rawValue]!
        if mode == .contract && extended { content.events.append(extendedContract); content.events.sort { $0.startFraction < $1.startFraction } }
        return content
    }
}
