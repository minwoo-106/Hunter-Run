import Foundation

/// The player's selected activity, its environment and its reason are independent.
public enum ActivityPurpose: String, Codable {
    case normalActivity, rankExam, storyObjective, replayTraining
}

public enum EncounterKind: String, Codable {
    case normalMonster, eliteMonster, normalGate, storyBoss, echoReplayBoss, mutatedReplayBoss, rankExamBoss
}

public enum CompletionKind: String, Codable {
    case normalGateClear, storyBossFirstClear, echoReplayClear, mutatedReplayClear, rankExamClear
    public var title: String {
        switch self {
        case .normalGateClear: return "일반 게이트 해결"
        case .storyBossFirstClear: return "주요 보스 첫 토벌"
        case .echoReplayClear: return "잔향 재현 완료"
        case .mutatedReplayClear: return "변이 재현 완료"
        case .rankExamClear: return "승급 심사 완료"
        }
    }
}

public enum CompletionRewards {
    public static func bonus(_ completion: CompletionKind?, oldRules: Bool, bossCleared: Bool) -> (xp: Int, crystals: Int, cores: Int) {
        if oldRules {
            return (bossCleared ? 120 : 0, bossCleared ? 15 : 0,
                    bossCleared ? 2 : completion == .normalGateClear ? 1 : 0)
        }
        switch completion {
        case .some(.storyBossFirstClear): return (120, 15, 2)
        case .some(.normalGateClear): return (0, 3, 1)
        case .some(.echoReplayClear): return (60, 7, 0)
        case .some(.mutatedReplayClear): return (90, 12, 0)
        case .some(.rankExamClear): return (120, 15, 0)
        case .none: return (0, 0, 0)
        }
    }
}

public struct GateBalance: Codable {
    public var firstEncounterChance: Double = 0.6
    public var eligibleSessionsToGuarantee: Int = 2
    public var encounterFraction: Double = 0.6
    public var coreHP: Double = 60
    public init() {}
    public var isValid: Bool {
        (0...1).contains(firstEncounterChance) && eligibleSessionsToGuarantee == 2
            && (0.5...0.8).contains(encounterFraction) && (1...1000).contains(coreHP)
    }
}

public struct GateProgress: Codable, Equatable {
    public var legacyCredits: Int = 0
    public var newCredits: Int = 0
    public var tracking = false
    public var missedEligibleSessions = 0
    public var pending = false
    public init() {}
    public init(legacyCredits: Int) { self.legacyCredits = legacyCredits }
    public var totalCredits: Int { legacyCredits + newCredits }
    public var isValid: Bool {
        (0...1_000_000).contains(legacyCredits) && (0...1_000_000).contains(newCredits)
            && (0...1).contains(missedEligibleSessions)
    }
}

public enum GateTracking {
    public static let eventID = "gate-core"

    /// Optional saved field: absence means a pre-upgrade profile whose old credits must be frozen.
    public static func migrate(_ profile: inout Profile) {
        guard profile.gateProgress == nil else { return }
        profile.gateProgress = GateProgress(legacyCredits: Progression.legacyGateClears(profile))
    }

    public static func canTrack(_ profile: Profile, catalog: ProgressionCatalog) -> Bool {
        Progression.allows(.gate, profile: profile, catalog: catalog)
    }

    /// The UUID roll is stable across recovery; the chosen encounter is saved in the run snapshot.
    public static func prepare(_ session: inout RunSession, profile: Profile, balance: GateBalance) {
        guard balance.isValid, session.mode == .contract, !session.isIndoor,
              profile.gateProgress?.tracking == true else { return }
        session.gateTracking = true
        session.gateWindowFraction = balance.encounterFraction
        let progress = profile.gateProgress ?? GateProgress()
        let hash = session.id.uuidString.utf8.reduce(UInt64(14695981039346656037)) {
            ($0 ^ UInt64($1)) &* 1099511628211
        }
        let roll = Double(hash % 10_000) / 10_000
        session.gateScheduled = progress.pending || progress.missedEligibleSessions >= 1
            || roll < balance.firstEncounterChance
    }

    public static func content(_ original: GameContent, session: RunSession, balance: GateBalance) -> GameContent {
        guard session.gateScheduled == true else { return original }
        var content = original
        content.events.removeAll { $0.id == "gate" }
        var gate = MissionTemplate(id: eventID, title: "일반 게이트 · 균열 감시자",
            kind: .boss, startFraction: balance.encounterFraction, duration: 45,
            hp: balance.coreHP, audio: "watcher_intro")
        gate.encounterKind = .normalGate
        content.events.append(gate)
        return content
    }

    /// Called once inside the activity-ID guarded settlement transaction.
    public static func settle(_ session: RunSession, completion: CompletionKind?, profile: inout Profile) {
        migrate(&profile)
        var progress = profile.gateProgress ?? GateProgress()
        if session.rulesVersion == nil {
            // An activity saved before the upgrade finishes under its original credit policy.
            if session.mode == .gate && (session.records.contains { $0.catalogID == eventID && $0.defeated == true }
                || session.boss != nil && completion != nil) { progress.newCredits += 1 }
        } else if completion == .normalGateClear || completion == .storyBossFirstClear {
            progress.newCredits += 1
        }
        if session.gateTracking == true {
            if completion == .normalGateClear {
                progress.pending = false; progress.missedEligibleSessions = 0
            } else if session.gatePresented == true {
                progress.pending = true
            } else if session.gateScheduled == true && session.gateOpportunityQualified == true {
                // A guaranteed encounter displaced by safety or scheduling keeps its guarantee.
                progress.pending = true
            } else if session.gateOpportunityQualified == true {
                progress.missedEligibleSessions = min(1, progress.missedEligibleSessions + 1)
            }
        }
        profile.gateProgress = progress
    }
}
