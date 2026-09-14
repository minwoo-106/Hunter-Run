import SwiftUI

struct BossHPView: View {
    let name: String
    let remaining: Double
    let maximum: Double
    let phase: String
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack { Text(name).font(.headline); Spacer(); Text(remaining == 0 ? "토벌 완료" : phase).font(.caption).foregroundStyle(Theme.teal) }
            ProgressView(value: remaining, total: maximum).tint(Theme.teal)
            Text("HP \(Int(remaining)) / \(Int(maximum))").font(.caption.monospacedDigit())
        }.card()
    }
}

struct BossReportView: View {
    let report: BossReport
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(report.name + " · \(report.round)회차").font(.headline)
            Text(report.cleared ? "토벌 완료 · 추가 EXP 120 / 마정석 15 / 코어 2 포함" : "이번 활동의 피해가 다음 토벌로 이어집니다.").font(.caption).foregroundStyle(Theme.teal)
            Text("누적 적용 피해 \(Int(report.damage)) · 남은 HP \(Int(report.remainingHP))").font(.callout)
            ProgressView(value: report.remainingHP, total: report.maximumHP).tint(Theme.teal)
        }.card()
    }
}

struct BossBoardView: View {
    @State private var mutations = false
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                eyebrow("LONG-TERM ASSIGNMENTS")
                Text("여러 번의 활동으로\n하나의 토벌을.").font(.largeTitle.bold())
                Text("활동을 마칠 때 남은 HP를 저장합니다. 목표를 넘겨 달릴 필요는 없습니다.").foregroundStyle(Theme.muted)
                Picker("토벌 종류", selection: $mutations) { Text("주요 토벌").tag(false); Text("변이 의뢰").tag(true) }
                    .pickerStyle(.segmented).accessibilityIdentifier("boss.category")
                if mutations { Text("원형 보스를 완전히 토벌하면 새로운 대응 패턴이 열려요. 변이별 토벌 기록은 따로 이어져요.").font(.caption).foregroundStyle(Theme.muted) }
                ForEach(model.allBosses.filter { ($0.requiredBossClear != nil) == mutations }) { boss in
                    let state = BossCampaign.state(boss, profile: model.save.profile)
                    let unlocked = model.progressionCatalog.map { boss.available(to: model.save.profile, catalog: $0) } ?? false
                    VStack(alignment: .leading, spacing: 14) {
                        Image(BossMutations.artwork(boss)).resizable().scaledToFit().frame(maxWidth: .infinity).frame(height: 240).clipShape(RoundedRectangle(cornerRadius: 16)).accessibilityLabel(boss.name + " 이미지")
                        Text(boss.name).font(.title2.bold())
                        Text(boss.description).font(.callout).foregroundStyle(Theme.muted)
                        if boss.requiredBossClear != nil { Label("변이 의뢰 · 원형 토벌 후 해금", systemImage: "sparkles").font(.caption).foregroundStyle(Theme.teal) }
                        let encounter = BossEncounter(definition: boss, state: state)
                        BossHPView(name: "\(state.round)회차 · 누적 토벌 \(state.clears)회", remaining: state.remainingHP, maximum: state.maximumHP, phase: encounter.phaseName)
                        if !unlocked { Label("\(boss.requiredRank)급 · 관측부 Lv.2 · 관련 지부 이야기 진행 필요", systemImage: "lock.fill").font(.caption).foregroundStyle(Theme.muted) }
                        if state.remainingHP > 0 {
                            Button("토벌 활동 준비") { model.prepareBoss(boss); dismiss() }.buttonStyle(GameButtonStyle(primary: true)).disabled(!unlocked || model.growthLocked).accessibilityIdentifier("boss.prepare." + boss.id)
                        } else {
                            Button("새 토벌 회차 열기") { model.restartBoss(boss) }.buttonStyle(GameButtonStyle(primary: true)).disabled(!unlocked || model.growthLocked)
                        }
                        if AppModel.testHarness {
                            Button("모의 토벌 준비") { model.prepareBoss(boss, simulated: true); dismiss() }.buttonStyle(GameButtonStyle()).disabled(model.growthLocked).accessibilityIdentifier("boss.demo." + boss.id)
                        }
                    }.card()
                }
            }.padding(20)
        }.labyrinthScreen().navigationTitle("주요 보스 토벌").navigationBarTitleDisplayMode(.inline)
    }
}

struct BossSelectionView: View {
    @EnvironmentObject var model: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("게이트 임무 선택").font(.headline)
            Button { model.selectedBoss = nil } label: { Label("일반 게이트", systemImage: model.selectedBoss == nil ? "checkmark.circle.fill" : "circle") }.buttonStyle(GameButtonStyle())
            ForEach(model.allBosses) { boss in
                let available = model.progressionCatalog.map { boss.available(to: model.save.profile, catalog: $0) } ?? false
                Button { model.selectedBoss = boss.id } label: {
                    HStack { Image(systemName: model.selectedBoss == boss.id ? "checkmark.circle.fill" : "circle"); Text(boss.name); Spacer(); if !available { Image(systemName: "lock.fill") } }
                }.buttonStyle(GameButtonStyle()).disabled(!available)
                if model.selectedBoss == boss.id {
                    let state = BossCampaign.state(boss, profile: model.save.profile)
                    BossHPView(name: boss.name, remaining: state.remainingHP, maximum: state.maximumHP, phase: BossEncounter(definition: boss, state: state).phaseName)
                    if !available { Text("\(boss.requiredRank)급과 관측부 Lv.2를 갖추고, 관련 지부 이야기를 이어가면 열려요.").font(.caption).foregroundStyle(Theme.muted) }
                }
            }
        }.card().accessibilityIdentifier("boss.selection")
    }
}

