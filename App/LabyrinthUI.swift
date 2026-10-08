import SwiftUI

enum Labyrinth {
    static let gold = Color(red: 0.79, green: 0.70, blue: 0.49)
    static let stone = Color(red: 0.055, green: 0.085, blue: 0.105)
    static let parchment = Color(red: 0.94, green: 0.92, blue: 0.86)
}

/// Geometry stays vector-based so long Korean labels and Dynamic Type never stretch a bitmap frame.
struct RelicShape: Shape {
    var cut: CGFloat = 10
    func path(in rect: CGRect) -> Path {
        let c = min(cut, min(rect.width, rect.height) / 3)
        return Path { p in
            p.addLines([CGPoint(x: rect.minX + c, y: rect.minY), CGPoint(x: rect.maxX, y: rect.minY), CGPoint(x: rect.maxX, y: rect.maxY - c),
                        CGPoint(x: rect.maxX - c, y: rect.maxY), CGPoint(x: rect.minX, y: rect.maxY),
                        CGPoint(x: rect.minX, y: rect.minY + c)])
            p.closeSubpath()
        }
    }
}

struct LabyrinthBackdrop: View {
    @Environment(\.labyrinthArtwork) private var inheritedArtwork
    var dim: Double = 0.55
    var artwork: String? = nil
    var body: some View {
        GeometryReader { geo in
            Image(artwork ?? inheritedArtwork).resizable().scaledToFill()
                .frame(width: geo.size.width, height: geo.size.height).clipped()
                .overlay(Theme.ink.opacity(dim))
                .overlay(LinearGradient(colors: [.black.opacity(0.12), Theme.ink.opacity(0.85)], startPoint: .top, endPoint: .bottom))
        }.ignoresSafeArea().accessibilityHidden(true).allowsHitTesting(false)
    }
}

private struct LabyrinthKey: EnvironmentKey { static let defaultValue = false }
private struct LabyrinthArtworkKey: EnvironmentKey { static let defaultValue = "LabyrinthEntrance" }
extension EnvironmentValues {
    var labyrinthStyle: Bool {
        get { self[LabyrinthKey.self] }
        set { self[LabyrinthKey.self] = newValue }
    }
    var labyrinthArtwork: String {
        get { self[LabyrinthArtworkKey.self] }
        set { self[LabyrinthArtworkKey.self] = newValue }
    }
}

struct RelicPanel: ViewModifier {
    @Environment(\.labyrinthStyle) private var styled
    func body(content: Content) -> some View {
        if styled {
            content.padding(18).frame(maxWidth: .infinity, alignment: .leading)
                .background(LinearGradient(colors: [Labyrinth.stone.opacity(0.96), Theme.ink.opacity(0.95)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RelicShape())
                .overlay(RelicShape().stroke(Labyrinth.gold.opacity(0.32), lineWidth: 1))
                .overlay(alignment: .topLeading) { Rectangle().fill(Labyrinth.gold).frame(width: 30, height: 2).padding(.leading, 12).accessibilityHidden(true) }
        } else {
            content.padding(18).frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white.opacity(0.056), in: RoundedRectangle(cornerRadius: 18))
                .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Color.white.opacity(0.08)))
        }
    }
}

struct GameButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var enabled
    var primary = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(.callout, design: .serif, weight: .semibold))
            .multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 17).padding(.vertical, 13).frame(minHeight: 48)
            .frame(maxWidth: .infinity, alignment: .leading)
            .foregroundStyle(primary ? Labyrinth.parchment : Color.white.opacity(0.92))
            .background(LinearGradient(colors: primary ? [Color(red: 0.12, green: 0.30, blue: 0.32), Labyrinth.stone] : [Labyrinth.stone, Theme.ink], startPoint: .topLeading, endPoint: .bottomTrailing), in: RelicShape())
            .overlay(RelicShape().stroke(primary ? Labyrinth.gold : Labyrinth.gold.opacity(0.4), lineWidth: 1))
            .brightness(configuration.isPressed ? 0.1 : 0).opacity(enabled ? 1 : 0.42)
    }
}

struct GameControlStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.callout.weight(.semibold)).foregroundStyle(Labyrinth.parchment)
            .padding(.horizontal, 12).frame(minHeight: 44)
            .background(Labyrinth.stone.opacity(configuration.isPressed ? 1 : 0.85), in: RelicShape(cut: 6))
            .overlay(RelicShape(cut: 6).stroke(Labyrinth.gold.opacity(0.5), lineWidth: 1))
    }
}

