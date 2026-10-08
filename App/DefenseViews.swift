import SwiftUI

/// One activity destination replaces the retired indoor-running entry; no new global tab.
struct SetupView: View {
    @EnvironmentObject var model: AppModel
    @State private var indoor = false
    @State private var defensePath: [Int] = []
    var body: some View {
        VStack(spacing: 0) {
            Picker("활동 선택", selection: $indoor) {
                Text("야외 활동").tag(false)
                Text("지부 방어 작전").tag(true)
            }.pickerStyle(.segmented).padding(.horizontal, 20).padding(.top, 8)
                .accessibilityIdentifier("activity.destination")
            if indoor { NavigationStack(path: $defensePath) { DefenseHubView(runtime: model.defenseRuntime) } }
            else { OutdoorSetupView() }
        }.background(Theme.ink)
            .onAppear { model.selectedEnvironment = .outdoor; if model.save.profile.defense?.active != nil || model.save.profile.defense?.pendingReport != nil { indoor = true } }
            .onChange(of: model.showDefense) { _, presented in
                // A started operation returns to the hub, never its now-stale briefing.
                if presented { defensePath.removeAll() }
            }
    }
}

struct DefenseHubView: View {
    @EnvironmentObject var model: AppModel
    @ObservedObject var runtime: DefenseRuntime
    private var progress: DefenseProgress { model.save.profile.defense ?? DefenseProgress() }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                DefenseHero(completed: progress.records.count)
                if let error = runtime.error { Text(error).foregroundStyle(.orange).accessibilityIdentifier("defense.error") }
                if runtime.catalog == nil {
                    Text("작전 자료를 읽지 못했어요. 앱 파일을 확인해주세요.").card()
                } else if let active = progress.active {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("\(active.episode)회차 · 중단한 작전").font(.headline)
                        Text("안내 진행 \(defenseTime(active.elapsed)) / 24:00 · \(active.intensity.title)").foregroundStyle(Theme.muted)
                        Button("이어서 준비하기") { runtime.restore(); model.showDefense = true }
                            .buttonStyle(GameButtonStyle(primary: true)).accessibilityIdentifier("defense.restore")
                    }.card()
                } else if let report = progress.pendingReport {
                    Button("\(report)회차 귀환 보고 확인") { model.showDefense = true }
                        .buttonStyle(GameButtonStyle(primary: true)).accessibilityIdentifier("defense.report")
                } else if let n = progress.nextEpisode, let episode = runtime.catalog?.episode(n) {
                    NavigationLink(value: n) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("다음 작전 · \(n) / 30").font(.caption)
                            Text(episode.title).font(.title3.bold())
                            Text("\(episode.operation.title) · 24분").font(.caption)
                        }.frame(maxWidth: .infinity, alignment: .leading)
                    }.buttonStyle(GameButtonStyle(primary: true)).accessibilityIdentifier("defense.next")
                } else { DefenseCompletionCard(progress: progress) }
                DisclosureGroup("지부 방어 작전은 어떤 운동인가요?") {
                    Text("지부가 격리해둔 침입 구역을 30번의 홈트로 정리하는 이야기예요. 날짜나 연속 출석과 관계없이 내 속도로 이어갑니다. 하루를 쉬어도 시설과 자원은 줄지 않아요.")
                    Text("회차는 이야기 진행도, 강도는 오늘의 선택이에요. 어떤 강도로 마쳐도 같은 이야기와 생활 일러스트를 받아요.").padding(.top, 8)
                    Text("진행 시간에 맞춰 따라 하는 운동 안내예요. 자세·횟수·칼로리를 자동 판정하지 않으며, 기록에는 안내를 완료한 시간을 남겨요.").padding(.top, 8)
                }.font(.callout).foregroundStyle(Theme.muted)
                if let catalog = runtime.catalog {
                    DefenseProgressMap(catalog: catalog, progress: progress)
                    NavigationLink { DefenseAlbumView(catalog: catalog, completed: progress.records.count) } label: {
                        Label("지켜낸 일상 · 생활 앨범", systemImage: "photo.on.rectangle.angled")
                    }.buttonStyle(GameButtonStyle()).accessibilityIdentifier("defense.album")
                    if !progress.records.isEmpty {
                        NavigationLink { DefenseHistoryView(catalog: catalog, progress: progress) } label: { Label("완료한 작전 기록", systemImage: "list.clipboard") }
                            .buttonStyle(GameButtonStyle())
                    }
                }
            }.padding(20)
        }.background(Theme.ink).navigationTitle("지부 방어 작전").navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: Int.self) { number in
                if let episode = runtime.catalog?.episode(number) {
                    DefenseBriefingView(runtime: runtime, episode: episode)
                }
            }
            .environment(\.labyrinthStyle, true)
    }
}

