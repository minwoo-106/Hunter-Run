import SwiftUI

struct RenamePartnersView: View {
    @EnvironmentObject var model: AppModel
    @State private var hunter = ""
    @State private var operatorName = ""
    @State private var saved = false
    var body: some View {
        ScrollView { VStack(alignment: .leading, spacing: 20) {
            GameSection("헌터") { TextField("헌터 이름", text: $hunter) }
            GameSection("오퍼레이터") { TextField("오퍼레이터 이름", text: $operatorName) }
            Text("기록과 관계는 유지돼요. 이전 이야기에도 변경한 이름이 표시돼요.").font(.caption)
            Button("이름 저장") {
                model.registerNames(hunter: hunter, operatorName: operatorName)
                saved = model.save.profile.name == Names.clean(hunter) && model.save.profile.journey?.operatorName == Names.clean(operatorName)
            }.disabled(model.growthLocked || !Names.valid(Names.clean(hunter)) || !Names.valid(Names.clean(operatorName)))
            if saved { Label("저장했어요", systemImage: "checkmark.circle").foregroundStyle(Theme.teal) }
        }.padding(20) }.labyrinthScreen().buttonStyle(GameButtonStyle()).navigationTitle("이름 변경")
            .onAppear { hunter = model.save.profile.name; operatorName = model.save.profile.journey?.operatorName ?? "서윤" }
            .onChange(of: hunter) { _, _ in saved = false }
            .onChange(of: operatorName) { _, _ in saved = false }
    }
}

struct RegistrationView: View {
    @EnvironmentObject var model: AppModel
    @State private var hunter = ""
    @State private var operatorName = "서윤"
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Image("OperatorCutout").resizable().scaledToFit().frame(height: 250).accessibilityHidden(true)
                    eyebrow("YOUR FIRST CONNECTION")
                    Text("두 사람의 첫 기록").font(.largeTitle.bold())
                    Text("헌터님의 이름과 함께할 오퍼레이터의 이름을 정해주세요. 나중에 설정에서 바꿀 수 있어요.").foregroundStyle(Theme.muted)
                    VStack(alignment: .leading, spacing: 12) {
                        TextField("헌터 이름", text: $hunter).textContentType(.nickname).accessibilityIdentifier("registration.hunter")
                        Divider()
                        TextField("오퍼레이터 이름", text: $operatorName).accessibilityIdentifier("registration.operator")
                    }.textFieldStyle(.roundedBorder).card()
                    Text("이름은 공백을 제외하고 1~16자로 입력해주세요.").font(.caption).foregroundStyle(Theme.muted)
                    if valid {
                        Text("\(Names.clean(hunter))님, 반가워요. 저는 \(Names.clean(operatorName))\(Names.hasFinal(Names.clean(operatorName)) ? "이에요" : "예요").")
                            .font(.headline).lineSpacing(5).card().accessibilityIdentifier("registration.preview")
                    }
                    Button("등록하고 시작하기") { model.registerNames(hunter: hunter, operatorName: operatorName) }
                        .buttonStyle(GameButtonStyle(primary: true)).disabled(!valid || model.growthLocked).accessibilityIdentifier("registration.confirm")
                }.padding(22)
            }.labyrinthScreen().navigationTitle("헌터 등록").navigationBarTitleDisplayMode(.inline)
        }.interactiveDismissDisabled()
            .onAppear { hunter = model.save.profile.name == "헌터" ? "" : model.save.profile.name; operatorName = model.save.profile.journey?.operatorName ?? "서윤" }
    }
    private var valid: Bool { Names.valid(Names.clean(hunter)) && Names.valid(Names.clean(operatorName)) }
}

