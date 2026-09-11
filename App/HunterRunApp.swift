import SwiftUI
import UniformTypeIdentifiers

@main struct HunterRunApp: App {
    @StateObject private var model = AppModel()
    @Environment(\.scenePhase) private var scenePhase
    var body: some Scene {
        WindowGroup {
            RootView().environmentObject(model).preferredColorScheme(.dark)
                .onChange(of: scenePhase) { _, phase in
                    if phase != .active { model.persist() }
                }
        }
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
        TabView(selection: $model.selectedTab) {
            HomeView().toolbar(.hidden, for: .tabBar).tag(0).tabItem { Label("협회", systemImage: "building.2") }
            HunterView().toolbar(.hidden, for: .tabBar).tag(1).tabItem { Label("헌터", systemImage: "person.crop.circle") }
            SetupView().toolbar(.hidden, for: .tabBar).tag(2).tabItem { Label("RUN", systemImage: "figure.run") }
            CodexView().toolbar(.hidden, for: .tabBar).tag(3).tabItem { Label("도감", systemImage: "book") }
            SettingsView().toolbar(.hidden, for: .tabBar).tag(4).tabItem { Label("메뉴", systemImage: "ellipsis") }
        }
        .toolbar(.hidden, for: .tabBar)
        .safeAreaInset(edge: .bottom, spacing: 0) { HunterTabBar() }
        .tint(Theme.teal)
        .fullScreenCover(isPresented: $model.showRun) { ActiveRunView().environmentObject(model) }
        .alert("안내", isPresented: Binding(get: { model.notice != nil }, set: { if !$0 { model.notice = nil } })) {
            Button("확인") { model.notice = nil }
        } message: { Text(model.notice ?? "") }
    }
}
struct HomeView: View {
    @EnvironmentObject var model: AppModel
    @State private var association = false
    var body: some View {
        GeometryReader { geo in
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("HUNTER RUN").font(.system(.title2, design: .rounded, weight: .black)).italic()
                            Text("헌터 협회 · 임시 지부").font(.caption).foregroundStyle(.white.opacity(0.8))
                        }
                        Spacer()
                        VStack(alignment: .trailing) {
                            Text(model.save.profile.name).font(.headline).lineLimit(1).minimumScaleFactor(0.8).accessibilityIdentifier("home.profile")
                            Text("\(model.save.profile.growth.rank)급 · Lv.\(model.save.profile.level)").font(.caption).foregroundStyle(Theme.muted)
                        }
                    }
                    Spacer(minLength: 60)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("오셨네요. 오늘도 함께하겠습니다.").font(.headline).accessibilityIdentifier("home.greeting")
                        Text("폐쇄 구역에서 새로운 마력 신호가 발견됐어요.").font(.subheadline).foregroundStyle(Theme.muted)
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
                    Button { association = true } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                Text("협회 관리").font(.system(size: 29, weight: .bold, design: .rounded))
                                Text("시설 확장 · 새로운 의뢰 해금").font(.subheadline)
                            }
                            Spacer(); Image(systemName: "arrow.up.right").font(.title2)
                        }.padding(20).foregroundStyle(Theme.ink)
                            .background(LinearGradient(colors: [Theme.teal, .cyan.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 22))
                    }.accessibilityLabel("협회 관리").accessibilityIdentifier("home.association")
                    ResourceStrip()
                    Text("FIELD DEMO · 0.3.0").font(.caption2.monospaced()).foregroundStyle(Theme.muted)
                }.padding(20)
                .frame(width: geo.size.width).frame(minHeight: geo.size.height)
            }.scrollIndicators(.hidden)
                .background {
                    // Artwork can extend beyond its canvas without enlarging the controls.
                    ZStack {
                        Theme.ink.ignoresSafeArea()
                        Image("AssociationOffice").resizable().scaledToFill()
                            .frame(width: geo.size.width, height: geo.size.height).clipped()
                            .ignoresSafeArea(edges: .top)
                        Image("OperatorCutout").resizable().scaledToFit()
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
        .sheet(isPresented: $association) { NavigationStack { AssociationView().toolbar { ToolbarItem(placement: .confirmationAction) { Button("닫기") { association = false } } } }.presentationDragIndicator(.visible) }
    }
}
struct SetupView: View {
    @EnvironmentObject var model: AppModel
    @State private var minutes = 20
    @State private var goalKind: GoalKind = .time
    @State private var kilometers = 3
    @State private var pursuit = false
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    eyebrow("TODAY'S ASSIGNMENT")
                    Text(model.missions?.content(for: model.selectedMode, extended: false).missionTitle ?? "현장 의뢰").font(.largeTitle.bold())
                    ForEach(RunMode.allCases, id: \.rawValue) { mode in
                        Button { model.selectedMode = mode } label: {
                            HStack {
                                Image(systemName: model.selectedMode == mode ? "checkmark.circle.fill" : model.modeAllowed(mode) ? "circle" : "lock.fill")
                                VStack(alignment: .leading, spacing: 5) { Text(mode.title).font(.headline); Text(mode.detail).font(.caption) }
                                Spacer()
                            }.foregroundStyle(model.modeAllowed(mode) ? Theme.teal : Theme.muted).card()
                        }.buttonStyle(.plain).disabled(!model.modeAllowed(mode)).accessibilityIdentifier("mode." + mode.rawValue)
                    }
                    if !model.modeAllowed(.gate) { Text("고위험 게이트: 관측부 Lv.2와 D급 평가 통과 필요").font(.caption).foregroundStyle(Theme.muted) }
                    Text("흔적을 찾고, 신호의 원인을 확인하세요. 안전한 페이스로 이동해도 의뢰는 이어집니다.").foregroundStyle(Theme.muted)
                    HStack { Image(systemName: "waveform.path"); Text(model.selectedMode.title + " · 음성 안내") }.foregroundStyle(Theme.teal)
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
                            Text("시간과 거리 제한 없이 활동합니다. 안전한 곳에서 ‘활동 종료’를 누르면 성과가 저장됩니다. 자유 활동은 승급의 목표 완료 횟수에는 포함되지 않습니다.").font(.caption).foregroundStyle(Theme.muted).accessibilityIdentifier("goal.free.help")
                        }
                        Toggle("선택적 추격 허용", isOn: $pursuit)
                        Text("가속하지 않으면 흔적 조사로 전환합니다. 첫 테스트는 추격을 꺼두는 것을 권합니다.").font(.caption).foregroundStyle(Theme.muted)
                    }.card()
                    VStack(alignment: .leading, spacing: 12) {
                        Label(model.permissionText, systemImage: "location")
                        Text("GPS 품질은 활동 시작 후 확인됩니다. 신호가 약하면 속도 판정을 제한합니다.").font(.caption).foregroundStyle(Theme.muted)
                        Button("위치 권한 확인") { model.authorize() }.buttonStyle(.bordered)
                        Button("음성 · 음악 혼합 테스트") { model.audioTest() }.buttonStyle(.bordered)
                    }.card()
                    Button {
                        let goal = ActivityGoal(kind: goalKind, value: goalKind == .time ? Double(minutes * 60) : goalKind == .distance ? Double(kilometers * 1000) : 0)
                        model.start(simulated: false, seconds: goalKind == .time ? goal.value : 1200, pursuit: pursuit, goal: goal)
                    } label: { Label("START RUN", systemImage: "figure.run").frame(maxWidth: .infinity).padding(10) }
                        .buttonStyle(.borderedProminent).disabled(!model.isReady || model.recoverable)
                    Text("걷기와 달리기는 활동시간에 포함됩니다. 위치·운동 정보는 기기에 저장되며 서버로 전송하지 않습니다.").font(.caption).foregroundStyle(Theme.muted)
                    Divider()
                    Text("실내에서 먼저 확인").font(.headline)
                    Text("가짜 센서로 같은 게임 엔진을 실행합니다. 모의 기록과 보상은 실제 성장에 반영되지 않습니다.").font(.caption).foregroundStyle(Theme.muted)
                    Button("3분 모의 러닝") { model.start(simulated: true, seconds: 180, pursuit: true) }.buttonStyle(.bordered).disabled(!model.isReady || model.recoverable)
                }.padding(22)
            }.background(Theme.ink).navigationTitle("RUN").navigationBarTitleDisplayMode(.inline)
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
                            Text(String(format: "%.2f", run.distance / 1000)).font(.system(size: 64, weight: .light, design: .rounded)).minimumScaleFactor(0.65)
                            Text("KILOMETERS").font(.caption.monospaced()).foregroundStyle(Theme.muted)
                            HStack {
                                metric("활동시간", clock(run.activeSeconds))
                                Spacer()
                                metric("현재 페이스", model.currentSpeed > 0.5 ? pace(model.currentSpeed) : "—")
                                Spacer()
                                metric("목표", run.activityGoal.label)
                            }
                            if run.activityGoal.kind != .free { ProgressView(value: run.goalProgress).tint(Theme.teal) }
                            else { Text("자유 활동 · 확보한 성과는 종료할 때 저장됩니다").font(.caption).foregroundStyle(Theme.muted) }
                            VStack(alignment: .leading, spacing: 12) {
                                eyebrow("OPERATOR")
                                Text(run.event?.template.title ?? (run.phase == .calibrating ? "신호를 확인하고 있습니다" : "주변을 탐색하고 있습니다")).font(.title2.bold())
                                Text(eventMessage(run)).foregroundStyle(Theme.muted)
                                if let event = run.event {
                                    ProgressView(value: min(event.elapsed, event.template.duration), total: event.template.duration).tint(Theme.teal)
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
                                Button("계속") { model.resume() }.buttonStyle(.borderedProminent)
                            } else {
                                Button("일시정지") { model.pause() }.buttonStyle(.borderedProminent)
                            }
                            Button("활동 종료") { confirmEnd = true }.buttonStyle(.bordered)
                            if run.simulated { mockControls }
                        }.padding(24)
                    }
                }
            }
        }
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
                ForEach(run.records) { record in
                    HStack { Text(record.title); Spacer(); Text(outcomeName(record.outcome)).foregroundStyle(Theme.teal) }.card()
                }
                if run.simulated {
                    Text("모의 러닝입니다. 실제 경험치와 자원은 변경되지 않았습니다.").foregroundStyle(Theme.muted)
                } else if let summary = model.lastSummary {
                    Text("EXP +\(summary.xp)  ·  마정석 +\(summary.crystals)").font(.title3.bold()).foregroundStyle(Theme.teal)
                    Text("조사 데이터 +\(summary.research ?? 0) · 코어 +\(summary.cores ?? 0)").foregroundStyle(Theme.teal)
                    Text("장비 보관함과 지부 관리에서 획득한 자원을 사용할 수 있습니다.").font(.caption).foregroundStyle(Theme.muted)
                }
                if let notice = model.notice {
                    Text(notice).foregroundStyle(.orange)
                    Button("결과 저장 재시도") { model.finish() }.buttonStyle(.bordered)
                }
                Button("협회로 돌아가기") { model.closeResult(); model.selectedTab = 0 }.buttonStyle(.borderedProminent).disabled(!model.resultSaved)
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
            Button("중단 복구 모의 실험") { model.recoveryDrill() }.buttonStyle(.bordered)
        }.card()
    }
    private func eventMessage(_ run: RunSession) -> String {
        guard let event = run.event else { return "편안한 페이스로 이동하세요. 정지는 실패로 처리하지 않습니다." }
        if event.stage == .briefing { return "오퍼레이터 안내를 듣는 중입니다." }
        if event.stage == .armed { return "안전한 구간이면 조금 가속하세요. 유지하면 조사로 전환합니다." }
        return event.template.kind == .discovery ? "주변 흔적을 확보하고 있습니다." : "안내받은 페이스를 유지하세요. 멈춰야 할 때는 편하게 멈추세요."
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
                    eyebrow("HUNTER PROFILE")
                    Text(model.save.profile.name).font(.largeTitle.bold())
                    Text("\(model.save.profile.growth.rank)급 · Lv.\(model.save.profile.level)").foregroundStyle(Theme.teal)
                    ProgressView(value: Double(model.save.profile.xp % 300), total: 300).tint(Theme.teal)
                    Text("다음 레벨까지 \(300 - model.save.profile.xp % 300) EXP").font(.caption).foregroundStyle(Theme.muted)
                    HStack { metric("마정석", "\(model.save.profile.crystals)"); Spacer(); metric("조사 데이터", "\(model.save.profile.research)") }.card()
                    ResourceStrip()
                    NavigationLink { EquipmentView() } label: { Label("장비 보관함", systemImage: "shield.lefthalf.filled").frame(maxWidth: .infinity, alignment: .leading).card() }
                    NavigationLink { RankView() } label: { Label("협회 평가 · 승급", systemImage: "checkmark.seal").frame(maxWidth: .infinity, alignment: .leading).card() }
                    NavigationLink { AssociationView() } label: { Label("협회 부서 관리", systemImage: "building.2").frame(maxWidth: .infinity, alignment: .leading).card() }
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
            }.background(Theme.ink).navigationTitle("헌터").navigationBarTitleDisplayMode(.inline)
        }
    }
}
struct CodexView: View {
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
                    Text("연구부를 확장하면 발견한 현상의 분석 정보가 열립니다. 몬스터 일러스트는 후속 버전에 추가됩니다.").font(.caption).foregroundStyle(Theme.muted)
                }.padding(22)
            }.background(Theme.ink).navigationTitle("도감").navigationBarTitleDisplayMode(.inline)
        }
    }
}
struct SettingsView: View {
    @EnvironmentObject var model: AppModel
    @State private var importing = false
    @State private var exported: URL?
    @State private var pendingImport: URL?
    @State private var confirmImport = false
    var body: some View {
        NavigationStack {
            Form {
                Section("헌터 등록") {
                    TextField("헌터명", text: Binding(get: { model.save.profile.name }, set: { model.nameChanged($0) }))
                }
                Section("오디오") {
                    Slider(value: $model.voiceVolume, in: 0.2...1).onChange(of: model.voiceVolume) { _, _ in model.applyAudio() }
                    Toggle("안내 중 외부 음악 낮추기", isOn: $model.ducking).onChange(of: model.ducking) { _, _ in model.applyAudio() }
                    Button("안내 음성 테스트") { model.audioTest() }
                    Text("데모는 미리 제작한 임시 한국어 음성을 사용합니다.").font(.caption)
                }
                Section("저장") {
                    Button("백업 파일 만들기") { exported = model.exportSave() }
                    if let exported { ShareLink("백업 공유·저장", item: exported) }
                    Button("백업 불러오기") { importing = true }
                    Text("불러오면 현재 진행도가 선택한 백업으로 교체됩니다. 먼저 백업을 저장해주세요.").font(.caption)
                }
                Section("진단") {
                    if let url = model.diagnostics() { ShareLink("진단 정보 내보내기", item: url) }
                    Text("진단 파일에는 원시 GPS 좌표와 헌터명을 넣지 않습니다.").font(.caption)
                }
                Section("이용 안내") {
                    NavigationLink("활동과 성장 가이드") { FieldGuideView() }
                }
                Section("개발 상태") {
                    Text("0.3.0 · 현장 활동과 장비 데모")
                    Text("장비 일러스트 12종 · 시간/거리/자유 목표 · 활동 상세 기록. 주요 보스 누적과 정식 음성은 후속 단계입니다.").font(.caption)
                }
            }.navigationTitle("메뉴")
        }
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
        self.padding(18).frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Color.white.opacity(0.08)))
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
