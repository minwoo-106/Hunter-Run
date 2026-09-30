import SwiftUI

struct OperatorLifeRootView: View {
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    var body: some View {
        RootView()
#if DEBUG && targetEnvironment(simulator)
            .environment(\.accessibilityReduceMotion, systemReduceMotion || ProcessInfo.processInfo.arguments.contains("--life-reduce-motion"))
#endif
    }
}