private struct DefenseHero: View {
    let completed: Int
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Image("DefenseAnnex").resizable().scaledToFill().frame(height: 235).clipped()
                .overlay(LinearGradient(colors: [.clear, Theme.ink], startPoint: .top, endPoint: .bottom))
            VStack(alignment: .leading, spacing: 8) {
                Text("지부 방어 작전 — 30회 캠페인").font(.caption).foregroundStyle(Theme.teal)
                Text(completed == 30 ? "우리가 지켜낸 일상" : "돌아올 곳을 지켜요").font(.title.bold())
                HStack { Text("\(completed) / 30 작전 완료").font(.headline.monospacedDigit()); Spacer(); Text(completed == 30 ? "안정화 완료" : "격리 유지 중").font(.caption).foregroundStyle(Theme.teal) }
                ProgressView(value: Double(completed), total: 30).tint(Theme.teal)
            }.padding(16)
        }.clipShape(RelicShape()).accessibilityElement(children: .combine)
    }
}

private struct DefenseProgressMap: View {
    let catalog: DefenseCatalog
    let progress: DefenseProgress
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("서른 번의 발걸음").font(.title3.bold())
            ForEach(0..<6) { act in
                VStack(alignment: .leading, spacing: 8) {
                    Text(progress.records.count >= act * 5 ? "\(act + 1)막 · \(catalog.acts[act])" : "\(act + 1)막 · 아직 펼치지 않은 이야기").font(.caption).foregroundStyle(Theme.muted)
                    HStack(spacing: 8) {
                        ForEach((act * 5 + 1)...(act * 5 + 5), id: \.self) { number in
                            let complete = number <= progress.records.count
                            VStack(spacing: 5) {
                                Text(String(number)).font(.headline.monospacedDigit())
                                Image(systemName: complete ? "checkmark" : number == progress.nextEpisode ? "arrow.right" : "lock.fill").font(.caption2)
                            }.frame(maxWidth: .infinity, minHeight: 52)
                                .background(complete ? Theme.teal.opacity(0.15) : Labyrinth.stone, in: RoundedRectangle(cornerRadius: 9))
                                .foregroundStyle(complete ? Theme.teal : Theme.muted)
                                .accessibilityLabel("\(number)회차 " + (complete ? "완료" : number == progress.nextEpisode ? "다음 작전" : "미진행"))
                        }
                    }
                }
            }
        }
    }
}

private struct DefenseBriefingView: View {
    @EnvironmentObject var model: AppModel
    @ObservedObject var runtime: DefenseRuntime
    let episode: DefenseEpisode
    @State private var intensity: DefenseIntensity = .standard
    @State private var ready = false
    @State private var guide = false
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("작전 \(episode.number) / 30 · \(episode.operation.title)").font(.caption).foregroundStyle(Theme.teal)
                Text(episode.title).font(.largeTitle.bold())
                Text(episode.briefing).font(.body).lineSpacing(5)
                Text("오늘의 컨디션").font(.headline)
                ForEach(DefenseIntensity.allCases, id: \.self) { level in
                    Button { intensity = level } label: {
                        HStack(alignment: .top) {
                            Image(systemName: intensity == level ? "checkmark.circle.fill" : "circle")
                            VStack(alignment: .leading, spacing: 5) {
                                Text(level.title).font(.headline)
                                Text("동작 \(level.workSeconds)초 · 회복과 준비 \(60-level.workSeconds)초").font(.caption)
                            }; Spacer()
                        }.padding(14).background(intensity == level ? Theme.teal.opacity(0.13) : Labyrinth.stone, in: RelicShape())
                    }.buttonStyle(.plain).foregroundStyle(intensity == level ? Theme.teal : Labyrinth.parchment)
                        .accessibilityIdentifier("defense.intensity." + level.rawValue)
                }
                Text("모두 24분 · 이야기와 일러스트 보상은 같아요. 도전에서도 점프나 전력 질주는 필요하지 않아요.").font(.caption).foregroundStyle(Theme.muted)
                VStack(alignment: .leading, spacing: 7) {
                    Text("준비 4분 → 교전 5분 → 재정비 1분").font(.callout)
                    Text("교전 5분 → 재정비 1분 → 교전 5분 → 정리 3분").font(.callout)
                }.card()
                Button("오늘의 동작과 쉬운 대안 보기") { guide = true }.buttonStyle(GameButtonStyle())
                Text("미끄럽지 않은 공간과 튼튼한 벽을 준비해요. 동작이 불편하면 편한 걷기로 바꾸고, 통증이나 어지러움이 있으면 멈춰요. 준비 시간이 더 필요하면 시작 전에 충분히 몸을 풀어주세요.").font(.caption).foregroundStyle(Theme.muted)
                Text("휴대폰은 손에 들지 않고 세워두어도 돼요. 운동 중 자동 화면 잠금을 막아요. 화면 잠금·다른 앱 이동·전화는 작전을 일시정지해요.").font(.caption).foregroundStyle(Theme.muted)
                Toggle("주변 공간과 안내 음량을 확인했어요", isOn: $ready).tint(Theme.teal).accessibilityIdentifier("defense.ready")
                if model.voiceVolume == 0 { Text("설정에서 안내 음량이 꺼져 있어요. 소리를 켜거나 화면의 안내를 확인하며 진행해주세요.").font(.caption).foregroundStyle(.orange) }
                if !runtime.audioReady { Text("작전 안내 음성이 준비되지 않았어요. 앱 파일을 확인해주세요.").foregroundStyle(.orange) }
                if let error = runtime.error { Text(error).foregroundStyle(.orange) }
                Button("작전 준비 완료") { runtime.start(episode: episode.number, intensity: intensity) }
                    .buttonStyle(GameButtonStyle(primary: true)).disabled(!ready || !runtime.audioReady || model.growthLocked)
                    .accessibilityIdentifier("defense.start")
            }.padding(22)
        }.labyrinthScreen(artwork: "DefenseAnnex").navigationTitle("출동 준비").navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $guide) { DefenseExerciseGuide(exercises: Array(Set(episode.exercises)).sorted { $0.rawValue < $1.rawValue }) }
    }
}