struct CodexView: View {
    @EnvironmentObject var model: AppModel
    @State private var archive = false
    @State private var category = 0
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    eyebrow("CREATURE ARCHIVE")
                    Text("지부의 관측 도감").font(.largeTitle.bold())
                    Picker("도감 분류", selection: $category) {
                        Text("개체").tag(0); Text("장비").tag(1); Text("활동").tag(2); Text("재료").tag(3)
                    }.pickerStyle(.segmented)
                    if category == 0 {
                    Text("흔적을 조사하거나 개체와 조우하면 도감이 열려요. 연구부를 확장하면 전투 기록을 분석할 수 있어요.").foregroundStyle(Theme.muted)
                    DisclosureGroup("현장 조사 자료") {
                        NavigationLink("개체 출현과 발견 장비") { EncounterBoardView() }.accessibilityIdentifier("codex.field-intel")
                        Button("사건 대응 기록") { archive = true }
                    }.font(.callout)
                    ForEach(model.world?.monsters ?? []) { monster in
                        let records = monster.records(in: model.save.profile)
                        let known = monster.isKnown(in: model.save.profile)
                        NavigationLink { MonsterDetailView(monster: monster) } label: {
                            HStack(spacing: 16) {
                                if known { Image("Monster-" + monster.id).resizable().scaledToFit().frame(width: 100, height: 100).clipShape(RoundedRectangle(cornerRadius: 16)) }
                                else { Image(systemName: "questionmark.diamond").font(.largeTitle).foregroundStyle(Theme.muted).frame(width: 100, height: 100) }
                                VStack(alignment: .leading, spacing: 8) { Text(known ? monster.name : "미발견 개체").font(.headline); Text(known ? monster.family : "현장 조사로 등록").font(.caption).foregroundStyle(Theme.muted) }
                                Spacer(minLength: 0); Image(systemName: "chevron.right").font(.caption)
                            }.card()
                        }.buttonStyle(.plain).accessibilityIdentifier("monster." + monster.id)
                    }
                    } else if category == 1 { EquipmentArchiveView() }
                    else if category == 2 { ActivityArchiveView() }
                    else { MaterialArchiveView() }
                }.padding(20)
            }.labyrinthScreen().navigationTitle("도감").navigationBarTitleDisplayMode(.inline)
        }
        .fullScreenCover(isPresented: $archive) { FieldArchiveView().toolbar { ToolbarItem(placement: .confirmationAction) { Button("닫기") { archive = false }.buttonStyle(GameControlStyle()) } } }
    }
}

struct MonsterDetailView: View {
    @EnvironmentObject var model: AppModel
    let monster: MonsterDefinition
    var body: some View {
        let records = monster.records(in: model.save.profile)
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if !monster.isKnown(in: model.save.profile) {
                    ContentUnavailableView("아직 발견하지 못했습니다", systemImage: "questionmark.diamond", description: Text("실제 활동에서 관련 개체의 흔적을 찾으면 기록과 이미지가 열립니다."))
                } else {
                    Image("Monster-" + monster.id).resizable().scaledToFit().clipShape(RoundedRectangle(cornerRadius: 22))
                    eyebrow(monster.family)
                    Text(monster.name).font(.largeTitle.bold())
                    Text(monster.description).foregroundStyle(Theme.muted)
                    if model.unlocked("tactical-analysis"), let entry = model.fieldEncounters?.encounters.first(where: { $0.monsterID == monster.id }) {
                        VStack(alignment: .leading, spacing: 10) {
                            Label("연구부 전술 분석", systemImage: "scope").font(.headline)
                            Text(entry.tactic)
                            Text(entry.unlockHint).font(.caption).foregroundStyle(Theme.muted)
                            ForEach(model.progressionCatalog?.equipment.filter { $0.requiredEvent == entry.id } ?? []) { item in
                                NavigationLink(item.name) { EquipmentDetailView(item: item) }
                            }
                        }.card()
                    }
                    Text("발견 기록 \(records.count)회").font(.headline)
                    if model.unlocked("analysis") {
                        Text("누적 피해 \(Int(records.reduce(0) { $0 + $1.damage })) · 토벌 \(records.filter { $0.defeated == true }.count)회").foregroundStyle(Theme.teal)
                        Text("추격 성공 \(records.filter { $0.kind == .pursuit && ($0.outcome == .success || $0.outcome == .perfect) }.count)회").font(.caption)
                    } else { Label("연구부 Lv.2에서 전투 분석 해금", systemImage: "lock.fill").font(.caption).foregroundStyle(Theme.muted) }
                }
            }.padding(22)
        }.labyrinthScreen().navigationTitle("개체 기록").navigationBarTitleDisplayMode(.inline)
    }
}
