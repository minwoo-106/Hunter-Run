import SwiftUI

// SwiftUI's system Reduce Motion value is read-only. The simulator fixture uses
// a separate override and never writes/replaces the real accessibility setting.
private struct OperatorLifeReduceMotionOverride: EnvironmentKey {
    static let defaultValue = false
}
extension EnvironmentValues {
    var operatorLifeReduceMotionOverride: Bool {
        get { self[OperatorLifeReduceMotionOverride.self] }
        set { self[OperatorLifeReduceMotionOverride.self] = newValue }
    }
}
struct OperatorLifeRootView: View {
    var body: some View {
        RootView()
#if DEBUG && targetEnvironment(simulator)
            .environment(\.operatorLifeReduceMotionOverride, ProcessInfo.processInfo.arguments.contains("--life-reduce-motion"))
#endif
    }
}
