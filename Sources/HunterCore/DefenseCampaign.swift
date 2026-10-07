import Foundation

public enum DefenseIntensity: String, Codable, CaseIterable {
    case light, standard, challenge
    public var title: String { switch self { case .light: return "가볍게"; case .standard: return "기본"; case .challenge: return "조금 더 도전" } }
    public var workSeconds: Int { switch self { case .light: return 20; case .standard: return 30; case .challenge: return 40 } }
}

public enum DefenseExercise: String, Codable, CaseIterable {
    case march, step, knee, squat, wallPush, heel, boxing
    public var title: String {
        switch self { case .march: return "제자리 걷기"; case .step: return "좌우 스텝"; case .knee: return "무릎 번갈아 올리기"; case .squat: return "스쿼트"; case .wallPush: return "벽 푸시업"; case .heel: return "뒤꿈치 들기"; case .boxing: return "가벼운 섀도복싱" }
    }
    public var symbol: String { switch self { case .march: return "figure.walk"; case .step: return "arrow.left.arrow.right"; case .knee: return "figure.march"; case .squat: return "figure.strengthtraining.functional"; case .wallPush: return "hand.raised"; case .heel: return "shoeprints.fill"; case .boxing: return "figure.boxing" } }
    public var instruction: String {
        switch self {
        case .march: return "제자리에서 편하게 걸어요. 발을 가볍게 딛고 어깨에 힘을 빼주세요."
        case .step: return "좌우로 한 걸음씩 옮겨요. 발을 교차하지 않고 좁게 움직여도 좋아요."
        case .knee: return "무릎을 번갈아 편한 높이까지만 올려요. 벽을 짚거나 앉아서 해도 좋아요."
        case .squat: return "발을 편하게 벌리고 엉덩이를 뒤로 보내며 천천히 앉았다 일어나요. 깊게 내려가지 않아도 돼요."
        case .wallPush: return "벽에 손을 대고 팔꿈치를 천천히 굽혔다 펴요. 벽 가까이 서면 더 가벼워져요."
        case .heel: return "벽을 가볍게 짚고 뒤꿈치를 천천히 들었다 내려요. 반동 없이 작게 움직여요."
        case .boxing: return "주먹을 가볍게 쥐고 번갈아 앞으로 뻗어요. 팔꿈치를 끝까지 세게 펴지는 마세요."
        }
    }
    public var alternative: String {
        switch self { case .squat: return "튼튼한 의자에서 천천히 일어나기 또는 제자리 걷기"; case .wallPush: return "벽 가까이 서기 또는 편한 팔 움직임"; case .boxing: return "앉아서 천천히 팔 뻗기"; case .knee: return "낮은 무릎 올리기 또는 앉아서 번갈아 들기"; case .heel: return "벽을 짚고 작게 들기"; default: return "작고 느린 제자리 걷기 또는 앉아서 발 움직이기" }
    }
}

public enum DefenseOperation: String, Codable, CaseIterable {
    case hold, repair, rescue, stabilize
    public var title: String { switch self { case .hold: return "방어선 유지"; case .repair: return "시설 복구"; case .rescue: return "구조팀 지원"; case .stabilize: return "봉인 안정화" } }
    public var purpose: String { switch self { case .hold: return "통로를 지킬 시간을 벌어요."; case .repair: return "격리벽 복구를 도와요."; case .rescue: return "지원팀이 지나갈 길을 확보해요."; case .stabilize: return "안정화 장치의 리듬을 맞춰요." } }
}

public struct DefenseEpisode: Codable, Identifiable {
    public let number: Int
    public let act: Int
    public let title: String
    public let operation: DefenseOperation
    public let briefing: String
    public let intermissions: [String]
    public let outro: String
    public let exercises: [DefenseExercise]
    public let scene: String
    public let reward: String?
    public var id: Int { number }
}

public struct DefenseIllustration: Codable, Identifiable {
    public let id: String
    public let episode: Int
    public let title: String
    public let caption: String
    public let asset: String
    public let behind: String?
}

