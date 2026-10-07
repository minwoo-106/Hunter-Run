import SwiftUI

struct OutdoorSetupView: View {
    @EnvironmentObject var model: AppModel
    @AppStorage("activityMinutes") private var minutes = 20
    @AppStorage("activityGoalKind") private var goalKind: GoalKind = .time
    @AppStorage("activityKilometers") private var kilometers = 3
    @AppStorage("activityAcceleration") private var pursuit = false
    @State private var indoorCheck = false
    @State private var indoorStartRequested = false
    @State private var quests = false
    @State private var bosses = false
    private let refresh = Timer.publish(every: 30, on: .main, in: .common).autoconnect()
    private var indoor: Bool { model.selectedEnvironment.isIndoor }
    private func beginActivity() {
        let kind: GoalKind = indoor && goalKind == .distance ? .time : goalKind
        let goal = ActivityGoal(kind: kind, value: kind == .time ? Double(minutes * 60) : kind == .distance ? Double(kilometers * 1000) : 0)
        model.start(simulated: false, seconds: kind == .time ? goal.value : 1200, pursuit: pursuit, goal: goal, environment: model.selectedEnvironment)
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    eyebrow("FIELD PREPARATION")
                    Text(model.activeExam == nil ? "오늘의 발걸음을 정해요" : "승급 심사 출동").font(.title.bold())
                    location
                    if let exam = model.activeExam {
                        VStack(alignment: .leading, spacing: 10) {
                            Label(exam.title, systemImage: "shield.checkered").font(.headline)
                            Text("전용 감시체를 상대하는 심사예요. 일반 의뢰도 조건이 맞으면 함께 진행돼요.").font(.caption).foregroundStyle(Theme.muted)
                            Button("일반 활동으로 돌아가기") { model.selectQuest(nil) }.buttonStyle(GameButtonStyle())
                        }.card().accessibilityIdentifier("setup.exam")
                    } else { modes }
                    if model.selectedMode == .contract && model.activeExam == nil && model.canTrackGate {
                        VStack(alignment: .leading, spacing: 10) {
                            Toggle("일반 게이트 추적", isOn: Binding(
                                get: { model.save.profile.gateProgress?.tracking == true },
                                set: { model.setGateTracking($0) }
                            )).tint(Theme.teal).accessibilityIdentifier("gate.tracking")
                            let progress = model.save.profile.gateProgress ?? GateProgress()
                            if progress.pending {
                                Text("게이트 위치를 확인했어요. 다음 적격 야외 현장 사냥에서 다시 접근할 수 있어요.")
                                    .foregroundStyle(Theme.teal)
                            } else if progress.missedEligibleSessions > 0 {
                                Text("흔적 분석 1 / 2 · 다음 적격 야외 현장 사냥에서 게이트를 발견해요.")
                                    .foregroundStyle(Theme.teal)
                            } else {
                                Text("야외 현장 사냥에서 게이트 흔적을 추적해요. 두 번의 적격 활동 안에 위치를 특정해요.")
                                    .foregroundStyle(Theme.muted)
                            }
                            if indoor { Text("실내 활동에서는 게이트 추적 횟수가 소모되지 않아요.").foregroundStyle(Theme.muted) }
                        }.font(.caption).card()
                    }
                    goal
                    VStack(alignment: .leading, spacing: 10) {
                        Label("함께 진행하는 의뢰", systemImage: "list.clipboard").font(.headline)
                        if let focus = model.activeQuest {
                            Label("현재 추적 중", systemImage: "scope").font(.caption.bold()).foregroundStyle(Theme.teal)
                            Text(focus.title).foregroundStyle(Theme.teal).accessibilityIdentifier("quest.focus")
                            Text(focus.detail).font(.caption).foregroundStyle(Theme.muted)
                            if focus.id == "wolf-first" || focus.id == "wolf-ten" {
                                Text("잔향 늑대 토벌은 야외 현장 사냥에서 달리기로 판정되고 위치 신호가 양호할 때 진행돼요. 탐험은 흔적 조사 중심이에요.").font(.caption).foregroundStyle(Theme.muted)
                            }
                        } else { Text("열린 일반 의뢰는 자동으로 함께 진행돼요.").font(.caption).foregroundStyle(Theme.muted) }
                        Button("추적 목표 변경") { quests = true }.buttonStyle(GameControlStyle()).accessibilityIdentifier("setup.quests")
                    }.card()
                    if model.selectedMode == .gate && model.activeExam == nil {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(model.allBosses.first { $0.id == model.selectedBoss }?.name ?? "토벌 대상을 선택해주세요").font(.headline)
                            if indoor && model.allBosses.first(where: { $0.id == model.selectedBoss })?.requiredBossClear != nil {
                                Text("변이 재현은 야외 전용이에요. 야외로 전환해주세요.").font(.caption).foregroundStyle(Theme.teal)
                            }
                            Button { bosses = true } label: { Label("토벌 대상 선택", systemImage: "scope") }.buttonStyle(GameButtonStyle()).accessibilityIdentifier("setup.bosses")
                        }.card()
                    }
                    Button { if indoor { indoorCheck = true } else { beginActivity() } } label: {
                        Label(indoor ? "움직임 확인 후 입장" : model.activeExam != nil ? "승급 심사 시작" : model.selectedMode.startTitle(boss: model.selectedBoss != nil), systemImage: "figure.run")
                            .frame(maxWidth: .infinity).padding(10)
                    }.buttonStyle(GameButtonStyle(primary: true)).disabled(!model.canStartReal).accessibilityIdentifier("activity.start")
                    Text(indoor ? "움직이는 시간만 인정해요. 화면 잠금·다른 앱 이동 시 일시정지해요." : "활동 중 화면을 유지해요. 종료하면 운동 기록과 의뢰 성과를 함께 저장해요.").font(.caption).foregroundStyle(Theme.muted)
                    Text("활동시간이 3분 미만이면 기록·보상·의뢰 진행도가 저장되지 않아요.").font(.caption).foregroundStyle(Theme.muted)
                    if AppModel.testHarness {
                        if model.selectedFieldDemo != nil {
                            Button("선택 개체 모의 활동") { model.start(simulated: true, seconds: 180, pursuit: true) }.accessibilityIdentifier("activity.mock.encounter")
                        }
                        if model.selectedBoss != nil {
                            Button("선택 보스 모의 활동") { model.start(simulated: true, seconds: 180, pursuit: true) }.accessibilityIdentifier("activity.mock.boss")
                        }
                        Button("3분 모의 활동") { model.start(simulated: true, seconds: 180, pursuit: pursuit, environment: model.selectedEnvironment) }.buttonStyle(GameButtonStyle()).accessibilityIdentifier("activity.mock")
                        Button("20분 의뢰 모의 활동 · 장기전 포함") { model.selectedBoss = nil; model.selectedMode = .contract; model.start(simulated: true, seconds: 1200, pursuit: true) }.accessibilityIdentifier("activity.mock.long")
                    }
                }.padding(22)
            }.labyrinthScreen().navigationTitle("헌터 활동").navigationBarTitleDisplayMode(.inline)
        }
        .onReceive(refresh) { _ in model.objectWillChange.send() }
        .onChange(of: model.selectedEnvironment) { _, value in if value.isIndoor && goalKind == .distance { goalKind = .time } }
        .sheet(isPresented: $bosses) { NavigationStack { BossBoardView().toolbar { ToolbarItem(placement: .cancellationAction) { Button { bosses = false } label: { Image(systemName: "xmark").frame(width: 44, height: 44) }.buttonStyle(.plain).accessibilityLabel("토벌 선택 닫기").accessibilityIdentifier("boss.close") } } } }
        .sheet(isPresented: $quests) { NavigationStack { QuestBoardView().toolbar { ToolbarItem(placement: .cancellationAction) { Button("닫기") { quests = false } } } } }
        .fullScreenCover(isPresented: $indoorCheck, onDismiss: {
            if indoorStartRequested { indoorStartRequested = false; beginActivity() }
            model.stopIndoorCheck()
        }) { IndoorCheckView { indoorStartRequested = true } }
    }
    private var location: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("야외 활동", systemImage: "location.fill").font(.headline)
            Text("평소 다니는 길에서 탐색과 전투를 이어가요.").font(.caption).foregroundStyle(Theme.muted)
        }.card()
    }
    private var modes: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("활동 방식").font(.headline)
            ForEach(RunMode.allCases, id: \.rawValue) { mode in
                Button { model.selectedMode = mode } label: {
                    HStack(spacing: 12) {
                        Image(systemName: !model.modeAllowed(mode) ? "lock.fill" : model.selectedMode == mode ? "checkmark.circle.fill" : "circle")
                        VStack(alignment: .leading, spacing: 4) { Text(mode.title).font(.headline); Text(mode.detail).font(.caption).foregroundStyle(Theme.muted) }
                        Spacer(minLength: 0)
                    }.frame(minHeight: 46).padding(10).background(model.selectedMode == mode ? Theme.teal.opacity(0.1) : .clear, in: RoundedRectangle(cornerRadius: 10))
                }.buttonStyle(.plain).foregroundStyle(model.modeAllowed(mode) ? Labyrinth.parchment : Theme.muted)
                    .disabled(!model.modeAllowed(mode)).accessibilityIdentifier("mode." + mode.rawValue)
            }
            if !model.modeAllowed(.gate) { Text("고위험 게이트 · D급 평가와 관측부 Lv.2에서 해금").font(.caption2).foregroundStyle(Theme.muted) }
            Text("탐험은 조사 중심이에요. 야외 현장 사냥의 토벌은 달리기 판정과 양호한 위치 신호가 필요하고, 걷기나 신호 부족 구간은 조사로 바뀌어요.").font(.caption).foregroundStyle(Theme.muted)
        }.card()
    }
    private var goal: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("운동 목표").font(.headline)
            Picker("목표 종류", selection: $goalKind) {
                ForEach(GoalKind.allCases.filter { !indoor || $0 != .distance }, id: \.rawValue) { Text($0.title).tag($0) }
            }.pickerStyle(.segmented).accessibilityIdentifier("goal.kind")
            if goalKind == .time {
                Picker("목표 시간", selection: $minutes) {
                    Text("5분").tag(5); Text("20분").tag(20); Text("30분").tag(30)
                    if model.unlocked("extended-contract") { Text("45분").tag(45) }
                }.pickerStyle(.segmented)
            } else if goalKind == .distance {
                Picker("목표 거리", selection: $kilometers) { Text("1 km").tag(1); Text("3 km").tag(3); Text("5 km").tag(5); Text("10 km").tag(10) }.pickerStyle(.segmented).accessibilityIdentifier("goal.distance")
            } else { Text(indoor ? "실내 자유 활동도 하루 합산 60분까지예요. 오늘 남은 시간에 자동 종료해요." : "시간과 거리 제한 없이 활동해요. 안전한 곳에서 활동을 마치면 성과를 저장해요.").font(.caption).foregroundStyle(Theme.muted).accessibilityIdentifier("goal.free.help") }
            if !indoor {
                Toggle("선택적 가속 허용", isOn: $pursuit)
                Text("선택적 가속은 10초, 최대 2회예요. 가속하지 않아도 유지 대응으로 진행해요.").font(.caption2).foregroundStyle(Theme.muted)
            } else { Text("실내 전투는 가속 대신 움직임 유지로 진행해요.").font(.caption).foregroundStyle(Theme.muted) }
        }.card()
    }
}
