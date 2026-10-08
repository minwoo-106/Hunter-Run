import SwiftUI

struct EncounterGuideView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                eyebrow("FIELD BRIEFING")
                Text("목소리를 따라, 나의 페이스로").font(.title.bold())
                Text("사건은 오퍼레이터 안내가 끝난 뒤 판정합니다. 신호 대기나 일시정지 중에는 사건 진행도 기다립니다.").foregroundStyle(Theme.muted)
                entry("발견 · 조사", "sparkle.magnifyingglass", "걷기만 해도 진행됩니다. 마력 흔적과 관측 자료를 확보합니다.")
                entry("전투 · 75m마다 공격", "figure.run", "조우 안내가 끝난 뒤 GPS가 양호하고 달리기로 인정된 거리 75m마다 공격해요. 한 번의 공격으로 주는 피해는 레벨과 착용 장비에 따라 달라져요. 더 빠르게 달릴 필요는 없어요.")
                entry("전투 게이지 읽기", "heart.text.square", "큰 게이지는 몬스터의 HP예요. 그 아래에는 공격 횟수와 다음 공격까지 누적된 거리 0~75m가 표시돼요. 화면 위 전체 이동거리와 전투 누적 거리는 별개예요.")
                entry("정지 · 걷기 · GPS 대기", "pause.circle", "걷거나 쉬는 동안, GPS가 불안정할 때는 공격을 기다려요. 이미 확보한 피해와 공격 거리는 활동 중 유지돼요. 수동 일시정지 구간은 활동 시간과 공격 거리에 더하지 않아요.")
                entry("일반 몬스터와 주요 보스", "diamond", "일반 몬스터는 한 활동에서 끝까지 토벌해야 해요. 다음 활동에서는 새 개체로 시작해요. 주요 보스와 승급 심사는 실제로 준 피해를 저장해 다음 활동으로 이어가요.")
                entry("활동 레벨 · 장비 · 헌터 등급", "shield", "활동 레벨은 운동과 탐색으로도 올라요. 장비는 전투 피해를 크게 높이고, 헌터 등급과 이야기·시설은 새로운 콘텐츠를 열어요. 레벨이 높다고 등급이 자동으로 오르지는 않아요.")
                Text("탐험은 조사 중심이고 현장 사냥과 고위험 게이트에는 전투가 섞여요. 몬스터 경험치는 실제 토벌했을 때 한 번 지급해요. 업데이트 전에 시작한 활동은 저장된 기존 규칙으로 마쳐요.").font(.caption).foregroundStyle(Theme.muted)
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
