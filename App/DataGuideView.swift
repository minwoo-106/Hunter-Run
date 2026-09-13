import SwiftUI

struct DataGuideView: View {
    var body: some View {
        ScrollView { VStack(alignment: .leading, spacing: 20) {
            GameSection("이 기기에 저장돼요") {
                Text("헌터와 오퍼레이터 이름, 활동 시간·거리·성과, 장비·협회 성장, 이야기 선택과 호감도를 앱 안에 저장해요.")
                Text("앱 서버나 분석 서비스로 진행도를 전송하지 않아요. 음성과 이미지는 앱에 포함되어 오프라인으로 이용할 수 있어요.")
            }
            GameSection("활동 측정에 사용하는 권한") {
                Text("위치는 활동 중 거리와 속도를 측정하는 데 사용해요. 원시 GPS 좌표나 이동 경로는 저장 파일과 진단 파일에 기록하지 않아요.")
                Text("동작 및 피트니스는 걷기·달리기·정지 구분과 보조 거리 측정에 사용해요. 마이크 권한은 사용하지 않아요.")
                Text("활동을 종료하면 위치·동작 측정도 종료해요. 권한은 iPhone 설정에서 변경할 수 있어요.")
            }
            GameSection("백업과 초기화") {
                Text("백업은 이름과 이야기 선택을 포함한 진행도 파일이에요. 공유 대상을 직접 선택하며, 불러오면 현재 진행도를 교체해요.")
                Text("설정의 진행도 초기화는 이 기기의 저장과 자동 복구 사본을 비워요. 직접 내보낸 백업 파일은 파일 앱에서 관리해주세요.")
            }
            GameSection("제작 자료") {
                Text("캐릭터·장비·배경은 게임용으로 제작한 AI 생성 일러스트예요. 오퍼레이터 안내는 미리 제작한 한국어 합성 음성이에요.")
                Text("사용자가 정한 이름은 화면 대사에 반영돼요. 녹음된 활동 안내에서는 이름 대신 상황을 설명해요.")
            }
        }.padding(20) }.labyrinthScreen().navigationTitle("데이터와 권한").navigationBarTitleDisplayMode(.inline)
    }
}
