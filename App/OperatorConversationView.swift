import SwiftUI

/// A conversation is a sequence of lines and a small set of replies, not a topic dashboard.
struct OperatorConversationView: View {
    @EnvironmentObject var model: AppModel
    @State private var line: String?
    @State private var expression = "calm"
    @State private var choosing = false
    @State private var topic = "greeting"
    @State private var opening: String?
    @State private var smallTalk: [OperatorChatEpisode] = []
    @State private var chatEpisode: OperatorChatEpisode?
    @State private var chatNodeID = "start"
    @State private var chatLineIndex = 0
    @State private var showGifts = false
    @State private var giftNote: String?
    private var chatNode: OperatorChatNode? { chatEpisode?.node(chatNodeID) }
    private var state: JourneyState { model.save.profile.journey ?? JourneyState() }
    private var tier: Int { model.narratives?.tier(model.save.profile) ?? 1 }
    private var greeting: String { tier < 3 ? "부르셨어요? 마침 기록 정리가 끝났어요. 잠깐 이야기할까요?" : "왔어요? 문소리 듣고 혹시나 했어요. 오늘은 무슨 이야기부터 할까요?" }
    var body: some View {
        NovelStage(expression: expression, resetKey: (line ?? "") + String(choosing)) {
            HStack {
                Text(state.operatorName).font(.headline).foregroundStyle(Labyrinth.parchment)
                if let giftNote { Text(giftNote).font(.caption).foregroundStyle(Theme.teal).accessibilityIdentifier("operator.gift-gain") }
                Spacer()
                Text(choosing ? "당신의 대답" : "터치해 계속").font(.caption2).foregroundStyle(Theme.muted)
            }
            Button {
                guard !choosing else { return }
                if topic == "smalltalk", let node = chatNode, chatLineIndex + 1 < node.lines.count {
                    chatLineIndex += 1
                    say(model.chatText(node.lines[chatLineIndex]), face: node.expression, next: "smalltalk")
                } else { withAnimation(.easeOut(duration: 0.18)) { choosing = true } }
            } label: {
                Text(line ?? opening ?? greeting).font(.title3).lineSpacing(7).fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, minHeight: 85, alignment: .topLeading).contentShape(Rectangle())
                    .foregroundStyle(Labyrinth.parchment)
            }.buttonStyle(.plain).accessibilityIdentifier("operator.continue")
            if choosing { choices }
            else { HStack { Spacer(); Image(systemName: "chevron.down").font(.caption).foregroundStyle(Labyrinth.gold) }.allowsHitTesting(false) }
        }.navigationTitle("").navigationBarTitleDisplayMode(.inline)
            .onAppear {
                guard opening == nil else { return }
                smallTalk = model.chatSuggestions()
                opening = openingLine()
            }
            .sheet(isPresented: $showGifts) {
                OperatorGiftView { response in
                    showGifts = false; chatEpisode = nil
                    say(response.text, face: response.expression)
                    giftNote = "친밀도 +\(response.affinity)"
                }.environmentObject(model)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    HStack(spacing: 8) {
                        NavigationLink { OperatorMemoriesView() } label: { Label("관계", systemImage: "heart") }
                            .buttonStyle(GameControlStyle()).accessibilityLabel("친밀도와 함께한 기록").accessibilityIdentifier("operator.memories")
                        Button { showGifts = true } label: { Image(systemName: "gift") }
                            .buttonStyle(GameControlStyle()).accessibilityLabel("선물 건네기").accessibilityIdentifier("operator.gifts")
                    }
                }
            }
    }
    private func say(_ text: String, face: String = "smile", next: String = "greeting") {
        giftNote = nil
        withAnimation(.easeOut(duration: 0.18)) { line = text; expression = face; topic = next; choosing = false }
    }
    @ViewBuilder private var choices: some View {
        switch topic {
        case "greeting":
            reply("잠깐 쉬어요") {
                say(tier < 3 ? "좋아요. 지금은 급한 연락도 없어요. 보고서는 잠깐 덮어둘게요." : "그 말 기다렸어요. 사실 같은 줄을 세 번이나 읽고 있었거든요. 잠깐, 같이 쉬어요.", face: "relieved", next: "rest")
            }
            if let episode = smallTalk.first {
                reply(model.chatText(episode.prompt)) { startChat(episode) }
                    .accessibilityIdentifier("operator.chat.featured." + episode.id)
            } else {
                reply("오늘 기분은 어때요?") { say("아까는 좀 피곤했는데, 잠깐 쉬니까 괜찮아졌어요. 헌터님은요?", next: "mood") }
            }
            reply("오늘은 다른 이야기도 하고 싶어요.") { openTopics() }
        case "rest":
            reply("말없이 같이 쉬어도 좋아요.") { say("네. 무슨 말을 해야 할지 고민하지 않아도 되는 시간도 좋네요.", face: "relieved") }
            reply("차 한 잔 마실까요?") { askDrink() }
            reply("쉬면서 오늘 있었던 일 들려줘요.") { say("아침에 서류 사이에서 컵 받침을 찾았어요. 분명 제가 넣어둔 건데 한참 찾았죠. 오늘은 책상부터 정리해야겠어요.", face: "playful", next: "desk") }
        case "mood":
            reply("무리하지 않았으면 좋겠어요.") { say("고마워요. 오늘은 정리할 것만 마치고 쉬어볼게요. 대신 당신도 약속해요.", face: "relieved") }
            reply("저도 이야기하니까 좋네요.") { say(tier < 3 ? "그렇게 말씀해 주시니 기뻐요. 다음에도 편하게 불러주세요." : "그럼 다음에도 그냥 들러요. 특별한 일이 없어도요.") }
            reply("차라도 준비할까요?") { askDrink() }
        case "topics":
            ForEach(smallTalk) { episode in
                reply(model.chatText(episode.prompt)) { startChat(episode) }
                    .accessibilityIdentifier("operator.chat.topic." + episode.id)
            }
        case "smalltalk":
            if let node = chatNode, !node.replies.isEmpty {
                ForEach(node.replies) { answer in
                    reply(model.chatText(answer.text)) { showChatNode(answer.next) }
                        .accessibilityIdentifier("operator.chat.reply." + answer.id)
                }
            } else {
                reply("다른 이야기도 듣고 싶어요.") { openTopics() }
                reply("같이 잠깐 쉬어요.") { say("좋아요. 보고서는 잠깐 덮어둘게요.", face: "relieved", next: "rest") }
                reply(state.completed.contains("R11") ? "우리 다음 약속도 이야기해요." : "오늘 맡을 일도 같이 볼까요?") {
                    if state.completed.contains("R11") { say("좋아요. 다음에는 어떤 시간을 보내고 싶어요?", next: "relationship") }
                    else { say("네. 준비해둔 의뢰를 같이 봐요.", next: "work") }
                }
            }
        case "desk":
            reply("우리 기록도 더 쌓이겠네요.") { say("네. 사진 옆에 붙일 이야기도 많아지겠죠. 하나씩 남겨봐요.") }
            reply("필요한 일부터 같이 볼까요?") { say("좋아요. 정리해둔 의뢰를 꺼내볼게요.", next: "work") }
            reply("다른 이야기도 듣고 싶어요.") { openTopics() }
        case "work":
            NavigationLink { QuestBoardView() } label: { Text("의뢰 기록을 같이 볼게요.") }.buttonStyle(GameButtonStyle())
            reply("조금 더 이야기하다 갈게요.") { openTopics() }
        case "relationship":
            reply("다음엔 일 얘기 말고 우리 얘기해요.") { preference("closer", "좋아요. 그때는 보고서부터 덮어둘게요. 저도 하고 싶은 얘기가 있어요.") }
            reply("든든한 동료로 함께해요.") { preference("partnership", "네. 서로 믿고 맡길 수 있는 사이, 저도 좋아요. 앞으로도 잘 부탁해요.") }
            reply("아직은 천천히 생각할게요.") { preference("undecided", "괜찮아요. 급하게 정하지 않아도 돼요. 오늘은 그냥 같이 쉬어요.") }
        case "drink":
            reply("따뜻한 게 좋아요.") { drink("warm", "좋아요. 조금 식혀서 가져올게요. 저처럼 급하게 마시다가 데지 말고요.") }
            reply("시원한 게 좋아요.") { drink("cool", "얼음 넣어서 준비할게요. 컵에 물방울 맺히니까 받침도 같이요.") }
            reply("오늘은 추천해 주세요.") { drink("flexible", "그럼 오늘은 제가 좋아하는 걸로요. 마셔보고 별로면 솔직하게 말해줘요.") }
        default: EmptyView()
        }
    }
    private func reply(_ text: String, action: @escaping () -> Void) -> some View { Button(text, action: action).buttonStyle(GameButtonStyle()) }
    private func openingLine() -> String {
        switch model.operatorChatActivity {
        case "coffee": return "커피 한 모금 마시던 참이에요. 같이 잠깐 쉬실래요?"
        case "tablet": return "마침 읽던 데까지 다 봤어요. 태블릿은 내려둘게요."
        case "spacingOut": return "아, 오셨어요? 창밖 보고 있었어요. 잠깐 멍때렸네요."
        case "hairSweep": return "머리가 자꾸 내려와서요. 자, 됐어요. 무슨 얘기 할까요?"
        default: return (tier < 3
            ? ["오셨어요? 급한 일은 정리해뒀어요. 잠깐 앉으실래요?", "부르셨어요? 마침 쉬려던 참이에요. 이야기해요.", "오늘은 일 얘기 말고 다른 얘기도 해봐요. 뭐부터 이야기할까요?"]
            : ["왔어요? 여기 앉아요. 오늘은 어떤 하루였어요?", "마침 잘 왔어요. 잠깐 같이 쉬고 싶었거든요.", "문소리 듣고 고개부터 들었네요. 오늘은 무슨 얘기부터 할까요?"]).randomElement() ?? greeting
        }
    }
    private func openTopics() {
        chatEpisode = nil
        smallTalk = model.chatSuggestions()
        say("좋아요. 오늘은 어떤 얘기가 궁금해요?", next: "topics")
    }
    private func startChat(_ episode: OperatorChatEpisode) {
        chatEpisode = episode
        model.selectedChatTopic(episode.id)
        showChatNode(episode.start)
    }
    private func showChatNode(_ id: String) {
        guard let node = chatEpisode?.node(id), let first = node.lines.first else { return }
        chatNodeID = id; chatLineIndex = 0
        say(model.chatText(first), face: node.expression, next: "smalltalk")
    }
    private func askDrink() {
        let remembered = state.memories["drink"] == "warm" ? "따뜻한 걸 좋아한다고 했죠? 오늘도 따뜻하게 준비할까요?" : state.memories["drink"] == "cool" ? "지난번엔 시원한 걸 골랐죠? 오늘도 얼음 넣을까요?" : "따뜻한 거랑 시원한 거, 어느 쪽이 좋아요? 알려주시면 기억해둘게요."
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
                VStack(alignment: .leading, spacing: 12) {
                    Label("\(state.operatorName) · \(NarrativeCatalog.tierNames[tier - 1])", systemImage: "heart.fill").foregroundStyle(Theme.teal)
                    Text("친밀도 \(state.affinity)").font(.title2.bold()).accessibilityIdentifier("operator.relationship-affinity")
                    if tier < NarrativeCatalog.tierNames.count {
                        let gate = NarrativeCatalog.relationshipGates[tier - 1]
                        ProgressView(value: Double(min(gate.0, state.affinity)), total: Double(gate.0))
                            .accessibilityLabel("다음 관계까지 친밀도 \(state.affinity) / \(gate.0)")
                        Text(state.affinity < gate.0 ? "다음 관계까지 친밀도 \(gate.0 - state.affinity) 더 필요해요." : "친밀도 조건은 채웠어요. 함께 새로운 사건을 겪으면 다음 관계로 이어져요.")
                            .font(.caption).foregroundStyle(Theme.muted)
                    } else { Text("함께 쌓은 이야기로 가장 가까운 관계가 되었어요.").font(.caption).foregroundStyle(Theme.muted) }
                    Text("함께한 이야기와 새로운 사건, 작은 선물로 가까워져요. 관계 변화에는 이야기 진행도 필요해요.")
                        .font(.caption).foregroundStyle(Theme.muted)
                }.card()
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
                Text("함께 겪은 사건과 새로운 이야기로 가까워져요. 같은 대화를 반복해서 친밀도가 쌓이지는 않아요.").font(.caption).foregroundStyle(Theme.muted)
            }.padding(22)
        }.labyrinthScreen().navigationTitle("함께한 기록").navigationBarTitleDisplayMode(.inline).modifier(GameBackModifier())
    }
}