extension View {
    func labyrinthScreen(artwork: String? = nil) -> some View {
        self.background { LabyrinthBackdrop(artwork: artwork) }.environment(\.labyrinthStyle, true)
            .tint(Labyrinth.gold).foregroundStyle(Labyrinth.parchment)
            .toolbarBackground(Theme.ink.opacity(0.92), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
    }
}

struct GameSection<Content: View>: View {
    let title: String
    let content: Content
    init(_ title: String, @ViewBuilder content: () -> Content) { self.title = title; self.content = content() }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Image(systemName: "diamond.fill").font(.system(size: 7))
                Text(title).font(.headline)
                Rectangle().frame(height: 1).opacity(0.3)
            }.foregroundStyle(Labyrinth.gold)
            content
        }.card()
    }
}

struct HunterDossier: View {
    @EnvironmentObject var model: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            eyebrow("HUNTER  /  PERSONAL RECORD")
            HStack(spacing: 20) {
                ZStack {
                    RelicShape(cut: 22).fill(Theme.ink)
                    RelicShape(cut: 22).stroke(Labyrinth.gold, lineWidth: 1)
                    VStack(spacing: 0) {
                        Image(systemName: "laurel.leading").font(.caption)
                        Text(model.save.profile.growth.rank).font(.system(size: 48, weight: .medium, design: .serif))
                        Text("RANK").font(.system(size: 9, weight: .bold)).tracking(3)
                    }.foregroundStyle(Labyrinth.gold)
                }.frame(width: 94, height: 116).accessibilityLabel("\(model.save.profile.growth.rank)급")
                VStack(alignment: .leading, spacing: 8) {
                    Text(model.save.profile.name).font(.largeTitle.bold()).fixedSize(horizontal: false, vertical: true)
                    Text("Lv.\(model.save.profile.level) · 협회 소속 헌터").font(.callout).foregroundStyle(Theme.teal)
                }
            }
            ProgressView(value: Double(model.save.profile.levelProgress), total: Double(model.save.profile.nextLevelExperience)).tint(Labyrinth.gold)
            Text("다음 레벨까지 \(model.save.profile.nextLevelExperience - model.save.profile.levelProgress) EXP").font(.caption.monospacedDigit()).foregroundStyle(Theme.muted)
        }.card()
    }
}

struct DossierLink: View {
    let title: String
    let subtitle: String
    let icon: String
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon).font(.title2).foregroundStyle(Labyrinth.gold).frame(width: 34)
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.headline).foregroundStyle(Labyrinth.parchment)
                Text(subtitle).font(.caption).foregroundStyle(Theme.muted)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(Labyrinth.gold)
        }.card().accessibilityElement(children: .ignore).accessibilityLabel(title).accessibilityHint(subtitle)
    }
}

/// Cold-launch title gate; returning from the background does not interrupt an activity.
struct LaunchGateView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var entered = false
    @State private var entering = false
    @State private var showingPortal = true
    @State private var entranceStartedAt: Date?
    private var skip: Bool {
#if DEBUG && targetEnvironment(simulator)
        return ProcessInfo.processInfo.arguments.contains("--ui-testing-skip-title")
#else
        return false
#endif
    }
    var body: some View {
        ZStack {
            if entered || skip { RootView(launchCovered: showingPortal && !skip)
                .allowsHitTesting(!showingPortal || skip).accessibilityHidden(showingPortal && !skip) }
            if showingPortal && !skip {
                GeometryReader { geo in
                    ZStack {
                        LaunchPortalScene(entering: entering, entranceStartedAt: entranceStartedAt,
                                          reduceMotion: reduceMotion).ignoresSafeArea()
                        VStack(spacing: 15) {
                            Spacer().frame(height: geo.size.height * 0.60)
                            Text("HUNTER RUN")
                                .font(.system(size: min(geo.size.width * 0.09, 42), weight: .semibold, design: .serif))
                                .tracking(4).foregroundStyle(Labyrinth.parchment)
                                .shadow(color: .black, radius: 9)
                            HStack(spacing: 12) {
                                Rectangle().frame(width: 22, height: 1)
                                Text("미궁 너머의 기록").font(.subheadline).tracking(3)
                                Rectangle().frame(width: 22, height: 1)
                            }.foregroundStyle(Labyrinth.parchment).shadow(color: .black, radius: 5, y: 2)
                            Spacer(minLength: 24)
                            Button(action: beginEntrance) {
                                VStack(spacing: 12) {
                                    Image(systemName: "diamond").font(.title3)
                                    Text(model.isReady ? "화면을 터치해 시작" : "기록 확인 후 계속하기")
                                        .font(.headline).tracking(2)
                                }.frame(maxWidth: .infinity).frame(minHeight: 90)
                            }.buttonStyle(.plain).foregroundStyle(Labyrinth.parchment)
                                .accessibilityIdentifier("title.enter")
                            // Preserve entry when catalog recovery is needed.
                            if !model.isReady {
                                Text("기록을 확인해야 해요. 계속해서 안내를 확인해주세요.")
                                    .font(.caption).multilineTextAlignment(.center)
                            }
                            Text("HUNTER RUN  ·  \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?")")
                                .font(.caption2.monospaced()).tracking(2).foregroundStyle(.white.opacity(0.5))
                        }
                        .padding(.horizontal, 24).padding(.bottom, 24)
                        .opacity(entering ? 0 : 1)
                        .animation(.easeOut(duration: 0.3), value: entering)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture(perform: beginEntrance)
                }
                .ignoresSafeArea()
                .allowsHitTesting(!entering)
            }
        }
        .background(Theme.ink.ignoresSafeArea())
        .onAppear { model.refreshLobbyMusic() }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active && entering { entered = true; showingPortal = false }
        }
    }

    private func beginEntrance() {
        guard !entering && !entered else { return }
        model.interfaceFeedback()
        guard !reduceMotion else { entered = true; showingPortal = false; return }
        entranceStartedAt = Date()
        entering = true
        DispatchQueue.main.asyncAfter(deadline: .now() + LaunchPortalScene.duration * 0.60) {
            entered = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + LaunchPortalScene.duration) { showingPortal = false }
    }
}

