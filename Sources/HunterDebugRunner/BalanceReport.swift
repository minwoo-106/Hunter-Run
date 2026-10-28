import Foundation
import HunterCore

/// 앱과 동일한 장비·공격·보스 생성 경로로 비교표를 만들고 마지막 1m 경계를 검사한다.
enum BalanceReport {
    struct Gear: Codable {
        var name: String
        var ids: [String]
        var names: [String] = []
    }
    struct Target: Codable {
        var id: String
        var name: String
        var kind: String
        var hp: Double
        var defense: Double
        var experience: Int
    }
    struct Row: Codable {
        var level: Int
        var gear: String
        var target: String
        var attack: Double
        var damage: Double
        var hits: Int
        var meters: Double
    }
    struct Report: Codable {
        var version = "1.9.2"
        var interval = 75
        var levels: [Int]
        var equipment: [Gear]
        var targets: [Target]
        var rows: [Row]
        var verifiedBoundaries: Int
    }
    static func generate(resources: URL, output: URL) throws {
        let rules = try read(resources.appendingPathComponent("combat-v3.json"), as: CombatRules.self)
        let catalog = try read(resources.appendingPathComponent("progression.json"), as: ProgressionCatalog.self)
        var world = try read(resources.appendingPathComponent("world.json"), as: WorldContent.self)
        guard rules.isValid else { throw ReplayError.invalidScenario }
        try catalog.validate(); try world.validate()
        world.bosses = world.bosses.map { CombatRelease.boss($0, rules: rules) }
        var gears = [Gear(name: "무장 없음", ids: []),
            Gear(name: "기본", ids: ["field-blade", "field-shoes", "field-compass"]),
            Gear(name: "현재 E급", ids: ["resonance-blade", "trace-shoes", "archive-lens"]),
            Gear(name: "첫 코어", ids: ["core-spear", "core-shoes", "core-orbit"]),
            Gear(name: "월영", ids: ["moon-blade", "moon-wardboots", "moon-compass"]),
            Gear(name: "몽환", ids: ["dream-staff", "dream-wardsteps", "dream-mirror"]),
            Gear(name: "거울결", ids: ["glass-rapier", "echo-striders", "glass-compass"]),
            Gear(name: "철갑", ids: ["ash-mallet", "ash-treads", "hollow-seal"]),
            Gear(name: "귀환", ids: ["return-blade", "anchor-boots", "return-badge"])]
        for i in gears.indices {
            gears[i].names = try gears[i].ids.map { id in
                guard let item = catalog.equipment.first(where: { $0.id == id }) else { throw ReplayError.invalidScenario }
                return item.name
            }
        }
        var monsters = rules.monsters
        var kinds = monsters.map { $0.persistent ? "주요 보스" : "일반·정예·선발대" }
        let extra = BossMutations.all(world) + Quests.entries.compactMap(\.boss) + world.bosses.filter(BossCampaign.allowsReplay)
        for boss in extra {
            var state = BossState(maximumHP: boss.maximumHP)
            let replay = boss.requiredBossClear == nil && !boss.id.hasPrefix("exam-")
            if replay { state.round = 2 }
            var session = RunSession(targetSeconds: 1800, simulated: false, allowPursuit: false, mode: .gate)
            session.boss = BossEncounter(definition: boss, state: state)
            try CombatRelease.prepare(&session, rules: rules)
            guard var monster = session.combatRules?.monsters.first(where: { $0.id == boss.id }) else { throw ReplayError.invalidScenario }
            if replay { monster.id += "-replay"; monster.name += " · 일반 재전" }
            monsters.append(monster)
            kinds.append(boss.id.hasPrefix("exam-") ? "승급 심사" : replay ? "일반 재전" : "변이 재전")
        }
        guard monsters.count == 37, Set(monsters.map(\.id)).count == 37 else { throw ReplayError.invalidScenario }
        let levels = [1, 10, 15, 20, 30, 45, 60, 100]
        var rows: [Row] = []
        for level in levels {
            for gear in gears {
                var save = SaveState()
                try GrowthEconomy.enable(in: &save)
                save.profile.growthEconomy?.level = level
                for id in gear.ids {
                    guard let item = catalog.equipment.first(where: { $0.id == id }) else { throw ReplayError.invalidScenario }
                    save.profile.growth.owned.insert(id); save.profile.growth.equipped[item.slot.rawValue] = id
                }
                try EquipmentRevision.migrate(&save, catalog: catalog)
                let stats = catalog.stats(for: save.profile)
                for monster in monsters {
                    let estimate = CombatEstimate(stats: stats, monster: monster)
                    var battle = DistanceBattle(monster: monster)
                    battle.advance(distance: estimate.distance - 1, attack: stats.attack)
                    guard battle.remainingHP > 0 else { throw ReplayError.invalidScenario }
                    battle.advance(distance: 1, attack: stats.attack)
                    guard battle.remainingHP == 0, battle.attacks == estimate.hits,
                          battle.advance(distance: 7500, attack: stats.attack) == 0,
                          battle.attacks == estimate.hits else { throw ReplayError.invalidScenario }
                    rows.append(Row(level: level, gear: gear.name, target: monster.id, attack: stats.attack,
                        damage: estimate.damage, hits: estimate.hits, meters: estimate.distance))
                }
            }
        }
        let targets = zip(monsters, kinds).map { monster, kind in
            Target(id: monster.id, name: monster.name, kind: kind, hp: monster.maximumHP,
                defense: monster.defense, experience: monster.experience)
        }
        let report = Report(levels: levels, equipment: gears, targets: targets, rows: rows, verifiedBoundaries: rows.count)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        try encoder.encode(report).write(to: output.appendingPathComponent("balance-report.json"), options: .atomic)
        print("전체 37종 · 9장비 · 8레벨 · \(rows.count)개 교전 거리와 중복 공격 경계 검증 통과")
    }
}
