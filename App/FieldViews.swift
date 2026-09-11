import SwiftUI

struct HunterTabBar: View {
    @EnvironmentObject var model: AppModel
    private let labels = ["홈", "헌터", "협회 관리", "도감", "메뉴"]
    private let icons = ["house", "person.crop.circle", "building.2", "book", "ellipsis"]
    var body: some View {
        HStack(alignment: .center, spacing: 2) {
            ForEach(0..<5) { index in
                Button { if index == 2 { model.showAssociation = true } else { model.selectedTab = index } } label: {
                    VStack(spacing: 4) {
                        Image(systemName: icons[index]).font(.system(size: index == 2 ? 27 : 21, weight: .semibold))
                        Text(labels[index]).font(.system(size: 11, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity).frame(height: index == 2 ? 64 : 54)
                    .foregroundStyle(index == 2 ? Theme.ink : model.selectedTab == index ? Theme.teal : Theme.muted)
                    .background {
                        if index == 2 { RoundedRectangle(cornerRadius: 21).fill(Theme.teal.gradient).shadow(color: Theme.teal.opacity(0.2), radius: 8, y: 3) }
                        else if model.selectedTab == index { RoundedRectangle(cornerRadius: 18).fill(.white.opacity(0.07)) }
                    }
                    .offset(y: index == 2 ? -4 : 0)
                }.buttonStyle(.plain).accessibilityLabel(labels[index]).accessibilityIdentifier("nav.\(index)")
                    .accessibilityAddTraits((index == 2 ? model.showAssociation : model.selectedTab == index) ? .isSelected : [])
            }
        }.padding(.horizontal, 12).padding(.top, 10).padding(.bottom, 4)
            .background(Theme.ink.opacity(0.98))
            .overlay(alignment: .top) { Rectangle().fill(.white.opacity(0.08)).frame(height: 1) }
    }
}

struct GearArtwork: View {
    let item: EquipmentDefinition
    var size: CGFloat = 96
    var body: some View {
        Image("Gear-" + item.id).resizable().scaledToFit()
            .frame(width: size, height: size)
            .background(Theme.ink, in: RoundedRectangle(cornerRadius: 16))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(item.cores > 0 ? Color.orange.opacity(0.5) : Theme.teal.opacity(0.2)))
            .accessibilityLabel(item.name + " 장비 이미지")
    }
}

struct LoadoutStrip: View {
    @EnvironmentObject var model: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("현재 착용 장비").font(.headline)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(EquipmentSlot.allCases, id: \.rawValue) { slot in
                    let id = model.save.profile.growth.equipped[slot.rawValue]
                    let item = model.progressionCatalog?.equipment.first { $0.id == id }
                    VStack(spacing: 8) {
                        if let item { GearArtwork(item: item, size: 80) }
                        else { Image(systemName: slot.symbol).font(.title).foregroundStyle(Theme.muted).frame(height: 80) }
                        Text(item?.name ?? slot.title + " 미착용").font(.caption).lineLimit(2)
                    }.frame(maxWidth: .infinity).padding(8).background(.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 16))
                }
            }
        }
    }
}

struct EquipmentDetailView: View {
    @EnvironmentObject var model: AppModel
    let item: EquipmentDefinition
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                GearArtwork(item: item, size: 240).frame(maxWidth: .infinity)
                eyebrow(item.cores > 0 ? "CORE EQUIPMENT" : item.supportLevel > 1 ? "ADVANCED EQUIPMENT" : "FIELD EQUIPMENT")
                Text(item.name).font(.largeTitle.bold())
                Text(item.slot.title).foregroundStyle(Theme.teal)
                Text(item.detail).font(.headline)
                Text("장착한 장비의 효과는 다음 활동에 적용됩니다. 활동 중에는 장비를 바꿀 수 없습니다.").foregroundStyle(Theme.muted)
                Text("필요 자원 · 마정석 \(item.crystals) / 조사 \(item.research) / 코어 \(item.cores)").font(.callout)
                Text("장비지원부 Lv.\(item.supportLevel)").font(.caption).foregroundStyle(Theme.muted)
                ResourceStrip()
                if model.save.profile.growth.owned.contains(item.id) {
                    Button(model.save.profile.growth.equipped[item.slot.rawValue] == item.id ? "장착 해제" : "장착") { model.equip(item.id) }
                        .buttonStyle(.borderedProminent).disabled(model.growthLocked)
                } else {
                    Button("장비 확보") { model.buy(item.id) }.buttonStyle(.borderedProminent)
                        .disabled(model.growthLocked || model.save.profile.growth.level(.equipment) < item.supportLevel || model.save.profile.crystals < item.crystals || model.save.profile.research < item.research || model.save.profile.growth.cores < item.cores)
                }
            }.padding(22)
        }.background(Theme.ink).navigationTitle("장비 상세").navigationBarTitleDisplayMode(.inline)
    }
}

