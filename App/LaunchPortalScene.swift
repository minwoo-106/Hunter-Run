import SwiftUI

/// 시작 연출은 실제 홈 화면 위에서 사라진다. 복제한 홈 이미지는 쓰지 않는다.
struct LaunchPortalScene: View {
    let entering: Bool
    let entranceProgress: Double
    let reduceMotion: Bool
    @Environment(\.scenePhase) private var scenePhase
    @State private var appearedAt = Date()
    static var duration: TimeInterval {
#if DEBUG && targetEnvironment(simulator)
        if ProcessInfo.processInfo.arguments.contains("--ui-testing-transition-clock") { return 10.5 }
#endif
        return 2.1
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: scenePhase != .active || (reduceMotion && !entering))) { tick in
            let elapsed = reduceMotion ? 0 : tick.date.timeIntervalSince(appearedAt)
            let progress = entering ? entranceProgress : 0
            TransitionArtwork(scene: .launch, progress: progress, elapsed: elapsed, reduced: reduceMotion)
                .opacity(1 - TransitionMath.smooth(progress, 0.68, 0.94))
        }
        .accessibilityHidden(true).allowsHitTesting(false)
    }
}
