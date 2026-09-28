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
    private var recordPortrait: String? {
        guard node?.speaker == "report" else { return nil }
        return node?.speakerLabel == "강해솔의 기록" ? "HaesolBefore" : scene.artwork
    }
    var body: some View {
        ConversationStage(artwork: scene.artwork, expression: node?.expression ?? "calm", resetKey: node?.id ?? "finished", portraitArtwork: recordPortrait) {
                if let node {
                    let speaker = node.speaker == "operator" ? model.save.profile.journey?.operatorName ?? "오퍼레이터" : node.speaker == "hunter" ? model.save.profile.name : node.speakerLabel ?? "관측 기록"
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
