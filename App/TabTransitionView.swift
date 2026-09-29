import SwiftUI

struct TabTransition: Identifiable {
    let id = UUID()
    let destination: Int
    let startedAt = Date()
    let spec: TabTransitionSpec
}

struct TabTransitionSpec {
    let duration: TimeInterval
    let handoff: Double
    let fadeStart: Double

    static func forTab(_ tab: Int) -> Self {
        switch tab {
        case 0: return .init(duration: 3.7, handoff: 0.78, fadeStart: 0.88)
        case 1: return .init(duration: 2.35, handoff: 0.72, fadeStart: 0.88)
        case 2: return .init(duration: 2.25, handoff: 0.70, fadeStart: 0.88)
        case 3: return .init(duration: 2.55, handoff: 0.70, fadeStart: 0.88)
        default: return .init(duration: 2.45, handoff: 0.72, fadeStart: 0.88)
        }
    }
}

/// Decorative animation only. The selected tab changes at the handoff point,
/// while this layer fades away over the already-loaded destination screen.
struct TabTransitionView: View {
    let transition: TabTransition

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30)) { context in
            let progress = TransitionMath.clamp(context.date.timeIntervalSince(transition.startedAt) / transition.spec.duration)
            GeometryReader { geometry in
                Group {
                    switch transition.destination {
                    case 0: HomeReturnTransition(progress: progress)
                    case 1: HunterRecordTransition(progress: progress)
                    case 2: HunterActivityTransition(progress: progress)
                    case 3: AssociationGateTransition(progress: progress)
                    default: CodexScrollTransition(progress: progress)
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
                .clipped()
                .opacity(TransitionMath.ramp(progress, 0, 0.07) * (1 - TransitionMath.ramp(progress, transition.spec.fadeStart, 1)))
            }
        }
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }
}

private enum TransitionMath {
    static func clamp(_ value: Double) -> Double { min(1, max(0, value)) }
    static func ramp(_ value: Double, _ start: Double, _ end: Double) -> Double {
        clamp((value - start) / max(0.001, end - start))
    }
    static func smooth(_ value: Double, _ start: Double, _ end: Double) -> Double {
        let t = ramp(value, start, end)
        return t * t * (3 - 2 * t)
    }
    static func pose(_ value: Double, _ start: Double, _ end: Double) -> Double {
        ramp(value, start, start + 0.045) * (1 - ramp(value, end - 0.04, end))
    }
}

private struct HomeReturnTransition: View {
    let progress: Double
    private let poses: [(name: String, start: Double, end: Double)] = [
        ("TransitionHomeWork", 0.07, 0.27),
        ("TransitionHomeCoffee", 0.23, 0.43),
        ("TransitionHomeBurger", 0.39, 0.61),
        ("TransitionHomeClose", 0.57, 0.77),
        ("TransitionHomeNap", 0.73, 1.0)
    ]

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                RadialGradient(colors: [Color(red: 0.10, green: 0.21, blue: 0.27), Theme.ink, .black],
                               center: .center, startRadius: 20, endRadius: geometry.size.height * 0.65)
                RadialGradient(colors: [Theme.teal.opacity(0.17), .clear], center: .center,
                               startRadius: 0, endRadius: geometry.size.width * 0.48)
                    .opacity(TransitionMath.ramp(progress, 0.08, 0.25))
                ForEach(poses.indices, id: \.self) { index in
                    let pose = poses[index]
                    Image(pose.name).resizable().scaledToFit()
                        .frame(width: geometry.size.width * 0.94, height: geometry.size.height * 0.82)
                        .scaleEffect(CGFloat(0.97 + 0.03 * TransitionMath.smooth(progress, pose.start, pose.end)))
                        .offset(y: CGFloat(8 * (1 - TransitionMath.smooth(progress, pose.start, pose.end))))
                        .opacity(TransitionMath.pose(progress, pose.start, pose.end))
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
    }
}

private struct HunterRecordTransition: View {
    let progress: Double

