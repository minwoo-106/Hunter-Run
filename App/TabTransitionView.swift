import SwiftUI

struct TabTransition: Identifiable {
    let id = UUID()
    let destination: Int
    var clock: PresentationClock
    let spec: TabTransitionSpec
    init(destination: Int, spec: TabTransitionSpec) {
        self.destination = destination
        var multiplier = 1.0
#if DEBUG && targetEnvironment(simulator)
        if ProcessInfo.processInfo.arguments.contains("--ui-testing-transition-clock") { multiplier = 5 }
#endif
        self.spec = TabTransitionSpec(duration: spec.duration * multiplier, handoff: spec.handoff, fadeStart: spec.fadeStart)
        clock = PresentationClock(duration: self.spec.duration, handoff: spec.handoff,
                                  at: ProcessInfo.processInfo.systemUptime)
    }
}

struct TabTransitionSpec {
    let duration: TimeInterval
    let handoff: Double
    let fadeStart: Double

    static func forTab(_ tab: Int) -> Self {
        switch tab {
        case 0: return .init(duration: 3.7, handoff: 0.78, fadeStart: 0.88)
        case 1: return .init(duration: 2.4, handoff: 0.72, fadeStart: 0.88)
        case 2: return .init(duration: 2.3, handoff: 0.70, fadeStart: 0.88)
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
        let progress = transition.clock.progress
        GeometryReader { geometry in
                Group {
                    switch transition.destination {
                    case 0: HomeReturnTransition(progress: progress)
                    case 1: TransitionArtwork(scene: .hunter, progress: progress, elapsed: transition.clock.elapsed)
                    case 2: TransitionArtwork(scene: .activity, progress: progress, elapsed: transition.clock.elapsed)
                    case 3: TransitionArtwork(scene: .association, progress: progress, elapsed: transition.clock.elapsed)
                    default: CodexScrollTransition(progress: progress)
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
                .clipped()
                .opacity(TransitionMath.ramp(progress, 0, 0.07) * (1 - TransitionMath.ramp(progress, transition.spec.fadeStart, 1)))
        }
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }
}

enum TransitionMath {
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
