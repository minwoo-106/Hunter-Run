import SwiftUI

struct LegacyStoryArchiveView: View {
    @EnvironmentObject var model: AppModel
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                eyebrow("ASSOCIATION DISPATCHES")
                Text("우리 지부의 기록").font(.largeTitle.bold())
                Text("현장에서 돌아온 뒤, 오퍼레이터가 남긴 이야기를 확인하세요.").foregroundStyle(Theme.muted)
                if let next = StoryProgress.nextRequirement(model.save.profile) {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("다음 기록을 여는 방법", systemImage: "flag.checkered").font(.headline)
                        Text(next).foregroundStyle(Theme.teal)
                        Text("이전 기록의 조건부터 차례로 달성합니다.").font(.caption).foregroundStyle(Theme.muted)
                    }.card()
                }
                ForEach(StoryProgress.entries) { entry in
                    let available = StoryProgress.available(entry, profile: model.save.profile)
                    NavigationLink { StoryDetailView(entry: entry) } label: {
                        HStack(alignment: .top, spacing: 14) {
                            Image(systemName: available ? "envelope.open" : "lock.fill").font(.title2).foregroundStyle(Theme.teal)
                            VStack(alignment: .leading, spacing: 7) {
                                Text(entry.title).font(.headline)
                                Text(available ? entry.subtitle : entry.requirement).font(.caption).foregroundStyle(Theme.muted)
                                if available { Text((model.save.profile.readStories ?? []).contains(entry.id) ? "읽은 기록 · 다시 보기" : "새 통신 도착").font(.caption).foregroundStyle(Theme.teal) }
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right").foregroundStyle(Theme.muted)
                        }.card()
                    }.buttonStyle(.plain).accessibilityIdentifier("story." + entry.id)
                }
            }.padding(20)
        }.labyrinthScreen().navigationTitle("협회 통신 기록").navigationBarTitleDisplayMode(.inline)
    }
}
struct StoryDetailView: View {
    @EnvironmentObject var model: AppModel
    let entry: StoryEntry
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                if StoryProgress.available(entry, profile: model.save.profile) {
                    GeometryReader { geo in Image(entry.artwork).resizable().scaledToFill().frame(width: geo.size.width, height: 190).clipped() }.frame(height: 190).clipShape(RoundedRectangle(cornerRadius: 20)).accessibilityHidden(true)
                    eyebrow("OPERATOR / DISPATCH")
                    Text(entry.title).font(.title.bold())
                    Text(entry.subtitle).foregroundStyle(Theme.teal)
                    ForEach(Array(entry.paragraphs.enumerated()), id: \.offset) { _, paragraph in
                        Text(paragraph).font(.body).lineSpacing(7).fixedSize(horizontal: false, vertical: true)
                    }
                    Button { model.playDispatch(entry) } label: { Label("오퍼레이터 통신 듣기", systemImage: "play.circle.fill") }
                        .buttonStyle(GameButtonStyle()).disabled(model.growthLocked).accessibilityIdentifier("story.listen")
                    Text("이 기록의 핵심 내용을 오퍼레이터 목소리로 들어요.").font(.caption).foregroundStyle(Theme.muted)
                    Button((model.save.profile.readStories ?? []).contains(entry.id) ? "확인한 기록입니다" : "기록 확인 완료") { model.readStory(entry.id) }
                        .buttonStyle(GameButtonStyle(primary: true))
                        .disabled(model.growthLocked || (model.save.profile.readStories ?? []).contains(entry.id))
                        .accessibilityIdentifier("story.read")
                } else {
                    Image(systemName: "lock.doc").font(.system(size: 48)).foregroundStyle(Theme.teal)
                    Text("아직 도착하지 않은 기록").font(.title2.bold()).accessibilityIdentifier("story.locked")
                    Text(entry.requirement).foregroundStyle(Theme.muted)
                    Text("이전 기록의 조건을 차례로 달성하면 열립니다. 이미 확보한 실제 활동과 시설 성장도 반영됩니다.").font(.callout)
                }
            }.padding(22)
        }.labyrinthScreen().navigationTitle("통신 내용").navigationBarTitleDisplayMode(.inline)
        .onDisappear { model.stopAudioPreview() }
    }
}

