import SwiftUI

struct EquipmentGoalCard: View {
    @EnvironmentObject var model: AppModel
    var body: some View {
        if let id = model.save.profile.equipmentJournal?.targetID,
           let item = model.progressionCatalog?.equipment.first(where: { $0.id == id }) {
            VStack(alignment: .leading, spacing: 12) {
                Label("다음 목표 장비", systemImage: "scope").font(.headline).foregroundStyle(Theme.teal)
                NavigationLink { EquipmentDetailView(item: item) } label: {
                    HStack { GearArtwork(item: item, size: 64); Text(item.name).font(.headline); Spacer(); Image(systemName: "chevron.right") }
                }.buttonStyle(.plain)
                ForEach(EquipmentExperience.requirements(item, profile: model.save.profile)) { requirement in
                    Label(requirement.title, systemImage: requirement.met ? "checkmark.circle.fill" : "circle")
                        .font(.caption).foregroundStyle(requirement.met ? Theme.teal : Theme.muted)
                }
                if let hint = item.discoveryHint { Text(hint).font(.caption).foregroundStyle(Theme.teal) }
                NavigationLink { QuestBoardView() } label: { Text("현재 진행 가능한 의뢰 보기").font(.callout.bold()) }
                Text("마정석은 활동, 조사 데이터는 탐험, 코어는 게이트 토벌로 모아요.").font(.caption).foregroundStyle(Theme.muted)
            }.card().accessibilityIdentifier("gear.target.card")
        }
    }
}

struct EquipmentPresetsView: View {
    @EnvironmentObject var model: AppModel
    @State private var replacing: Int?
    var body: some View {
        DisclosureGroup("장비 조합 · 출발 전에 한 번에 착용") {
            VStack(spacing: 16) {
                ForEach(0..<3) { index in
                    let preset = model.save.profile.equipmentJournal?.presets.first { $0.id == index }
                    VStack(alignment: .leading, spacing: 8) {
                        Text(["탐색용", "사냥용", "보스용"][index]).font(.headline)
                        Text(preset.map { saved in
                            EquipmentSlot.allCases.compactMap { slot in model.progressionCatalog?.equipment.first { $0.id == saved.slots[slot.rawValue] }?.name }.joined(separator: " · ")
                        } ?? "저장한 조합이 없어요.").font(.caption).foregroundStyle(Theme.muted)
                        HStack {
                            Button("현재 장비 저장") { if preset != nil { replacing = index } else { model.storePreset(index) } }
                                .accessibilityIdentifier("gear.preset.save.\(index)")
                            Spacer()
                            Button("착용") { model.applyPreset(index) }.disabled(preset == nil)
                                .accessibilityIdentifier("gear.preset.apply.\(index)")
                        }.font(.callout.bold()).disabled(model.growthLocked)
                    }
                }
                Text("조합 이름은 구분용이에요. 자동 추천이나 추가 능력치는 없어요.").font(.caption).foregroundStyle(Theme.muted)
            }.padding(.top, 12)
        }.card().confirmationDialog("저장된 조합을 현재 착용 장비로 바꿀까요?", isPresented: Binding(get: { replacing != nil }, set: { if !$0 { replacing = nil } })) {
            Button("현재 장비로 저장") { if let index = replacing { model.storePreset(index) }; replacing = nil }
        }
    }
}

struct EquipmentComparisonCard: View {
    @EnvironmentObject var model: AppModel
    let item: EquipmentDefinition
    var body: some View {
        if let catalog = model.progressionCatalog {
            let next = EquipmentExperience.preview(item, profile: model.save.profile, catalog: catalog)
            VStack(alignment: .leading, spacing: 12) {
                Text("이 장비로 교체하면").font(.headline)
                HStack { metric("현재 공격", String(format: "×%.2f", model.stats.attack)); Spacer(); Image(systemName: "arrow.right"); Spacer(); metric("교체 후", String(format: "×%.2f", next.attack)) }
                Text(String(format: "최대 HP %+.0f · 피해 경감 %+.0f%%", next.hp - model.stats.hp, (next.defense - model.stats.defense) * 100)).font(.caption)
                NavigationLink { EquipmentLabView(candidate: item) } label: {
                    Label("몬스터별 공격 횟수 비교", systemImage: "scope").font(.callout.bold())
                }.accessibilityIdentifier("gear.lab.open")
                Text("같은 슬롯만 교체한 실제 계산값이에요. 다른 장비와 레벨은 유지해요.").font(.caption).foregroundStyle(Theme.muted)
            }.card()
        }
    }
}