struct HistoryView: View {
    @EnvironmentObject var model: AppModel
    @State private var filter: RunMode?
    private var runs: [RunSummary] { model.save.profile.runs.filter { filter == nil || ($0.mode ?? .contract) == filter } }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                eyebrow("ACTIVITY JOURNAL")
                HStack {
                    metric("총 거리", String(format: "%.1f km", runs.reduce(0) { $0 + $1.distance } / 1000)); Spacer()
                    metric("활동 횟수", "\(runs.count)회")
                }.card()
                Picker("활동 모드", selection: $filter) {
                    Text("전체").tag(nil as RunMode?)
                    ForEach(RunMode.allCases, id: \.rawValue) { Text($0.title).tag(Optional($0)) }
                }.pickerStyle(.menu)
                if runs.isEmpty { ContentUnavailableView("아직 활동 기록이 없습니다", systemImage: "figure.walk", description: Text("실제 활동을 마치면 거리와 사건, 보상이 여기에 남습니다.")) }
                ForEach(runs) { run in
                    NavigationLink { RunDetailView(run: run) } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack { Text(run.date, style: .date); Spacer(); Image(systemName: "chevron.right") }
                            Text(run.mode?.title ?? "헌터 의뢰").font(.caption).foregroundStyle(Theme.teal)
                            Text(String(format: "%.2f km", run.distance / 1000) + " · " + clock(run.seconds)).font(.title3.bold())
                            Text(run.completedGoal ? "목표 완료" : "성과 저장").font(.caption).foregroundStyle(Theme.muted)
                        }.card()
                    }.buttonStyle(.plain)
                }
            }.padding(20)
        }.background(Theme.ink).navigationTitle("활동 기록").navigationBarTitleDisplayMode(.inline)
    }
}

struct RunDetailView: View {
    let run: RunSummary
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                eyebrow("MISSION REPORT")
                Text(run.mode?.title ?? "헌터 의뢰").font(.largeTitle.bold())
                Text(run.date, format: .dateTime.year().month().day().hour().minute()).foregroundStyle(Theme.muted)
                HStack { metric("거리", String(format: "%.2f km", run.distance / 1000)); Spacer(); metric("활동시간", clock(run.seconds)) }.card()
                HStack { metric("목표", run.goal?.label ?? "시간 목표"); Spacer(); metric("결과", run.completedGoal ? "완료" : "성과 저장") }
                if let seconds = run.runningSeconds { Text("달리기 \(clock(seconds)) · 걷기 \(clock(max(0, run.seconds - seconds)))").foregroundStyle(Theme.muted) }
                Text("EXP +\(run.xp) · 마정석 +\(run.crystals)").font(.headline).foregroundStyle(Theme.teal)
                if let research = run.research { Text("조사 데이터 +\(research) · 코어 +\(run.cores ?? 0)").foregroundStyle(Theme.teal) }
                if let boss = run.majorBoss { BossReportView(report: boss) }
                Text("현장 사건").font(.title2.bold())
                if run.records.isEmpty { Text("기록된 사건이 없습니다. 이동 기록과 확보한 보상은 저장됐습니다.").foregroundStyle(Theme.muted) }
                ForEach(run.records) { record in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack { Text(record.title).font(.headline); Spacer(); Text(outcomeName(record.outcome)).font(.caption).foregroundStyle(Theme.teal) }
                        if record.damage > 0 { Text("게임 피해 \(Int(record.damage))" + (record.defeated == true ? " · 토벌 완료" : "")).font(.caption).foregroundStyle(Theme.muted) }
                    }.card()
                }
            }.padding(22)
        }.background(Theme.ink).navigationTitle("활동 상세").navigationBarTitleDisplayMode(.inline)
    }
}

struct FieldGuideView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                eyebrow("FIELD MANUAL")
                guide("01 · 나에게 맞는 활동", "탐험은 걷기 중심의 조사, 계약은 페이스 유지와 선택적 추격, 게이트는 해금 후 입장하는 고위험 의뢰입니다.")
                guide("02 · 목표와 종료", "시간·거리 목표는 달성하면 자동 종료합니다. 자유 활동은 직접 종료합니다. 일찍 마쳐도 확보한 성과를 저장하며, 모의 러닝은 실제 보상을 지급하지 않습니다.")
                guide("03 · 멈춰도 괜찮습니다", "신호 대기처럼 잠깐 멈춘 동안에는 판정도 멈춥니다. 직접 일시정지했다면 ‘계속’을 눌러 재개하세요. 화면을 보지 않아도 음성으로 사건을 안내합니다.")
                guide("04 · 보상에서 성장으로", "헌터의 장비 보관함에서 장비를 확보하고 장착하세요. 하단 중앙 협회 관리에서 부서를 확장하면 새로운 기능이 열립니다. 등급은 헌터의 협회 평가에서 심사합니다.")
                guide("05 · 게이트 입장", "D급 심사에는 Lv.2와 목표 완료 2회가 필요합니다. 관측부 Lv.2까지 갖추면 게이트가 열립니다. 자유 활동도 경험치와 자원을 주지만 목표 완료 횟수에는 포함되지 않습니다.")
                guide("06 · 기록과 복구", "앱이 중단되면 홈에서 활동을 복구할 수 있습니다. 메뉴에서 저장 파일을 백업하고, 헌터에서 지난 활동의 사건과 보상을 확인하세요.")
            }.padding(22)
        }.background(Theme.ink).navigationTitle("활동과 성장 가이드").navigationBarTitleDisplayMode(.inline)
    }
    private func guide(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 10) { Text(title).font(.headline); Text(body).foregroundStyle(Theme.muted) }.card()
    }
}
