import Foundation

/// 확정된 3차 수치의 세션 스냅샷. 이전 활동의 규칙은 복구 때 변경하지 않는다.
public struct CombatRules: Codable {
    public var version: Int
    public var attackInterval: Double
    public var monsters: [CombatMonster]
    public var eventMonsters: [String: String]
    public var isValid: Bool {
        version == 3 && attackInterval == 75 && !monsters.isEmpty
            && Set(monsters.map(\.id)).count == monsters.count
            && monsters.allSatisfy(\.isValid)
            && eventMonsters.allSatisfy { entry in !entry.key.isEmpty && monsters.contains { $0.id == entry.value } }
    }
    public func monster(for eventID: String, bossID: String? = nil) -> CombatMonster? {
        let id = eventID.components(separatedBy: "#")[0]
        let monsterID = id.hasPrefix("major-strike") ? bossID : eventMonsters[id]
        return monsters.first { $0.id == monsterID }
    }
}

public struct CombatMonster: Codable, Equatable {
    public var id: String
    public var name: String
    public var maximumHP: Double
    public var defense: Double
    public var experience: Int
    public var persistent: Bool
    public var isValid: Bool {
        !id.isEmpty && maximumHP.isFinite && (1...100_000).contains(maximumHP)
            && defense.isFinite && (0...1000).contains(defense)
            && (0...10_000).contains(experience)
    }
}

public struct DistanceBattle: Codable {
    public static func damagePerAttack(attack: Double, defense: Double) -> Double {
        guard attack.isFinite, defense.isFinite, (0.5...12).contains(attack), defense >= 0 else { return 0 }
        return max(1, floor(60 * attack * 100 / (100 + defense) + 1e-9))
    }
    public var monster: CombatMonster
    public var remainder: Double = 0
    public var attacks: Int = 0
    public var remainingHP: Double
    public init(monster: CombatMonster, remainingHP: Double? = nil) {
        self.monster = monster
        self.remainingHP = min(monster.maximumHP, max(0, remainingHP ?? monster.maximumHP))
    }
    public var isValid: Bool {
        monster.isValid && remainder.isFinite && (0..<75).contains(remainder)
            && remainingHP.isFinite && (0...monster.maximumHP).contains(remainingHP)
            && (0...100_000).contains(attacks)
    }
    /// 한 프레임의 여러 공격을 모두 처리하되, 마지막 공격의 실제 피해만 기록한다.
    @discardableResult public mutating func advance(distance: Double, attack: Double) -> Double {
        guard remainingHP > 0, distance.isFinite, distance > 0,
              attack.isFinite, (0.5...12).contains(attack) else { return 0 }
        let damage = Self.damagePerAttack(attack: attack, defense: monster.defense)
        let total = remainder + distance
        guard total.isFinite else { return 0 }
        let needed = ceil(remainingHP / damage)
        let count = min(floor((total + 1e-9) / 75), needed)
        let applied = min(remainingHP, count * damage)
        remainingHP = max(0, remainingHP - applied)
        attacks += Int(count)
        // 토벌 이후 잉여 거리는 다음 몬스터에 이전하지 않는다.
        remainder = remainingHP == 0 ? 0 : max(0, total - count * 75)
        return applied
    }
}

extension RunEngine {
    static func preparedEvent(_ event: RunEvent, session: RunSession) -> RunEvent {
        guard event.battle == nil, event.template.kind != .discovery,
              let rules = session.combatRules,
              let monster = rules.monster(for: event.template.id, bossID: session.boss?.definition.id) else { return event }
        var prepared = event
        if prepared.template.kind == .pursuit || prepared.template.burstSeconds != nil {
            prepared.template.audio = prepared.template.steadyAudio ?? (prepared.template.kind == .boss ? "boss" : "maintain")
            prepared.template.burstSeconds = nil; prepared.burstStarted = nil
            if prepared.template.kind == .pursuit { prepared.template.kind = .maintain }
            if prepared.stage == .armed { prepared.stage = .active }
        }
        prepared.template.audio = prepared.template.kind == .boss ? "boss" : "maintain"
        let hp = monster.persistent ? session.boss?.remainingHP ?? monster.maximumHP : monster.maximumHP
        prepared.hp = hp; prepared.startingHP = hp
        prepared.battle = DistanceBattle(monster: monster, remainingHP: hp)
        return prepared
    }
}
