import Foundation
import SwiftUI
import CoreLocation

@MainActor final class AppModel: ObservableObject {
    @Published var save = SaveState()
    @Published var engine: RunEngine?
    @Published var notice: String?
    @Published var recoverable = false
    @Published var selectedTab = 0
    @Published var showRun = false
    @Published var mockMovement: Movement = .running
    @Published var mockSignal: Signal = .good
    @Published var mockSpeed = 2.6
    @Published var mockRate = 1
    @Published var currentSpeed = 0.0
    @Published var signal: Signal = .unavailable
    @Published var movement: Movement = .unknown
    @Published var permissionText = "미확인"
    @Published var isReady = false
    @Published var lastSummary: RunSummary?
    @Published var lastDemo: RunSession?
    @Published var voiceVolume = 0.85
    @Published var ducking = true
    let sensor = SensorProbe()
    let audio = AudioDirector()
    let repository: SaveRepository
    let content: GameContent?
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
        do { save = try repository.load(); recoverable = save.active != nil }
        catch { notice = "저장 파일을 읽지 못했습니다. 원본 보호를 위해 새 활동을 막았습니다."; saveBlocked = true }
        if content == nil { notice = "의뢰 데이터를 읽지 못했습니다." }
        isReady = content != nil && !saveBlocked
        sensor.onUpdate = { [weak self] in
            guard let self else { return }
            self.updatePermissions()
            if self.engine?.session.simulated == false { self.tick() }
        }
        audio.onInterruption = { [weak self] in
            DispatchQueue.main.async { self?.interruption() }
        }
        audio.onFailure = { [weak self] message in
            DispatchQueue.main.async {
                guard let self else { return }
                self.notice = message
                if self.engine != nil { self.engine?.pause(true); self.persist() }
            }
        }
    }
    func updatePermissions() {
        switch sensor.permission {
        case .authorizedAlways, .authorizedWhenInUse: permissionText = sensor.precision ? "위치 허용" : "정확한 위치 꺼짐"
        case .denied, .restricted: permissionText = "위치 권한 필요"
        default: permissionText = "위치 권한 미확인"
        }
    }
    func authorize() { sensor.requestPermission() }
    func start(simulated: Bool, seconds: Double, pursuit: Bool) {
        guard isReady, let content, engine == nil, save.active == nil else { return }
        if !simulated && sensor.permission != .authorizedAlways && sensor.permission != .authorizedWhenInUse {
            notice = "먼저 위치 권한을 허용해주세요."; sensor.requestPermission(); return
        }
        let session = RunSession(targetSeconds: seconds, simulated: simulated, allowPursuit: pursuit)
        engine = RunEngine(session: session, content: content, attack: save.profile.attack)
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
        currentSpeed = frame.speed; signal = frame.signal; movement = frame.movement
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
    func pause() { engine?.pause(true); audio.stop(); persist() }
    func resume() {
        engine?.pause(false)
        if let event = engine?.session.event, event.stage == .briefing {
            audio.play(event.template.audio) { [weak self] in
                DispatchQueue.main.async { self?.engine?.instructionFinished(); self?.persist() }
            }
        } else { audio.play("resume") }
        persist()
    }
    func interruption() {
        guard engine != nil else { return }
        engine?.interrupt(true); engine?.interrupt(false)
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
    func closeResult() { guard resultSaved else { return }; engine = nil; showRun = false; audio.stop() }
    func recover() {
        guard let run = save.active, let content else { return }
        engine = RunEngine(session: run, content: content, attack: save.profile.attack)
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
    func upgrade() {
        guard save.profile.observationLevel == 1, save.profile.research >= 3 else { return }
        save.profile.research -= 3; save.profile.observationLevel = 2; persist()
    }
    func audioTest() { audio.ducking = ducking; audio.volume = Float(voiceVolume); audio.play("audio_test") }
    func applyAudio() { audio.ducking = ducking; audio.volume = Float(voiceVolume) }
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
            saveBlocked = false; isReady = content != nil; recoverable = save.active != nil
        } catch { notice = "호환되는 Hunter Run 백업 파일이 아닙니다." }
    }
    func diagnostics() -> URL? {
        let run = engine?.session
        let report = """
        Hunter Run 0.1 technical demo
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
