import SwiftUI

struct EncounterBoardView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                eyebrow("FIELD INTELLIGENCE")
                Text("월영과 몽환의 흔적").font(.largeTitle.bold())
                Text("협회가 공유한 개체 정보예요. 실제 출현 조건을 확인하거나 모의 활동으로 먼저 만나보세요.").foregroundStyle(Theme.muted)
                ForEach(model.fieldEncounters?.encounters ?? []) { entry in
                    VStack(alignment: .leading, spacing: 14) {
                        Image("Monster-" + entry.monsterID).resizable().scaledToFit().frame(maxWidth: .infinity).frame(height: 260).clipShape(RoundedRectangle(cornerRadius: 18)).accessibilityLabel(entry.name + " 협회 자료")
                        Label(entry.elite ? "엘리트 개체" : "일반 개체", systemImage: entry.elite ? "diamond.fill" : "sparkles").font(.caption).foregroundStyle(entry.elite ? Color.orange : Theme.teal)
                        Text(entry.name).font(.title2.bold())
                        let available = model.progressionCatalog.map { entry.available(to: model.save.profile, catalog: $0) } ?? false
                        Label(available ? "현장 출현 가능" : entry.unlockHint, systemImage: available ? "checkmark.circle" : "lock.fill").font(.callout)
                        if !entry.elite || model.unlocked("tactical-analysis") {
                            Text(entry.tactic).foregroundStyle(Theme.muted)
                        } else { Text("상세 공략은 연구부 Lv.3에서 분석해요. 모의 활동은 먼저 체험할 수 있어요.").font(.callout).foregroundStyle(Theme.muted) }
                        if FieldDiscovery.events(in: model.save.profile).contains(entry.event.id) { Label("실제 발견 기록 등록됨", systemImage: "book.closed.fill").foregroundStyle(Theme.teal) }
                        Button("이 개체 모의 활동 준비") { model.prepareFieldDemo(entry); dismiss() }.buttonStyle(.borderedProminent).disabled(model.growthLocked).accessibilityIdentifier("encounter.demo." + entry.id)
                        let gear = model.progressionCatalog?.equipment.filter { $0.requiredEvent == entry.event.id } ?? []
                        ForEach(gear) { item in
                            NavigationLink { EquipmentDetailView(item: item) } label: {
                                HStack { GearArtwork(item: item, size: 58); VStack(alignment: .leading) { Text(item.name); Text("발견 기록 연계 장비 · 지원부 Lv.\(item.supportLevel)").font(.caption).foregroundStyle(Theme.muted) }; Spacer(); Image(systemName: "chevron.right") }
                            }.buttonStyle(.plain)
                        }
                    }.card()
                }
                Text("모의 체험과 협회 자료 열람은 실제 도감·자원·장비 조건을 해금하지 않아요.").font(.caption).foregroundStyle(Theme.muted)
            }.padding(20)
        }.background(Theme.ink).navigationTitle("신규 개체 정보").navigationBarTitleDisplayMode(.inline)
    }
}