struct EquipmentLabView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    let candidate: EquipmentDefinition
    @State private var selected = ""
    @State private var pulse = 0
    @State private var playing = false
    private var monsters: [CombatMonster] {
        guard let rules = model.combatRules else { return [] }
        return rules.monsters.filter { monster in
            model.world?.monsters.contains(where: { $0.id == monster.id && $0.isKnown(in: model.save.profile) }) == true
            || model.save.profile.runs.contains { $0.majorBoss?.bossID == monster.id || $0.records.contains { $0.monsterID == monster.id } }
        }
    }
    private var monster: CombatMonster? { monsters.first { $0.id == selected } ?? monsters.first }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                eyebrow("EQUIPMENT / TRAINING")
                Text("장비 시험실").font(.largeTitle.bold())
                Text(candidate.name + " 교체 비교").foregroundStyle(Theme.teal)
                if let monster, let catalog = model.progressionCatalog {
                    Picker("만난 몬스터", selection: Binding(get: { self.monster?.id ?? "" }, set: { selected = $0 })) {
                        ForEach(monsters, id: \.id) { Text($0.name).tag($0.id) }
                    }
                    Image("Monster-" + monster.id).resizable().scaledToFit().frame(maxWidth: .infinity).frame(height: 180)
                    let current = CombatEstimate(stats: model.stats, monster: monster)
                    let next = CombatEstimate(stats: EquipmentExperience.preview(candidate, profile: model.save.profile, catalog: catalog), monster: monster)
                    estimateRow("현재 착용", current, monster: monster)
                    estimateRow("교체 후", next, monster: monster)
                    Text("공격 \(current.hits)회 → \(next.hits)회 · 유효 거리 \(Int(current.distance))m → \(Int(next.distance))m")
                        .font(.headline).foregroundStyle(Theme.teal).accessibilityIdentifier("gear.lab.estimate")
                    Button(playing ? "재생 중" : "공격 과정 비교 재생") { pulse = 0; playing = true }
                        .buttonStyle(GameButtonStyle(primary: true)).disabled(playing)
                        .accessibilityIdentifier("gear.lab.play")
                    Text("실제 야외 전투 공식을 사용해요. 적의 최대 HP 기준이며, 조우 대기·안내·GPS 보류 시간은 제외합니다. 실내 시간형 전투에는 적용하지 않아요. 보상과 활동 기록은 생성하지 않습니다.")
                        .font(.caption).foregroundStyle(Theme.muted)
                    if max(current.hits, next.hits) > 12 { Text("긴 전투는 12단계로 압축해서 보여줘요.").font(.caption).foregroundStyle(Theme.muted) }
                } else {
                    ContentUnavailableView("아직 비교할 몬스터가 없어요", systemImage: "scope", description: Text("현장에서 만난 몬스터만 시험실에 나타나요."))
                }
            }.padding(22)
        }.labyrinthScreen().navigationTitle("장비 시험실").navigationBarTitleDisplayMode(.inline)
            .onChange(of: selected) { _, _ in playing = false; pulse = 0 }
            .onChange(of: scenePhase) { _, phase in if phase != .active { playing = false } }
            .task(id: playing) {
                guard playing else { return }
                if reduceMotion { pulse = 12; playing = false; return }
                for i in 1...12 {
                    do { try await Task.sleep(for: .milliseconds(240)) } catch { return }
                    guard !Task.isCancelled, scenePhase == .active else { return }
                    pulse = i
                }
                playing = false
            }
    }
    private func estimateRow(_ title: String, _ estimate: CombatEstimate, monster: CombatMonster) -> some View {
        let maximum = max(1, max(CombatEstimate(stats: model.stats, monster: monster).hits,
            model.progressionCatalog.map { CombatEstimate(stats: EquipmentExperience.preview(candidate, profile: model.save.profile, catalog: $0), monster: monster).hits } ?? 1))
        let hits = min(estimate.hits, Int(ceil(Double(pulse) / 12 * Double(maximum))))
        let hp = max(0, monster.maximumHP - Double(hits) * estimate.damage)
        return VStack(alignment: .leading, spacing: 8) {
            HStack { Text(title); Spacer(); Text("회당 피해 \(Int(estimate.damage)) · \(estimate.hits)회") }
            ProgressView(value: hp / monster.maximumHP).tint(Theme.teal)
            Text("HP \(Int(hp)) / \(Int(monster.maximumHP))").font(.caption.monospacedDigit())
        }.card()
    }
}

struct EquipmentMemoryView: View {
    @EnvironmentObject var model: AppModel
    let item: EquipmentDefinition
    var body: some View {
        if model.save.profile.growth.owned.contains(item.id) {
            VStack(alignment: .leading, spacing: 10) {
                Label("이 장비와 함께", systemImage: "bookmark").font(.headline)
                if let memory = model.save.profile.equipmentJournal?.memories[item.id] {
                    if let date = memory.acquiredAt { Text("첫 획득 · " + date.formatted(date: .abbreviated, time: .omitted)) }
                    else { Text("기존 보유 장비 · 획득일 기록 없음") }
                    Text(String(format: "함께한 활동 %d회 · 야외 %.2fkm", memory.activities, memory.outdoorDistance / 1000))
                    if let boss = memory.firstBossName { Text("함께한 첫 보스 토벌 · " + boss) }
                    Text(memory.trackingSince.formatted(date: .abbreviated, time: .omitted) + "부터 기록한 활동이에요.").font(.caption).foregroundStyle(Theme.muted)
                } else { Text("다음 활동부터 함께한 기록을 남겨요. 과거 착용 이력은 추정하지 않아요.").foregroundStyle(Theme.muted) }
            }.font(.callout).card()
        }
    }
}