struct WelcomeView: View {
    @EnvironmentObject var model: AppModel
    @State private var page = 0
    private let titles = ["당신의 발걸음이, 지부의 다음 기록이 됩니다.", "이동은 당신의 페이스로", "돌아온 뒤에는 협회에서", "준비되면 함께 출발해요"]
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    if page == 0 {
                        GeometryReader { geo in
                            ZStack {
                                Image("AssociationOffice").resizable().scaledToFill().frame(width: geo.size.width, height: 230).clipped()
                                Image("OperatorCutout").resizable().scaledToFit().frame(width: geo.size.width, height: 230)
                            }
                        }.frame(height: 230).clipped().clipShape(RoundedRectangle(cornerRadius: 22)).accessibilityHidden(true)
                    } else {
                        Image(systemName: ["antenna.radiowaves.left.and.right", "figure.walk", "building.2", "headphones"][page]).font(.system(size: 56)).foregroundStyle(Theme.teal).padding(.top, 24)
                    }
                    eyebrow("WELCOME / 0\(page + 1)")
                    Text(titles[page]).font(.largeTitle.bold()).accessibilityIdentifier("welcome.title")
                    switch page {
                    case 0:
                        Text("당신은 현장 헌터입니다. 오퍼레이터는 협회 관제실에서 당신의 활동을 안내합니다. 평소의 산책과 달리기에서 얻은 기록으로 작은 지부를 키워갑니다.").lineSpacing(6)
                    case 1:
                        welcomeItem("걷기도 활동입니다", "달리지 않는다고 억지로 가속할 필요는 없습니다. 전투는 흔적 조사로 전환될 수 있습니다.")
                        welcomeItem("멈춰야 하면 멈추세요", "신호가 약하거나 정지하면 정밀 판정이 쉬어갑니다. 추격은 선택 사항입니다.")
                        welcomeItem("화면 대신 안내를 들어요", "활동 중 조작은 안전한 곳에서 하세요. 안내를 듣고 평소 페이스로 움직이면 됩니다.")
                    case 2:
                        welcomeItem("헌터 활동 준비", "탐험·의뢰·게이트와 시간·거리·자유 목표를 선택합니다.")
                        welcomeItem("협회와 장비 성장", "실제 활동의 자원으로 부서를 확장하고 장비를 확보합니다. 하단 중앙은 헌터 활동, 그 오른쪽은 협회 관리입니다.")
                        welcomeItem("통신 기록과 도감", "발견한 개체와 지부의 이야기가 쌓입니다. 다음 해금 조건은 협회 통신 기록에서 확인하세요.")
                    default:
                        welcomeItem("위치와 동작", "위치는 거리·페이스 측정, 동작은 걷기·달리기 구분에 사용합니다. 동작 권한은 활동을 시작할 때 요청합니다.")
                        Button("위치 권한 확인") { model.authorize() }.buttonStyle(GameButtonStyle())
                        Text(model.permissionText).font(.caption).foregroundStyle(Theme.muted)
                        welcomeItem("소리 확인", "실제 활동을 시작하면 협회 BGM이 멈추고 안내 음성을 듣습니다. 스피커 또는 이어폰으로 아래 미리 듣기로 확인하세요.")
                        Button("안내 음성 미리 듣기") { model.audioTest() }.buttonStyle(GameButtonStyle())
                        Text("권한과 소리는 나중에 활동 준비와 메뉴에서도 확인할 수 있습니다.").font(.caption).foregroundStyle(Theme.muted)
                    }
                    HStack {
                        if page > 0 { Button("이전") { page -= 1 }.buttonStyle(GameButtonStyle()) }
                        Spacer()
                        Button(page == 3 ? "협회로 들어가기" : "다음") {
                            if page == 3 { model.completeWelcome() } else { page += 1 }
                        }.buttonStyle(GameButtonStyle(primary: true)).accessibilityIdentifier("welcome.next")
                    }
                }.padding(22)
            }.labyrinthScreen()
                .navigationTitle("첫 이용 안내").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("건너뛰기") { model.completeWelcome() }.accessibilityIdentifier("welcome.skip") } }
        }.interactiveDismissDisabled()
    }
    private func welcomeItem(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 8) { Text(title).font(.headline).foregroundStyle(Theme.teal); Text(body).foregroundStyle(Theme.muted).lineSpacing(4) }
    }
}
