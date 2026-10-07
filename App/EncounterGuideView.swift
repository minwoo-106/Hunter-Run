import SwiftUI

struct EncounterGuideView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                eyebrow("FIELD BRIEFING")
                Text("목소리를 따라, 나의 페이스로").font(.title.bold())
                Text("사건은 오퍼레이터 안내가 끝난 뒤 판정합니다. 신호 대기나 일시정지 중에는 사건 진행도 기다립니다.").foregroundStyle(Theme.muted)
                entry("발견 · 조사", "sparkle.magnifyingglass", "걷기만 해도 진행됩니다. 마력 흔적과 관측 자료를 확보합니다.")
                entry("유지 · 개체 견제", "shield", "자연스러운 달리기 페이스를 유지하며 개체를 압박합니다.")
                entry("추격 · 선택적 대응", "figure.run", "안전한 구간에서만 조금 가속하면 시작됩니다. 추격을 허용하지 않거나 가속하지 않으면 조사로 바뀝니다.")
                entry("장기전 · 달리기 인정 거리 400m", "point.topleft.down.to.point.bottomright.curvepath", "조우 안내가 끝난 뒤 GPS가 양호하고 달리기로 판정된 거리만 전투에 누적됩니다. 전체 이동거리와 별개이며, 걷거나 쉬는 동안에는 확보한 진행도가 유지됩니다. 가속할 필요는 없습니다. 20분 이상 시간 목표, 3km 이상 거리 목표와 자유 활동에서 만날 수 있습니다. 짧은 활동은 30초 견제로 바뀝니다.")
                entry("기습 대응 · 25초 유지", "bolt.shield", "속도를 높일 필요 없이 달리기 상태를 유지합니다. 멈췄다고 즉시 실패하지 않습니다.")
                entry("보스 · 신호원 안정화", "diamond", "장비와 성장에 따라 게임 피해가 달라집니다. 장비가 좋아져도 더 빠른 달리기를 요구하지 않습니다.")
                Text("탐험은 조사 중심, 의뢰와 게이트는 전투가 섞입니다. 전투 시작 시 걷고 있거나 GPS가 불안정하면 조사로 전환하며, 전투 도중 신호가 불안정해지면 피해 없이 중립 종료합니다. 활동을 마칠 때 진행 중이던 사건도 중립 종료됩니다.").font(.caption).foregroundStyle(Theme.muted)
            }.padding(22)
        }.labyrinthScreen().navigationTitle("현장 사건 안내").navigationBarTitleDisplayMode(.inline)
    }
    private func entry(_ title: String, _ icon: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: icon).font(.headline).foregroundStyle(Theme.teal)
            Text(detail).foregroundStyle(Theme.muted)
        }.card()
    }
}