private struct DefenseExerciseGuide: View {
    @Environment(\.dismiss) private var dismiss
    let exercises: [DefenseExercise]
    var body: some View {
        NavigationStack {
            List(exercises, id: \.self) { exercise in
                VStack(alignment: .leading, spacing: 12) {
                    Label(exercise.title, systemImage: exercise.symbol).font(.headline)
                    Text(exercise.instruction)
                    Text("쉬운 대안 · " + exercise.alternative).font(.caption).foregroundStyle(.secondary)
                }.padding(.vertical, 8)
            }.navigationTitle("오늘의 동작").toolbar { ToolbarItem(placement: .confirmationAction) { Button("확인") { dismiss() } } }
        }
    }
}

struct DefenseSessionView: View {
    @EnvironmentObject var model: AppModel
    @ObservedObject var runtime: DefenseRuntime
    @State private var end = false
    @Environment(\.accessibilityReduceMotion) private var reducedMotion
    var body: some View {
        NavigationStack {
            Group {
                if let report = model.save.profile.defense?.pendingReport, let episode = runtime.catalog?.episode(report) {
                    DefenseReportView(runtime: runtime, episode: episode)
                } else if let session = runtime.session, let moment = runtime.moment {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 22) {
                            HStack { Text("작전 \(session.episode) / 30").font(.headline); Spacer(); Text(session.intensity.title).foregroundStyle(Theme.teal) }
                            Text(runtime.episode?.title ?? "지부 방어 작전").font(.title2.bold())
                            DefenseBattleDisplay(moment: moment, elapsed: session.elapsed, paused: session.paused, reducedMotion: reducedMotion)
                            HStack(alignment: .firstTextBaseline) {
                                Text(moment.title).font(.title3.bold()); Spacer()
                                Text(defenseTime(moment.phaseRemaining)).font(.title2.monospacedDigit())
                            }
                            Text(moment.phase == .battle ? (moment.preparing ? "잠깐 회복 · 다음 동작 준비" : moment.exercise.title) : "천천히 걷고 편하게 호흡해요")
                                .font(.title.bold()).accessibilityIdentifier("defense.exercise")
                            if moment.phase == .battle {
                                Text(moment.preparing ? "다음 · " + moment.exercise.title : "편한 걷기로 바꿔도 괜찮아요").foregroundStyle(Theme.muted)
                                Text("\(Int(ceil(moment.intervalRemaining)))초").font(.system(size: 48, weight: .semibold, design: .rounded)).monospacedDigit()
                            }
                            Text(runtime.caption).font(.body).lineSpacing(4).frame(maxWidth: .infinity, alignment: .leading).card()
                            HStack { Text("안내 진행").foregroundStyle(Theme.muted); Spacer(); Text("\(defenseTime(session.elapsed)) / 24:00").monospacedDigit().accessibilityIdentifier("defense.elapsed") }.font(.caption)
                            if let error = runtime.error { Text(error).foregroundStyle(.orange) }
                            if session.elapsed >= 1440 {
                                Button("완료 기록 다시 저장") { runtime.retryCompletion() }.buttonStyle(GameButtonStyle(primary: true))
                            } else {
                                Button(session.paused ? "준비됐어요 · 계속" : "일시정지") { if session.paused { runtime.resume() } else { runtime.pause() } }
                                    .buttonStyle(GameButtonStyle(primary: true)).accessibilityIdentifier("defense.pause")
                            }
                            if session.paused {
                                Button("저장하고 나중에 이어하기") { runtime.leave() }.buttonStyle(GameButtonStyle())
                                Button("이번 작전 종료") { end = true }.buttonStyle(GameControlStyle())
                            }
                        }.padding(22)
                    }.labyrinthScreen(artwork: "DefenseAnnex")
                } else {
                    VStack(spacing: 20) { Text("지부 방어 작전").font(.title); Button("활동 화면으로") { model.showDefense = false }.buttonStyle(GameButtonStyle()) }.padding()
                }
            }.navigationBarTitleDisplayMode(.inline).navigationTitle("지부 통신")
        }.interactiveDismissDisabled()
            .confirmationDialog("이번 작전을 종료할까요?", isPresented: $end, titleVisibility: .visible) {
                Button("진행 중인 회차만 처음부터", role: .destructive) { runtime.discard() }
                Button("계속 보관", role: .cancel) {}
            } message: { Text("완료한 회차와 보상은 유지돼요. 현재 회차의 진행 시간만 초기화됩니다.") }
    }
}

