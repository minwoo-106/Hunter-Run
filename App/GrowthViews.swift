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
struct HaesolMomentsView: View {
    private let moments: [(asset: String, title: String, detail: String)] = [
        ("HaesolBefore", "평범한 귀갓길", "강해솔은 도시의 오후를 천천히 걸었어요."),
        ("HaesolHairTie", "출발 전", "머리를 묶고 다시 길을 나설 준비를 해요."),
        ("HaesolCurious", "궁금한 얼굴", "무슨 이야기를 들었는지 한 걸음 가까이 다가왔어요."),
        ("HaesolBeetle", "작은 예외", "수많은 게이트 앞에서도 침착했지만, 작은 벌레 앞에서는 잠깐 움찔했어요.")
    ]
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                eyebrow("HUNTER / OFF DUTY")
                Text("강해솔의 일상").font(.largeTitle.bold())
                Text("도시에서 보낸 평범한 오후예요. 좌우로 넘겨보세요.").foregroundStyle(Theme.muted)
                TabView {
                    ForEach(0..<moments.count, id: \.self) { index in
                        VStack(alignment: .leading, spacing: 12) {
                            Image(moments[index].asset).resizable().scaledToFit()
                                .frame(maxWidth: .infinity, maxHeight: 505)
                                .accessibilityLabel(moments[index].title + ". " + moments[index].detail)
                            Text(moments[index].title).font(.title3.bold()).foregroundStyle(Theme.teal)
                            Text(moments[index].detail).font(.callout).foregroundStyle(Theme.muted)
                            Spacer(minLength: 0)
                        }.padding(.horizontal, 2)
                    }
                }.tabViewStyle(.page(indexDisplayMode: .always)).frame(height: 615)
            }.padding(20)
        }.labyrinthScreen().navigationTitle("일상 기록").navigationBarTitleDisplayMode(.inline)
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
                statsCard
                EquipmentGoalCard()
                EquipmentPresetsView()
                slotPicker
                Toggle("보유 장비만 보기", isOn: $ownedOnly).font(.callout)
                equipmentList
                Text("장비 효과는 다음 활동 시작 시 적용됩니다. 신발은 게임 피해량만 보정하며 실제 목표 속도를 바꾸지 않습니다.").font(.caption).foregroundStyle(Theme.muted)
            }.padding(20)
        }.labyrinthScreen().navigationTitle("장비 보관함").navigationBarTitleDisplayMode(.inline)
    }

    private var statsCard: some View {
        HStack {
            metric("HP", "\(Int(model.stats.hp))"); Spacer()
            metric("공격", String(format: "×%.2f", model.stats.attack)); Spacer()
            metric("피해 경감", "\(Int(model.stats.defense * 100))%")
        }.card()
    }

    private var slotPicker: some View {
        Picker("장비 슬롯", selection: $slot) {
            ForEach(EquipmentSlot.allCases, id: \.rawValue) { Text($0.title).tag($0) }
        }.pickerStyle(.segmented)
    }

    private var equipmentList: some View {
        Group {
            if ownedOnly && equipment.isEmpty {
                Text("이 종류의 보유 장비가 없습니다.").foregroundStyle(Theme.muted)
            }
            ForEach(equipment) { item in
                EquipmentListRow(item: item)
            }
        }
    }

    private var equipment: [EquipmentDefinition] {
        model.progressionCatalog?.equipment.filter { item in
            item.slot == slot && (!ownedOnly || model.save.profile.growth.owned.contains(item.id))
        } ?? []
    }
}

private struct EquipmentListRow: View {
    @EnvironmentObject var model: AppModel
    let item: EquipmentDefinition

    private var owned: Bool { model.save.profile.growth.owned.contains(item.id) }
    private var equipped: Bool { model.save.profile.growth.equipped[item.slot.rawValue] == item.id }
    private var unlocked: Bool { item.available(to: model.save.profile) }

    private var lockHint: String {
        let rank = item.requiredRank.map { " · " + $0 + "급" } ?? ""
        let discovery = item.discoveryHint.map { " · " + $0 } ?? " 필요"
        return "장비지원부 Lv.\(item.supportLevel)" + rank + discovery
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            detailLink
            if owned {
                Button(equipped ? "장착 해제" : "장착") { model.equip(item.id) }
                    .buttonStyle(GameButtonStyle(primary: true)).disabled(model.growthLocked)
                if equipped { Label("장착 중", systemImage: "checkmark.circle.fill").font(.caption).foregroundStyle(Theme.teal) }
            } else if unlocked {
                Text("마정석 \(item.crystals) · 조사 \(item.research) · 코어 \(item.cores)").font(.caption)
                Button("장비 확보") { model.buy(item.id) }.buttonStyle(GameButtonStyle())
                    .disabled(model.growthLocked || model.save.profile.crystals < item.crystals || model.save.profile.research < item.research || model.save.profile.growth.cores < item.cores)
            } else {
                Label(lockHint, systemImage: "lock.fill").font(.caption).foregroundStyle(Theme.muted)
            }
        }.card()
    }

    private var detailLink: some View {
        NavigationLink { EquipmentDetailView(item: item) } label: {
            HStack(spacing: 14) {
                GearArtwork(item: item)
                VStack(alignment: .leading, spacing: 5) {
                    Text(item.name).font(.headline)
                    Text(item.detail).font(.caption).foregroundStyle(Theme.muted)
                    Text("단계 \(item.tier ?? 1) · \(item.stageName)").font(.caption2).foregroundStyle(Theme.teal)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(Theme.muted)
            }
        }.buttonStyle(.plain).accessibilityIdentifier("gear." + item.id)
    }
}

