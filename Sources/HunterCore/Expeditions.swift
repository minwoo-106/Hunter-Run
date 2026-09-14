import Foundation

public struct ReturnBriefing: Codable, Equatable, Identifiable {
    public var id: UUID
    public var lines: [String]
    public var acknowledged = false
    public var isValid: Bool { (1...6).contains(lines.count) && lines.allSatisfy { !$0.isEmpty && $0.count <= 500 } }
}
public struct ExpeditionState: Codable, Equatable {
    public var claimedWeeks: Set<String> = []
    public var briefing: ReturnBriefing?
    public init() {}
    public var isValid: Bool {
        claimedWeeks.count <= 10000 && claimedWeeks.allSatisfy { $0.count <= 32 && !$0.isEmpty }
        && (briefing?.isValid ?? true)
    }
}
public struct WeeklySurvey {
    public var id: String
    public var title: String
    public var startsAt: Date
    public var days: Int
    public var seconds: Double
    public var clues: Int
    public var claimed: Bool
    public var complete: Bool { days >= 3 && seconds >= 3600 && clues >= 6 }
    public var beacons: Int { (days >= 3 ? 1 : 0) + (seconds >= 3600 ? 1 : 0) + (clues >= 6 ? 1 : 0) }
}
public enum Expeditions {
    private static var calendar: Calendar {
        var cal = Calendar(identifier: .iso8601); cal.timeZone = TimeZone(secondsFromGMT: 32400)!
        cal.firstWeekday = 2; cal.minimumDaysInFirstWeek = 4; return cal
    }
    public static func weekStart(_ date: Date) -> Date { calendar.dateInterval(of: .weekOfYear, for: date)!.start }
    public static func survey(_ profile: Profile, at date: Date) -> WeeklySurvey {
        let start = weekStart(date), end = start.addingTimeInterval(7 * 86400)
        var daily: [Date: Double] = [:], clues = 0
        var counted: Set<UUID> = []
        // Require an actual outdoor trace, not just a running clock. No individual route is retained here.
        for run in profile.runs where run.date >= start && run.date < end && run.date <= date && !run.activityEnvironment.isIndoor {
            guard run.seconds.isFinite, run.distance.isFinite, run.seconds >= 60, run.distance >= 50, counted.insert(run.id).inserted else { continue }
            daily[calendar.startOfDay(for: run.date), default: 0] += run.seconds
            clues += run.records.filter { $0.kind == .discovery && [.perfect, .success].contains($0.outcome) }.count
        }
        let titles = ["흩어진 관측 신호", "도시의 잔향 지도", "경계 너머의 흔적", "돌아오는 빛"]
        let index = Int(start.timeIntervalSince1970 / (7 * 86400))
        let id = String(Int(start.timeIntervalSince1970))
        return WeeklySurvey(id: id, title: titles[(index % 4 + 4) % 4], startsAt: start,
            days: daily.values.filter { $0 >= 600 }.count, seconds: daily.values.reduce(0, +), clues: clues,
            claimed: profile.expeditions?.claimedWeeks.contains(id) == true)
    }
    public static func claim(in save: inout SaveState, at date: Date) throws {
        guard save.active == nil else { throw ProgressionError.activeRun }
        let survey = survey(save.profile, at: date)
        guard survey.complete, !survey.claimed else { throw ProgressionError.unavailable }
        var state = save.profile.expeditions ?? ExpeditionState()
        guard state.claimedWeeks.count < 10000 else { throw ProgressionError.unavailable }
        state.claimedWeeks.insert(survey.id); save.profile.expeditions = state
        save.profile.xp += 80; save.profile.crystals += 6; save.profile.research += 4
    }
    // Inside the same guarded settlement/save transaction as the activity and quests.
    static func returned(_ run: RunSession, profile: inout Profile, previousQuests: Set<String>) {
        guard !run.simulated else { return }
        let summary = profile.runs.first { $0.id == run.id }
        var lines = [run.isIndoor ? "다녀오셨어요! 실내에서 움직인 \(Int(run.activeSeconds / 60))분도 기록에 잘 담았어요. 오늘의 흐름을 이어갔네요." : "다녀오셨어요! 오늘의 \(Int(run.activeSeconds / 60))분과 발걸음을 기록했어요. 이제 잠깐 숨을 돌려요."]
        if let boss = summary?.majorBoss {
            lines.append(boss.cleared ? "잘했어요! \(boss.name)의 반응이 사라졌어요. 토벌 기록은 보관했고, 게시판에서 다음 조사를 확인할 수 있어요." : "\(boss.name)에게 준 피해를 저장했어요. 남은 반응은 다음 출동에서 함께 확인해요.")
        } else if let found = run.records.first(where: { $0.defeated == true && $0.outcome != .neutral }) {
            lines.append("\(found.title) 토벌 기록을 확인했어요. 오늘 알아낸 내용이 다음 조사에 도움이 될 거예요.")
        } else if run.records.contains(where: { $0.kind == .discovery && [.perfect, .success].contains($0.outcome) }) {
            lines.append("가져온 표본을 관측판에 옮겼어요. 흩어져 있던 흔적들이 조금씩 이어지고 있어요.")
        } else { lines.append("오늘은 발걸음 기록부터 정리해둘게요. 표본을 못 모은 날에도 운동한 시간은 그대로 남아요.") }
        let new = (profile.journey?.completedQuests ?? []).subtracting(previousQuests)
        if !new.isEmpty { lines.append("함께 진행한 의뢰 \(new.count)건의 조건을 채웠어요! 협회 의뢰 게시판에 보상을 준비해뒀어요.") }
        if !run.isIndoor {
            let week = survey(profile, at: run.startedAt.addingTimeInterval(1))
            lines.append(week.complete ? "이번 주 관측등 세 개가 모두 켜졌어요! 함께 완성한 기록으로 지부가 한층 밝아졌어요." : "이번 주 관측등은 \(week.beacons)개가 켜졌어요. 하루 쉬어도 사라지지 않으니, 우리 속도로 이어가요.")
        }
        var state = profile.expeditions ?? ExpeditionState()
        state.briefing = ReturnBriefing(id: run.id, lines: lines); profile.expeditions = state
    }
    public static func acknowledge(_ id: UUID, in save: inout SaveState) {
        guard save.profile.expeditions?.briefing?.id == id else { return }
        save.profile.expeditions?.briefing?.acknowledged = true
    }
}
