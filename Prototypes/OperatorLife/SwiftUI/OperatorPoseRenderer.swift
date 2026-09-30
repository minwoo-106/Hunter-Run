import SwiftUI

// Approved whole-body key poses, NOT Live2D or continuous joint animation.
struct OperatorPoseRenderer: OperatorLifeRendering {
    let frame: LifeRenderFrame
    let animating: Bool
    var body: some View {
        GeometryReader { geo in
            // Reserve real overhead room instead of clipping the raised hands.
            let width = min(geo.size.width * 0.90, geo.size.height * 0.61)
            let height = width * 1.5
            let raisedTop = max(92, geo.size.height * 0.14)
            let restTop = raisedTop + height * 0.19
            let dozeBlend = frame.phase == .dozing ? (frame.reducedMotion ? 1 : smooth((frame.dozeProgress - 0.35) / 0.65)) : 0
            ZStack(alignment: .topLeading) {
                portrait("OperatorLifeIdle", width, height, restTop, baseOpacity)
                if frame.phase == .stretching {
                    portrait("OperatorLifeStretch", width, height, raisedTop, stretchWeight)
                }
                if frame.phase == .dozing {
                    portrait("OperatorLifeDoze", width, height, restTop, dozeBlend)
                }
                if frame.phase == .surprised {
                    portrait("OperatorLifeSurprised", width, height, restTop, 1)
                }
                if frame.phase == .embarrassed {
                    portrait("OperatorLifeEmbarrassed", width, height, restTop, embarrassedWeight)
                }
                // The new blink drawing matches the new idle face. Never use
                // the old pocket-pose eyelids on this new body/head position.
                Image("OperatorLifeBlink").resizable().scaledToFit()
                    .frame(width: width, height: height)
                    .mask(LifeEyelids().fill(.white).blur(radius: width * 0.004))
                    .opacity(eyeClosure * baseOpacity)
                    .position(x: geo.size.width / 2, y: restTop + height / 2)
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .drawingGroup()
            .distortionEffect(ShaderLibrary.operatorBreath(.float(Float(frame.activeTime)), .float2(Float(geo.size.width), Float(geo.size.height))),
                              maxSampleOffset: CGSize(width: 4, height: 4), isEnabled: animating && frame.phase != .surprised)
            .rotationEffect(.degrees(rotation), anchor: UnitPoint(x: 0.5, y: 0.7))
            .offset(x: animating && frame.phase == .idle ? sin(frame.activeTime / 6.1) * 1.2 : 0,
                    y: animating && frame.phase == .dozing ? 2.5 * frame.dozeProgress + max(0, sin(frame.elapsed * 1.35)) * 2.0 : 0)
        }.clipped()
    }
    private func portrait(_ name: String, _ width: Double, _ height: Double, _ top: Double, _ opacity: Double) -> some View {
        GeometryReader { geo in
            Image(name).resizable().scaledToFit().frame(width: width, height: height)
                .opacity(opacity).position(x: geo.size.width / 2, y: top + height / 2)
        }
    }
    private var stretchWeight: Double {
        frame.reducedMotion ? 1 : smooth(min(frame.elapsed / 0.28, max(0, (1 - frame.progress) / 0.20)))
    }
    private var embarrassedWeight: Double { frame.reducedMotion ? 1 : smooth((1 - frame.progress) / 0.09) }
    private var baseOpacity: Double {
        switch frame.phase {
        case .idle: return 1
        case .stretching: return 1 - stretchWeight
        case .dozing: return frame.reducedMotion ? 0 : 1 - smooth((frame.dozeProgress - 0.35) / 0.65)
        case .surprised: return 0
        case .embarrassed: return 1 - embarrassedWeight
        }
    }
    private var eyeClosure: Double {
        if frame.phase == .dozing { return smooth(frame.dozeProgress / 0.55) }
        guard animating, frame.phase == .idle else { return 0 }
        let phase = frame.activeTime.truncatingRemainder(dividingBy: 17)
        for point in [3.8, 9.2, 14.6, 15.0] {
            let elapsed = phase - point
            if (0...0.18).contains(elapsed) { return elapsed < 0.055 ? elapsed / 0.055 : elapsed < 0.095 ? 1 : max(0, (0.18 - elapsed) / 0.085) }
        }
        return 0
    }
    private var rotation: Double {
        guard animating else { return 0 }
        switch frame.phase {
        case .stretching: return sin(frame.progress * .pi) * -0.8
        case .idle: return sin(frame.activeTime / 4.2) * 0.38
        case .dozing: return frame.dozeProgress * (0.5 + max(0, sin(frame.elapsed * 1.35)) * 0.65)
        case .surprised: return 0
        case .embarrassed: return sin(frame.progress * .pi) * -0.45
        }
    }
    private func smooth(_ value: Double) -> Double { let x = min(1, max(0, value)); return x * x * (3 - 2 * x) }
}
private struct LifeEyelids: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addEllipse(in: CGRect(x: rect.width * 0.38, y: rect.height * 0.155, width: rect.width * 0.10, height: rect.height * 0.039))
        path.addEllipse(in: CGRect(x: rect.width * 0.505, y: rect.height * 0.139, width: rect.width * 0.10, height: rect.height * 0.039))
        return path
    }
}