struct RankView: View {
    @EnvironmentObject var model: AppModel
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                eyebrow("HUNTER LICENSE")
                Text("\(model.save.profile.growth.rank)급 헌터").font(.largeTitle.bold())
                if model.save.profile.growth.rank != "E" {
                    Image("Rank-" + model.save.profile.growth.rank).resizable().scaledToFit().frame(height: 180).frame(maxWidth: .infinity)
                }
                Text("등급은 활동 기록과 게이트 성과를 함께 평가합니다.").foregroundStyle(Theme.muted)
                if let next = Progression.nextRank(model.save.profile) {
                    let requirements = Progression.requirements(model.save.profile)
                    let readiness = Progression.promotionReadiness(model.save.profile)
                    let examDone = model.save.profile.journey?.completedQuests.contains("exam-" + next) == true
                    Text("다음 평가 · \(next)급").font(.title2.bold())
                    VStack(alignment: .leading, spacing: 14) {
                        requirement("헌터 레벨", model.save.profile.level, requirements.level)
                        requirement("누적 활동 시간(분)", Progression.activityMinutes(model.save.profile), requirements.runs * 20)
                        requirement("누적 게이트 실적", Progression.gateClears(model.save.profile), requirements.gates)
                        HStack {
                            Image(systemName: examDone ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(examDone ? Theme.teal : Theme.muted)
                            Text("전용 승급 심사 토벌")
                            Spacer()
                            Text(examDone ? "완료" : "미완료")
                        }.font(.callout).accessibilityIdentifier("rank.exam.requirement")
                    }.card()
                    Text(promotionMessage(readiness, rank: next)).font(.callout).foregroundStyle(Theme.teal)
                        .accessibilityIdentifier("rank.readiness")
                    if model.growthLocked {
                        Text("진행 중이거나 저장해둔 활동이 있어요. 해당 활동을 마치거나 종료한 뒤 승급할 수 있어요.")
                            .font(.caption).foregroundStyle(Theme.muted).accessibilityIdentifier("rank.activity-lock")
                    }
                    Button(examDone ? "승급 평가 받기" : "심사 토벌 후 승급 가능") { model.promote() }.buttonStyle(GameButtonStyle(primary: true))
                        .disabled(model.growthLocked || !Progression.canPromote(model.save.profile))
                        .accessibilityIdentifier("rank.promote")
                    if !examDone {
                        NavigationLink { QuestBoardView() } label: { Label(readiness == .exam ? "\(next)급 승급 심사 확인" : "진행 중인 의뢰 확인", systemImage: "shield.checkered") }
                            .buttonStyle(GameButtonStyle(primary: readiness == .exam)).accessibilityIdentifier("rank.exam.open")
                        Text("심사 감시체의 남은 HP는 다음 활동으로 이어져요. 한 번에 끝내지 않아도 괜찮아요.").font(.caption).foregroundStyle(Theme.muted)
                    }
                    if let notice = model.notice { Text(notice).font(.caption).foregroundStyle(Theme.muted) }
                } else { Text("최고 등급에 도달했습니다.").foregroundStyle(Theme.teal) }
            }.padding(20)
        }.labyrinthScreen().navigationTitle("협회 평가").navigationBarTitleDisplayMode(.inline)
    }
    private func promotionMessage(_ readiness: PromotionReadiness, rank: String) -> String {
        switch readiness {
        case .requirements: return "먼저 레벨·활동 시간·게이트 자격을 채워주세요. 심사 토벌도 별도로 필요해요."
        case .story: return "기본 자격은 모두 충족했어요. 지부 이야기와 현재 의뢰를 진행하면 \(rank)급 승급 심사가 열려요."
        case .exam: return "기본 자격은 모두 충족했어요. 이제 \(rank)급 승급 심사에 출동해 전용 감시체를 토벌해주세요."
        case .ready: return "자격과 전용 심사 토벌을 모두 마쳤어요. 승급 평가를 받을 수 있어요."
        case .maximumRank: return "최고 등급에 도달했어요."
        }
    }
    private func requirement(_ label: String, _ value: Int, _ target: Int) -> some View {
        HStack { Image(systemName: value >= target ? "checkmark.circle.fill" : "circle").foregroundStyle(value >= target ? Theme.teal : Theme.muted); Text(label); Spacer(); Text("\(value) / \(target)").monospacedDigit() }.font(.callout)
    }
}