private struct DefenseBattleDisplay: View {
    let moment: DefenseMoment
    let elapsed: Double
    let paused: Bool
    let reducedMotion: Bool
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20).fill(Theme.ink.opacity(0.9))
            VStack(spacing: 16) {
                HStack(spacing: 14) {
                    ForEach(0..<3) { index in
                        Image(systemName: elapsed >= Double([540,900,1260][index]) ? "checkmark.shield.fill" : "shield.lefthalf.filled")
                            .font(.system(size: 34)).foregroundStyle(elapsed >= Double([540,900,1260][index]) ? Theme.teal : Labyrinth.gold.opacity(0.6))
                    }
                }
                ProgressView(value: elapsed, total: 1440).tint(Theme.teal)
                Text(paused ? "격리 유지 · 일시정지" : moment.phase == .battle ? (moment.preparing ? "격리벽이 통로를 지키고 있어요" : "방어선 유지 중") : "지부 통신 연결 중")
                    .font(.caption).foregroundStyle(Theme.muted)
            }.padding(24)
        }.frame(height: 150)
            .animation(reducedMotion ? nil : .easeInOut(duration: 0.4), value: moment.phaseIndex)
            .accessibilityElement(children: .ignore).accessibilityLabel("\(moment.title). \(paused ? "일시정지" : "진행 중")")
    }
}

private struct DefenseReportView: View {
    @EnvironmentObject var model: AppModel
    @ObservedObject var runtime: DefenseRuntime
    let episode: DefenseEpisode
    @State private var reward: DefenseIllustration?
    private var progress: DefenseProgress { model.save.profile.defense ?? DefenseProgress() }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text("작전 완료").font(.largeTitle.bold()).foregroundStyle(Theme.teal)
                Text("\(episode.number)회차 · \(episode.title)").font(.title2.bold())
                if let record = progress.records.first(where: { $0.episode == episode.number }) {
                    Text("24분 안내 완료 · \(record.intensity.title)").font(.headline)
                    Text("동작·칼로리 자동 측정 기록이 아닌 안내 완료 기록이에요.").font(.caption).foregroundStyle(Theme.muted)
                }
                Text(episode.outro).lineSpacing(6).card()
                Text("EXP +10 · 마정석 +2 · 이번 회차 최초 완료 보상 저장됨").font(.caption).foregroundStyle(Theme.teal)
                if let illustration = runtime.catalog?.illustrations.first(where: { $0.episode == episode.number }) {
                    Button { reward = illustration } label: {
                        VStack(alignment: .leading, spacing: 10) {
                            Image(illustration.asset).resizable().scaledToFit().clipShape(RelicShape())
                            Text("새 생활 일러스트 · " + illustration.title).font(.headline)
                            Text("눌러서 감상하기").font(.caption)
                        }
                    }.buttonStyle(.plain).accessibilityIdentifier("defense.reward")
                }
                if episode.number == 30 { DefenseCompletionCard(progress: progress) }
                if let error = runtime.error { Text(error).foregroundStyle(.orange) }
                Button("지부로 돌아가기") { runtime.clearReport() }.buttonStyle(GameButtonStyle(primary: true)).accessibilityIdentifier("defense.return")
            }.padding(22)
        }.labyrinthScreen(artwork: "DefenseAnnex")
            .sheet(item: $reward) { DefenseArtView(illustration: $0) }
    }
}