struct StoryArchiveView: View {
    @EnvironmentObject var model: AppModel
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                eyebrow("OUR STORY")
                Text("우리 지부의 이야기").font(.largeTitle.bold())
                let entries = model.narratives?.main ?? []
                let state = model.save.profile.journey ?? JourneyState()
                let available = entries.filter { state.unlocked.contains($0.id) }
                let read = available.filter { state.completed.contains($0.id) }.count
                Text("전체 \(entries.count) · 읽음 \(read) · 새 이야기 \(available.count - read) · 잠김 \(entries.count - available.count)")
                    .font(.caption).foregroundStyle(Theme.teal).accessibilityIdentifier("story.counts")
                if let current = state.cursor, current.sceneID.hasPrefix("M"), let entry = model.narratives?.scene(current.sceneID) {
                    NavigationLink { DialogueView(scene: entry) } label: { Label("읽던 이야기 이어보기", systemImage: "bookmark.fill").card() }
                }
                if let next = entries.first(where: { !state.unlocked.contains($0.id) }) {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("다음 이야기를 향해", systemImage: "flag.checkered").font(.headline)
                        ForEach(Array(next.requirements.enumerated()), id: \.offset) { _, requirement in
                            HStack {
                                Text(requirement.hint)
                                Spacer()
                                Image(systemName: requirement.satisfied(model.save.profile) ? "checkmark.circle.fill" : "circle")
                            }.font(.caption).foregroundStyle(Theme.muted)
                        }
                    }.card().accessibilityIdentifier("story.next-goal")
                }
                ForEach(entries) { scene in
                    if state.unlocked.contains(scene.id) {
                        NavigationLink { DialogueView(scene: scene) } label: {
                            sceneRow(scene, read: state.completed.contains(scene.id))
                        }.buttonStyle(.plain).accessibilityIdentifier("story." + scene.id)
                    } else {
                        HStack {
                            Image(systemName: "lock.fill").foregroundStyle(Theme.muted)
                            Text(String(format: "%02d", scene.order) + " · 아직 도착하지 않은 이야기")
                            Spacer(minLength: 0)
                        }.font(.callout).card().accessibilityIdentifier("story.locked." + scene.id)
                    }
                }
                if !(model.save.profile.readStories ?? []).isEmpty {
                    NavigationLink("이전 통신 기록") { LegacyStoryArchiveView() }.font(.caption).foregroundStyle(Theme.muted)
                }
            }.padding(20)
        }.labyrinthScreen().navigationTitle("스토리").navigationBarTitleDisplayMode(.inline)
    }
    private func sceneRow(_ scene: NarrativeScene, read: Bool) -> some View {
        HStack(spacing: 14) {
            Image(systemName: read ? "book.closed" : "envelope.badge").font(.title2).foregroundStyle(Theme.teal)
            VStack(alignment: .leading, spacing: 6) {
                Text(String(format: "%02d", scene.order) + " · " + scene.title).font(.headline)
                Text(read ? "다시 보기" : "새 이야기").font(.caption).foregroundStyle(Theme.teal)
            }
            Spacer(minLength: 0); Image(systemName: "chevron.right").foregroundStyle(Theme.muted)
        }.card()
    }
}

