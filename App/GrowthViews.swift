import SwiftUI

struct ResourceStrip: View {
    @EnvironmentObject var model: AppModel
    var body: some View {
        HStack(spacing: 14) {
            Label("\(model.save.profile.crystals)", systemImage: "diamond.fill")
            Label("\(model.save.profile.research)", systemImage: "doc.text.magnifyingglass")
            Label("\(model.save.profile.growth.cores)", systemImage: "hexagon.fill")
        }.font(.caption.monospacedDigit()).foregroundStyle(Theme.teal)
            .accessibilityLabel("마정석 \(model.save.profile.crystals), 조사 데이터 \(model.save.profile.research), 코어 \(model.save.profile.growth.cores)")
    }
}
struct AssociationView: View {
    @EnvironmentObject var model: AppModel
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Image(AssociationStage.artwork(model.save.profile)).resizable().scaledToFill().frame(height: 160).clipped().clipShape(RoundedRectangle(cornerRadius: 20))
                eyebrow("ASSOCIATION")
                Text(AssociationStage.name(model.save.profile)).font(.headline).foregroundStyle(Theme.teal)
                Text("시설 확장 \(AssociationStage.upgrades(model.save.profile)) / 4 · 2개 확장 시 정식 지부, 4개 확장 시 광역 지부").font(.caption).foregroundStyle(Theme.muted)
                NavigationLink { BossBoardView() } label: { Label("주요 보스 토벌 게시판", systemImage: "shield.checkered").frame(maxWidth: .infinity, alignment: .leading).card() }.accessibilityIdentifier("association.bosses")
                Text("우리의 지부를\n키워갑니다.").font(.largeTitle.bold())
                Text("현장에서 얻은 자원으로 새로운 기능을 열어보세요.").foregroundStyle(Theme.muted)
                ResourceStrip()
                ForEach(Department.allCases, id: \.rawValue) { department in
                    let level = model.save.profile.growth.level(department)
                    let next = model.progressionCatalog?.upgrades.first { $0.department == department && $0.level == level + 1 }
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Image(systemName: department.symbol).font(.title2).foregroundStyle(Theme.teal)
                            Text(department.title).font(.title3.bold())
                            Spacer(); Text("Lv.\(level)").font(.headline.monospacedDigit())
                        }
                        if let next {
                            Text(next.playerHint).foregroundStyle(Theme.muted)
                            Text("마정석 \(next.crystals) · 조사 데이터 \(next.research)").font(.caption)
                            Button("시설 확장") { model.upgrade(department) }
                                .buttonStyle(.borderedProminent)
                                .disabled(model.growthLocked || model.save.profile.crystals < next.crystals || model.save.profile.research < next.research)
                        } else {
                            Text(model.progressionCatalog?.upgrades.first { $0.department == department }?.reveal ?? "확장 완료")
                                .font(.callout).foregroundStyle(Theme.teal)
                        }
                    }.card()
                }
                Text("이번 버전에서는 각 부서를 Lv.2까지 확장할 수 있습니다.").font(.caption).foregroundStyle(Theme.muted)
            }.padding(20)
        }.background(Theme.ink).navigationTitle("협회 관리").navigationBarTitleDisplayMode(.inline)
    }
}
struct EquipmentView: View {
    @EnvironmentObject var model: AppModel
    @State private var slot: EquipmentSlot = .weapon
    @State private var ownedOnly = false
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ResourceStrip()
                HStack {
                    metric("HP", "\(Int(model.stats.hp))"); Spacer()
                    metric("공격", String(format: "×%.2f", model.stats.attack)); Spacer()
                    metric("피해 경감", "\(Int(model.stats.defense * 100))%")
                }.card()
                Picker("장비 슬롯", selection: $slot) {
                    ForEach(EquipmentSlot.allCases, id: \.rawValue) { Text($0.title).tag($0) }
                }.pickerStyle(.segmented)
                Toggle("보유 장비만 보기", isOn: $ownedOnly).font(.callout)
                if ownedOnly && !(model.progressionCatalog?.equipment.contains { $0.slot == slot && model.save.profile.growth.owned.contains($0.id) } ?? false) { Text("이 종류의 보유 장비가 없습니다.").foregroundStyle(Theme.muted) }
                ForEach(model.progressionCatalog?.equipment.filter { $0.slot == slot && (!ownedOnly || model.save.profile.growth.owned.contains($0.id)) } ?? []) { item in
                    let owned = model.save.profile.growth.owned.contains(item.id)
                    let equipped = model.save.profile.growth.equipped[item.slot.rawValue] == item.id
                    let unlocked = model.save.profile.growth.level(.equipment) >= item.supportLevel
                    VStack(alignment: .leading, spacing: 12) {
                        NavigationLink { EquipmentDetailView(item: item) } label: { HStack(spacing: 14) {
                            GearArtwork(item: item)
                            VStack(alignment: .leading, spacing: 5) {
                                Text(item.name).font(.headline)
                                Text(item.detail).font(.caption).foregroundStyle(Theme.muted)
                                Text(item.cores > 0 ? "코어 장비" : item.supportLevel > 1 ? "고급 장비" : "기본 장비").font(.caption2).foregroundStyle(Theme.teal)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right").font(.caption).foregroundStyle(Theme.muted)
                        } }.buttonStyle(.plain).accessibilityIdentifier("gear." + item.id)
                        if owned {
                            Button(equipped ? "장착 해제" : "장착") { model.equip(item.id) }
                                .buttonStyle(.borderedProminent).disabled(model.growthLocked)
                            if equipped { Label("장착 중", systemImage: "checkmark.circle.fill").font(.caption).foregroundStyle(Theme.teal) }
                        } else if unlocked {
                            Text("마정석 \(item.crystals) · 조사 \(item.research) · 코어 \(item.cores)").font(.caption)
                            Button("장비 확보") { model.buy(item.id) }.buttonStyle(.bordered)
                                .disabled(model.growthLocked || model.save.profile.crystals < item.crystals || model.save.profile.research < item.research || model.save.profile.growth.cores < item.cores)
                        } else {
                            Label("장비지원부 Lv.\(item.supportLevel) 필요", systemImage: "lock.fill").font(.caption).foregroundStyle(Theme.muted)
                        }
                    }.card()
                }
                Text("장비 효과는 다음 활동 시작 시 적용됩니다. 신발은 게임 피해량만 보정하며 실제 목표 속도를 바꾸지 않습니다.").font(.caption).foregroundStyle(Theme.muted)
            }.padding(20)
        }.background(Theme.ink).navigationTitle("장비 보관함").navigationBarTitleDisplayMode(.inline)
    }
}
struct RankView: View {
    @EnvironmentObject var model: AppModel
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                eyebrow("HUNTER LICENSE")
                Text("\(model.save.profile.growth.rank)급 헌터").font(.largeTitle.bold())
                Text("등급은 활동 기록과 게이트 성과를 함께 평가합니다.").foregroundStyle(Theme.muted)
                if let next = Progression.nextRank(model.save.profile) {
                    let requirements = Progression.requirements(model.save.profile)
                    Text("다음 평가 · \(next)급").font(.title2.bold())
                    VStack(alignment: .leading, spacing: 14) {
                        requirement("헌터 레벨", model.save.profile.level, requirements.level)
                        requirement("목표 완료 기록", model.save.profile.runs.filter(\.completedGoal).count, requirements.runs)
                        requirement("고위험 게이트 보스 토벌", Progression.gateClears(model.save.profile), requirements.gates)
                    }.card()
                    Button("승급 평가 받기") { model.promote() }.buttonStyle(.borderedProminent)
                        .disabled(model.growthLocked || !Progression.canPromote(model.save.profile))
                } else { Text("최고 등급에 도달했습니다.").foregroundStyle(Theme.teal) }
            }.padding(20)
        }.background(Theme.ink).navigationTitle("협회 평가").navigationBarTitleDisplayMode(.inline)
    }
    private func requirement(_ label: String, _ value: Int, _ target: Int) -> some View {
        HStack { Image(systemName: value >= target ? "checkmark.circle.fill" : "circle").foregroundStyle(value >= target ? Theme.teal : Theme.muted); Text(label); Spacer(); Text("\(value) / \(target)").monospacedDigit() }.font(.callout)
    }
}
