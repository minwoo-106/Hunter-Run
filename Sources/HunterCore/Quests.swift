import Foundation

public struct QuestRecord: Codable, Equatable {
    public var seconds: Double = 0
    public var evidence: Set<String> = []
    public init() {}
    public var isValid: Bool { seconds.isFinite && (0...100_000_000).contains(seconds) && evidence.count <= 100 }
}
public struct QuestDefinition: Identifiable {
    public var id: String
    public var title: String
    public var detail: String
    public var main: Int
    public var seconds: Double
    public var samples: Int
    public var xp: Int
    public var crystals: Int
    public var research: Int
    public var promotion: String? = nil
    public var lifetimeDefeats: Int? = nil
    public var boss: BossDefinition? {
        guard let rank = promotion, let index = Progression.ranks.firstIndex(of: rank) else { return nil }
        let hp = [200.0, 200, 420, 650, 900, 1400][index]
        let phase = GameContent(schema: 1, missionTitle: title, events: [
            MissionTemplate(id: "exam-observation", title: "심사 표식 확인", kind: .discovery, startFraction: 0.15, duration: 20, hp: 0, audio: "discovery"),
            MissionTemplate(id: "major-strike-exam-a", title: "감시체 외피 공략", kind: .boss, startFraction: 0.35, duration: 30, hp: 35, audio: "boss"),
            MissionTemplate(id: "major-strike-exam-b", title: "감시체 핵 반응 확인", kind: .boss, startFraction: 0.65, duration: 35, hp: 40, audio: "boss")
        ])
        return BossDefinition(id: id, name: title, description: "조사와 전투 판단을 확인하는 누적 심사예요.", requiredRank: Progression.ranks[index-1], maximumHP: hp, phases: [phase, phase, phase])
    }
    public func available(_ profile: Profile) -> Bool {
        let state = profile.journey ?? JourneyState()
        if let promotion {
            return Progression.nextRank(profile) == promotion && Progression.qualifiesForExam(profile)
                && (main == 0 || state.unlocked.contains(String(format: "M%02d", main)))
        }
        return main == 0 || state.unlocked.contains(String(format: "M%02d", main))
    }
    public func progress(_ profile: Profile) -> QuestRecord { profile.journey?.questRecords[id] ?? QuestRecord() }
    public func mission(from original: GameContent) -> GameContent {
        if let boss { return boss.phases[0] }
        if lifetimeDefeats != nil {
            return GameContent(schema: 1, missionTitle: title, events: [
                MissionTemplate(id: "discovery", title: "잔향 추적", kind: .discovery, startFraction: 0.15, duration: 20, hp: 0, audio: "discovery"),
                MissionTemplate(id: "beast", title: "잔향 늑대", kind: .maintain, startFraction: 0.4, duration: 30, hp: 25, audio: "maintain"),
                MissionTemplate(id: "trail", title: "남은 흔적 조사", kind: .discovery, startFraction: 0.7, duration: 25, hp: 0, audio: "investigate")
            ])
        }
        // Quest evidence has separate IDs and cannot accidentally count as a monster kill.
        let events = (0..<max(1, samples)).map { sample in
            MissionTemplate(id: "evidence-\(id)-\(sample)", title: "조사 표본 \(sample + 1)", kind: .discovery,
                            startFraction: 0.18 + Double(sample) * 0.20, duration: 35, hp: 0, audio: "investigate")
        }
        return GameContent(schema: 1, missionTitle: title, events: events)
    }
}

