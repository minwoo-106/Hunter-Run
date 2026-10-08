import Foundation

public struct GrowthEconomyState: Codable, Equatable {
    public var version: Int = 3
    public var level: Int
    public var progress: Int
    public var accountedXP: Int
    public var legacyBaseAttack: Double
    public var isValid: Bool {
        version == 3 && (1...1_000_000).contains(level)
            && (0..<GrowthEconomy.requiredExperience(level)).contains(progress)
            && (0...100_000_000).contains(accountedXP)
            && legacyBaseAttack.isFinite && (1...30_000).contains(legacyBaseAttack)
    }
}

public enum GrowthEconomy {
    public static func requiredExperience(_ level: Int) -> Int {
        let anchors: [(Int, Double)] = [(1,1),(5,1.4),(10,1.9),(15,2.4),(20,2.9),(30,3.5),(45,4.4),(60,5.3),(100,7.3)]
        let value: Double
        if level >= 100 { value = 7.3 + 0.05 * Double(level - 100) }
        else {
            let index = (0..<anchors.count-1).first { level <= anchors[$0+1].0 } ?? 0
            let (a,x) = anchors[index], (b,y) = anchors[index+1]
            value = x + (y-x) * Double(max(1,level)-a) / Double(b-a)
        }
        return Int((275 * value / 5).rounded(.toNearestOrAwayFromZero)) * 5
    }
    public static func baseAttack(_ level: Int) -> Double {
        if level <= 15 { return 1 + 0.08 * Double(max(0,level-1)) }
        if level <= 30 { return 2.12 + 0.012 * Double(level-15) }
        if level <= 60 { return 2.30 + 0.006 * Double(level-30) }
        return 2.48 + 0.16 * (-expm1(-Double(level-60)/60))
    }
    /// 기존 의뢰와 주간 보상을 포함한 모든 EXP 증가를 차분으로 반영한다.
    public static func resolved(_ state: GrowthEconomyState, totalXP: Int) -> GrowthEconomyState {
        var next = state
        next.progress += max(0, totalXP - state.accountedXP)
        next.accountedXP = max(totalXP, state.accountedXP)
        while next.progress >= requiredExperience(next.level) {
            next.progress -= requiredExperience(next.level); next.level += 1
        }
        return next
    }
    /// 자동 이행 없이 검증 시작 또는 향후 승인된 이행에서 명시적으로 호출한다.
    public static func enable(in save: inout SaveState) throws {
        guard save.active == nil else { throw ProgressionError.activeRun }
        guard save.profile.growthEconomy == nil else { return }
        let xp = save.profile.xp, level = save.profile.level
        save.profile.growthEconomy = GrowthEconomyState(level: level, progress: xp % 300,
            accountedXP: xp, legacyBaseAttack: 1 + 0.08 * Double(level-1))
    }
    public static func attack(level: Int, gear: Double, legacyBase: Double? = nil) -> Double {
        min(12, max(baseAttack(level) * (1 + 1.5 * gear), (legacyBase ?? 0) + gear))
    }
}

public enum CombatExperience {
    public static func reward(_ session: RunSession, bossReport: BossReport?) -> Int {
        guard let rules = session.combatRules else { return 0 }
        var seen: Set<String> = []
        let records = session.records.filter { seen.insert($0.id).inserted }
        let discoveryCount = records.filter { $0.kind == .discovery && $0.outcome != .neutral }.count
        let investigation = min(discoveryCount * 20, Int(session.activeSeconds / 60) * 2)
        let ordinary = records.reduce(0) { result, record in
            guard record.defeated == true, record.kind != .discovery, record.outcome != .neutral,
                  let monster = rules.monster(for: record.id), !monster.persistent,
                  record.monsterID == monster.id else { return result }
            return result + monster.experience
        }
        let boss = bossReport.flatMap { report in
            report.cleared ? rules.monsters.first { $0.id == report.bossID && $0.persistent }?.experience : nil
        } ?? 0
        return investigation + ordinary + boss
    }
}
