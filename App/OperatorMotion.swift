import SwiftUI

/// A single coherent portrait surface: breathing deformation is applied AFTER
/// the eyelid overlay so the face and blink cannot drift apart while breathing.
struct OperatorPortrait: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("operatorMotionEnabled") private var motionEnabled = true
    @State private var origin = Date()
    var active = true
    var expression = "calm"
    private var animate: Bool { active && scenePhase == .active && motionEnabled && !reduceMotion }
    var body: some View {
        GeometryReader { geometry in
            let width = min(geometry.size.width, geometry.size.height * 2 / 3)
            let height = width * 1.5
            TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !animate)) { context in
                let time = animate ? context.date.timeIntervalSince(origin) : 0
                ZStack {
                    Image("OperatorCutout").resizable().scaledToFit()
                    if ["smile", "playful", "thoughtful", "worried", "relieved"].contains(expression) {
                        Image("Operator-" + expression).resizable().scaledToFit()
                            .mask(OperatorFace().fill(.white).blur(radius: width * 0.006))
                    }
                    Image("OperatorBlink").resizable().scaledToFit()
                        .mask(OperatorEyelids().fill(.white).blur(radius: width * 0.005))
                        .opacity(blink(time))
                }
                .frame(width: width, height: height)
                .drawingGroup()
                .distortionEffect(ShaderLibrary.operatorBreath(.float(Float(time)), .float2(Float(width), Float(height))),
                                  maxSampleOffset: CGSize(width: 4, height: 4), isEnabled: animate)
                .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
            }
        }.accessibilityHidden(true).allowsHitTesting(false)
    }
    private func blink(_ time: Double) -> Double {
        // Unequal intervals feel less mechanical; total closed time stays short.
        let phase = time.truncatingRemainder(dividingBy: 17)
        for point in [3.8, 9.2, 14.6, 15.0] {
            let elapsed = phase - point
            if (0...0.18).contains(elapsed) {
                return elapsed < 0.055 ? elapsed / 0.055 : elapsed < 0.095 ? 1 : max(0, (0.18 - elapsed) / 0.085)
            }
        }
        return 0
    }
}

private struct OperatorFace: Shape {
    func path(in rect: CGRect) -> Path {
        Path(ellipseIn: CGRect(x: rect.width * 0.394, y: rect.height * 0.102,
                              width: rect.width * 0.22, height: rect.height * 0.157))
    }
}

private struct OperatorEyelids: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        // Only the generated eyelids are composited. Its background/pose are not used.
        path.addEllipse(in: CGRect(x: rect.width * 0.393, y: rect.height * 0.159,
                                   width: rect.width * 0.081, height: rect.height * 0.036))
        path.addEllipse(in: CGRect(x: rect.width * 0.495, y: rect.height * 0.136,
                                   width: rect.width * 0.081, height: rect.height * 0.036))
        return path
    }
}