struct DialogueView: View {
    @EnvironmentObject var model: AppModel
    let scene: NarrativeScene
    @State private var replay = false
    @State private var replayNode: String?
    @State private var replayMemory: [String: String] = [:]
    @State private var finished = false
    @State private var prepared = false
    private var cursor: DialogueCursor? { model.save.profile.journey?.cursor }
    private var node: DialogueNode? {
        guard !finished else { return nil }
        return scene.node(replay ? (replayNode ?? scene.start) : (cursor?.sceneID == scene.id ? cursor!.nodeID : scene.start))
    }
    private var pending: [String: String] { replay ? replayMemory : cursor?.pendingMemory ?? [:] }
    var body: some View {
        ConversationStage(artwork: scene.artwork, expression: node?.expression ?? "calm", resetKey: node?.id ?? "finished") {
                if let node {
                    let speaker = node.speaker == "operator" ? model.save.profile.journey?.operatorName ?? "오퍼레이터" : node.speaker == "hunter" ? model.save.profile.name : "관측 기록"
                    Label(speaker, systemImage: "diamond.fill").font(.headline).foregroundStyle(Labyrinth.gold)
                    Text(node.rendered(profile: model.save.profile, pending: pending)).font(.title3).lineSpacing(7)
                        .fixedSize(horizontal: false, vertical: true).accessibilityIdentifier("dialogue.text")
                    let memory = (model.save.profile.journey?.memories ?? [:]).merging(pending) { _, new in new }
                    if let choices = node.choices, !choices.isEmpty {
                        ForEach(choices.filter { $0.available(memory) }) { choice in
                            Button { advance(choice) } label: {
                                HStack(alignment: .top, spacing: 12) { Image(systemName: "diamond").font(.caption).padding(.top, 3); Text(Names.render(choice.text, profile: model.save.profile)).frame(maxWidth: .infinity, alignment: .leading) }
                            }.buttonStyle(GameButtonStyle()).accessibilityIdentifier("dialogue.choice." + choice.id)
                        }
                    } else {
                        Button { advance(nil) } label: { HStack { Text(node.next == nil ? "이야기 마치기" : "다음"); Spacer(); Image(systemName: node.next == nil ? "bookmark" : "chevron.right") } }
                            .buttonStyle(GameButtonStyle(primary: true)).accessibilityIdentifier("dialogue.next")
                    }
                    if !replay { Text("나가도 읽던 곳에서 이어볼 수 있어요.").font(.caption).foregroundStyle(Theme.muted) }
                } else if finished {
                    Label("이야기를 간직했어요", systemImage: "bookmark.fill").font(.title2.bold()).foregroundStyle(Theme.teal)
                    Text(replay ? "언제든 다시 읽을 수 있어요." : scene.kind == "bond" ? "함께 나눈 이야기가 한 편 더 쌓였어요." : "다음 목표는 스토리 목록과 의뢰에서 확인할 수 있어요.").foregroundStyle(Theme.muted)
                    if scene.kind == "bond" && !replay { Text("호감도 +4").font(.headline).foregroundStyle(Theme.teal) }
                    Button("다시 읽기") { replay = true; replayNode = scene.start; replayMemory = [:]; finished = false }.buttonStyle(GameButtonStyle())
                    if ["M01", "M06", "M13", "M16"].contains(scene.id) {
                        Button("오퍼레이터의 한마디 듣기") { model.playStorySummary(scene.id) }.buttonStyle(GameButtonStyle())
                    }
                }
        }.navigationTitle(scene.title).navigationBarTitleDisplayMode(.inline).modifier(GameBackModifier())
            .disabled(model.growthLocked)
            .onAppear {
                guard !prepared else { return }; prepared = true
                replay = model.save.profile.journey?.completed.contains(scene.id) == true
                if replay { replayNode = scene.start } else { model.beginDialogue(scene.id) }
            }
            .onDisappear { model.stopAudioPreview() }
    }
    private func advance(_ choice: DialogueChoice?) {
        guard let node else { return }
        if replay {
            replayMemory.merge(choice?.memory ?? [:]) { _, new in new }
            if let next = choice?.next ?? node.next { replayNode = next } else { finished = true }
        } else {
            model.advanceDialogue(choice?.id)
            finished = model.save.profile.journey?.completed.contains(scene.id) == true
        }
    }
}

