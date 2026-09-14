import Foundation
import SwiftUI
import CoreLocation
import CoreMotion
import UIKit

@MainActor final class AppModel: ObservableObject {
    static var testHarness: Bool {
        #if DEBUG && targetEnvironment(simulator)
        return ProcessInfo.processInfo.arguments.contains("--ui-testing-simulations")
        #else
        return false
        #endif
    }
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
    @Published var showOperator = false
    @Published var showReturnBriefing = false
    var allBosses: [BossDefinition] { (world?.bosses ?? []) + (world.map(BossMutations.all) ?? []) }
    var activeExam: QuestDefinition? { activeQuest?.promotion != nil ? activeQuest : nil }
    var expeditionDate: Date {
        #if DEBUG && targetEnvironment(simulator)
        if Self.testHarness && ProcessInfo.processInfo.arguments.contains("--ui-testing-expedition") {
            return ISO8601DateFormatter().date(from: "2026-09-17T12:00:00+09:00")!
        }
        #endif
        return Date()
    }
    var weeklySurvey: WeeklySurvey { Expeditions.survey(save.profile, at: expeditionDate) }
    func claimWeeklySurvey() {
        guard !growthLocked else { return }
        var candidate = save
        do { try Expeditions.claim(in: &candidate, at: expeditionDate); try repository.write(candidate); save = candidate; interfaceFeedback("ui-reward") }
        catch { notice = "이번 주 조사 조건과 보상 수령 상태를 확인해주세요." }
    }
    func acknowledgeReturn() {
        guard let id = save.profile.expeditions?.briefing?.id else { showReturnBriefing = false; return }
        var candidate = save; Expeditions.acknowledge(id, in: &candidate)
        do { try repository.write(candidate); save = candidate; showReturnBriefing = false }
        catch { notice = "귀환 보고를 저장하지 못했어요. 다시 확인해주세요." }
    }
    var startStoryAfterWelcome = false
    @Published var selectedFieldDemo: String?
    @Published var selectedBoss: String?
    @Published var selectedMode: RunMode = .contract
    @Published var selectedEnvironment: ActivityEnvironment = .outdoor
    @Published var indoorCheckActive = false
    @Published var indoorDetected = false
    @Published var indoorCheckMessage = "아이폰을 들거나 몸에 지니고 편하게 움직여보세요."
    private var indoorCheckTimer: Timer?
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
    @Published var voiceVolume = UserDefaults.standard.object(forKey: "voiceVolume") as? Double ?? 0.85
    @Published var ducking = UserDefaults.standard.object(forKey: "voiceDucking") as? Bool ?? true
    @Published var homeMusicEnabled = (UserDefaults.standard.object(forKey: "homeMusicEnabled") == nil ? true : UserDefaults.standard.bool(forKey: "homeMusicEnabled"))
    @Published var homeMusicVolume = UserDefaults.standard.object(forKey: "homeMusicVolume") as? Double ?? 0.45
    @Published var musicNotice: String?
    @Published var effectsVolume = UserDefaults.standard.object(forKey: "effectsVolume") as? Double ?? 0.35
    @Published var hapticsEnabled = UserDefaults.standard.object(forKey: "hapticsEnabled") as? Bool ?? true
    let lobbyMusic = LobbyMusicPlayer()
    private var sceneActive = true
    private var testingAudio = false
    var indoorRemaining: Double { IndoorDailyLimit.remaining(in: save.profile, on: Date()) }
    var indoorBudgetText: String {
        let remaining = Int(ceil(indoorRemaining))
        return remaining > 0 ? "오늘 남은 실내 활동 · \(remaining / 60)분 \(remaining % 60)초" : "오늘의 실내 활동 60분을 모두 마쳤어요."
    }
    var canStartReal: Bool {
        guard !selectedEnvironment.isIndoor || indoorRemaining > 0 else { return false }
        if let quest = activeExam { return isReady && !recoverable && quest.available(save.profile) }
        guard isReady, !recoverable, modeAllowed(selectedMode) else { return false }
        guard selectedMode == .gate, let id = selectedBoss else { return true }
        guard let boss = allBosses.first(where: { $0.id == id }), let catalog = progressionCatalog else { return false }
        guard boss.requiredBossClear == nil || !selectedEnvironment.isIndoor else { return false }
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
        if !active {
            if engine?.session.isIndoor == true && engine?.session.phase != .finished { pause() }
            if indoorCheckActive { sensor.stop() }
        } else if indoorCheckActive { sensor.start(environment: selectedEnvironment) }
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
    @Published var operatorCaption: String?
    private var voiceVariants = VoiceVariants()
    private let voiceLines: [String: String] = AppModel.resource("audio-lines") ?? [:]
    private let variantCatalog: [String: [String]] = AppModel.resource("audio-variants") ?? [:]
    let narration: NarrationCatalog? = AppModel.resource("narration")
    let narratives: NarrativeCatalog? = AppModel.resource("narrative")
    private var narrationReady: Bool {
        guard let narration else { return false }
        return (try? narration.validate()) != nil && !voiceLines.isEmpty
    }
    private static func resource<T: Decodable>(_ name: String) -> T? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "json"), let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
    let repository: SaveRepository
    let content: GameContent?
    let progressionCatalog: ProgressionCatalog?
    let missions: MissionCatalog?
    let fieldEncounters: EncounterCatalog? = AppModel.resource("encounters")
    let world: WorldContent?
    var stats: CombatStats { progressionCatalog?.stats(for: save.profile) ?? CombatStats() }
    var growthLocked: Bool { engine != nil || save.active != nil || recoverable || !isReady }
    var activeQuest: QuestDefinition? {
        guard let quest = Quests.entry(save.profile.journey?.selectedQuest), save.profile.journey?.completedQuests.contains(quest.id) != true else { return nil }
        return quest
    }
    func interfaceFeedback(_ key: String = "ui-select") {
        guard engine == nil, !testingAudio else { return }
        lobbyMusic.playEffect(key, volume: Float(effectsVolume))
        if hapticsEnabled { UISelectionFeedbackGenerator().selectionChanged() }
    }
    func applyFeedbackSettings() {
        UserDefaults.standard.set(effectsVolume, forKey: "effectsVolume")
        UserDefaults.standard.set(hapticsEnabled, forKey: "hapticsEnabled")
    }
    func selectQuest(_ id: String?) {
        guard !growthLocked else { return }
        var candidate = save
        do {
            try Quests.select(id, save: &candidate); try repository.write(candidate); save = candidate
            if activeExam != nil { selectedBoss = nil; selectedMode = .gate }
            if id != nil { selectedTab = 2; showAssociation = false }
        } catch { notice = "지금 선택할 수 없는 의뢰예요." }
    }
    func claimQuest(_ id: String) { changeGrowth { save, _ in try Quests.claim(id, save: &save); return "의뢰 보상을 받았어요!" } }
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
    private var announcedResult: UUID?
    init() {
        var directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("HunterRun")
        #if DEBUG && targetEnvironment(simulator)
        let arguments = ProcessInfo.processInfo.arguments
        if let flag = arguments.firstIndex(of: "--ui-testing-save"), flag + 1 < arguments.count,
           let identifier = UUID(uuidString: arguments[flag + 1]) {
            directory = FileManager.default.temporaryDirectory.appendingPathComponent("HunterRunUITests").appendingPathComponent(identifier.uuidString)
        }
        #endif
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
        let encountersReady = fieldEncounters.map { (try? $0.validate()) != nil } ?? false
        let existingSave = repository.hasStoredSave
        do {
            save = try repository.load()
            if save.active?.simulated == true && !Self.testHarness { save.active = nil; try repository.write(save) }
            recoverable = save.active != nil
        }
        catch { notice = "저장 파일을 읽지 못했습니다. 원본 보호를 위해 새 활동을 막았습니다."; saveBlocked = true }
        #if DEBUG && targetEnvironment(simulator)
        if Self.testHarness && ProcessInfo.processInfo.arguments.contains("--ui-testing-expedition") {
            var journey = JourneyState(); journey.unlocked = Set((1...16).map { String(format: "M%02d", $0) }); journey.selectedQuest = "wolf-first"
            save.profile.journey = journey
            var growth = save.profile.growth; growth.rank = "S"; growth.departments["observation"] = 2; save.profile.growth = growth
            for offset in 1...3 {
                var fixture = RunSession(targetSeconds: 1200, simulated: false, allowPursuit: false)
                fixture.startedAt = expeditionDate.addingTimeInterval(Double(-offset) * 86400)
                fixture.activeSeconds = 1200; fixture.distance = 1000; fixture.phase = .finished
                fixture.records = ["discovery", "trail"].map { EventRecord(id: $0, title: "단서", outcome: .success, damage: 0, kind: .discovery) }
                _ = Settlement.apply(fixture, to: &save.profile)
            }
            if let parent = world?.bosses.first {
                var cleared = BossState(maximumHP: parent.maximumHP); cleared.remainingHP = 0; cleared.clears = 1
                save.profile.bosses = [parent.id: cleared]
            }
        }
        if Self.testHarness && ProcessInfo.processInfo.arguments.contains("--ui-testing-indoor-exhausted") {
            var fixture = RunSession(targetSeconds: 3600, simulated: false, allowPursuit: false)
            fixture.environment = .indoor; fixture.activeSeconds = 3600; fixture.phase = .finished
            _ = Settlement.apply(fixture, to: &save.profile)
        }
        #endif
        if content == nil || progressionCatalog == nil || missions == nil || world == nil || !narrationReady || !encountersReady { notice = "게임 콘텐츠를 읽지 못했습니다." }
        isReady = content != nil && progressionCatalog != nil && missions != nil && world != nil && narrationReady && encountersReady && !saveBlocked
        if !existingSave { save.profile.introductionSeen = false }
        if let narratives, (try? narratives.validate()) != nil { narratives.refresh(&save.profile) }
        else { isReady = false; notice = "이야기 자료를 읽지 못했어요. 앱 파일을 확인해주세요." }
        showWelcome = isReady && !recoverable && (!existingSave || save.profile.introductionSeen == false || save.profile.journey?.registered != true)
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
        do { try repository.write(candidate); save = candidate; startStoryAfterWelcome = !(candidate.profile.journey?.completed.contains("M01") ?? false); showWelcome = false }
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
    func updateJourney(_ operation: (NarrativeCatalog, inout Profile) throws -> Void) {
        guard !growthLocked, let narratives else { return }
        var candidate = save
        do {
            try operation(narratives, &candidate.profile)
            narratives.refresh(&candidate.profile)
            try repository.write(candidate); save = candidate
        } catch { notice = "변경을 저장하지 못했어요. 입력과 저장 공간을 확인하고 다시 시도해주세요." }
    }
    func registerNames(hunter: String, operatorName: String) {
        updateJourney { catalog, profile in try catalog.register(hunter: hunter, operatorName: operatorName, profile: &profile) }
    }
    func beginDialogue(_ id: String) { updateJourney { try $0.begin(id, profile: &$1) } }
    func advanceDialogue(_ choice: String? = nil) { updateJourney { _ = try $0.advance(choice: choice, profile: &$1) } }
    func rememberPreference(_ key: String, value: String) {
        let allowed = ["drink": ["warm", "cool", "flexible"], "relationshipPreference": ["closer", "partnership", "undecided"]]
        guard allowed[key]?.contains(value) == true else { return }
        if key == "relationshipPreference", save.profile.journey?.completed.contains("R11") != true { return }
        updateJourney { _, profile in profile.journey?.memories[key] = value }
    }
    func updatePermissions() {
        switch sensor.permission {
        case .authorizedAlways, .authorizedWhenInUse: permissionText = sensor.precision ? "위치 허용" : "정확한 위치 꺼짐"
        case .denied, .restricted: permissionText = "위치 권한 필요"
        default: permissionText = "위치 권한 미확인"
        }
    }
    func authorize() { sensor.requestPermission() }
    func beginIndoorCheck() {
        guard engine == nil, !recoverable else { return }
        stopIndoorCheck(); indoorCheckActive = true; indoorDetected = false
        sensor.start(environment: selectedEnvironment)
        indoorCheckTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.indoorCheckActive else { return }
                let status = CMPedometer.authorizationStatus()
                self.indoorDetected = self.sensor.frame(at: Date()).signal == .good
                self.indoorCheckMessage = status == .denied || status == .restricted ? "설정에서 Hunter Run의 동작 및 피트니스 권한을 허용해주세요." :
                    !self.sensor.indoorAvailable ? "이 기기에서는 운동 센서를 사용할 수 없어요." :
                    self.indoorDetected ? "움직임이 잘 감지돼요. 실내 활동을 시작할 수 있어요." : "아이폰을 손에 들거나 주머니에 넣고 몇 초간 움직여보세요."
            }
        }
    }
    func stopIndoorCheck() {
        indoorCheckTimer?.invalidate(); indoorCheckTimer = nil; indoorCheckActive = false
        if engine == nil { sensor.stop() }
    }
    func start(simulated: Bool, seconds: Double, pursuit: Bool, goal: ActivityGoal? = nil, encounterDemo: FieldEncounter? = nil, environment: ActivityEnvironment = .outdoor) {
        guard !simulated || Self.testHarness else { return }
        guard isReady, let content, engine == nil, save.active == nil else { return }
        if !simulated && !environment.isIndoor && sensor.permission != .authorizedAlways && sensor.permission != .authorizedWhenInUse {
            notice = "먼저 위치 권한을 허용해주세요."; sensor.requestPermission(); return
        }
        guard simulated || encounterDemo == nil else { return }
        let requested = goal ?? ActivityGoal(kind: .time, value: seconds)
        guard !environment.isIndoor || requested.kind != .distance else { notice = "실내 활동은 시간 또는 자유 목표로 진행해요."; return }
        if environment.isIndoor && indoorRemaining <= 0 {
            notice = "오늘의 실내 활동 60분을 모두 마쳤어요. 한국 시간 자정에 다시 열려요."; return
        }
        if !simulated && environment.isIndoor {
            guard sensor.indoorAvailable, CMPedometer.authorizationStatus() != .denied, CMPedometer.authorizationStatus() != .restricted,
                  indoorCheckActive, sensor.frame(at: Date()).signal == .good else { notice = "먼저 실내 움직임 확인을 진행해주세요."; return }
        }
        guard requested.isValid else { notice = "활동 목표를 다시 선택해주세요."; return }
        let quest = simulated ? nil : activeExam
        guard quest == nil || quest!.available(save.profile) else { notice = "의뢰 조건을 다시 확인해주세요."; return }
        let mode: RunMode = quest == nil ? selectedMode : quest?.promotion == nil ? .contract : .gate
        guard (simulated || quest?.promotion != nil || modeAllowed(mode)), requested.kind != .time || requested.value <= 1800 || unlocked("extended-contract") else { notice = "협회 성장 또는 헌터 평가가 필요한 의뢰입니다."; return }
        var mission = missions?.content(for: mode, extended: seconds >= 1200 && unlocked("extended-contract")) ?? content
        var session = RunSession(targetSeconds: seconds, simulated: simulated, allowPursuit: pursuit, mode: mode, loadout: stats)
        session.environment = environment; session.steps = environment.isIndoor ? 0 : nil
        IndoorDailyLimit.prepare(&session, profile: save.profile)
        if environment.isIndoor { session.allowPursuit = false; session.paceObservation = nil }
        session.questID = quest?.id
        if let definition = quest?.boss {
            session.mode = .gate
            let state = BossCampaign.state(definition, profile: save.profile)
            guard state.remainingHP > 0 else { notice = "심사 토벌을 완료했어요. 헌터 화면에서 결과를 확인해주세요."; return }
            session.boss = BossEncounter(definition: definition, state: state); mission = session.boss!.content
        } else if quest == nil && selectedMode == .gate, let id = selectedBoss {
            guard let boss = allBosses.first(where: { $0.id == id }), let catalog = progressionCatalog,
                  (simulated || boss.available(to: save.profile, catalog: catalog)) else { notice = "주요 보스 토벌 조건을 확인해주세요."; return }
            guard boss.requiredBossClear == nil || !environment.isIndoor else { notice = "변이 토벌은 야외에서 진행해요. 일반 실내 활동은 계속 이용할 수 있어요."; return }
            let state = simulated ? BossState(maximumHP: boss.maximumHP) : BossCampaign.state(boss, profile: save.profile)
            guard state.remainingHP > 0 else { notice = "토벌을 완료했습니다. 토벌 게시판에서 새로운 회차를 열 수 있습니다."; return }
            let encounter = BossEncounter(definition: boss, state: state)
            session.boss = encounter; mission = encounter.content
        }
        if session.boss == nil, let catalog = progressionCatalog, let fieldEncounters {
            mission = fieldEncounters.populate(mission, mode: selectedMode, profile: save.profile, catalog: catalog)
        }
        applyAudio()
        if simulated, let encounterDemo { mission = encounterDemo.preview; mockRate = 10 }
        lobbyMusic.stop(); testingAudio = false
        displayedPace.reset(); currentSpeed = 0
        session.learnedReference = simulated || environment.isIndoor ? nil : save.profile.paceMemory?.reference
        session.goal = requested
        session.directorVersion = 2
        session.missionSnapshot = mission
        stopIndoorCheck()
        engine = RunEngine(session: session, content: mission, attack: save.profile.attack)
        mockTime = Date().timeIntervalSince1970
        lastSummary = nil; lastDemo = nil; resultSaved = true; notice = nil; showRun = true
        if !simulated { sensor.start(environment: environment) }
        persist()
        beginTimer()
        playOperator(quest?.promotion != nil ? "exam_start" : quest != nil ? "quest_start" : "run_start")
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
                if key == "run_end" { continue } // Finish announces only after the result is saved.
                let id = current.session.event?.template.id
                let rebrief = key == "resume" && current.session.event?.stage == .briefing
                let logicalKey = rebrief ? (current.session.event?.instructionAudio ?? key) : key
                let playbackKey = narration?.response(to: logicalKey, session: current.session) ?? logicalKey
                let isInstruction = current.session.event?.stage == .briefing && playbackKey == current.session.event?.instructionAudio
                playOperator(playbackKey) { [weak self] in
                    DispatchQueue.main.async {
                        guard isInstruction, let self, self.engine?.session.event?.template.id == id,
                              self.engine?.session.event?.stage == .briefing,
                              self.engine?.session.event?.instructionAudio == playbackKey,
                              self.engine?.session.manualPause == false else { return }
                        self.engine?.instructionFinished(); self.persist()
                    }
                }
            }
        }
    }
    func pause() { engine?.pause(true); if engine?.session.isIndoor == true { sensor.stop() }; displayedPace.reset(); currentSpeed = 0; audio.stop(); operatorCaption = voiceLines["pause"]; persist() }
    func resume() {
        if let run = engine?.session, run.isIndoor && !run.simulated { sensor.start(environment: run.activityEnvironment) }
        displayedPace.reset(); currentSpeed = 0
        engine?.pause(false)
        if let event = engine?.session.event, event.stage == .briefing {
            playOperator(event.instructionAudio) { [weak self] in
                DispatchQueue.main.async { self?.engine?.instructionFinished(); self?.persist() }
            }
        } else { playOperator("resume") }
        persist()
    }
    func interruption() {
        testingAudio = false
        guard engine != nil else { return }
        engine?.interrupt(true); engine?.interrupt(false)
        if engine?.session.isIndoor == true { sensor.stop() }
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
        if !run.simulated { narratives?.refresh(&save.profile) }
        save.active = nil
        do { try repository.write(save); lastSaveAt = Date(); resultSaved = true; notice = nil }
        catch { resultSaved = false; notice = "결과 저장에 실패했습니다. 앱을 종료하지 말고 다시 저장해주세요."; return }
        recoverable = false
        if announcedResult != run.id {
            announcedResult = run.id
            let questDone = run.questID.map { save.profile.journey?.completedQuests.contains($0) == true } ?? false
            playOperator(questDone ? (run.boss != nil ? "exam_pass" : "quest_complete") : "run_end")
        }
    }
    func closeResult() { guard resultSaved else { return }; engine = nil; showRun = false; audio.stop(); refreshLobbyMusic() }
    func recover() {
        guard var run = save.active, let content else { return }
        IndoorDailyLimit.prepare(&run, profile: save.profile)
        displayedPace.reset(); currentSpeed = 0
        lobbyMusic.stop(); testingAudio = false
        engine = RunEngine(session: run, content: run.missionSnapshot ?? content, attack: save.profile.attack)
        if run.phase == .finished { finish(); showRun = true; return }
        engine?.restorePaused(); recoverable = false; showRun = true
        mockTime = Date().timeIntervalSince1970
        if !run.simulated && !run.isIndoor { sensor.start(environment: run.activityEnvironment) }
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
            narratives?.refresh(&candidate.profile)
            try repository.write(candidate)
            save = candidate; notice = message; interfaceFeedback("ui-reward")
        } catch { notice = (error as? ProgressionError)?.localizedDescription ?? "저장하지 못해 변경을 적용하지 않았습니다." }
    }
    func prepareFieldDemo(_ encounter: FieldEncounter) {
        guard !growthLocked else { return }
        selectedFieldDemo = encounter.id; selectedBoss = nil; selectedMode = .contract
        showAssociation = false; selectedTab = 2
    }
    func prepareBoss(_ boss: BossDefinition, simulated: Bool = false) {
        guard let catalog = progressionCatalog, (simulated || boss.available(to: save.profile, catalog: catalog)) else { notice = "필요한 등급과 관측부 레벨을 먼저 달성해주세요."; return }
        guard !growthLocked else { return }
        if activeExam != nil { selectQuest(nil) }
        guard activeExam == nil else { return }
        if boss.requiredBossClear != nil { selectedEnvironment = .outdoor }
        selectedFieldDemo = nil; selectedBoss = boss.id; selectedMode = .gate; showAssociation = false; selectedTab = 2
    }
    func restartBoss(_ boss: BossDefinition) {
        changeGrowth { save, catalog in try BossCampaign.restart(boss, save: &save, catalog: catalog); return "새 토벌 회차를 열었습니다." }
    }
    func buy(_ id: String) { changeGrowth { save, catalog in try Progression.buy(id, save: &save, catalog: catalog); return "장비를 확보했습니다. 장착하면 다음 활동부터 적용됩니다." } }
    func equip(_ id: String) { changeGrowth { save, catalog in try Progression.equip(id, save: &save, catalog: catalog); return nil } }
    func upgrade(_ department: Department) { changeGrowth { save, catalog in try Progression.upgrade(department, save: &save, catalog: catalog) } }
    func promote() { changeGrowth { save, _ in try Progression.promote(save: &save); return "협회 평가를 통과했습니다. \(save.profile.growth.rank)급 헌터로 등록되었습니다." } }
    private func playOperator(_ key: String, completion: (() -> Void)? = nil) {
        let clip = voiceVariants.select(key == "indoor_hold" ? "resume" : key, catalog: variantCatalog)
        operatorCaption = voiceLines[clip]
        audio.play(clip, completion: completion)
    }
    func playDispatch(_ entry: StoryEntry) {
        guard !growthLocked, StoryProgress.available(entry, profile: save.profile) else { return }
        previewAudio("dispatch_" + entry.id)
    }
    func audioTest() { previewAudio("audio_test") }
    private func previewAudio(_ key: String) {
        guard engine == nil else { return }
        lobbyMusic.stop(); testingAudio = true
        audio.ducking = ducking; audio.volume = Float(voiceVolume)
        playOperator(key) { [weak self] in
            DispatchQueue.main.async { self?.testingAudio = false; self?.refreshLobbyMusic() }
        }
    }
    func applyAudio() {
        UserDefaults.standard.set(voiceVolume, forKey: "voiceVolume"); UserDefaults.standard.set(ducking, forKey: "voiceDucking")
        audio.ducking = ducking; audio.volume = Float(voiceVolume)
    }
    func playStorySummary(_ id: String) {
        let key = ["M01": "story_welcome", "M06": "exam_pass", "M13": "exam_pass", "M16": "story_return"][id]
        guard let key, save.profile.journey?.unlocked.contains(id) == true else { return }
        previewAudio(key)
    }
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
            var imported = try JSONDecoder().decode(SaveState.self, from: Data(contentsOf: url))
            try repository.validate(imported)
            if imported.active?.simulated == true && !Self.testHarness { imported.active = nil }
            narratives?.refresh(&imported.profile)
            if let cursor = imported.profile.journey?.cursor,
               narratives?.scene(cursor.sceneID)?.node(cursor.nodeID) == nil {
                imported.profile.journey?.cursor = nil
            }
            try repository.write(imported); save = imported
            saveBlocked = false
            isReady = content != nil && progressionCatalog != nil && missions != nil && world != nil && narrationReady
                && fieldEncounters.map { (try? $0.validate()) != nil } == true
                && narratives.map { (try? $0.validate()) != nil } == true
            recoverable = save.active != nil; selectedBoss = nil; selectedFieldDemo = nil; lastSummary = nil
            notice = "백업을 불러왔어요."
        } catch { notice = "호환되는 Hunter Run 백업 파일이 아닙니다." }
    }
    func resetProgress() {
        guard engine == nil, save.active == nil else { notice = "진행 중인 활동을 먼저 마쳐주세요."; return }
        do {
            save = try repository.reset(); narratives?.refresh(&save.profile)
            saveBlocked = false; recoverable = false; selectedBoss = nil; selectedFieldDemo = nil
            selectedMode = .contract; lastSummary = nil; lastDemo = nil; selectedTab = 0
            showSettings = false; showWelcome = true
            notice = nil
        } catch { notice = "진행도를 초기화하지 못했어요. 저장 공간을 확인해주세요." }
    }
    func diagnostics() -> URL? {
        let run = engine?.session
        let report = """
        Hunter Run 1.0.0
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
