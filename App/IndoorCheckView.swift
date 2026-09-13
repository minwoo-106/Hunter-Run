import SwiftUI

struct IndoorCheckView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    let start: () -> Void
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Image(systemName: model.indoorDetected ? "figure.run.circle.fill" : "waveform.path").font(.system(size: 70)).foregroundStyle(Theme.teal)
                    Text("실내 훈련 게이트").font(.largeTitle.bold())
                    Text("워치 없이, 지금의 발걸음으로").font(.title3)
                    Text(model.indoorCheckMessage).font(.headline).card().accessibilityIdentifier("indoor.detection")
                    Text("아이폰을 손에 들거나 몸에 밀착되는 주머니·운동 벨트에 넣어주세요. 러닝머신 거치대에 두면 움직임을 읽기 어려워요.")
                    Text("활동 시간으로 탐색과 전투가 진행돼요. 제자리 운동은 거리·페이스를 만들지 않으며, 러닝머신의 표시값과 자동 연결되지 않아요.").foregroundStyle(Theme.muted)
                    Button("움직임 다시 확인") { model.beginIndoorCheck() }.buttonStyle(GameButtonStyle())
                    Button("실내 활동 시작") { start(); dismiss() }
                        .buttonStyle(GameButtonStyle(primary: true)).disabled(!model.indoorDetected).accessibilityIdentifier("indoor.start")
                    Text("감지가 불안정하면 잡는 위치를 바꿔보세요. 잠금·다른 앱 이동 시에는 실내 활동을 일시정지해요.").font(.caption).foregroundStyle(Theme.muted)
                    if let notice = model.notice { Text(notice).font(.caption) }
                }.padding(24)
            }.labyrinthScreen().navigationTitle("움직임 확인").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("닫기") { dismiss() }.buttonStyle(GameControlStyle()) } }
        }.onAppear { model.beginIndoorCheck() }
    }
}
