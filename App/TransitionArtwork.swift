import SwiftUI
import UIKit

/// 승인된 웹 시연의 390×844 좌표와 원화를 사용하는 네이티브 렌더러.
/// 매 프레임 이미지 파일을 읽거나 분리하지 않고 준비된 텍스처를 재사용한다.
struct TransitionArtwork: View {
    enum Scene { case launch, activity, hunter, association }
    let scene: Scene
    let progress: Double
    var elapsed: Double = 0
    var reduced = false

    var body: some View {
        Canvas { context, size in
            var c = context
            let scale = max(size.width / 390, size.height / 844)
            c.translateBy(x: (size.width - 390 * scale) / 2, y: (size.height - 844 * scale) / 2)
            c.scaleBy(x: scale, y: scale)
            let painter = TransitionPainter(context: c)
            switch scene {
            case .launch: painter.launch(progress, elapsed, reduced)
            case .activity: painter.activity(progress, elapsed)
            case .hunter: painter.hunter(progress, elapsed)
            case .association: painter.association(progress, elapsed)
            }
        }
        .accessibilityHidden(true).allowsHitTesting(false)
    }
}

private enum TransitionTextures {
    static let names = ["LaunchPortal", "TransitionAssociationGate", "TransitionHunterArmory", "TransitionHunterBadge", "FacilityBase-2"]
    static let originals: [String: UIImage] = Dictionary(uniqueKeysWithValues: names.compactMap { name in
        UIImage(named: name).map { (name, $0) }
    })
    static let portal: UIImage? = {
        guard let source = originals["LaunchPortal"] else { return nil }
        let format = UIGraphicsImageRendererFormat(); format.scale = 2
        return UIGraphicsImageRenderer(size: CGSize(width: 390, height: 844), format: format).image { _ in
            source.draw(in: cover(source.size, CGRect(x: 0, y: 0, width: 390, height: 844)))
        }
    }()
    static let left = column(left: true)
    static let right = column(left: false)
    static let light: UIImage? = {
        guard let cg = portal?.cgImage else { return nil }
        let width = cg.width, height = cg.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        return pixels.withUnsafeMutableBytes { bytes -> UIImage? in
            guard let buffer = bytes.baseAddress,
                  let c = CGContext(data: buffer, width: width, height: height, bitsPerComponent: 8,
                    bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
            c.draw(cg, in: CGRect(x: 0, y: 0, width: width, height: height))
            let p = buffer.assumingMemoryBound(to: UInt8.self)
            for i in stride(from: 0, to: width * height * 4, by: 4) {
                let cyan = Double(min(p[i+1], p[i+2])) - Double(p[i])
                let alpha = TransitionMath.clamp((cyan - 25) / 65)
                for channel in 0..<3 { p[i+channel] = UInt8(min(255, Double(p[i+channel]) * 1.9) * alpha) }
                p[i+3] = UInt8(255 * alpha)
            }
            return c.makeImage().map { UIImage(cgImage: $0, scale: 2, orientation: .up) }
        }
    }()
    static func column(left: Bool) -> UIImage? {
        guard let source = portal else { return nil }
        let format = UIGraphicsImageRendererFormat(); format.scale = 2
        return UIGraphicsImageRenderer(size: source.size, format: format).image { renderer in
            source.draw(at: .zero)
            let c = renderer.cgContext; c.setBlendMode(.destinationIn)
            let colors = left ? [UIColor.white.cgColor, UIColor.white.cgColor, UIColor.clear.cgColor, UIColor.clear.cgColor]
                              : [UIColor.clear.cgColor, UIColor.clear.cgColor, UIColor.white.cgColor, UIColor.white.cgColor]
            let positions: [CGFloat] = left ? [0, 0.1, 0.23, 1] : [0, 0.77, 0.9, 1]
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: positions) {
                c.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 390, y: 0), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
            }
        }
    }
    static func cover(_ size: CGSize, _ bounds: CGRect) -> CGRect {
        let s = max(bounds.width / size.width, bounds.height / size.height)
        return CGRect(x: bounds.midX-size.width*s/2, y: bounds.midY-size.height*s/2, width: size.width*s, height: size.height*s)
    }
}

