import Foundation

/// 실제 앱의 이행·신규 세션 연결. 진행 중인 이전 활동의 스냅샷은 변경하지 않는다.
public enum CombatRelease {
    @discardableResult public static func migrate(_ save: inout SaveState) throws -> Bool {
        guard save.active == nil else { return false }
        let previous = save.profile.growthEconomy
        try GrowthEconomy.enable(in: &save)
        if let economy = save.profile.growthEconomy {
            save.profile.growthEconomy = GrowthEconomy.resolved(economy,totalXP:save.profile.xp)
        }
        return previous != save.profile.growthEconomy
    }

    public static func boss(_ definition: BossDefinition, rules: CombatRules) -> BossDefinition {
        var result = definition
        if let monster = rules.monsters.first(where: { $0.id == definition.id && $0.persistent }) {
            result.maximumHP = monster.maximumHP
        }
        return result
    }

    public static func prepare(_ session: inout RunSession, rules: CombatRules) throws {
        guard !session.isIndoor, rules.isValid else { throw ProgressionError.invalid }
        var snapshot = rules
        if let encounter = session.boss {
            let definition = encounter.definition
            let parent = rules.monsters.first { $0.id == (definition.requiredBossClear ?? definition.id) && $0.persistent }
            var monster: CombatMonster
            if var inherited = parent {
                inherited.id = definition.id; inherited.name = definition.name; monster = inherited
            } else if definition.id.hasPrefix("exam-") {
                // 심사 전용 보상은 기존 심사 완료 및 의뢰 수령에서 지급한다.
                monster = CombatMonster(id:definition.id,name:definition.name,maximumHP:encounter.maximumHP,
                    defense:0,experience:0,persistent:true)
            } else { throw ProgressionError.invalid }
            // 진행 중이던 보스의 기존 최대·남은 HP를 변경하지 않는다.
            monster.maximumHP = encounter.maximumHP
            snapshot.monsters.removeAll { $0.id == definition.id }; snapshot.monsters.append(monster)
        }
        guard snapshot.isValid else { throw ProgressionError.invalid }
        session.combatRules = snapshot
    }
}

public extension Profile {
    var levelProgress: Int { growthEconomy.map { GrowthEconomy.resolved($0,totalXP:xp).progress } ?? xp % 300 }
    var nextLevelExperience: Int { growthEconomy == nil ? 300 : GrowthEconomy.requiredExperience(level) }
}