    var body: some View {
        GeometryReader { geometry in
            let arrival = CGFloat(TransitionMath.smooth(progress, 0.05, 0.83))
            ZStack {
                Color.black
                Image("TransitionHunterArmory").resizable().scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .scaleEffect(1.17 - 0.17 * arrival)
                    .offset(y: geometry.size.height * 0.07 * (1 - arrival))
                    .overlay(Theme.ink.opacity(0.63 - 0.16 * Double(arrival)))
                    .opacity(TransitionMath.ramp(progress, 0, 0.17))
                RadialGradient(colors: [Labyrinth.parchment.opacity(0.38), Theme.teal.opacity(0.10), .clear],
                               center: UnitPoint(x: 0.5, y: 0.08), startRadius: 5,
                               endRadius: geometry.size.height * 0.58)
                    .blendMode(.screen)
                    .opacity(TransitionMath.ramp(progress, 0.16, 0.45) * (1 - TransitionMath.ramp(progress, 0.78, 0.96)))
                Ellipse().fill(Labyrinth.gold.opacity(0.31))
                    .frame(width: geometry.size.width * 0.8, height: geometry.size.height * 0.07)
                    .blur(radius: 19).offset(y: geometry.size.height * 0.21)
                    .scaleEffect(0.55 + 0.5 * arrival)
                    .opacity(TransitionMath.pose(progress, 0.30, 0.95))
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipped()
        }
    }
}

private struct HunterActivityTransition: View {
    let progress: Double

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black
                Image("LabyrinthEntrance").resizable().scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .scaleEffect(CGFloat(1.18 - 0.18 * TransitionMath.smooth(progress, 0, 0.88)))
                    .overlay(Theme.ink.opacity(0.48))
                    .opacity(TransitionMath.ramp(progress, 0.05, 0.35))
                Circle().stroke(Labyrinth.parchment.opacity(0.85), lineWidth: 1.5)
                    .frame(width: 190, height: 190)
                    .shadow(color: Theme.teal, radius: 20)
                    .scaleEffect(CGFloat(0.3 + TransitionMath.smooth(progress, 0.14, 0.75) * 1.5))
                    .opacity(TransitionMath.pose(progress, 0.12, 0.88))
                Circle().fill(Theme.teal.opacity(0.25)).frame(width: 70, height: 70)
                    .blur(radius: 30).scaleEffect(CGFloat(1 + progress * 3))
                    .opacity(TransitionMath.pose(progress, 0.25, 0.90))
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipped()
        }
    }
}

private struct AssociationGateTransition: View {
    let progress: Double

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            let opened = CGFloat(TransitionMath.smooth(progress, 0.52, 0.86))
            let shake = CGFloat(sin(progress * 110) * 4 * TransitionMath.pose(progress, 0.24, 0.38))
            ZStack {
                Color.black
                Image("TransitionAssociationHall").resizable().scaledToFill()
                    .frame(width: width, height: height).overlay(Theme.ink.opacity(0.48))
                    .opacity(TransitionMath.ramp(progress, 0.45, 0.83))
                gateLeaf(width: width, height: height, left: true)
                    .offset(x: -width * 0.55 * opened + shake)
                gateLeaf(width: width, height: height, left: false)
                    .offset(x: width * 0.55 * opened + shake)
                RoundedRectangle(cornerRadius: 3)
                    .fill(Labyrinth.gold.gradient).frame(width: 114, height: 14)
                    .shadow(color: .black, radius: 7, y: 4)
                    .offset(x: CGFloat(-100 * TransitionMath.smooth(progress, 0.49, 0.61)))
                    .opacity(TransitionMath.pose(progress, 0.27, 0.62))
                Circle().stroke(Labyrinth.parchment, lineWidth: 2)
                    .frame(width: 104, height: 104)
                    .shadow(color: Theme.teal, radius: 17)
                    .rotationEffect(.degrees(120 * TransitionMath.smooth(progress, 0.37, 0.59)))
                    .scaleEffect(CGFloat(0.7 + 0.4 * TransitionMath.smooth(progress, 0.37, 0.58)))
                    .opacity(TransitionMath.pose(progress, 0.35, 0.63))
            }
            .frame(width: width, height: height)
            .clipped()
        }
    }

    private func gateLeaf(width: CGFloat, height: CGFloat, left: Bool) -> some View {
        Image("TransitionAssociationGate").resizable().scaledToFill()
            .frame(width: width, height: height).clipped()
            .mask {
                Rectangle().frame(width: width / 2, height: height)
                    .offset(x: left ? -width / 4 : width / 4)
            }
    }
}

private struct CodexScrollTransition: View {
    let progress: Double

    var body: some View {
        GeometryReader { geometry in
            let width = min(geometry.size.width * 0.88, geometry.size.height * 0.56)
            let height = width * 1.5
            let unfolded = CGFloat(max(0.02, TransitionMath.smooth(progress, 0.16, 0.61)))
            ZStack {
                Color(red: 0.025, green: 0.045, blue: 0.065)
                Image("TransitionCodexArchive").resizable().scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .overlay(Theme.ink.opacity(0.67))
                    .opacity(TransitionMath.ramp(progress, 0.63, 0.92))
                scrollImage(width: width, height: height)
                    .mask { Rectangle().frame(width: width, height: height * unfolded) }
                scrollImage(width: width, height: height)
                    .mask { Rectangle().frame(width: width, height: height * 0.095).offset(y: -height * 0.4525) }
                    .offset(y: height * 0.45 * (1 - unfolded))
                scrollImage(width: width, height: height)
                    .mask { Rectangle().frame(width: width, height: height * 0.095).offset(y: height * 0.4525) }
                    .offset(y: -height * 0.45 * (1 - unfolded))
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipped()
        }
    }

    private func scrollImage(width: CGFloat, height: CGFloat) -> some View {
        Image("TransitionCodexScroll").resizable().scaledToFit()
            .frame(width: width, height: height)
            .shadow(color: .black.opacity(0.65), radius: 22, y: 15)
    }
}