private struct DefenseCompletionCard: View {
    let progress: DefenseProgress
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("30회 캠페인 완주", systemImage: "seal.fill").font(.title2.bold()).foregroundStyle(Labyrinth.gold)
            Text("쉬었다 돌아온 날도, 가볍게 움직인 날도. 함께 지켜낸 서른 번의 작전입니다.")
            ForEach(DefenseIntensity.allCases, id: \.self) { level in
                HStack { Text(level.title); Spacer(); Text("\(progress.records.filter { $0.intensity == level }.count)회") }
            }
            Text("완료한 안내 시간 · \(Int(progress.totalSeconds) / 3600)시간 \(Int(progress.totalSeconds) % 3600 / 60)분").font(.headline)
            Text("지부는 안정화됐어요. 생활 앨범과 작전 기록은 언제든 다시 볼 수 있어요.").font(.caption).foregroundStyle(Theme.muted)
        }.card()
    }
}

private struct DefenseAlbumView: View {
    let catalog: DefenseCatalog
    let completed: Int
    @State private var selected: DefenseIllustration?
    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 18) {
                ForEach(catalog.illustrations) { art in
                    Button { if completed >= art.episode { selected = art } } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            if completed >= art.episode { Image(art.asset).resizable().scaledToFit().clipShape(RelicShape()) }
                            else { RoundedRectangle(cornerRadius: 10).fill(Labyrinth.stone).aspectRatio(2.0/3.0, contentMode: .fit).overlay(Image(systemName: "lock.fill").foregroundStyle(Theme.muted)) }
                            Text(completed >= art.episode ? art.title : "아직 펼치지 않은 일상").font(.headline)
                            Text("\(art.episode)회차 기념").font(.caption).foregroundStyle(Theme.muted)
                        }
                    }.buttonStyle(.plain).disabled(completed < art.episode)
                }
            }.padding(20)
        }.background(Theme.ink).navigationTitle("지켜낸 일상")
            .sheet(item: $selected) { DefenseArtView(illustration: $0) }
    }
}

private struct DefenseArtView: View {
    @Environment(\.dismiss) private var dismiss
    let illustration: DefenseIllustration
    @State private var behind = false
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Image(behind ? (illustration.behind ?? illustration.asset) : illustration.asset).resizable().scaledToFit()
                    Text(behind ? "“으아앙! 왜 나만 따라와! 나 오늘 휴가인데!”\n예쁘게 입고 나와서 눈물 콧물 다 빼는 중. 조금 더 걷겠다고 했지, 뛰겠다고는 안 했는데…!" : illustration.caption).padding(.horizontal, 20).lineSpacing(5)
                    if illustration.behind != nil {
                        Button(behind ? "메인 일러스트" : "비하인드") { behind.toggle() }.buttonStyle(GameButtonStyle()).padding(.horizontal, 20).accessibilityIdentifier("defense.behind")
                    }
                }.padding(.bottom, 24)
            }.background(Theme.ink).navigationTitle(behind ? "나 오늘 휴가인데!" : illustration.title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("닫기") { dismiss() } } }
        }
    }
}

private struct DefenseHistoryView: View {
    let catalog: DefenseCatalog
    let progress: DefenseProgress
    var body: some View {
        List(progress.records.reversed()) { record in
            VStack(alignment: .leading, spacing: 8) {
                Text("\(record.episode)회차 완료 · \(record.intensity.title)").font(.headline)
                Text(catalog.episode(record.episode)?.title ?? "지부 방어 작전")
                Text(record.date.formatted(date: .abbreviated, time: .shortened) + " · 안내 24분").font(.caption).foregroundStyle(.secondary)
                if let episode = catalog.episode(record.episode) { DisclosureGroup("귀환 후일담") { Text(episode.outro).padding(.vertical, 8) } }
            }.padding(.vertical, 8)
        }.navigationTitle("완료한 작전")
    }
}

private func defenseTime(_ seconds: Double) -> String {
    let s = max(0, Int(ceil(seconds)))
    return String(format: "%02d:%02d", s / 60, s % 60)
}
