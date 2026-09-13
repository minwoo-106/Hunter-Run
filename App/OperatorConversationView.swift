import SwiftUI

/// A conversation is a sequence of lines and a small set of replies, not a topic dashboard.
struct OperatorConversationView: View {
    @EnvironmentObject var model: AppModel
    @State private var line: String?
    @State private var expression = "calm"
    @State private var choosing = false
    @State private var topic = "greeting"
    private var state: JourneyState { model.save.profile.journey ?? JourneyState() }
    private var tier: Int { model.narratives?.tier(model.save.profile) ?? 1 }
    private var greeting: String { tier < 3 ? "부르셨어요? 마침 기록 정리가 끝났어요. 잠깐 이야기할까요?" : "왔어요? 문소리 듣고 혹시나 했어요. 오늘은 무슨 이야기부터 할까요?" }
    var body: some View {
        NovelStage(expression: expression, resetKey: (line ?? "") + String(choosing)) {
            HStack {
                Text(state.operatorName).font(.headline).foregroundStyle(Labyrinth.parchment)
                Spacer()
                Text(choosing ? "당신의 대답" : "터치해 계속").font(.caption2).foregroundStyle(Theme.muted)
            }
            Button {
                guard !choosing else { return }
                withAnimation(.easeOut(duration: 0.18)) { choosing = true }
            } label: {
                Text(line ?? greeting).font(.title3).lineSpacing(7).fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, minHeight: 85, alignment: .topLeading).contentShape(Rectangle())
                    .foregroundStyle(Labyrinth.parchment)
            }.buttonStyle(.plain).accessibilityIdentifier("operator.continue")
            if choosing { choices }
            else { HStack { Spacer(); Image(systemName: "chevron.down").font(.caption).foregroundStyle(Labyrinth.gold) }.allowsHitTesting(false) }
        }.navigationTitle("").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink { OperatorMemoriesView() } label: { Image(systemName: "book.closed") }
                        .buttonStyle(GameControlStyle()).accessibilityLabel("함께한 기록").accessibilityIdentifier("operator.memories")
                }
            }
    }
    private func say(_ text: String, face: String = "smile", next: String = "greeting") {
        withAnimation(.easeOut(duration: 0.18)) { line = text; expression = face; topic = next; choosing = false }
    }
    @ViewBuilder private var choices: some View {
        switch topic {
        case "greeting":
            reply("잠깐 쉬어요") {
                say(tier < 3 ? "좋아요. 지금은 급한 연락도 없어요. 보고서는 잠깐 덮어둘게요." : "그 말 기다렸어요. 사실 같은 줄을 세 번이나 읽고 있었거든요. 잠깐, 같이 쉬어요.", face: "relieved", next: "rest")
            }
            reply("오늘 기분은 어때요?") {
                say(tier < 3 ? "관측값이 잘 정리돼서 마음이 놓여요. 이렇게 먼저 물어봐 주시니까 조금 더요." : "아까까진 조금 피곤했는데… 지금은 괜찮아요. 일 말고 제 기분부터 물어봐 줘서요.", next: "mood")
            }
            reply("오늘은 다른 이야기도 하고 싶어요.") { say("좋아요. 의뢰 말고도 나눌 이야기는 많으니까요.", next: "topics") }
        case "rest":
            reply("말없이 같이 쉬어도 좋아요.") { say("네. 무슨 말을 해야 할지 고민하지 않아도 되는 시간도 좋네요.", face: "relieved") }
            reply("차 한 잔 마실까요?") { askDrink() }
            reply("쉬면서 오늘 있었던 일 들려줘요.") { say("아침에 서류 사이에서 컵 받침을 찾았어요. 분명 제가 넣어둔 건데 한참 찾았죠. 오늘은 책상부터 정리해야겠어요.", face: "playful", next: "desk") }
        case "mood":
            reply("무리하지 않았으면 좋겠어요.") { say("고마워요. 오늘은 정리할 것만 마치고 쉬어볼게요. 대신 당신도 약속해요.", face: "relieved") }
            reply("저도 이야기하니까 좋네요.") { say(tier < 3 ? "그렇게 말씀해 주시니 기뻐요. 다음에도 편하게 불러주세요." : "그럼 다음에도 그냥 들러요. 특별한 일이 없어도요.") }
            reply("차라도 준비할까요?") { askDrink() }
        case "topics":
            reply("오늘은 어떤 음료 마실까요?") { askDrink() }
            reply("책상 위에 있는 건 뭐예요?") { say(state.memories["desk"] == "cup" ? "컵 놓을 자리예요. 서류는 조금 떨어뜨려뒀어요. 이제 누가 오면 어디에 앉을지도 정해졌네요." : "처음 받았던 보고서예요. 지나간 일인데도 꺼내보면 그때 생각이 나서 남겨뒀어요.", face: "thoughtful", next: "desk") }
            reply(state.completed.contains("R11") ? "우리 다음 약속도 이야기해요." : "오늘 맡을 일도 알려주세요.") {
                if state.completed.contains("R11") { say("좋아요. 지난번 약속은 어떻게 이어가고 싶어요?", next: "relationship") }
                else { say("지금 맡을 수 있는 의뢰를 정리해뒀어요. 준비되면 같이 살펴봐요.", next: "work") }
            }
        case "drink":
            reply("따뜻한 게 좋아요.") { drink("warm", "그럼 따뜻하게 준비할게요. 컵 잡고 손을 녹이는 시간도 좋더라고요.") }
            reply("시원한 게 좋아요.") { drink("cool", "알겠어요. 받침도 같이 둘게요. 서류는 제가 먼저 치워둘게요.") }
            reply("오늘은 추천해 주세요.") { drink("flexible", "그럼 오늘은 제가 골라볼게요. 다음번에는 당신 차례예요.") }
        case "desk":
            reply("우리 기록도 더 쌓이겠네요.") { say("네. 아직 비어 있는 칸이 많아요. 서두르지 말고 하나씩 채워가요.") }
            reply("필요한 일부터 같이 볼까요?") { say("좋아요. 정리해둔 의뢰를 꺼내볼게요.", next: "work") }
            reply("다른 이야기도 듣고 싶어요.") { say("얼마든지요. 무엇부터 이야기할까요?", next: "topics") }
        case "work":
            NavigationLink { QuestBoardView() } label: { Text("의뢰 기록을 같이 볼게요.") }.buttonStyle(GameButtonStyle())
            reply("조금 더 이야기하다 갈게요.") { say("그럼 기록은 잠깐 내려둘게요. 지금은 이야기부터 해요.", next: "topics") }
        case "relationship":
            reply("조금 더 개인적인 시간으로요.") { preference("closer", "좋아요. 저도 우리 이야기부터 하고 싶어요.") }
            reply("든든한 동료로 함께해요.") { preference("partnership", "네. 그 말도 저한테는 특별해요. 앞으로도 잘 부탁해요.") }
            reply("아직은 천천히 생각할게요.") { preference("undecided", "괜찮아요. 오늘 대화부터 편하게 해요.") }
        default: EmptyView()
        }
    }
    private func reply(_ text: String, action: @escaping () -> Void) -> some View { Button(text, action: action).buttonStyle(GameButtonStyle()) }
    private func askDrink() {
        let remembered = state.memories["drink"] == "warm" ? "따뜻한 걸 좋아한다고 했죠? 오늘도 그렇게 할까요?" : state.memories["drink"] == "cool" ? "시원한 걸 좋아했죠? 오늘은 어떤 기분이에요?" : "오늘은 어떤 걸로 할까요? 취향을 알려주면 기억해둘게요."
        say(remembered, next: "drink")
    }
    private func drink(_ value: String, _ text: String) { model.rememberPreference("drink", value: value); say(text) }
    private func preference(_ value: String, _ text: String) { model.rememberPreference("relationshipPreference", value: value); say(text) }
}