struct OperatorConversationView: View {
    @EnvironmentObject var model: AppModel
    @State private var casual: String?
    @State private var topic: String?
    @State private var memories = false
    var body: some View {
        ConversationStage(artwork: AssociationStage.artwork(model.save.profile), expression: casual == nil ? "calm" : "smile", resetKey: (casual ?? "") + String(memories)) {
                let state = model.save.profile.journey ?? JourneyState()
                let tier = model.narratives?.tier(model.save.profile) ?? 1
                HStack { Text(state.operatorName).font(.title2.bold()).foregroundStyle(Labyrinth.gold); Spacer(); Button { memories.toggle() } label: { Label(memories ? "대화로" : "함께한 기록", systemImage: memories ? "bubble.left" : "book.closed") }.buttonStyle(GameControlStyle()).accessibilityIdentifier("operator.memories") }
                Label(NarrativeCatalog.tierNames[tier - 1], systemImage: "heart.text.clipboard").foregroundStyle(Theme.teal)
                if !memories {
                ProgressView(value: Double(min(68, state.affinity)), total: 68).tint(Theme.teal).accessibilityLabel("호감도 \(state.affinity)")
                Text(casual ?? (tier <= 2 ? "부르셨어요? 잠깐 이야기할까요?" : "마침 잘 오셨어요. 오늘은 제가 먼저 물어볼 게 있어요."))
                    .font(.title3).lineSpacing(7).fixedSize(horizontal: false, vertical: true).accessibilityIdentifier("operator.reply")
                VStack(spacing: 10) {
                    Button("잠깐 쉬어요") {
                        topic = nil
                        casual = state.memories["rest"] == "quiet" ? "좋아요. 오늘도 잠깐 조용히 있어요. 창문만 조금 열어둘게요." : tier < 3 ? "괜찮아요. 다음 의뢰는 준비되시면 확인해요." : "좋아요. 저도 잠깐 쉬려고 했어요. 오늘은 보고서 이야기 빼고요."
                    }.buttonStyle(GameButtonStyle())
                    Button("오늘 기분은 어때요?") { topic = nil; casual = tier < 3 ? "오늘은 관측값이 잘 정리돼서 마음이 놓여요. 아직 확인할 건 조금 남았지만요." : "오늘은 일 얘기 말고 먼저 인사하고 싶었어요. 특별한 일이 없을 때도 이야기하고 싶어서요." }.buttonStyle(GameButtonStyle())
                }
                NavigationLink { QuestBoardView() } label: { Label("오늘의 의뢰 이야기", systemImage: "list.clipboard").card() }
                VStack(spacing: 10) {
                    Button("음료 이야기") { topic = "drink"; casual = "오늘은 어떤 걸로 할까요? 지난번과 달라도 괜찮아요." }.buttonStyle(GameButtonStyle())
                    Button("책상 구경") {
                        topic = nil
                        casual = state.memories["desk"] == "cup" ? "컵 놓을 자리는 여기예요. 서류는 조금 떨어뜨려뒀어요. 오래 쓸 자리니까요." : "첫 보고서는 여기 남겨뒀어요. 지나간 건데도 꺼내보면 그때 생각이 나요."
                    }.buttonStyle(GameButtonStyle())
                }
                if topic == "drink" {
                    ForEach([("warm", "따뜻한 게 좋아요.", "그럼 따뜻한 쪽으로 준비할게요. 컵 잡고 쉬는 시간도 좋더라고요."), ("cool", "시원한 게 좋아요.", "알겠어요. 받침도 같이 둘게요. 서류는 제가 먼저 치워둘 거예요."), ("flexible", "그날 기분대로 골라요.", "그럼 하나로 정하지 않을게요. 오늘 기분을 물어볼 이유가 생겼네요.")], id: \.0) { option in
                        Button(option.1) { model.rememberPreference("drink", value: option.0); casual = option.2; topic = nil }.buttonStyle(GameButtonStyle())
                    }
                }
                if state.completed.contains("R11") {
                    Button("다음 약속 이야기") { topic = "relationship"; casual = "지난번 약속, 어떻게 이어갈까요?" }.buttonStyle(GameButtonStyle())
                    if topic == "relationship" {
                        ForEach([("closer", "조금 더 개인적인 시간으로요.", "좋아요. 저도 우리 이야기부터 하고 싶어요."), ("partnership", "든든한 동료로 함께해요.", "네. 그 말도 저한테는 특별해요. 앞으로도 잘 부탁해요."), ("undecided", "아직은 천천히 생각할게요.", "괜찮아요. 오늘 대화부터 편하게 해요.")], id: \.0) { option in
                            Button(option.1) { model.rememberPreference("relationshipPreference", value: option.0); casual = option.2; topic = nil }.buttonStyle(GameButtonStyle())
                        }
                    }
                }
                } else {
                Text("함께 나눌 이야기").font(.title2.bold())
                ForEach(model.narratives?.bonds ?? []) { entry in
                    if state.unlocked.contains(entry.id) {
                        NavigationLink { DialogueView(scene: entry) } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(entry.title).font(.headline)
                                    Text(state.completed.contains(entry.id) ? "추억 다시 보기" : "새로운 대화").font(.caption).foregroundStyle(Theme.teal)
                                }
                                Spacer(); Image(systemName: "chevron.right")
                            }.card()
                        }.buttonStyle(.plain).accessibilityIdentifier("bond." + entry.id)
                    } else {
                        Label("아직 나누지 않은 이야기", systemImage: "lock.fill").font(.callout).foregroundStyle(Theme.muted).card()
                    }
                }
                Text("새로운 대화와 함께 겪은 사건으로 가까워져요. 이미 나눈 이야기는 언제든 다시 읽을 수 있어요.").font(.caption).foregroundStyle(Theme.muted)
                }
        }.navigationTitle("오퍼레이터와 대화").navigationBarTitleDisplayMode(.inline)
    }
}
