import SwiftUI

struct EquipmentArchiveView: View {
    @EnvironmentObject var model: AppModel
    var body: some View {
        ForEach(EquipmentSlot.allCases, id: \.rawValue) { slot in
            Text(slot.title).font(.title2.bold()).frame(maxWidth: .infinity, alignment: .leading)
            ForEach(model.progressionCatalog?.equipment.filter { $0.slot == slot } ?? []) { item in
                let owned = model.save.profile.growth.owned.contains(item.id)
                let known = owned || item.available(to: model.save.profile)
                NavigationLink { EquipmentDetailView(item: item) } label: {
                    HStack(spacing: 14) {
                        if known { GearArtwork(item: item, size: 72) }
                        else { Image(systemName: "lock.shield").font(.title).frame(width: 72, height: 72) }
                        VStack(alignment: .leading, spacing: 6) {
                            Text(known ? item.name : "미해금 " + slot.title).font(.headline)
                            Text(owned ? "보유 중" : "장비지원부 Lv." + String(item.supportLevel) + (item.requiredRank.map { " · " + $0 + "급" } ?? "")).font(.caption).foregroundStyle(Theme.muted)
                            if let hint = item.discoveryHint, !owned { Text(hint).font(.caption).foregroundStyle(Theme.muted) }
                        }
                        Spacer(minLength: 0)
                    }.card()
                }.buttonStyle(.plain).disabled(!known)
            }
        }
    }
}
struct ActivityArchiveView: View {
    @EnvironmentObject var model: AppModel
    var body: some View {
        ForEach(RunMode.allCases, id: \.rawValue) { mode in
            VStack(alignment: .leading, spacing: 12) {
                Label(mode.title, systemImage: mode == .exploration ? "binoculars" : mode == .contract ? "list.clipboard" : "sparkles").font(.title2.bold())
                Text(mode.detail).foregroundStyle(Theme.muted)
                Text(model.modeAllowed(mode) ? "활동 준비에서 선택할 수 있어요." : "D급 승급과 관측부 확장으로 열려요.").font(.caption).foregroundStyle(Theme.teal)
                Text(mode == .exploration ? "걸어서도 표본을 모을 수 있어요. 개체 토벌로 기록되지는 않아요." : mode == .contract ? "탐색·유지 대응·짧은 기습·거리 공방을 만나요. 허용한 경우에만 가속 제안이 나와요." : "일반 게이트의 핵을 공략하거나, 해금된 주요 보스의 HP를 여러 활동에 걸쳐 줄여요.")
                    .font(.callout)
            }.card()
        }
        Text("활동 시작과 토벌 대상 선택은 하단 헌터 활동에서, 의뢰 보상은 협회 관리에서 확인해요.").font(.caption).foregroundStyle(Theme.muted)
    }
}
struct MaterialArchiveView: View {
    @EnvironmentObject var model: AppModel
    var body: some View {
        material("마정석", "hexagon.fill", model.save.profile.crystals, "이동 시간과 사건 대응으로 모아요.", "장비 구매와 협회 시설 확장에 사용해요.")
        material("조사 데이터", "waveform.path", model.save.profile.research, "사건 대응과 탐험의 표본 조사로 모아요.", "연구·관측 시설과 분석 장비를 준비할 때 사용해요.")
        material("게이트 코어", "diamond.fill", model.save.profile.growth.cores, "게이트 핵 또는 주요 토벌을 완수하면 모아요.", "상위 장비를 구매할 때 사용해요.")
        Text("이 재료들은 실제 활동의 성과로 획득해요. 현금으로 구매하는 항목은 없어요.").font(.caption).foregroundStyle(Theme.muted)
    }
    private func material(_ name: String, _ symbol: String, _ count: Int, _ source: String, _ use: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack { Label(name, systemImage: symbol).font(.title2.bold()); Spacer(); Text(String(count)).monospacedDigit().foregroundStyle(Theme.teal) }
            Text(source); Text(use).font(.callout).foregroundStyle(Theme.muted)
        }.card()
    }
}