public struct DefenseCatalog: Codable {
    public let version: Int
    public let acts: [String]
    public let episodes: [DefenseEpisode]
    public let illustrations: [DefenseIllustration]
    public func episode(_ number: Int) -> DefenseEpisode? { episodes.first { $0.number == number } }
    public func validate() throws {
        guard version == 1, acts.count == 6, episodes.map(\.number) == Array(1...30),
              Set(illustrations.map(\.id)).count == 7,
              illustrations.map(\.episode) == [1, 5, 10, 15, 20, 25, 30] else { throw DefenseError.invalid }
        for e in episodes {
            guard e.act == (e.number - 1) / 5 + 1, !e.title.isEmpty, !e.briefing.isEmpty,
                  e.intermissions.count == 2, e.intermissions.allSatisfy({ !$0.isEmpty }),
                  !e.outro.isEmpty, e.exercises.count == 15, !e.scene.isEmpty,
                  e.reward == illustrations.first(where: { $0.episode == e.number })?.id else { throw DefenseError.invalid }
        }
        guard illustrations.allSatisfy({ !$0.title.isEmpty && !$0.caption.isEmpty && !$0.asset.isEmpty }),
              illustrations.last?.behind?.isEmpty == false else { throw DefenseError.invalid }
    }
}

public enum DefenseError: Error { case invalid, unavailable, unfinished }
public enum DefensePhase: String { case warmup, battle, recovery, cooldown, complete }

public struct DefenseMoment {
    public let phase: DefensePhase
    public let phaseIndex: Int
    public let phaseRemaining: Double
    public let intervalRemaining: Double
    public let preparing: Bool
    public let exercise: DefenseExercise
    public let slot: Int
    public var title: String {
        switch phase { case .warmup: return "준비와 브리핑"; case .battle: return "교전 \(phaseIndex)"; case .recovery: return "재정비 \(phaseIndex)"; case .cooldown: return "정리와 귀환"; case .complete: return "작전 완료" }
    }
}

/// A fixed 24-minute guide clock, independent of GPS, run rewards and wall time.
/// The first part of every combat minute is recovery/instruction; the remainder is movement.
public enum DefenseTimeline {
    public static let duration: Double = 1440
    public static func moment(at elapsed: Double, intensity: DefenseIntensity, episode: DefenseEpisode) -> DefenseMoment {
        let t = min(duration, max(0, elapsed.isFinite ? elapsed : 0))
        if t >= duration { return DefenseMoment(phase: .complete, phaseIndex: 0, phaseRemaining: 0, intervalRemaining: 0, preparing: false, exercise: .march, slot: 0) }
        let sections: [(Double, Double, DefensePhase, Int)] = [(0,240,.warmup,0),(240,540,.battle,1),(540,600,.recovery,1),(600,900,.battle,2),(900,960,.recovery,2),(960,1260,.battle,3),(1260,1440,.cooldown,0)]
        let section = sections.first { t >= $0.0 && t < $0.1 }!
        let local = t - section.0
        let slot = Int(local / 60)
        let within = local.truncatingRemainder(dividingBy: 60)
        let lead = Double(60 - intensity.workSeconds)
        let battle = section.2 == .battle
        let exercise = battle ? episode.exercises[(section.3 - 1) * 5 + slot] : [.march, .step, .heel, .march][min(slot, 3)]
        return DefenseMoment(phase: section.2, phaseIndex: section.3, phaseRemaining: section.1 - t,
            intervalRemaining: battle ? (within < lead ? lead - within : 60 - within) : 60 - within,
            preparing: battle && within < lead, exercise: exercise, slot: slot)
    }
}

public struct DefenseSession: Codable, Identifiable {
    public let id: UUID
    public let episode: Int
    public let intensity: DefenseIntensity
    public let contentVersion: Int
    public var elapsed: Double
    public var paused: Bool
    public init(episode: Int, intensity: DefenseIntensity) {
        id = UUID(); self.episode = episode; self.intensity = intensity
        contentVersion = 1; elapsed = 0; paused = true
    }
    public var isValid: Bool { (1...30).contains(episode) && contentVersion == 1 && elapsed.isFinite && (0...DefenseTimeline.duration).contains(elapsed) }
}