struct OperatorMemoriesView: View {
    @EnvironmentObject var model: AppModel
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                let state = model.save.profile.journey ?? JourneyState()
                let tier = model.narratives?.tier(model.save.profile) ?? 1
                Text("함께 나눌 이야기").font(.title.bold())
                Label(NarrativeCatalog.tierNames[tier - 1], systemImage: "heart").foregroundStyle(Theme.teal)
                ProgressView(value: Double(min(68, state.affinity)), total: 68).accessibilityLabel("호감도 \(state.affinity)")
                ForEach(model.narratives?.bonds ?? []) { entry in
                    if state.unlocked.contains(entry.id) {
                        NavigationLink { DialogueView(scene: entry) } label: {
                            VStack(alignment: .leading, spacing: 7) {
                                Text(entry.title).font(.headline)
                                Text(state.completed.contains(entry.id) ? "추억 다시 보기" : "새로운 대화").font(.caption).foregroundStyle(Theme.teal)
                            }.card()
                        }.buttonStyle(.plain).accessibilityIdentifier("bond." + entry.id)
                    } else { Label("아직 나누지 않은 이야기", systemImage: "lock.fill").foregroundStyle(Theme.muted).card() }
                }
                Text("함께 겪은 사건과 새로운 이야기로 가까워져요. 같은 대화를 반복해서 호감도가 쌓이지는 않아요.").font(.caption).foregroundStyle(Theme.muted)
            }.padding(22)
        }.labyrinthScreen().navigationTitle("함께한 기록").navigationBarTitleDisplayMode(.inline).modifier(GameBackModifier())
    }
}

struct NovelStage<Content: View>: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dynamicTypeSize) private var textSize
    let expression: String
    var resetKey: String
    @ViewBuilder var content: () -> Content
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                Image(AssociationStage.artwork(model.save.profile)).resizable().scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height).clipped().allowsHitTesting(false)
                OperatorPortrait(expression: expression).frame(width: geo.size.width, height: geo.size.width * 1.5)
                    .allowsHitTesting(false).accessibilityHidden(true)
                LinearGradient(colors: [.clear, Theme.ink.opacity(0.1), Theme.ink], startPoint: .top, endPoint: .bottom).allowsHitTesting(false)
                VStack {
                    Spacer(minLength: 0)
                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(alignment: .leading, spacing: 14) {
                                Color.clear.frame(height: 1).id("novel-top")
                                content()
                            }.padding(20)
                        }.onChange(of: resetKey) { _, _ in proxy.scrollTo("novel-top", anchor: .top) }
                    }.frame(maxHeight: geo.size.height * (textSize.isAccessibilitySize ? 0.66 : 0.48))
                        .background(Theme.ink.opacity(0.96), in: RelicShape(cut: 14))
                        .overlay(RelicShape(cut: 14).stroke(Labyrinth.gold.opacity(0.55), lineWidth: 1))
                        .padding(.horizontal, 12).padding(.bottom, 12)
                }
            }.clipped()
        }.foregroundStyle(Labyrinth.parchment).tint(Labyrinth.gold).environment(\.labyrinthStyle, true)
            .toolbarBackground(Theme.ink, for: .navigationBar).toolbarBackground(.visible, for: .navigationBar).toolbarColorScheme(.dark, for: .navigationBar)
    }
}