public enum Quests {
    public static let entries: [QuestDefinition] = [
        QuestDefinition(id: "wolf-first", title: "첫 잔향 토벌", detail: "잔향 늑대의 반응을 끝까지 확인해요.", main: 1, seconds: 0, samples: 0, xp: 40, crystals: 3, research: 2, lifetimeDefeats: 1),
        QuestDefinition(id: "wolf-ten", title: "잔향수 분석 의뢰", detail: "잔향 늑대 10마리를 토벌해요. 이전 토벌도 함께 반영돼요.", main: 3, seconds: 0, samples: 0, xp: 220, crystals: 15, research: 8, lifetimeDefeats: 10),
        QuestDefinition(id: "compare-signals", title: "비교 관측", detail: "두 종류의 표본과 활동 20분을 모아요.", main: 3, seconds: 1200, samples: 2, xp: 80, crystals: 5, research: 3),
        QuestDefinition(id: "basic-survey", title: "기초 조사", detail: "심사에 제출할 표본 두 종류와 활동 30분을 모아요.", main: 4, seconds: 1800, samples: 2, xp: 100, crystals: 7, research: 4),
        QuestDefinition(id: "moon-mark", title: "월영 표식 조사", detail: "낯선 표식을 관측해요. 표본 두 종류와 활동 30분이 필요해요.", main: 6, seconds: 1800, samples: 2, xp: 120, crystals: 8, research: 5),
        QuestDefinition(id: "illusion-survey", title: "환영 관측", detail: "표본 세 종류와 활동 40분으로 반응을 분리해요.", main: 7, seconds: 2400, samples: 3, xp: 140, crystals: 10, research: 5),
        QuestDefinition(id: "compare-original", title: "원본 대조", detail: "활동 20분과 표본 세 종류를 모아 비교해요.", main: 8, seconds: 1200, samples: 3, xp: 100, crystals: 6, research: 5),
        QuestDefinition(id: "restore-link", title: "관측망 복구", detail: "표본 두 종류와 활동 30분을 모아 연결을 점검해요.", main: 9, seconds: 1800, samples: 2, xp: 140, crystals: 10, research: 6),
        QuestDefinition(id: "restore-records", title: "원본 복원", detail: "활동 60분과 두 종류의 표본을 모아요. 여러 활동에 걸쳐 이어갈 수 있어요.", main: 11, seconds: 3600, samples: 2, xp: 200, crystals: 15, research: 8),
        QuestDefinition(id: "inner-signal", title: "안쪽 신호 조사", detail: "활동 60분과 표본 세 종류로 다음 관측을 준비해요.", main: 13, seconds: 3600, samples: 3, xp: 200, crystals: 15, research: 8)
    ] + ["D", "C", "B", "A", "S"].enumerated().map { index, rank in
        QuestDefinition(id: "exam-" + rank, title: rank + "급 승급 심사", detail: "전용 감시체를 완전히 토벌해요. 피해량은 다음 활동으로 이어져요.", main: index == 0 ? 5 : index == 1 ? 12 : 16, seconds: 0, samples: 0, xp: 120 + index * 60, crystals: 10 + index * 5, research: 5 + index * 2, promotion: rank)
    }
    public static func entry(_ id: String?) -> QuestDefinition? { entries.first { $0.id == id } }
    public static func defeats(_ profile: Profile) -> Int {
        profile.runs.flatMap(\.records).filter { $0.catalogID == "beast" && $0.defeated == true && $0.outcome != .neutral }.count
    }
    // Must only be called inside Settlement's guarded real-run transaction.
    static func settle(_ session: RunSession, profile: inout Profile) {
        guard !session.simulated, session.phase == .finished else { return }
        var state = profile.journey ?? JourneyState()
        // Ordinary assignments accompany every eligible activity. Selection only pins a focus.
        let eligible = entries.filter { quest in
            quest.promotion == nil ? (quest.available(profile) || quest.id == session.questID) : quest.id == session.questID
        }
        for quest in eligible where !state.completedQuests.contains(quest.id) {
            var record = state.questRecords[quest.id] ?? QuestRecord()
            record.seconds = min(100_000_000, record.seconds + session.activeSeconds)
            for event in session.records where event.kind == .discovery && [.perfect, .success, .partial].contains(event.outcome) {
                if record.evidence.count < 100 { record.evidence.insert(event.catalogID) }
            }
            state.questRecords[quest.id] = record
            if quest.promotion != nil {
                if (profile.bosses?[quest.id]?.clears ?? 0) > 0 { state.completedQuests.insert(quest.id) }
            } else if quest.lifetimeDefeats == nil && record.seconds >= quest.seconds && record.evidence.count >= quest.samples {
                state.completedQuests.insert(quest.id)
            }
        }
        for quest in entries {
            if let count = quest.lifetimeDefeats, defeats(profile) >= count { state.completedQuests.insert(quest.id) }
        }
        profile.journey = state
    }
    public static func select(_ id: String?, save: inout SaveState) throws {
        guard save.active == nil else { throw ProgressionError.activeRun }
        var state = save.profile.journey ?? JourneyState()
        if let id {
            guard let quest = entry(id), quest.available(save.profile), !state.completedQuests.contains(id) else { throw ProgressionError.unavailable }
        }
        state.selectedQuest = id; save.profile.journey = state
    }
    public static func claim(_ id: String, save: inout SaveState) throws {
        guard save.active == nil else { throw ProgressionError.activeRun }
        guard let quest = entry(id), var state = save.profile.journey,
              quest.main == 0 || state.unlocked.contains(String(format: "M%02d", quest.main)),
              state.completedQuests.contains(id), !state.claimedQuests.contains(id) else { throw ProgressionError.unavailable }
        save.profile.xp += quest.xp; save.profile.crystals += quest.crystals; save.profile.research += quest.research
        state.claimedQuests.insert(id)
        if state.selectedQuest == id { state.selectedQuest = nil }
        save.profile.journey = state
    }
}