/// Uptime is deliberately transient: relaunch never credits time spent with the app closed.
public struct DefenseClock {
    public private(set) var session: DefenseSession
    private var last: Double?
    public init(_ session: DefenseSession) { self.session = session; self.session.paused = true }
    public mutating func resume(at uptime: Double) {
        guard uptime.isFinite, session.elapsed < DefenseTimeline.duration else { return }
        last = uptime; session.paused = false
    }
    public mutating func pause(at uptime: Double) { advance(to: uptime); session.paused = true; last = nil }
    public mutating func advance(to uptime: Double) {
        guard !session.paused, uptime.isFinite, let previous = last, uptime >= previous else { return }
        let delta = uptime - previous; last = uptime
        // A suspended process must not silently jump across unheard exercise instructions.
        guard delta <= 3 else { session.paused = true; last = nil; return }
        session.elapsed = min(DefenseTimeline.duration, session.elapsed + delta)
        if session.elapsed >= DefenseTimeline.duration { session.paused = true; last = nil }
    }
}

public struct DefenseRecord: Codable, Identifiable {
    public let id: UUID
    public let episode: Int
    public let intensity: DefenseIntensity
    public let seconds: Double
    public let date: Date
}

public struct DefenseProgress: Codable {
    public var version = 1
    public var records: [DefenseRecord] = []
    public var active: DefenseSession?
    public var pendingReport: Int?
    public init() {}
    public var nextEpisode: Int? { records.count < 30 ? records.count + 1 : nil }
    public var totalSeconds: Double { records.reduce(0) { $0 + $1.seconds } }
    public var isValid: Bool {
        guard version == 1, records.count <= 30, records.map(\.episode) == Array(1..<(records.count + 1)),
              Set(records.map(\.id)).count == records.count,
              records.allSatisfy({ $0.seconds == DefenseTimeline.duration && $0.date.timeIntervalSince1970.isFinite }) else { return false }
        if let report = pendingReport, !records.contains(where: { $0.episode == report }) { return false }
        if let active { return active.isValid && active.episode == nextEpisode && pendingReport == nil }
        return true
    }
}

public enum DefenseCampaign {
    public static func begin(episode: Int, intensity: DefenseIntensity, in save: inout SaveState) throws {
        var progress = save.profile.defense ?? DefenseProgress()
        guard save.active == nil, progress.active == nil, progress.pendingReport == nil,
              progress.nextEpisode == episode else { throw DefenseError.unavailable }
        progress.active = DefenseSession(episode: episode, intensity: intensity)
        save.profile.defense = progress
    }
    public static func checkpoint(_ session: DefenseSession, in save: inout SaveState) throws {
        guard session.isValid, save.active == nil, var progress = save.profile.defense,
              progress.active?.id == session.id, progress.active?.episode == session.episode,
              progress.active?.intensity == session.intensity,
              session.elapsed >= (progress.active?.elapsed ?? 0) else { throw DefenseError.invalid }
        progress.active = session; save.profile.defense = progress
    }
    @discardableResult public static func complete(_ session: DefenseSession, at date: Date, in save: inout SaveState) throws -> Bool {
        var progress = save.profile.defense ?? DefenseProgress()
        if progress.records.contains(where: { $0.id == session.id }) { return false }
        guard session.isValid, session.elapsed == DefenseTimeline.duration else { throw DefenseError.unfinished }
        guard save.active == nil, progress.active?.id == session.id, progress.active?.episode == session.episode,
              progress.active?.intensity == session.intensity, progress.nextEpisode == session.episode,
              date.timeIntervalSince1970.isFinite else { throw DefenseError.unavailable }
        progress.records.append(DefenseRecord(id: session.id, episode: session.episode, intensity: session.intensity, seconds: session.elapsed, date: date))
        progress.active = nil; progress.pendingReport = session.episode
        save.profile.defense = progress
        save.profile.xp += 10; save.profile.crystals += 2
        return true
    }
}
