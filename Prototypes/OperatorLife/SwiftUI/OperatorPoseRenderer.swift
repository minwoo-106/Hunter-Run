import SwiftUI

// Raster pose transitions + small screen-space movement, NOT Live2D or skeletal rigging.
struct OperatorPoseRenderer: OperatorLifeRendering {
    let frame: LifeRenderFrame
    let animating: Bool
    var body: some View {
        GeometryReader { geo in
            let width = min(geo.size.width, geo.size.height * 2 / 3)
            let height = width * 1.5
            let dozeBlend = frame.phase == .dozing ? (frame.reducedMotion ? 1 : smooth((frame.dozeProgress - 0.52) / 0.48)) : 0
            ZStack {
                Image("OperatorCutout").resizable().scaledToFit().opacity(baseOpacity)
                if frame.phase == .stretching {
                    Image("OperatorLifeStretch").resizable().scaledToFit()
                        .opacity(smooth(min(frame.elapsed / 0.3, max(0, (1 - frame.progress) / 0.16))))
                }
                if frame.phase == .dozing {
                    Image("OperatorLifeDoze").resizable().scaledToFit().opacity(dozeBlend)
                }
                if frame.phase == .surprised { Image("OperatorLifeSurprised").resizable().scaledToFit() }
                if frame.phase == .embarrassed { Image("OperatorLifeEmbarrassed").resizable().scaledToFit().opacity(embarrassedWeight) }
                // Original closed eyelids are used only while aligned to the original pose.
                Image("OperatorBlink").resizable().scaledToFit()
                    .mask(LifeEyelids().fill(.white).blur(radius: width * 0.005))
                    .opacity(eyeClosure * (1 - dozeBlend))
            }
            .frame(width: width, height: height)
            .drawingGroup()
            .distortionEffect(ShaderLibrary.operatorBreath(.float(Float(frame.activeTime)), .float2(Float(width), Float(height))),
                              maxSampleOffset: CGSize(width: 4, height: 4), isEnabled: animating && frame.phase != .surprised)
            .rotationEffect(.degrees(rotation), anchor: UnitPoint(x: 0.5, y: 0.7))
            .offset(x: animating && frame.phase == .idle ? sin(frame.activeTime / 6.1) * 1.2 : 0,
                    y: animating && frame.phase == .dozing ? 2.5 * frame.dozeProgress + max(0, sin(frame.elapsed * 1.35)) * 2.0 : 0)
            .position(x: geo.size.width / 2, y: geo.size.height / 2)
        }.clipped() // same portrait canvas; no scaling beyond the home background
    }
    private var embarrassedWeight: Double { frame.reducedMotion ? 1 : smooth((1 - frame.progress) / 0.09) }
    private var baseOpacity: Double {
        switch frame.phase {
        case .idle: return 1
        case .stretching: return 1 - smooth(min(frame.elapsed / 0.3, max(0, (1 - frame.progress) / 0.16)))
        case .dozing: return frame.reducedMotion ? 0 : 1 - smooth((frame.dozeProgress - 0.52) / 0.48)
        case .surprised: return 0
        case .embarrassed: return 1 - embarrassedWeight
        }
    }
    private var eyeClosure: Double {
        if frame.phase == .dozing { return smooth(frame.dozeProgress / 0.65) }
        guard animating, frame.phase == .idle || frame.phase == .stretching else { return 0 }
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
        path.addEllipse(in: CGRect(x: rect.width * 0.393, y: rect.height * 0.159, width: rect.width * 0.081, height: rect.height * 0.036))
        path.addEllipse(in: CGRect(x: rect.width * 0.495, y: rect.height * 0.136, width: rect.width * 0.081, height: rect.height * 0.036))
        return path
    }
}