/// Portrait and dialogue share one stage. The lower panel scrolls independently for long choices.
struct ConversationStage<Content: View>: View {
    @Environment(\.dynamicTypeSize) private var textSize
    var artwork: String
    var expression = "calm"
    var resetKey: String
    var portraitArtwork: String?
    let content: Content
    init(artwork: String, expression: String = "calm", resetKey: String = "", portraitArtwork: String? = nil, @ViewBuilder content: () -> Content) {
        self.artwork = artwork; self.expression = expression; self.resetKey = resetKey; self.portraitArtwork = portraitArtwork; self.content = content()
    }
    var body: some View {
        GeometryReader { geo in
            let portraitHeight = max(155, geo.size.height * (textSize.isAccessibilitySize ? 0.27 : 0.46))
            ZStack(alignment: .top) {
                Image(artwork).resizable().scaledToFill().frame(width: geo.size.width, height: geo.size.height).clipped().overlay(Theme.ink.opacity(0.33)).accessibilityHidden(true)
                VStack(spacing: 0) {
                    ZStack(alignment: .top) {
                        if let portraitArtwork {
                            Image(portraitArtwork).resizable().scaledToFill()
                                .frame(width: geo.size.width, height: geo.size.width * 1.5).clipped()
                                .offset(y: -geo.size.width * 0.025)
                        } else {
                            OperatorPortrait(expression: expression).frame(width: geo.size.width, height: geo.size.width * 1.5)
                                .offset(y: -geo.size.width * 0.025)
                        }
                    }.frame(height: portraitHeight, alignment: .top).clipped().overlay(alignment: .bottom) {
                        LinearGradient(colors: [.clear, Theme.ink], startPoint: .top, endPoint: .bottom).frame(height: 45).allowsHitTesting(false)
                    }.accessibilityIdentifier("conversation.portrait")
                        // Clipping changes drawing, not SwiftUI hit testing. The full portrait
                        // extends behind the dialogue on compact screens; it is decorative here.
                        .allowsHitTesting(false)
                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(alignment: .leading, spacing: 17) {
                                Color.clear.frame(height: 1).id("reply-top")
                                content
                            }.padding(20).padding(.bottom, 16)
                        }.onChange(of: resetKey) { _, _ in proxy.scrollTo("reply-top", anchor: .top) }
                    }.background(Theme.ink.opacity(0.96))
                        .overlay(alignment: .top) { Rectangle().fill(LinearGradient(colors: [.clear, Labyrinth.gold, .clear], startPoint: .leading, endPoint: .trailing)).frame(height: 1) }
                }
            }
        }.environment(\.labyrinthStyle, true).foregroundStyle(Labyrinth.parchment).tint(Labyrinth.gold)
            .toolbarBackground(Theme.ink, for: .navigationBar).toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
    }
}

struct GameBackModifier: ViewModifier {
    @Environment(\.dismiss) private var dismiss
    func body(content: Content) -> some View {
        content.navigationBarBackButtonHidden().toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { dismiss() } label: { Image(systemName: "chevron.left") }
                    .buttonStyle(GameControlStyle()).accessibilityLabel("이전")
            }
        }
    }
}
