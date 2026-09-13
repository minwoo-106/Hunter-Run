import SwiftUI
import UniformTypeIdentifiers

@main struct HunterRunApp: App {
    @StateObject private var model = AppModel()
    @Environment(\.scenePhase) private var scenePhase
    var body: some Scene {
        WindowGroup {
            content.environmentObject(model).preferredColorScheme(.dark)
                .onChange(of: scenePhase) { _, phase in
                    model.sceneChanged(active: phase == .active)
                    if phase != .active { model.persist() }
                }
        }
    }
    @ViewBuilder private var content: some View {
#if DEBUG && targetEnvironment(simulator)
        if ProcessInfo.processInfo.arguments.contains("--ui-testing-portrait") {
            OperatorVisualCheckView()
        } else { LaunchGateView() }
#else
        LaunchGateView()
#endif
    }
}
enum Theme {
    static let ink = Color(red: 0.035, green: 0.065, blue: 0.09)
    static let teal = Color(red: 0.23, green: 0.86, blue: 0.83)
    static let muted = Color(red: 0.64, green: 0.71, blue: 0.76)
}
struct RootView: View {
    @EnvironmentObject var model: AppModel
    var body: some View {
        VStack(spacing: 0) {
        TabView(selection: $model.selectedTab) {
            HomeView().toolbar(.hidden, for: .tabBar).tag(0).tabItem { Label("홈", systemImage: "house") }
            HunterView().toolbar(.hidden, for: .tabBar).tag(1).tabItem { Label("헌터", systemImage: "person.crop.circle") }
            SetupView().toolbar(.hidden, for: .tabBar).tag(2).tabItem { Label("헌터 활동", systemImage: "figure.run") }
            CodexView().toolbar(.hidden, for: .tabBar).tag(4).tabItem { Label("도감", systemImage: "book") }
        }
        .toolbar(.hidden, for: .tabBar)
        HunterTabBar()
        }
        .background(Theme.ink.ignoresSafeArea())
        .tint(Theme.teal)
        .onAppear { model.refreshLobbyMusic(); model.refreshActivityDisplay() }
        .onChange(of: model.selectedTab) { _, _ in model.refreshLobbyMusic() }
        .onChange(of: model.showAssociation) { _, _ in model.refreshLobbyMusic() }
        .onChange(of: model.showRun) { _, _ in model.refreshLobbyMusic(); model.refreshActivityDisplay() }
        .onChange(of: model.engine?.session.phase) { _, _ in model.refreshActivityDisplay() }
        .fullScreenCover(isPresented: $model.showWelcome, onDismiss: {
            if model.startStoryAfterWelcome { model.startStoryAfterWelcome = false; model.showStories = true }
        }) {
            if model.save.profile.journey?.registered == true { WelcomeView() } else { RegistrationView() }
        }
        .fullScreenCover(isPresented: $model.showSettings, onDismiss: {
            if model.replayWelcomeAfterSettings { model.replayWelcomeAfterSettings = false; model.showWelcome = true }
        }) { SettingsView() }
        .fullScreenCover(isPresented: $model.showStories) { NavigationStack { StoryArchiveView().toolbar { ToolbarItem(placement: .confirmationAction) { Button("닫기") { model.showStories = false }.buttonStyle(GameControlStyle()) } } } }
        .fullScreenCover(isPresented: $model.showOperator) { NavigationStack { OperatorConversationView().toolbar { ToolbarItem(placement: .confirmationAction) { Button("닫기") { model.showOperator = false }.buttonStyle(GameControlStyle()) } } } }
        .fullScreenCover(isPresented: $model.showAssociation) { NavigationStack { AssociationView().toolbar { ToolbarItem(placement: .confirmationAction) { Button("닫기") { model.showAssociation = false }.buttonStyle(GameControlStyle()) } } } }
        .fullScreenCover(isPresented: $model.showRun) { ActiveRunView().environmentObject(model) }
        .alert("안내", isPresented: Binding(get: { model.notice != nil }, set: { if !$0 { model.notice = nil } })) {
            Button("확인") { model.notice = nil }
        } message: { Text(model.notice ?? "") }
    }
}
struct HomeView: View {
    @EnvironmentObject var model: AppModel
    var body: some View {
        GeometryReader { geo in
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("HUNTER RUN").font(.system(.title2, design: .rounded, weight: .black)).italic()
                            Text("헌터 협회 · " + AssociationStage.name(model.save.profile)).font(.caption).foregroundStyle(.white.opacity(0.8))
                        }
                        Spacer()
                        VStack(alignment: .trailing) {
                            Text(model.save.profile.name).font(.headline).lineLimit(1).minimumScaleFactor(0.8).accessibilityIdentifier("home.profile")
                            Text("\(model.save.profile.growth.rank)급 · Lv.\(model.save.profile.level)").font(.caption).foregroundStyle(Theme.muted)
                            Button { model.showSettings = true } label: {
                                Image(systemName: "gearshape.fill").font(.system(size: 20, weight: .semibold))
                                    .foregroundStyle(.white).frame(width: 44, height: 44)
                                    .background(.black.opacity(0.28), in: Circle())
                            }.buttonStyle(.plain).accessibilityLabel("설정").accessibilityIdentifier("home.settings")
                        }
                    }
                    Button { model.showOperator = true } label: { Color.clear.frame(maxWidth: .infinity).frame(minHeight: 180).contentShape(Rectangle()) }
                        .buttonStyle(.plain).accessibilityLabel("오퍼레이터와 대화").accessibilityIdentifier("home.operator").disabled(model.growthLocked)
                    Spacer(minLength: 0)
                    VStack(alignment: .leading, spacing: 8) {
                        Button { model.showOperator = true } label: {
                            Text((model.narratives?.tier(model.save.profile) ?? 1) > 2 ? "잘 오셨어요. 오늘은 어떤 이야기부터 할까요?" : "오셨네요! 오늘도 함께해요.").font(.headline)
                        }.buttonStyle(.plain).accessibilityIdentifier("home.greeting")
                        Button { model.showStories = true } label: {
                            let unread = (model.narratives?.main ?? []).filter { model.save.profile.journey?.unlocked.contains($0.id) == true && model.save.profile.journey?.completed.contains($0.id) != true }.count
                            Label(unread > 0 ? "스토리 · 새 이야기 \(unread)편" : "스토리 · 우리 지부의 기록", systemImage: "book.closed").font(.subheadline).foregroundStyle(Theme.teal)
                        }.buttonStyle(.plain).accessibilityIdentifier("home.stories")
                    }.padding(18).frame(maxWidth: .infinity, alignment: .leading).background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
                    if model.recoverable {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("중단된 활동이 있습니다").font(.headline)
                            HStack {
                                Button("활동 복구") { model.recover() }.buttonStyle(.borderedProminent)
                                Button("기록 종료") { model.endRecovered() }.buttonStyle(.bordered)
                            }
                        }.padding().background(Theme.ink.opacity(0.9), in: RoundedRectangle(cornerRadius: 18))
                    }
                    ResourceStrip()
                    Text("HUNTER RUN · 1.1.0").font(.caption2.monospaced()).foregroundStyle(Theme.muted).accessibilityIdentifier("home.version")
                }.padding(20)
                .frame(width: geo.size.width).frame(minHeight: geo.size.height)
            }.scrollIndicators(.hidden)
                .background {
                    // Artwork can extend beyond its canvas without enlarging the controls.
                    ZStack {
                        Theme.ink.ignoresSafeArea()
                        Image(AssociationStage.artwork(model.save.profile)).resizable().scaledToFill()
                            .frame(width: geo.size.width, height: geo.size.height).clipped()
                            .ignoresSafeArea(edges: .top)
                        OperatorPortrait(active: model.selectedTab == 0 && !model.showStories && !model.showOperator && !model.showSettings && !model.showAssociation && !model.showRun && !model.showWelcome)
                            .frame(width: geo.size.width * 1.08, height: geo.size.height * 0.88)
                            .offset(y: -geo.size.height * 0.015)
                        LinearGradient(colors: [.black.opacity(0.5), .clear, Theme.ink], startPoint: .top, endPoint: .bottom)
                            .ignoresSafeArea()
                    }
                    .frame(width: geo.size.width, height: geo.size.height)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                }
        }
    }
}
struct SetupView: View {
    @EnvironmentObject var model: AppModel
    @AppStorage("activityMinutes") private var minutes = 20
    @AppStorage("activityGoalKind") private var goalKind: GoalKind = .time
    @AppStorage("activityKilometers") private var kilometers = 3
    @AppStorage("activityAcceleration") private var pursuit = false
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    eyebrow("TODAY'S ASSIGNMENT")
                    NavigationLink { QuestBoardView() } label: { Label("의뢰 게시판", systemImage: "list.clipboard").card() }.accessibilityIdentifier("setup.quests")
                    if let quest = model.activeQuest {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("선택 의뢰 · " + quest.title).font(.headline).foregroundStyle(Theme.teal)
                            Text(quest.detail).font(.caption)
                            Button("일반 활동으로 변경") { model.selectQuest(nil) }.buttonStyle(GameButtonStyle())
                        }.card()
                    }
                    Text(model.missions?.content(for: model.selectedMode, extended: false).missionTitle ?? "현장 의뢰").font(.largeTitle.bold())
                    NavigationLink { EncounterBoardView() } label: { Label("현장 개체 조사", systemImage: "sparkles").frame(maxWidth: .infinity, alignment: .leading).card() }.accessibilityIdentifier("setup.field-intel")
                    if AppModel.testHarness, let entry = model.fieldEncounters?.encounters.first(where: { $0.id == model.selectedFieldDemo }) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("모의 체험 대상 · " + entry.name).font(.headline)
                            Text("20분 모의 활동에서 해당 개체를 만나요. 실제 출현·보상에는 영향을 주지 않아요.").font(.caption)
                            Button("선택 개체 모의 활동 시작") { model.start(simulated: true, seconds: 1200, pursuit: true, encounterDemo: entry) }.buttonStyle(GameButtonStyle(primary: true)).disabled(model.growthLocked).accessibilityIdentifier("activity.mock.encounter")
                            Button("모의 대상 선택 해제") { model.selectedFieldDemo = nil }.font(.caption)
                        }.card()
                    }
                    ForEach(RunMode.allCases, id: \.rawValue) { mode in
                        Button { model.selectedMode = mode } label: {
                            HStack {
                                Image(systemName: model.selectedMode == mode ? "checkmark.circle.fill" : model.modeAllowed(mode) ? "circle" : "lock.fill")
                                VStack(alignment: .leading, spacing: 5) { Text(mode.title).font(.headline); Text(mode.detail).font(.caption) }
                                Spacer()
                            }.foregroundStyle(model.modeAllowed(mode) ? Theme.teal : Theme.muted).card()
                        }.buttonStyle(.plain).disabled(model.activeQuest != nil || !model.modeAllowed(mode)).accessibilityIdentifier("mode." + mode.rawValue)
                    }
                    if !model.modeAllowed(.gate) { Text("고위험 게이트: 관측부 Lv.2와 D급 평가 통과 필요").font(.caption).foregroundStyle(Theme.muted) }
                    if model.activeQuest != nil { Text("선택한 의뢰에 맞는 활동으로 준비했어요. 모드를 바꾸려면 위에서 일반 활동으로 변경해주세요.").font(.caption).foregroundStyle(Theme.muted) }
                    if model.selectedMode == .gate && model.activeQuest == nil { BossSelectionView() }
                    Text("흔적을 찾고, 신호의 원인을 확인하세요. 안전한 페이스로 이동해도 의뢰는 이어집니다.").foregroundStyle(Theme.muted)
                    NavigationLink { PaceProfileView() } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("나의 활동 기준").font(.headline)
                            Text(learnedPaceText(model.save.profile.paceMemory?.reference)).foregroundStyle(Theme.teal)
                        }.card()
                    }.buttonStyle(.plain).accessibilityIdentifier("setup.pace")
                    HStack { Image(systemName: "waveform.path"); Text(model.selectedMode.title + " · 음성 안내") }.foregroundStyle(Theme.teal)
                    NavigationLink { EncounterGuideView() } label: { Label("현장 사건 안내", systemImage: "waveform") }.accessibilityIdentifier("setup.encounters")
                    VStack(alignment: .leading, spacing: 14) {
                        Text("활동 목표").font(.headline)
                        Picker("목표 종류", selection: $goalKind) {
                            ForEach(GoalKind.allCases, id: \.rawValue) { Text($0.title).tag($0) }
                        }.pickerStyle(.segmented).accessibilityIdentifier("goal.kind")
                        if goalKind == .time {
                            Picker("목표 시간", selection: $minutes) {
                                Text("5분").tag(5); Text("20분").tag(20); Text("30분").tag(30)
                                if model.unlocked("extended-contract") { Text("45분").tag(45) }
                            }.pickerStyle(.segmented)
                        } else if goalKind == .distance {
                            Picker("목표 거리", selection: $kilometers) {
                                Text("1 km").tag(1); Text("3 km").tag(3); Text("5 km").tag(5); Text("10 km").tag(10)
                            }.pickerStyle(.segmented).accessibilityIdentifier("goal.distance")
                            Text("기록된 이동 거리가 목표에 도달하면 자동으로 마칩니다. GPS 상태에 따라 실제 거리와 차이가 날 수 있습니다.").font(.caption).foregroundStyle(Theme.muted)
                        } else {
                            Text("시간과 거리 제한 없이 활동합니다. 안전한 곳에서 ‘활동 종료’를 누르면 성과가 저장됩니다. 자유 활동 시간도 승급 심사 자격에 포함돼요.").font(.caption).foregroundStyle(Theme.muted).accessibilityIdentifier("goal.free.help")
                        }
                        Toggle("선택적 가속 허용", isOn: $pursuit)
                        Text("추격·보스 가속은 10초씩 최대 2회, 사이에 최소 3분을 둡니다. 가속하지 않으면 추격은 조사로, 보스는 유지 공격으로 바뀝니다.").font(.caption).foregroundStyle(Theme.muted)
                    }.card()
                    VStack(alignment: .leading, spacing: 12) {
                        Label(model.permissionText, systemImage: "location")
                        Text("GPS 품질은 활동 시작 후 확인됩니다. 신호가 약하면 속도 판정을 제한합니다.").font(.caption).foregroundStyle(Theme.muted)
                        Button("위치 권한 확인") { model.authorize() }.buttonStyle(GameButtonStyle())
                        Button("안내 음성 미리 듣기") { model.audioTest() }.buttonStyle(GameButtonStyle())
                    }.card()
                    Button {
                        let goal = ActivityGoal(kind: goalKind, value: goalKind == .time ? Double(minutes * 60) : goalKind == .distance ? Double(kilometers * 1000) : 0)
                        model.start(simulated: false, seconds: goalKind == .time ? goal.value : 1200, pursuit: pursuit, goal: goal)
                    } label: { Label(model.selectedMode.startTitle(boss: model.selectedBoss != nil), systemImage: "figure.run").frame(maxWidth: .infinity).padding(10) }
                        .buttonStyle(GameButtonStyle(primary: true)).disabled(!model.canStartReal).accessibilityIdentifier("activity.start")
                    Text("활동 중에는 화면을 자동으로 끄지 않습니다. 전원 버튼으로 직접 잠글 수 있으며, 종료하면 원래 자동 잠금 설정으로 돌아갑니다.").font(.caption).foregroundStyle(Theme.muted)
                    Text("걷기와 달리기는 활동시간에 포함됩니다. 위치·운동 정보는 기기에 저장되며 서버로 전송하지 않습니다.").font(.caption).foregroundStyle(Theme.muted)
                    if AppModel.testHarness {
                    Divider()
                    Text("실내에서 먼저 확인").font(.headline)
                    Text("가짜 센서로 같은 게임 엔진을 실행합니다. 모의 기록과 보상은 실제 성장에 반영되지 않습니다.").font(.caption).foregroundStyle(Theme.muted)
                    Button("3분 모의 활동") { model.start(simulated: true, seconds: 180, pursuit: true) }.buttonStyle(GameButtonStyle()).disabled(!model.isReady || model.recoverable).accessibilityIdentifier("activity.mock")
                    Button("20분 의뢰 모의 활동 · 장기전 포함") {
                        model.selectedBoss = nil; model.selectedMode = .contract
                        model.start(simulated: true, seconds: 1200, pursuit: true)
                    }.buttonStyle(GameButtonStyle()).disabled(!model.isReady || model.recoverable).accessibilityIdentifier("activity.mock.long")
                    if model.selectedBoss != nil {
                        Button("20분 보스 패턴 모의 활동 · 가속 포함") {
                            model.start(simulated: true, seconds: 1200, pursuit: true)
                        }.buttonStyle(GameButtonStyle()).disabled(!model.isReady || model.recoverable).accessibilityIdentifier("activity.mock.boss")
                    }
                    Text("긴 모의 활동에서는 진행 속도를 10배로 바꿔 장기전과 기습 대응을 빠르게 확인할 수 있습니다.").font(.caption).foregroundStyle(Theme.muted)
                    }
                }.padding(22)
            }.labyrinthScreen().navigationTitle("헌터 활동 준비").navigationBarTitleDisplayMode(.inline)
        }
    }
}
struct ActiveRunView: View {
    @EnvironmentObject var model: AppModel
    @State private var confirmEnd = false
    var body: some View {
        ZStack {
            Theme.ink.ignoresSafeArea()
            if let run = model.engine?.session {
                if run.phase == .finished { result(run) }
                else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            HStack {
                                eyebrow(run.simulated ? "SIMULATION" : "HUNTER ASSIGNMENT")
                                Spacer()
                                Text(stateName(run)).font(.caption.bold()).foregroundStyle(Theme.teal)
                            }
                            Text((run.mode ?? .contract).activityTitle(boss: run.boss != nil)).font(.title2.bold())
                            Text(String(format: "%.2f", run.distance / 1000)).font(.system(size: 64, weight: .light, design: .rounded)).minimumScaleFactor(0.65)
                            Text("KILOMETERS").font(.caption.monospaced()).foregroundStyle(Theme.muted)
                            HStack {
                                metric("활동시간", clock(run.activeSeconds))
                                Spacer()
                                metric("최근 페이스", model.currentSpeed > 0.5 ? pace(model.currentSpeed) : "—")
                                Spacer()
                                metric("목표", run.activityGoal.label)
                            }
                            Text("최근 12초 기준 · 정지하거나 GPS가 불안정하면 — 로 표시합니다.").font(.caption2).foregroundStyle(Theme.muted)
                            if run.activityGoal.kind != .free { ProgressView(value: run.goalProgress).tint(Theme.teal) }
                            else { Text("자유 활동 · 확보한 성과는 종료할 때 저장됩니다").font(.caption).foregroundStyle(Theme.muted) }
                            if AccelerationRules.isRecovering(run) {
                                Text(run.intensityCount >= 2 ? "회복 이동 · 이번 활동의 가속을 마쳤어요" : "회복 이동 · 다음 가속까지 \(max(0, Int(ceil(180 - (run.activeSeconds - run.lastIntensityAt)))))초")
                                    .font(.caption).foregroundStyle(Theme.teal).accessibilityIdentifier("activity.recovery")
                            }
                            if let boss = run.boss { BossHPView(name: boss.definition.name, remaining: boss.remainingHP, maximum: boss.maximumHP, phase: boss.phaseName) }
                            VStack(alignment: .leading, spacing: 12) {
                                eyebrow("OPERATOR")
                                Text(run.event?.template.title ?? (run.phase == .calibrating ? "신호를 확인하고 있어요" : "주변을 살펴보고 있어요")).font(.title2.bold())
                                Text(model.operatorCaption ?? eventMessage(run)).foregroundStyle(Theme.muted).accessibilityIdentifier("activity.caption")
                                if let event = run.event {
                                    if event.template.burstSeconds != nil {
                                        Text(event.stage == .armed ? "가속 선택 대기 · 평소 페이스면 유지/조사로 전환" : event.stage == .briefing ? "안내 후 시작해요" : "가속 남은 시간 · \(max(0, Int(ceil((event.template.burstSeconds ?? 10) - event.elapsed))))초")
                                            .font(.headline).foregroundStyle(Theme.teal).accessibilityIdentifier("activity.burst")
                                    }
                                    ProgressView(value: event.progress).tint(Theme.teal)
                                    if event.template.kind == .endurance { Text("장기전 · \(Int(event.traveledDistance ?? 0)) / \(Int(event.template.targetDistance ?? 400)) m").font(.caption).foregroundStyle(Theme.teal) }
                                }
                            }.card()
                            HStack {
                                Label(signalName(model.signal), systemImage: "antenna.radiowaves.left.and.right")
                                Spacer()
                                Text("HP \(Int(run.hp))").monospacedDigit()
                            }.font(.caption).foregroundStyle(Theme.muted)
                            if let notice = model.notice {
                                Text(notice).foregroundStyle(.orange).font(.callout)
                            }
                            if run.manualPause || run.interruption {
                                Button("계속") { model.resume() }.buttonStyle(GameButtonStyle(primary: true))
                            } else {
                                Button("일시정지") { model.pause() }.buttonStyle(GameButtonStyle(primary: true))
                            }
                            Button("활동 종료") { confirmEnd = true }.buttonStyle(GameButtonStyle())
                            if AppModel.testHarness && run.simulated { mockControls }
                        }.padding(24)
                    }
                }
            }
        }
        .environment(\.labyrinthStyle, true)
        .confirmationDialog("확보한 기록과 보상을 저장하고 종료할까요?", isPresented: $confirmEnd, titleVisibility: .visible) {
            Button("저장하고 종료") { model.finish() }
        }
    }
    private func result(_ run: RunSession) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                eyebrow(run.simulated ? "SIMULATION COMPLETE" : "MISSION REPORT")
                Text("활동 보고").font(.largeTitle.bold())
                HStack { metric("거리", String(format: "%.2f km", run.distance / 1000)); Spacer(); metric("활동시간", clock(run.activeSeconds)) }
                Text(run.reachedGoal ? "목표 활동을 마쳤습니다." : "확보한 성과를 정리했습니다.").foregroundStyle(Theme.muted)
                if let report = run.simulated ? PaceLearning.report(run, memory: nil) : model.lastSummary?.paceReport { PaceFeedbackView(report: report, simulated: run.simulated) }
                ForEach(run.records) { record in
                    HStack { Text(record.title); Spacer(); Text(outcomeName(record.outcome)).foregroundStyle(Theme.teal) }.card()
                }
                if run.simulated {
                    Text("모의 활동입니다. 실제 경험치와 자원은 변경되지 않았습니다.").foregroundStyle(Theme.muted)
                } else if let summary = model.lastSummary {
                    Text("EXP +\(summary.xp)  ·  마정석 +\(summary.crystals)").font(.title3.bold()).foregroundStyle(Theme.teal)
                    Text("조사 데이터 +\(summary.research ?? 0) · 코어 +\(summary.cores ?? 0)").foregroundStyle(Theme.teal)
                    if let boss = summary.majorBoss { BossReportView(report: boss) }
                    Text("장비 보관함과 지부 관리에서 획득한 자원을 사용할 수 있습니다.").font(.caption).foregroundStyle(Theme.muted)
                }
                if let notice = model.notice {
                    Text(notice).foregroundStyle(.orange)
                    Button("결과 저장 재시도") { model.finish() }.buttonStyle(GameButtonStyle())
                }
                Button("협회로 돌아가기") { model.closeResult(); model.selectedTab = 0 }.buttonStyle(GameButtonStyle(primary: true)).disabled(!model.resultSaved)
            }.padding(24)
        }
    }
    private var mockControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("개발자 센서").font(.headline)
            Picker("이동", selection: $model.mockMovement) {
                Text("달리기").tag(Movement.running); Text("걷기").tag(Movement.walking)
                Text("정지").tag(Movement.stationary); Text("차량").tag(Movement.vehicle)
            }.pickerStyle(.segmented)
            Picker("GPS", selection: $model.mockSignal) {
                Text("양호").tag(Signal.good); Text("약함").tag(Signal.degraded); Text("없음").tag(Signal.unavailable)
            }.pickerStyle(.segmented)
            Text(String(format: "속도 %.1f km/h", model.mockSpeed * 3.6))
            Slider(value: $model.mockSpeed, in: 0...6)
            Picker("진행 속도", selection: $model.mockRate) { Text("1배").tag(1); Text("5배").tag(5); Text("10배").tag(10) }.pickerStyle(.segmented)
            Button("중단 복구 모의 실험") { model.recoveryDrill() }.buttonStyle(GameButtonStyle())
        }.card()
    }
    private func eventMessage(_ run: RunSession) -> String {
        guard let event = run.event else { return "편안한 페이스로 함께 이동해요. 잠시 멈춰도 괜찮아요!" }
        if event.stage == .briefing { return "지금 필요한 행동을 안내하고 있어요." }
        if event.stage == .armed { return event.template.kind == .boss ? "안전하면 가속 공격을 선택해요. 아니면 유지 공격으로 이어가요." : "안전하면 가속해도 좋아요. 아니면 흔적을 함께 조사해요." }
        if event.template.kind == .endurance { return "편안한 페이스로 400m를 함께 전진해요. 잠시 멈춰도 괜찮아요!" }
        if event.template.kind == .ambush { return "더 빨라질 필요 없이 달리기를 이어가요. 멈춰야 할 때는 기다릴게요." }
        return event.template.kind == .discovery ? "주변 흔적을 모으고 있어요!" : "안내받은 페이스로 함께 가요. 멈춰야 할 때는 편하게 멈춰요."
    }
    private func stateName(_ run: RunSession) -> String {
        switch run.phase { case .calibrating: return "준비 중"; case .moving: return "활동 중"; case .paused: return "일시정지"; case .interrupted: return "중단"; case .finished: return "완료" }
    }
}
struct HunterView: View {
    @EnvironmentObject var model: AppModel
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HunterDossier()
                    HStack { metric("마정석", "\(model.save.profile.crystals)"); Spacer(); metric("조사 데이터", "\(model.save.profile.research)") }.card()
                    ResourceStrip()
                    NavigationLink { PaceProfileView() } label: { DossierLink(title: "나의 활동 기준", subtitle: "현장 기록으로 맞추는 페이스", icon: "waveform.path") }.accessibilityIdentifier("hunter.pace")
                    NavigationLink { EquipmentView() } label: { DossierLink(title: "장비 보관함", subtitle: "출발 전, 장비를 정비해요", icon: "shield.lefthalf.filled") }
                    NavigationLink { RankView() } label: { DossierLink(title: "협회 평가 · 승급", subtitle: "다음 등급으로 가는 심사", icon: "checkmark.seal") }
                    NavigationLink { AssociationView() } label: { DossierLink(title: "협회 부서 관리", subtitle: "우리 지부의 시설과 지원", icon: "building.2") }
                    LoadoutStrip()
                    NavigationLink { HistoryView() } label: { Label("활동 기록 전체 보기", systemImage: "clock.arrow.circlepath").frame(maxWidth: .infinity, alignment: .leading).card() }
                    Text("최근 활동").font(.title2.bold())
                    if model.save.profile.runs.isEmpty { Text("첫 의뢰를 마치면 기록이 남습니다.").foregroundStyle(Theme.muted) }
                    ForEach(Array(model.save.profile.runs.prefix(3))) { run in
                        NavigationLink { RunDetailView(run: run) } label: { VStack(alignment: .leading, spacing: 8) {
                            Text(run.date, style: .date)
                            Text(run.mode?.title ?? "헌터 의뢰").font(.caption).foregroundStyle(Theme.teal)
                            Text(String(format: "%.2f km", run.distance / 1000) + " · " + clock(run.seconds)).font(.title3)
                            Text("EXP +\(run.xp)").foregroundStyle(Theme.teal)
                        }.card() }.buttonStyle(.plain)
                    }
                }.padding(22)
            }.labyrinthScreen().navigationTitle("헌터").navigationBarTitleDisplayMode(.inline)
        }
    }
}
struct FieldArchiveView: View {
    @EnvironmentObject var model: AppModel
    private var events: [MissionTemplate] {
        var all = model.missions?.modes.values.flatMap(\.events) ?? model.content?.events ?? []
        if let extra = model.missions?.extendedContract { all.append(extra) }
        return Array(Dictionary(all.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first }).values).sorted { $0.id < $1.id }
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    eyebrow("FIELD ARCHIVE")
                    Text("현장 조사 기록").font(.largeTitle.bold())
                    ForEach(events) { event in
                        let known = model.save.profile.runs.contains { $0.records.contains { $0.catalogID == event.id } }
                        VStack(alignment: .leading, spacing: 8) {
                            Image(systemName: known ? "sparkle.magnifyingglass" : "questionmark.diamond").font(.title).foregroundStyle(Theme.teal)
                            Text(known ? event.title : "미발견 신호").font(.headline)
                            Text(known ? "활동 중 확인한 현상입니다." : "의뢰를 진행하면 조사 기록이 열립니다.").font(.caption).foregroundStyle(Theme.muted)
                            if known && model.unlocked("analysis") {
                                let records = model.save.profile.runs.flatMap(\.records).filter { $0.catalogID == event.id }
                                Text("기준 HP \(Int(event.hp)) · 토벌 \(records.filter { $0.defeated == true }.count)회").font(.caption).foregroundStyle(Theme.teal)
                                Text("누적 피해 \(Int(records.reduce(0) { $0 + $1.damage }))").font(.caption)
                            }
                        }.card()
                    }
                    Text("연구부를 확장하면 발견한 현상의 분석 정보가 열립니다. 개체 일러스트는 도감의 개체 목록에서 확인할 수 있습니다.").font(.caption).foregroundStyle(Theme.muted)
                }.padding(22)
            }.labyrinthScreen().navigationTitle("도감").navigationBarTitleDisplayMode(.inline)
        }
    }
}
struct SettingsView: View {
    @EnvironmentObject var model: AppModel
    @State private var importing = false
    @State private var exported: URL?
    @State private var pendingImport: URL?
    @State private var confirmImport = false
    @State private var confirmReset = false
    @AppStorage("operatorMotionEnabled") private var operatorMotion = true
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                GameSection("헌터 등록") {
                    Text("헌터 · " + model.save.profile.name)
                    NavigationLink("두 사람의 이름 변경") { RenamePartnersView() }
                    Toggle("오퍼레이터 움직임", isOn: $operatorMotion)
                }
                GameSection("협회 BGM") {
                    Toggle("협회 배경음악", isOn: $model.homeMusicEnabled).onChange(of: model.homeMusicEnabled) { _, _ in model.applyHomeMusic() }
                    Slider(value: $model.homeMusicVolume, in: 0...1).accessibilityLabel("협회 BGM 음량").onChange(of: model.homeMusicVolume) { _, _ in model.applyHomeMusic() }
                    Text(model.musicNotice ?? "활동 준비 화면까지 BGM이 이어집니다. 활동을 시작하면 멈춥니다. 다른 앱의 음악이 재생 중이면 쉬어갑니다.").font(.caption)
                }
                GameSection("오디오") {
                    Slider(value: $model.voiceVolume, in: 0...1).onChange(of: model.voiceVolume) { _, _ in model.applyAudio() }
                    Toggle("안내 중 외부 음악 낮추기", isOn: $model.ducking).onChange(of: model.ducking) { _, _ in model.applyAudio() }
                    Button("안내 음성 미리 듣기") { model.audioTest() }
                    Text("오퍼레이터 · 밝고 다정한 목소리. 상황별 한국어 안내가 오프라인으로 재생돼요.").font(.caption)
                }
                GameSection("저장") {
                    Button("백업 파일 만들기") { exported = model.exportSave() }
                    if let exported { ShareLink("백업 공유·저장", item: exported) }
                    Button("백업 불러오기") { importing = true }
                    Text("불러오면 현재 진행도가 선택한 백업으로 교체됩니다. 먼저 백업을 저장해주세요.").font(.caption)
                    Button("진행도 초기화", role: .destructive) { confirmReset = true }.disabled(model.growthLocked)
                }
                GameSection("효과음과 진동") {
                    Slider(value: $model.effectsVolume, in: 0...1).accessibilityLabel("효과음 음량").onChange(of: model.effectsVolume) { _, _ in model.applyFeedbackSettings() }
                    Toggle("버튼 진동", isOn: $model.hapticsEnabled).onChange(of: model.hapticsEnabled) { _, _ in model.applyFeedbackSettings() }
                    Button("효과음 미리 듣기") { model.interfaceFeedback("ui-reward") }
                }
                GameSection("진단") {
                    if let url = model.diagnostics() { ShareLink("진단 정보 내보내기", item: url) }
                    Text("진단 파일에는 원시 GPS 좌표와 헌터명을 넣지 않습니다.").font(.caption)
                }
                GameSection("이용 안내") {
                    Button("첫 이용 안내 다시 보기") { model.replayWelcomeAfterSettings = true; model.showSettings = false }.accessibilityIdentifier("settings.welcome")
                    NavigationLink("협회 통신 기록") { StoryArchiveView() }.accessibilityIdentifier("settings.stories")
                    NavigationLink("활동과 성장 가이드") { FieldGuideView() }
                }
                GameSection("앱 정보") {
                    Text("Hunter Run · 1.1.0")
                    Text("당신의 발걸음으로 이어지는 지부의 이야기").font(.caption)
                    NavigationLink("데이터와 권한 안내") { DataGuideView() }
                }
                }.padding(20)
            }.labyrinthScreen().buttonStyle(GameButtonStyle()).navigationTitle("설정").navigationBarTitleDisplayMode(.inline).toolbar { ToolbarItem(placement: .confirmationAction) { Button("닫기") { model.showSettings = false }.buttonStyle(GameControlStyle()).accessibilityIdentifier("settings.close") } }
        }
        .onDisappear { model.stopAudioPreview() }
        .confirmationDialog("모든 활동·장비·이야기 진행도를 초기화할까요?", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("진행도 초기화", role: .destructive) { model.resetProgress() }
        } message: { Text("이 기기의 진행도와 자동 복구 사본이 초기화돼요. 보관하려면 먼저 백업 파일을 저장해주세요.") }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
            if case .success(let url) = result { pendingImport = url; confirmImport = true }
        }
        .confirmationDialog("현재 진행도를 선택한 백업으로 교체할까요?", isPresented: $confirmImport, titleVisibility: .visible) {
            Button("백업으로 교체", role: .destructive) {
                if let pendingImport { model.importSave(pendingImport) }
                pendingImport = nil
            }
            Button("취소", role: .cancel) { pendingImport = nil }
        }
    }
}
extension View {
    func card() -> some View {
        modifier(RelicPanel())
    }
}
func eyebrow(_ text: String) -> some View { Text(text).font(.caption.monospaced().weight(.semibold)).tracking(2).foregroundStyle(Theme.teal) }
func metric(_ label: String, _ value: String) -> some View {
    VStack(alignment: .leading, spacing: 6) { Text(label).font(.caption).foregroundStyle(Theme.muted); Text(value).font(.title3.monospacedDigit().bold()) }
}
func clock(_ seconds: Double) -> String { let value = max(0, Int(seconds)); return String(format: "%02d:%02d", value / 60, value % 60) }
private func pace(_ speed: Double) -> String { let value = Int(1000 / speed); return String(format: "%d′%02d″", value / 60, value % 60) }
private func signalName(_ signal: Signal) -> String { switch signal { case .good: return "GPS 양호"; case .degraded: return "GPS 약함"; case .unavailable: return "GPS 대기 / 보조 측정" } }
func outcomeName(_ outcome: Outcome) -> String { switch outcome { case .perfect: return "완벽"; case .success: return "성공"; case .partial: return "부분 확보"; case .fail: return "철수"; case .neutral: return "중립 종료" } }