private struct TransitionPainter {
    let context: GraphicsContext
    let bounds = CGRect(x: 0, y: 0, width: 390, height: 844)
    let center = CGPoint(x: 195, y: 254)
    func s(_ p: Double, _ a: Double, _ b: Double) -> Double { TransitionMath.smooth(p, a, b) }
    func color(_ rgb: UInt32, _ alpha: Double = 1) -> Color {
        Color(red: Double((rgb >> 16) & 255)/255, green: Double((rgb >> 8) & 255)/255, blue: Double(rgb & 255)/255).opacity(alpha)
    }
    func fill(_ c: GraphicsContext, _ rgb: UInt32, _ alpha: Double = 1, rect: CGRect? = nil) {
        c.fill(Path(rect ?? bounds), with: .color(color(rgb, alpha)))
    }
    func scaled(_ c: GraphicsContext, _ scale: Double, at point: CGPoint? = nil) -> GraphicsContext {
        let point = point ?? center
        var c = c; c.translateBy(x: point.x, y: point.y); c.scaleBy(x: scale, y: scale); c.translateBy(x: -point.x, y: -point.y); return c
    }
    func image(_ c: GraphicsContext, _ name: String, rect: CGRect? = nil) {
        guard let asset = TransitionTextures.originals[name] else { return }
        texture(c, asset, rect: rect)
    }
    func texture(_ c: GraphicsContext, _ asset: UIImage?, rect: CGRect? = nil) {
        guard let asset else { return }
        c.draw(Image(uiImage: asset), in: TransitionTextures.cover(asset.size, rect ?? bounds))
    }
    func glow(_ c: GraphicsContext, at point: CGPoint, radius: Double, rgb: UInt32, alpha: Double, stretch: Double = 1) {
        var c = c; c.translateBy(x: point.x, y: point.y); c.scaleBy(x: 1, y: stretch)
        c.fill(Path(CGRect(x: -radius, y: -radius, width: radius*2, height: radius*2)), with:
            .radialGradient(Gradient(colors: [color(rgb, alpha), .clear]), center: .zero, startRadius: 0, endRadius: radius))
    }
    func fog(_ c: GraphicsContext, _ t: Double, _ amount: Double, _ height: Double) {
        var c = c; c.blendMode = .screen
        for i in 0..<7 {
            let x = (Double(i)*123 + sin(t*0.22+Double(i))*70).truncatingRemainder(dividingBy: 580)-90
            glow(c, at: CGPoint(x: x, y: 844*height+sin(Double(i)*2+t*0.33)*45), radius: 145, rgb: 0x4c7c88, alpha: 0.18*amount, stretch: 0.34)
        }
    }
    func motes(_ c: GraphicsContext, _ t: Double, _ pull: Double, _ alpha: Double) {
        for i in 0..<44 {
            let angle = Double(i)*2.39996+t*(i.isMultiple(of: 2) ? -0.026 : 0.035)
            let radius = Double(70+(i*41)%220)*(1-0.62*pull)
            let point = CGPoint(x: 195+cos(angle)*radius, y: 254+sin(angle)*radius*1.35)
            c.fill(Path(ellipseIn: CGRect(x: point.x, y: point.y, width: 1.2, height: 1.2)), with: .color(color(0x80e3e8, alpha)))
        }
    }
    func launch(_ p: Double, _ t: Double, _ reduced: Bool) {
        let travel = reduced ? 0 : pow(TransitionMath.ramp(p, 0.14, 0.67), 2.4)
        let zoom = 1/(1-0.93*travel)-0.018*s(p,0,0.13)*(1-s(p,0.14,0.26))
        let rush = reduced ? 0 : s(p,0.32,0.56)*(1-s(p,0.59,0.69))
        fill(context, 0x040c12)
        var c = context; c.opacity = 1-s(p,0.57,0.68)
        let camera = scaled(c, zoom)
        texture(camera, TransitionTextures.portal); fill(camera, 0x01070c, 0.18)
        var light = camera; light.blendMode = .screen; light.opacity *= 0.12*s(p,0,0.22)+rush*0.22
        texture(light, TransitionTextures.light)
        if rush > 0 {
            var blur = c
            var mask = Path(bounds); mask.addEllipse(in: CGRect(x:131,y:164,width:128,height:180))
            blur.clip(to: mask, style: FillStyle(eoFill: true)); blur.blendMode = .screen
            for i in 1...4 {
                var trail = scaled(blur, zoom*(1+Double(i)*0.021*rush)); trail.opacity *= 0.04*rush*(1-Double(i)*0.12)
                texture(trail, TransitionTextures.portal)
            }
        }
        if travel > 0 {
            for left in [true,false] {
                var column = c; column.opacity *= 0.6; column.translateBy(x:(left ? -1 : 1)*travel*40,y:0)
                texture(scaled(column,zoom+travel*0.35),left ? TransitionTextures.left : TransitionTextures.right)
            }
        }
        fog(c,reduced ? 0 : t,0.7*(1-s(p,0.18,0.48)),0.65)
        if !reduced { motes(c,t,s(p,0.1,0.46),0.28*(1-s(p,0.3,0.49))) }
        glow(c,at:center,radius:62+travel*110,rgb:0x69d3d3,alpha:rush*0.21)
        let pulse = reduced ? 0 : s(p,0.54,0.64)*(1-s(p,0.66,0.77))
        let veil = s(p,0.52,0.66)*(1-s(p,0.72,0.94))
        glow(context,at:center,radius:150+pulse*160,rgb:0x66bfc9,alpha:pulse*0.26,stretch:1.35)
        glow(context,at:CGPoint(x:195,y:371),radius:330,rgb:0x203944,alpha:veil*0.28,stretch:1.5)
        fog(context,reduced ? 0 : t,veil*0.45,0.58)
    }
    func activity(_ p: Double, _ t: Double) {
        image(context,"LaunchPortal"); fill(context,0x01070c,0.54*(1-s(p,0.02,0.78)))
        for i in 0..<16 {
            let on = s(p,0.07+Double(i)*0.026,0.18+Double(i)*0.026)
            var c = context; c.opacity = on*0.55; c.blendMode = .screen
            var sector = Path(); sector.move(to:center)
            sector.addArc(center:center,radius:83,startAngle:.radians(Double(i)*Double.pi/8-0.1),endAngle:.radians(Double(i+1)*Double.pi/8+0.03),clockwise:false)
            sector.closeSubpath(); c.clip(to:sector)
            var ring = Path(ellipseIn:CGRect(x:117,y:171,width:156,height:166))
            ring.addEllipse(in:CGRect(x:139,y:193,width:112,height:122)); c.clip(to:ring,style:FillStyle(eoFill:true))
            texture(c,TransitionTextures.light)
        }
        glow(context,at:center,radius:65,rgb:0x238d9a,alpha:s(p,0.4,0.73)*0.33)
        fog(context,t,0.8,0.65); motes(context,t,s(p,0.18,0.83),0.22)
    }
    func hunter(_ p: Double, _ t: Double) {
        let c = scaled(context,1.055-0.055*s(p,0.1,0.88),at:CGPoint(x:195,y:355))
        image(c,"TransitionHunterArmory"); fill(c,0x00060c,0.7*(1-s(p,0.33,0.84)))
        for item in [(60.0,160.0,100.0,435.0,0.32),(330,200,99,380,0.43),(197,400,110,130,0.61)] {
            var lit = c; lit.opacity = s(p,item.4,item.4+0.19)*0.65
            lit.clip(to:Path(CGRect(x:item.0-item.2/2,y:item.1,width:item.2,height:item.3)))
            image(lit,"TransitionHunterArmory")
            glow(c,at:CGPoint(x:item.0,y:item.1+10),radius:70,rgb:0xdcc396,alpha:s(p,item.4,item.4+0.19)*0.13,stretch:2.5)
        }
        if p < 0.66 {
            let move = s(p,0.26,0.65), size = 58-32*s(p,0.23,0.65)
            var badge = context; badge.opacity = s(p,0.02,0.11)*(1-s(p,0.35,0.65))
            badge.translateBy(x:195-130*move,y:345-140*move); badge.rotate(by:.radians(-0.045))
            image(badge,"TransitionHunterBadge",rect:CGRect(x:-size*0.76,y:-size*1.3,width:size*1.52,height:size*2.6))
        }
        var record = context; record.opacity = s(p,0.59,0.79)
        var panel = Path(); panel.addLines([CGPoint(x:157,y:415),CGPoint(x:230,y:415),CGPoint(x:241,y:459),CGPoint(x:146,y:459)]); panel.closeSubpath()
        record.fill(panel,with:.color(color(0x08181d,0.9))); record.stroke(panel,with:.color(color(0xaa9774,0.37)),lineWidth:1)
        for i in 0..<4 {
            var line = Path(); line.move(to:CGPoint(x:164-i*2,y:426+i*7)); line.addLine(to:CGPoint(x:219+i*2,y:426+i*7))
            record.stroke(line,with:.color(color(0x5ccaba,0.52-Double(i)*0.07)),lineWidth:1)
        }
        fog(context,t,0.18,0.81)
    }
    func association(_ p: Double, _ t: Double) {
        let u = s(p,0.34,0.87)
        let open = u < 0.5 ? 4*u*u*u : 1-pow(-2*u+2,3)/2
        image(context,"FacilityBase-2"); fill(context,0x030a10,0.25)
        if open < 1 {
            var inside = context; inside.clip(to:Path(CGRect(x:32,y:67,width:326,height:753)))
            for left in [true,false] {
                var leaf = inside; leaf.translateBy(x:(left ? -1 : 1)*191*open,y:0)
                leaf.clip(to:Path(CGRect(x:left ? 0 : 195,y:0,width:195,height:844)))
                image(leaf,"TransitionAssociationGate",rect:CGRect(x:20,y:44,width:350,height:786))
                fill(leaf,0x00050a,0.12+open*0.18)
            }
            let glowValue = s(p,0.22,0.37)*(1-open)
            glow(inside,at:CGPoint(x:195,y:447),radius:74,rgb:0x76dfd3,alpha:glowValue*0.23)
            if open < 0.015 { fill(inside,0x68e5d6,glowValue*0.8*(1-open/0.015),rect:CGRect(x:194,y:75,width:2,height:744)) }
            var frame = context; frame.opacity = 1-s(p,0.84,0.97)
            for x in [0.0,356.0] {
                frame.fill(Path(CGRect(x:x,y:0,width:34,height:844)),with:.linearGradient(Gradient(colors:[color(0x334044),color(0x111d22),color(0x766849),color(0x03080b)]),startPoint:CGPoint(x:x,y:0),endPoint:CGPoint(x:x+34,y:0)))
                for j in 0..<8 { fill(frame,0x7c714c,0.33,rect:CGRect(x:x+10,y:Double(70+j*104),width:14,height:3)) }
            }
            fill(frame,0x111d22,rect:CGRect(x:0,y:0,width:390,height:68)); fill(frame,0x665740,0.65,rect:CGRect(x:0,y:65,width:390,height:3))
            for x in [35.0,337.0] {
                var lock = context; lock.opacity = 1-open
                fill(lock,0x080e13,rect:CGRect(x:x,y:340,width:18,height:70))
                fill(lock,0xb6a07a,rect:CGRect(x:x+3,y:351+s(p,0.12,0.28)*19,width:12,height:29))
                fill(lock,p > 0.27 ? 0x67dbc9 : 0xb38b51,rect:CGRect(x:x+5,y:346,width:8,height:2))
            }
        }
        fog(context,t,0.24*(1-open),0.85)
    }
}

#if DEBUG && targetEnvironment(simulator)
/// 동일 렌더러를 고정 시점에 표시해 두 크기에서 중간 장면을 보존한다.
struct TransitionFrameCheckView: View {
    private let args = ProcessInfo.processInfo.arguments
    private var values: (TransitionArtwork.Scene, Double) {
        let index = args.firstIndex(of: "--ui-testing-transition-frame") ?? 0
        let key = args.count > index+1 ? args[index+1] : "launch"
        let scene: TransitionArtwork.Scene = key == "association" ? .association : key == "hunter" ? .hunter : key == "activity" ? .activity : .launch
        let p = args.count > index+2 ? Double(args[index+2]) ?? 0.5 : 0.5
        return (scene, p)
    }
    var body: some View {
        ZStack(alignment: .bottom) {
            TransitionArtwork(scene: values.0, progress: values.1, elapsed: 1.2).ignoresSafeArea()
            Text("전환 화면 검증").font(.caption2).accessibilityIdentifier("transition.frame").padding(8)
        }
    }
}
#endif
