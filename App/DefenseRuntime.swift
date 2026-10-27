import Foundation
import SwiftUI

@MainActor final class DefenseRuntime: ObservableObject {
    @Published private(set) var session: DefenseSession?
    @Published private(set) var caption = ""
    @Published private(set) var error: String?
    let catalog: DefenseCatalog?
    let workouts: DefenseWorkoutCatalog?
    private weak var model: AppModel?
    private var clock: DefenseClock?
    private var ticker: Timer?
    private var lastCheckpoint = 0.0
    private var delivered = Set<String>()
    private let voice = AudioDirector()
    private let lines: [String: String]
    private var lastBoundary = ""
    private var isFinishing = false
    private var sequenceID = UUID()
    var episode: DefenseEpisode? { session.flatMap { catalog?.episode($0.episode) } }
    var moment: DefenseMoment? {
        guard let session, let episode else { return nil }
        if session.contentVersion == 2, let workout = workouts?.workout(session.episode) {
            return DefenseWorkoutTimeline.moment(at: session.elapsed, intensity: session.intensity,
                workout: workout, standingOnly: session.standingOnly == true)
        }
        return DefenseTimeline.moment(at: session.elapsed, intensity: session.intensity, episode: episode)
    }
    var audioReady: Bool {
        let keys = lines.keys.filter { session?.contentVersion != 1 || !$0.hasPrefix("defense_v2_") }
        return !keys.isEmpty && (session?.contentVersion == 1 || lines["defense_v2_floor"] != nil)
            && keys.allSatisfy {
            Bundle.main.url(forResource: $0, withExtension: "wav", subdirectory: "DefenseAudio") != nil
                || Bundle.main.url(forResource: $0, withExtension: "wav") != nil
        }
    }
    init(model: AppModel) {
        self.model = model
        let loaded: DefenseCatalog? = Self.resource("defense-campaign")
        catalog = loaded.flatMap { (try? $0.validate()) != nil ? $0 : nil }
        let workoutData: DefenseWorkoutCatalog? = Self.resource("defense-workouts")
        workouts = workoutData.flatMap { (try? $0.validate()) != nil ? $0 : nil }
        let oldLines: [String: String] = Self.resource("defense-lines") ?? [:]
        let newLines: [String: String] = Self.resource("defense-workout-lines") ?? [:]
        lines = oldLines.merging(newLines) { _, new in new }
        voice.onInterruption = { [weak self] in DispatchQueue.main.async { self?.pause(reason: "통신이 잠시 멈췄어요. 준비되면 이어가세요.") } }
        voice.onFailure = { [weak self] message in DispatchQueue.main.async {
            self?.pause(reason: message); self?.error = message
        } }
    }
    deinit { ticker?.invalidate() }
    private static func resource<T: Decodable>(_ name: String) -> T? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "json"), let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
    func start(episode: Int, intensity: DefenseIntensity, standingOnly: Bool = false) {
        guard let model, model.isReady, model.engine == nil, model.save.active == nil,
              catalog?.episode(episode) != nil, workouts?.workout(episode) != nil, audioReady else { error = "작전 자료와 안내 음성을 확인할 수 없어요. 진행 중인 활동이 있다면 먼저 마쳐주세요."; return }
        do {
            var candidate = model.save
            try DefenseCampaign.begin(episode: episode, intensity: intensity, standingOnly: standingOnly, in: &candidate)
            try model.repository.write(candidate); model.save = candidate
            restore(); model.showDefense = true
        } catch { self.error = "작전 시작을 저장하지 못했어요. 다시 시도해주세요." }
    }
    func restore() {
        guard let model, let saved = model.save.profile.defense?.active, saved.isValid, catalog?.episode(saved.episode) != nil else { return }
        guard saved.contentVersion == 1 || workouts?.workout(saved.episode) != nil else {
            error = "이어서 할 운동 자료를 확인할 수 없어요. 진행 기록은 보관되어 있어요."; return
        }
        model.audio.stop(); voice.stop(); ticker?.invalidate(); ticker = nil
        sequenceID = UUID()
        clock = DefenseClock(saved); session = clock?.session
        delivered = []; lastBoundary = ""; lastCheckpoint = saved.elapsed; error = nil
        caption = saved.elapsed > 0 ? "중단한 지점에서 이어갈 수 있어요. 준비되면 계속을 눌러주세요." : "휴대폰을 보기 편한 곳에 두고, 준비되면 시작해주세요."
        model.refreshLobbyMusic(); model.refreshActivityDisplay()
    }
    func resume() {
        guard let model, clock != nil, audioReady, (session?.elapsed ?? 1440) < 1440 else { return }
        error = nil; voice.volume = Float(model.voiceVolume); voice.ducking = model.ducking
        sequenceID = UUID(); let token = sequenceID
        // On resume, use easy walking until the next boundary; never repeat a full
        // duration instruction for a partially completed work interval.
        let initial = (session?.elapsed ?? 0) == 0
        let key = initial ? "defense_warm" : session?.contentVersion == 2 ? "defense_v2_resume" : "defense_resume"
        caption = lines[key] ?? "준비되면 이어갈게요."
        voice.play(key) { [weak self] in DispatchQueue.main.async {
            guard let self, token == self.sequenceID, self.model?.showDefense == true, self.session?.paused == true else { return }
            self.clock?.resume(at: ProcessInfo.processInfo.systemUptime)
            self.session = self.clock?.session
            if !initial, let m = self.moment {
                self.lastBoundary = "\(m.phase.rawValue):\(m.phaseIndex):\(m.slot):\(m.preparing)"
            } else { self.lastBoundary = "" }
            self.ticker?.invalidate()
            self.ticker = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
                Task { @MainActor in self?.tick() }
            }
            self.model?.refreshActivityDisplay()
        } }
    }
    func pause(reason: String? = nil) {
        sequenceID = UUID()
        voice.stop()
        guard clock != nil else { return }
        clock?.pause(at: ProcessInfo.processInfo.systemUptime); session = clock?.session
        ticker?.invalidate(); ticker = nil
        if let reason { caption = reason }
        checkpoint(); model?.refreshActivityDisplay()
    }
    func leave() { pause(); model?.showDefense = false; model?.refreshLobbyMusic() }
    func discard() {
        pause()
        guard let model else { return }
        var candidate = model.save; candidate.profile.defense?.active = nil
        do {
            try model.migrateEquipment(&candidate)
            try model.repository.write(candidate); model.save = candidate
            clock = nil; session = nil; model.showDefense = false; model.refreshLobbyMusic(); model.refreshActivityDisplay()
        } catch { self.error = "종료 상태를 저장하지 못했어요. 진행 기록은 유지돼요." }
    }
    func clearReport() {
        voice.stop()
        guard let model else { return }
        var candidate = model.save; candidate.profile.defense?.pendingReport = nil
        do { try model.repository.write(candidate); model.save = candidate; model.showDefense = false; model.refreshLobbyMusic() }
        catch { self.error = "귀환 보고 확인을 저장하지 못했어요. 다시 시도해주세요." }
    }
    func retryCompletion() { finish() }
    private func tick() {
        guard !isFinishing else { return }
        clock?.advance(to: ProcessInfo.processInfo.systemUptime); session = clock?.session
        guard let session else { return }
        if session.elapsed >= DefenseTimeline.duration { finish(); return }
        if session.paused { pause(reason: "앱 동작이 잠시 멈춰 작전도 일시정지했어요. 준비되면 이어가세요."); return }
        announce()
        if session.elapsed - lastCheckpoint >= 5 { checkpoint() }
    }
    private func checkpoint() {
        guard let model, let session else { return }
        do {
            var candidate = model.save
            try DefenseCampaign.checkpoint(session, in: &candidate)
            try model.repository.write(candidate); model.save = candidate; lastCheckpoint = session.elapsed
        } catch {
            clock?.pause(at: ProcessInfo.processInfo.systemUptime); self.session = clock?.session
            ticker?.invalidate(); ticker = nil; voice.stop()
            self.error = "진행 상태를 저장하지 못해 잠시 멈췄어요. 저장 공간을 확인한 뒤 계속해주세요."
        }
    }
    private func finish() {
        guard let model, let session, session.elapsed >= DefenseTimeline.duration, !isFinishing else { return }
        isFinishing = true; defer { isFinishing = false }
        ticker?.invalidate(); ticker = nil; voice.stop()
        do {
            var candidate = model.save
            try DefenseCampaign.complete(session, at: Date(), in: &candidate)
            try model.migrateEquipment(&candidate)
            try model.repository.write(candidate); model.save = candidate
            clock = nil; self.session = nil; error = nil; caption = lines["defense_done"] ?? "작전 완료"
            voice.play("defense_done"); model.refreshActivityDisplay()
        } catch { self.error = "완료 기록을 저장하지 못했어요. 다시 저장을 눌러주세요. 운동을 다시 할 필요는 없어요." }
    }
    private func announce() {
        guard let m = moment, let session else { return }
        let boundary = "\(m.phase.rawValue):\(m.phaseIndex):\(m.slot):\(m.preparing)"
        guard boundary != lastBoundary else { return }; lastBoundary = boundary
        let prefix = String(format: "defense_%02d", session.episode)
        if session.contentVersion == 2 {
            let keys = DefenseWorkoutAudio.keys(moment: m, episode: session.episode,
                                                intensity: session.intensity, standingOnly: session.standingOnly == true)
            caption = keys.compactMap { lines[$0] }.joined(separator: " ")
            sequenceID = UUID(); playSequence(keys, token: sequenceID)
            return
        }
        let key: String
        switch m.phase {
        case .warmup: key = m.slot == 0 ? prefix + "_brief" : m.slot == 1 ? "defense_warm_step" : m.slot == 2 ? "defense_warm_heel" : "defense_warm_last"
        case .recovery: key = prefix + "_rest\(m.phaseIndex)"
        case .cooldown: key = m.slot == 0 ? "defense_cool" : m.slot == 1 ? prefix + "_outro" : "defense_cool_last"
        case .battle:
            key = m.preparing ? "defense_move_\(m.exercise.rawValue)_\(session.intensity.rawValue)" : "defense_go"
        case .complete: return
        }
        let once = "\(boundary):\(key)"
        guard !delivered.contains(once) else { return }; delivered.insert(once)
        caption = lines[key] ?? ""
        voice.play(key)
    }
    private func playSequence(_ keys: [String], token: UUID) {
        guard token == sequenceID else { return }
        guard let first = keys.first else { return }
        voice.play(first) { [weak self] in DispatchQueue.main.async {
            guard let self, token == self.sequenceID, self.session?.paused == false, self.model?.showDefense == true else { return }
            self.playSequence(Array(keys.dropFirst()), token: token)
        } }
    }
}
