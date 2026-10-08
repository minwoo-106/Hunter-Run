import SwiftUI

/// 시작 연출은 실제 홈 화면 위에서 사라진다. 복제한 홈 이미지는 쓰지 않는다.
struct LaunchPortalScene: View {
    let entering: Bool
    let entranceStartedAt: Date?
    let reduceMotion: Bool
    @Environment(\.scenePhase) private var scenePhase
    @State private var appearedAt = Date()
    static let duration: TimeInterval = 2.1

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: scenePhase != .active || (reduceMotion && !entering))) { tick in
            let elapsed = reduceMotion ? 0 : tick.date.timeIntervalSince(appearedAt)
            let progress = entering ? entranceStartedAt.map {
                TransitionMath.clamp(tick.date.timeIntervalSince($0) / Self.duration)
            } ?? 0 : 0
            TransitionArtwork(scene: .launch, progress: progress, elapsed: elapsed, reduced: reduceMotion)
                .opacity(1 - TransitionMath.smooth(progress, 0.68, 0.94))
        }
        .accessibilityHidden(true).allowsHitTesting(false)
    }
}