struct OperatorGiftView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    var onGiven: (GiftReaction) -> Void
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("작은 마음을 전해요").font(.title2.bold())
                    Text("야외 탐험에서 실제로 움직인 시간이 30분 쌓일 때마다 작은 선물을 발견해요. 여러 활동의 시간이 합산돼요.")
                        .font(.callout).foregroundStyle(Theme.muted)
                    let inventory = model.save.profile.journey?.gifts?.inventory ?? [:]
                    if inventory.values.reduce(0, +) == 0 {
                        Text("아직 보관 중인 선물이 없어요.").card().accessibilityIdentifier("operator.gifts-empty")
                        Text("발견한 선물은 귀환 보고에서 확인할 수 있어요.").font(.caption).foregroundStyle(Theme.muted)
                    }
                    ForEach(OperatorGift.allCases.filter { inventory[$0.id, default: 0] > 0 }) { gift in
                        VStack(alignment: .leading, spacing: 10) {
                            HStack { Label(gift.name, systemImage: gift.symbol).font(.headline); Spacer(); Text("×\(inventory[gift.id, default: 0])").monospacedDigit() }
                            Text(gift.detail).font(.callout).foregroundStyle(Theme.muted)
                            let gain = min(2, max(0, 1000 - (model.save.profile.journey?.affinity ?? 0)))
                            Button(gain > 0 ? "건네기 · 친밀도 +\(gain)" : "건네기") {
                                if let response = model.giveOperatorGift(gift) { onGiven(response) }
                            }.buttonStyle(GameButtonStyle()).disabled(model.growthLocked)
                                .accessibilityIdentifier("operator.give." + gift.id)
                        }.card()
                    }
                }.padding(22)
            }.labyrinthScreen().navigationTitle("선물 건네기").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("닫기") { dismiss() }.buttonStyle(GameControlStyle()) } }
        }
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
