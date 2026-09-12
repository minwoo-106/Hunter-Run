import Foundation

public struct MonsterDefinition: Codable, Identifiable {
    public var id: String
    public var name: String
    public var family: String
    public var description: String
    public var eventIDs: [String]
    public var bossID: String?
    public func isKnown(in profile: Profile) -> Bool {
        !records(in: profile).isEmpty || (bossID == nil && !FieldDiscovery.events(in: profile).isDisjoint(with: eventIDs))
    }
    public func records(in profile: Profile) -> [EventRecord] {
        profile.runs.flatMap { run -> [EventRecord] in
            if let bossID, run.majorBoss?.bossID != bossID { return [] }
            return run.records.filter { eventIDs.contains($0.catalogID) }
        }
    }
}

public struct BossDefinition: Codable, Identifiable {
    public var id: String
    public var name: String
    public var description: String
    public var requiredRank: String
    public var maximumHP: Double
    public var phases: [GameContent]
    public func validate() throws {
        guard !id.isEmpty, Progression.ranks.contains(requiredRank), maximumHP.isFinite,
              (100...100000).contains(maximumHP), phases.count == 3 else { throw ProgressionError.invalid }
        for phase in phases {
            try phase.validate()
            guard phase.events.contains(where: { $0.id.hasPrefix("major-strike") && $0.kind == .boss }) else { throw ProgressionError.invalid }
        }
    }
    public func available(to profile: Profile, catalog: ProgressionCatalog) -> Bool {
        let rank = Progression.ranks.firstIndex(of: profile.growth.rank) ?? 0
        return rank >= (Progression.ranks.firstIndex(of: requiredRank) ?? Int.max) && catalog.unlocked("gate", profile: profile)
    }
}

public struct WorldContent: Codable {
    public var schema: Int
    public var monsters: [MonsterDefinition]
    public var bosses: [BossDefinition]
    public func validate() throws {
        guard schema == 1, !monsters.isEmpty, !bosses.isEmpty,
              Set(monsters.map(\.id)).count == monsters.count, Set(bosses.map(\.id)).count == bosses.count,
              monsters.allSatisfy({ monster in !monster.id.isEmpty && !monster.eventIDs.isEmpty && (monster.bossID == nil || bosses.contains(where: { $0.id == monster.bossID })) }) else { throw ProgressionError.invalid }
        for boss in bosses { try boss.validate() }
    }
}

public struct BossState: Codable, Equatable {
    public var round: Int = 1
    public var maximumHP: Double
    public var remainingHP: Double
    public var clears: Int = 0
    public init(maximumHP: Double) { self.maximumHP = maximumHP; remainingHP = maximumHP }
    public var isValid: Bool {
        maximumHP.isFinite && remainingHP.isFinite && (100...100000).contains(maximumHP)
        && (0...maximumHP).contains(remainingHP) && (1...1000000).contains(round) && (0...1000000).contains(clears)
    }
}

public struct BossEncounter: Codable {
    public var definition: BossDefinition
    public var round: Int
    public var maximumHP: Double
    public var startingHP: Double
    public var damage: Double = 0
    public init(definition: BossDefinition, state: BossState) {
        self.definition = definition; round = state.round; maximumHP = state.maximumHP; startingHP = state.remainingHP
    }
    public var remainingHP: Double { max(0, startingHP - damage) }
    public var phase: Int { remainingHP / maximumHP > 0.7 ? 0 : remainingHP / maximumHP > 0.35 ? 1 : 2 }
    public var phaseName: String { ["경계", "균열", "핵심 노출"][phase] }
    public var content: GameContent { definition.phases[phase] }
    public var isValid: Bool {
        maximumHP.isFinite && startingHP.isFinite && damage.isFinite && (100...100000).contains(maximumHP)
        && (0...maximumHP).contains(startingHP) && (0...startingHP).contains(damage) && (1...1000000).contains(round)
    }
}

public struct BossReport: Codable {
    public var bossID: String
    public var name: String
    public var round: Int
    public var damage: Double
    public var remainingHP: Double
    public var maximumHP: Double
    public var cleared: Bool
}

public enum BossCampaign {
    public static func state(_ boss: BossDefinition, profile: Profile) -> BossState {
        profile.bosses?[boss.id] ?? BossState(maximumHP: boss.maximumHP)
    }
    public static func restart(_ boss: BossDefinition, save: inout SaveState, catalog: ProgressionCatalog) throws {
        guard save.active == nil else { throw ProgressionError.activeRun }
        guard boss.available(to: save.profile, catalog: catalog) else { throw ProgressionError.unavailable }
        var state = state(boss, profile: save.profile)
        guard state.remainingHP == 0, state.round < 1000000 else { throw ProgressionError.unavailable }
        state.round += 1; state.maximumHP = boss.maximumHP; state.remainingHP = boss.maximumHP
        var all = save.profile.bosses ?? [:]; all[boss.id] = state; save.profile.bosses = all
    }
    // Called only inside the run-ID-guarded settlement transaction.
    static func settle(_ session: RunSession, to profile: inout Profile) -> BossReport? {
        guard session.phase == .finished, !session.simulated, session.mode == .gate,
              let encounter = session.boss, encounter.isValid else { return nil }
        var state = state(encounter.definition, profile: profile)
        guard state.round == encounter.round, state.remainingHP == encounter.startingHP,
              state.maximumHP == encounter.maximumHP else { return nil }
        let verifiedDamage = session.records.filter { $0.catalogID.hasPrefix("major-strike") && $0.kind == .boss && $0.outcome != .neutral }.reduce(0) { $0 + $1.damage }
        let damage = min(encounter.damage, max(0, verifiedDamage), state.remainingHP)
        state.remainingHP -= damage
        let cleared = encounter.startingHP > 0 && state.remainingHP == 0
        if cleared { state.clears += 1 }
        var all = profile.bosses ?? [:]; all[encounter.definition.id] = state; profile.bosses = all
        return BossReport(bossID: encounter.definition.id, name: encounter.definition.name, round: state.round, damage: damage, remainingHP: state.remainingHP, maximumHP: state.maximumHP, cleared: cleared)
    }
}

public enum AssociationStage {
    public static func upgrades(_ profile: Profile) -> Int { Department.allCases.filter { profile.growth.level($0) >= 2 }.count }
    public static func level(_ profile: Profile) -> Int { let count = upgrades(profile); return count >= 4 ? 2 : count >= 2 ? 1 : 0 }
    public static func name(_ profile: Profile) -> String { ["임시 지부", "정식 관측 지부", "광역 작전 지부"][level(profile)] }
    public static func artwork(_ profile: Profile) -> String { ["AssociationOffice", "AssociationOperational", "AssociationAdvanced"][level(profile)] }
}
