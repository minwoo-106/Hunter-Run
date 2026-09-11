import Foundation
import SwiftUI
import CoreLocation
import UIKit

@MainActor final class AppModel: ObservableObject {
    @Published var save = SaveState()
    @Published var engine: RunEngine?
    @Published var notice: String?
    @Published var recoverable = false
    @Published var selectedTab = 0
    @Published var showRun = false
    @Published var showAssociation = false
    @Published var showSettings = false
    var replayWelcomeAfterSettings = false
    @Published var showWelcome = false
    @Published var showStories = false
    @Published var selectedBoss: String?
    @Published var selectedMode: RunMode = .contract
    @Published var mockMovement: Movement = .running
    @Published var mockSignal: Signal = .good
    @Published var mockSpeed = 2.6
    @Published var mockRate = 1
    @Published var currentSpeed = 0.0
    private var displayedPace = DisplayedPace()
    @Published var signal: Signal = .unavailable
    @Published var movement: Movement = .unknown
    @Published var permissionText = "미확인"
    @Published var isReady = false
    @Published var lastSummary: RunSummary?
    @Published var lastDemo: RunSession?
    @Published var voiceVolume = 0.85
    @Published var ducking = true
    @Published var homeMusicEnabled = (UserDefaults.standard.object(forKey: "homeMusicEnabled") == nil ? true : UserDefaults.standard.bool(forKey: "homeMusicEnabled"))
    @Published var homeMusicVolume = UserDefaults.standard.object(forKey: "homeMusicVolume") as? Double ?? 0.45
    @Published var musicNotice: String?
    let lobbyMusic = LobbyMusicPlayer()
    private var sceneActive = true
    private var testingAudio = false
    var canStartReal: Bool {
        guard isReady, !recoverable, modeAllowed(selectedMode) else { return false }
        guard selectedMode == .gate, let id = selectedBoss else { return true }
        guard let boss = world?.bosses.first(where: { $0.id == id }), let catalog = progressionCatalog else { return false }
        return boss.available(to: save.profile, catalog: catalog) && BossCampaign.state(boss, profile: save.profile).remainingHP > 0
    }
    func refreshLobbyMusic() {
        var context = LobbyMusicContext()
        context.tab = selectedTab; context.associationPresented = showAssociation
        context.runPresented = showRun; context.hasRun = engine != nil
        context.foreground = sceneActive; context.enabled = homeMusicEnabled; context.testingVoice = testingAudio
        if context.shouldPlay {
            lobbyMusic.play(volume: Float(homeMusicVolume))
        } else { lobbyMusic.stop() }
    }
    func sceneChanged(active: Bool) {
        sceneActive = active
        if active { lobbyMusic.allowPlayback() }
        refreshLobbyMusic()
        refreshActivityDisplay()
    }
    /// Only prevent automatic locking during a presented, unfinished activity.
    /// Backgrounding, results and normal browsing return control to iOS.
    func refreshActivityDisplay() {
        UIApplication.shared.isIdleTimerDisabled = sceneActive && showRun && engine != nil && engine?.session.phase != .finished
    }
    func applyHomeMusic() {
        UserDefaults.standard.set(homeMusicEnabled, forKey: "homeMusicEnabled")
        UserDefaults.standard.set(homeMusicVolume, forKey: "homeMusicVolume")
        musicNotice = nil; lobbyMusic.allowPlayback(); refreshLobbyMusic()
    }
    let sensor = SensorProbe()
    let audio = AudioDirector()
    let repository: SaveRepository
    let content: GameContent?
    let progressionCatalog: ProgressionCatalog?
    let missions: MissionCatalog?
    let world: WorldContent?
    var stats: CombatStats { progressionCatalog?.stats(for: save.profile) ?? CombatStats() }
    var growthLocked: Bool { engine != nil || save.active != nil || recoverable || !isReady }
    func unlocked(_ action: String) -> Bool { progressionCatalog?.unlocked(action, profile: save.profile) ?? false }
    func modeAllowed(_ mode: RunMode) -> Bool {
        guard let progressionCatalog else { return false }
        return Progression.allows(mode, profile: save.profile, catalog: progressionCatalog)
    }
    private var timer: Timer?
    private var lastSaveAt = Date.distantPast
    private var mockTime: Double = 0
    @Published var resultSaved = true
    private var saveBlocked = false
    init() {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("HunterRun")
        repository = SaveRepository(directory: directory)
        if let url = Bundle.main.url(forResource: "mission", withExtension: "json"),
           let data = try? Data(contentsOf: url), let decoded = try? JSONDecoder().decode(GameContent.self, from: data),
           (try? decoded.validate()) != nil { content = decoded }
        else { content = nil }
        if let url = Bundle.main.url(forResource: "progression", withExtension: "json"),
           let data = try? Data(contentsOf: url), let decoded = try? JSONDecoder().decode(ProgressionCatalog.self, from: data),
           (try? decoded.validate()) != nil { progressionCatalog = decoded } else { progressionCatalog = nil }
        if let url = Bundle.main.url(forResource: "missions", withExtension: "json"),
           let data = try? Data(contentsOf: url), let decoded = try? JSONDecoder().decode(MissionCatalog.self, from: data),
           (try? decoded.validate()) != nil { missions = decoded } else { missions = nil }
        if let url = Bundle.main.url(forResource: "world", withExtension: "json"),
           let data = try? Data(contentsOf: url), let decoded = try? JSONDecoder().decode(WorldContent.self, from: data),
           (try? decoded.validate()) != nil { world = decoded } else { world = nil }
        let existingSave = repository.hasStoredSave
        do { save = try repository.load(); recoverable = save.active != nil }
        catch { notice = "저장 파일을 읽지 못했습니다. 원본 보호를 위해 새 활동을 막았습니다."; saveBlocked = true }
        if content == nil || progressionCatalog == nil || missions == nil || world == nil { notice = "게임 콘텐츠를 읽지 못했습니다." }
        isReady = content != nil && progressionCatalog != nil && missions != nil && world != nil && !saveBlocked
        if !existingSave { save.profile.introductionSeen = false }
        showWelcome = isReady && (!existingSave || save.profile.introductionSeen == false)
        #if targetEnvironment(simulator)
        if ProcessInfo.processInfo.arguments.contains("--ui-testing-skip-welcome") { showWelcome = false }
        #endif
        sensor.onUpdate = { [weak self] in
            guard let self else { return }
            self.updatePermissions()
            if self.engine?.session.simulated == false { self.tick() }
        }
        lobbyMusic.onFailure = { [weak self] message in DispatchQueue.main.async { self?.musicNotice = message } }
        audio.onInterruption = { [weak self] in
            DispatchQueue.main.async { self?.interruption() }
        }
        audio.onFailure = { [weak self] message in
            DispatchQueue.main.async {
                guard let self else { return }
                self.notice = message; self.testingAudio = false
                if self.engine != nil { self.engine?.pause(true); self.persist() }
            }
        }
    }
    func completeWelcome() {
        guard !saveBlocked else { return }
        var candidate = save; candidate.profile.introductionSeen = true
        do { try repository.write(candidate); save = candidate; showWelcome = false }
        catch { notice = "안내 확인을 저장하지 못했습니다. 다시 시도해주세요." }
    }
    func resetPaceMemory() {
        guard !growthLocked else { notice = "활동을 마친 뒤 기준을 초기화해주세요."; return }
        var candidate = save; candidate.profile.paceMemory = nil
        do { try repository.write(candidate); save = candidate }
        catch { notice = "기준을 초기화하지 못했습니다. 다시 시도해주세요." }
    }
    func readStory(_ id: String) {
        guard isReady, !growthLocked else { notice = "활동을 마친 뒤 통신 기록을 확인해주세요."; return }
        var candidate = save
        guard StoryProgress.markRead(id, profile: &candidate.profile) else { return }
        do { try repository.write(candidate); save = candidate }
        catch { notice = "읽음 표시를 저장하지 못했습니다. 다시 시도해주세요." }
    }
    func updatePermissions() {
        switch sensor.permission {
        case .authorizedAlways, .authorizedWhenInUse: permissionText = sensor.precision ? "위치 허용" : "정확한 위치 꺼짐"
        case .denied, .restricted: permissionText = "위치 권한 필요"
        default: permissionText = "위치 권한 미확인"
        }
    }
    func authorize() { sensor.requestPermission() }
    func start(simulated: Bool, seconds: Double, pursuit: Bool, goal: ActivityGoal? = nil) {
        guard isReady, let content, engine == nil, save.active == nil else { return }
        if !simulated && sensor.permission != .authorizedAlways && sensor.permission != .authorizedWhenInUse {
            notice = "먼저 위치 권한을 허용해주세요."; sensor.requestPermission(); return
        }
        let requested = goal ?? ActivityGoal(kind: .time, value: seconds)
        guard requested.isValid else { notice = "활동 목표를 다시 선택해주세요."; return }
        guard (simulated || modeAllowed(selectedMode)), requested.kind != .time || requested.value <= 1800 || unlocked("extended-contract") else { notice = "협회 성장 또는 헌터 평가가 필요한 의뢰입니다."; return }
        var mission = missions?.content(for: selectedMode, extended: seconds >= 1200 && unlocked("extended-contract")) ?? content
        var session = RunSession(targetSeconds: seconds, simulated: simulated, allowPursuit: pursuit, mode: selectedMode, loadout: stats)
        if selectedMode == .gate, let id = selectedBoss {
            guard let boss = world?.bosses.first(where: { $0.id == id }), let catalog = progressionCatalog,
                  (simulated || boss.available(to: save.profile, catalog: catalog)) else { notice = "주요 보스 토벌 조건을 확인해주세요."; return }
            let state = simulated ? BossState(maximumHP: boss.maximumHP) : BossCampaign.state(boss, profile: save.profile)
            guard state.remainingHP > 0 else { notice = "토벌을 완료했습니다. 토벌 게시판에서 새로운 회차를 열 수 있습니다."; return }
            let encounter = BossEncounter(definition: boss, state: state)
            session.boss = encounter; mission = encounter.content
        }
        lobbyMusic.stop(); testingAudio = false
        displayedPace.reset(); currentSpeed = 0
        session.learnedReference = simulated ? nil : save.profile.paceMemory?.reference
        session.goal = requested
        session.directorVersion = 1
        session.missionSnapshot = mission
        engine = RunEngine(session: session, content: mission, attack: save.profile.attack)
        mockTime = Date().timeIntervalSince1970
        lastSummary = nil; lastDemo = nil; resultSaved = true; notice = nil; showRun = true
        if !simulated { sensor.start() }
        persist()
        beginTimer()
        audio.play("run_start")
    }
    private func beginTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }
    func tick() {
        guard engine != nil else { return }
        if engine?.session.simulated == true {
            for _ in 0..<mockRate {
                mockTime += 1
                process(SensorFrame(timestamp: mockTime, speed: mockSpeed, distance: mockMovement == .running || mockMovement == .walking ? mockSpeed : 0, movement: mockMovement, signal: mockSignal))
                if engine?.session.phase == .finished { break }
            }
        } else { process(sensor.frame(at: Date())) }
        if Date().timeIntervalSince(lastSaveAt) >= 10 { persist() }
    }
    private func process(_ frame: SensorFrame) {
        displayedPace.update(frame, paused: engine?.session.manualPause == true || engine?.session.interruption == true)
        currentSpeed = displayedPace.speed ?? 0; signal = frame.signal; movement = frame.movement
        guard var current = engine else { return }
        let cues = current.consume(frame); engine = current
        for cue in cues {
            switch cue {
            case .checkpoint: persist()
            case .goalReached: finish()
            case .voice(let key):
                let id = current.session.event?.template.id
                let rebrief = key == "resume" && current.session.event?.stage == .briefing
                let playbackKey = rebrief ? (current.session.event?.template.audio ?? key) : key
                let isInstruction = current.session.event?.stage == .briefing && playbackKey == current.session.event?.template.audio
                audio.play(playbackKey) { [weak self] in
                    DispatchQueue.main.async {
                        guard isInstruction, let self, self.engine?.session.event?.template.id == id else { return }
                        self.engine?.instructionFinished(); self.persist()
                    }
                }
            }
        }
    }
    func pause() { engine?.pause(true); displayedPace.reset(); currentSpeed = 0; audio.stop(); persist() }
    func resume() {
        displayedPace.reset(); currentSpeed = 0
        engine?.pause(false)
        if let event = engine?.session.event, event.stage == .briefing {
            audio.play(event.template.audio) { [weak self] in
                DispatchQueue.main.async { self?.engine?.instructionFinished(); self?.persist() }
            }
        } else { audio.play("resume") }
        persist()
    }
    func interruption() {
        testingAudio = false
        guard engine != nil else { return }
        engine?.interrupt(true); engine?.interrupt(false)
        displayedPace.reset(); currentSpeed = 0
        notice = "통화 또는 이어폰 변경으로 일시정지했습니다. 안전한 곳에서 재개해주세요."
        persist()
    }
    func finish() {
        guard engine != nil else { return }
        engine?.end(); sensor.stop(); timer?.invalidate(); timer = nil
        guard let run = engine?.session else { return }
        if run.simulated { lastDemo = run }
        else if let summary = Settlement.apply(run, to: &save.profile) { lastSummary = summary }
        save.active = nil
        do { try repository.write(save); lastSaveAt = Date(); resultSaved = true; notice = nil }
        catch { resultSaved = false; notice = "결과 저장에 실패했습니다. 앱을 종료하지 말고 다시 저장해주세요."; return }
        recoverable = false
    }
    func closeResult() { guard resultSaved else { return }; engine = nil; showRun = false; audio.stop(); refreshLobbyMusic() }
    func recover() {
        guard let run = save.active, let content else { return }
        displayedPace.reset(); currentSpeed = 0
        lobbyMusic.stop(); testingAudio = false
        engine = RunEngine(session: run, content: run.missionSnapshot ?? content, attack: save.profile.attack)
        if run.phase == .finished { finish(); showRun = true; return }
        engine?.restorePaused(); recoverable = false; showRun = true
        mockTime = Date().timeIntervalSince1970
        if !run.simulated { sensor.start() }
        beginTimer(); persist()
    }
    func endRecovered() { recover(); finish() }
    func recoveryDrill() {
        guard engine?.session.simulated == true else { return }
        persist(); timer?.invalidate(); timer = nil; audio.stop()
        engine = nil; showRun = false; recoverable = true
    }
    func persist() {
        guard !saveBlocked else { return }
        if let current = engine, current.session.phase != .finished { save.active = current.session }
        do { try repository.write(save); lastSaveAt = Date() }
        catch { notice = "저장하지 못했습니다. 저장 공간을 확인해주세요." }
    }
    func nameChanged(_ name: String) { save.profile.name = String(name.prefix(16)); persist() }
    func changeGrowth(_ operation: (inout SaveState, ProgressionCatalog) throws -> String?) {
        guard !growthLocked, let progressionCatalog else { notice = "진행 중인 활동을 마친 뒤 변경해주세요."; return }
        var candidate = save
        do {
            let message = try operation(&candidate, progressionCatalog)
            try repository.write(candidate)
            save = candidate; notice = message
        } catch { notice = (error as? ProgressionError)?.localizedDescription ?? "저장하지 못해 변경을 적용하지 않았습니다." }
    }
    func prepareBoss(_ boss: BossDefinition, simulated: Bool = false) {
        guard let catalog = progressionCatalog, (simulated || boss.available(to: save.profile, catalog: catalog)) else { notice = "필요한 등급과 관측부 레벨을 먼저 달성해주세요."; return }
        selectedBoss = boss.id; selectedMode = .gate; showAssociation = false; selectedTab = 2
    }
    func restartBoss(_ boss: BossDefinition) {
        changeGrowth { save, catalog in try BossCampaign.restart(boss, save: &save, catalog: catalog); return "새 토벌 회차를 열었습니다." }
    }
    func buy(_ id: String) { changeGrowth { save, catalog in try Progression.buy(id, save: &save, catalog: catalog); return "장비를 확보했습니다. 장착하면 다음 활동부터 적용됩니다." } }
    func equip(_ id: String) { changeGrowth { save, catalog in try Progression.equip(id, save: &save, catalog: catalog); return nil } }
    func upgrade(_ department: Department) { changeGrowth { save, catalog in try Progression.upgrade(department, save: &save, catalog: catalog) } }
    func promote() { changeGrowth { save, _ in try Progression.promote(save: &save); return "협회 평가를 통과했습니다. \(save.profile.growth.rank)급 헌터로 등록되었습니다." } }
    func audioTest() { previewAudio("audio_test") }
    private func previewAudio(_ key: String) {
        guard engine == nil else { return }
        lobbyMusic.stop(); testingAudio = true
        audio.ducking = ducking; audio.volume = Float(voiceVolume)
        audio.play(key) { [weak self] in
            DispatchQueue.main.async { self?.testingAudio = false; self?.refreshLobbyMusic() }
        }
    }
    func applyAudio() { audio.ducking = ducking; audio.volume = Float(voiceVolume) }
    func stopAudioPreview() {
        guard testingAudio, engine == nil else { return }
        audio.stop(); testingAudio = false; refreshLobbyMusic()
    }
    func exportSave() -> URL? {
        do {
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("HunterRun-backup.json")
            try JSONEncoder().encode(save).write(to: url, options: .atomic)
            return url
        } catch { notice = "백업 파일을 만들지 못했습니다."; return nil }
    }
    func importSave(_ url: URL) {
        guard engine == nil, save.active == nil else { notice = "진행 중인 활동을 먼저 종료해주세요."; return }
        let granted = url.startAccessingSecurityScopedResource()
        defer { if granted { url.stopAccessingSecurityScopedResource() } }
        do {
            let imported = try JSONDecoder().decode(SaveState.self, from: Data(contentsOf: url))
            try repository.validate(imported)
            try repository.write(imported); save = imported
            saveBlocked = false; isReady = content != nil && progressionCatalog != nil && missions != nil && world != nil; recoverable = save.active != nil
        } catch { notice = "호환되는 Hunter Run 백업 파일이 아닙니다." }
    }
    func diagnostics() -> URL? {
        let run = engine?.session
        let report = """
        Hunter Run 0.8.0 operator voice and artwork
        Device: \(UIDevice.current.model)
        iOS: \(UIDevice.current.systemVersion)
        Location: \(permissionText)
        Signal: \(signal.rawValue)
        Movement: \(movement.rawValue)
        Activity seconds: \(run?.activeSeconds ?? 0)
        Distance meters: \(run?.distance ?? 0)
        Phase: \(run?.phase.rawValue ?? "idle")
        Simulated: \(run?.simulated ?? false)
        Last location error: \(sensor.lastError ?? "none")
        No raw coordinates, names or device identifiers included.
        """
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("HunterRun-diagnostics.txt")
        do { try report.write(to: url, atomically: true, encoding: .utf8); return url }
        catch { notice = "진단 파일을 만들지 못했습니다."; return nil }
    }
}
