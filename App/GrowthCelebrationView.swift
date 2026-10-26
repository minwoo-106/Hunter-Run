import SwiftUI

struct GrowthCelebration: Identifiable {
    let id = UUID()
    var rank: String? = nil
    var equipmentID: String? = nil
    var unlocks: [UnlockNotice] = []
}
enum RankVisual {
    static func duration(_ rank: String) -> Double { ["D": 4.2, "C": 3.9, "B": 5.2, "A": 5.4, "S": 5.6][rank] ?? 4 }
    static func name(_ rank: String) -> String { ["D": "청동의 서약", "C": "은빛 첨탑", "B": "공명 코어", "A": "자수정의 관", "S": "여명의 왕관"][rank] ?? "협회 기본 인장" }
    static func color(_ rank: String) -> Color {
        switch rank { case "D": return Color(red: 0.84, green: 0.63, blue: 0.42); case "C": return Color(red: 0.77, green: 0.89, blue: 0.96)
        case "A": return Color(red: 0.74, green: 0.60, blue: 0.93); case "S": return Color(red: 0.93, green: 0.77, blue: 0.49); default: return Theme.teal }
    }
}

struct GrowthCelebrationView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    let celebration: GrowthCelebration
    @State private var clock: PresentationClock?
    @State private var showUnlocks = false
    private var progress: Double { reduceMotion ? 1 : clock?.progress ?? 0 }
    var body: some View {
        ZStack {
            Theme.ink.ignoresSafeArea()
            RadialGradient(colors: [RankVisual.color(celebration.rank ?? "B").opacity(0.13), .clear], center: .center, startRadius: 10, endRadius: 360).ignoresSafeArea()
            ScrollView {
                VStack(spacing: 14) {
                    eyebrow(celebration.rank == nil ? "EQUIPMENT ACQUIRED" : "HUNTER LICENSE")
                    Text(celebration.rank == nil ? "새로운 장비 확보" : "협회 승급 심사 통과").font(.headline).tracking(3)
                    if let rank = celebration.rank {
                        RankMotionCanvas(rank: rank, progress: progress).aspectRatio(390 / 420, contentMode: .fit)
                            .frame(maxWidth: 390).accessibilityLabel(rank + "급 " + RankVisual.name(rank))
                        VStack(spacing: 12) {
                            Text(RankVisual.name(rank)).foregroundStyle(RankVisual.color(rank))
                            Text(rank + "급 헌터").font(.system(size: 40, weight: .bold, design: .serif))
                            Text(rank == "S" ? "여기까지, 정말 수고하셨어요." : "새로운 등급으로 등록되었습니다.")
                        }.opacity(progress >= 0.79 ? min(1, (progress - 0.79) / 0.15) : 0)
                    } else if let id = celebration.equipmentID, let item = model.progressionCatalog?.equipment.first(where: { $0.id == id }) {
                        GearArtwork(item: item, size: 260).scaleEffect(0.86 + min(1, progress / 0.65) * 0.14)
                            .opacity(min(1, progress * 3)).padding(.vertical, 32)
                        Text(item.name).font(.largeTitle.bold())
                        Text(item.stageName).foregroundStyle(Theme.teal)
                        Text("장비 보관함에 기록했어요. 장착하면 다음 활동부터 적용됩니다.").foregroundStyle(Theme.muted)
                    }
                    if progress >= 1 {
                        if let id = celebration.equipmentID {
                            Button("바로 장착") { model.equip(id); if model.notice == nil { model.growthCelebration = nil } }
                                .buttonStyle(GameButtonStyle(primary: true)).disabled(model.growthLocked)
                        }
                        if !celebration.unlocks.isEmpty {
                            Button(showUnlocks ? "해금 목록 접기" : "새로 열린 콘텐츠 \(celebration.unlocks.count)개 보기") { showUnlocks.toggle() }
                                .buttonStyle(GameButtonStyle()).accessibilityIdentifier("growth.unlocks")
                            if showUnlocks { UnlockListView(entries: celebration.unlocks) }
                        } else if celebration.rank != nil {
                            Text("추가 콘텐츠는 의뢰·스토리·시설 조건도 함께 확인해요.").font(.caption).foregroundStyle(Theme.muted)
                        }
                        Button("확인") { model.growthCelebration = nil }.buttonStyle(GameButtonStyle(primary: celebration.equipmentID == nil))
                            .accessibilityIdentifier("growth.celebration.close")
                    }
                }.padding(22)
            }
        }.environment(\.labyrinthStyle, true).interactiveDismissDisabled()
            .onChange(of: scenePhase) { _, phase in clock?.setActive(phase == .active, at: ProcessInfo.processInfo.systemUptime) }
            .task {
                guard !reduceMotion else { return }
                clock = PresentationClock(duration: celebration.rank.map(RankVisual.duration) ?? 1.1, handoff: 1, at: ProcessInfo.processInfo.systemUptime)
                if scenePhase != .active { clock?.setActive(false, at: ProcessInfo.processInfo.systemUptime) }
                while !Task.isCancelled, clock?.complete == false {
                    do { try await Task.sleep(for: .milliseconds(33)) } catch { return }
                    if scenePhase == .active { clock?.advance(to: ProcessInfo.processInfo.systemUptime) }
                }
            }
    }
}

/// 승인한 HTML의 좌표계(390×420)와 등급별 시간표를 사용하는 네이티브 Canvas.
struct RankMotionCanvas: View {
    let rank: String
    let progress: Double
    private func q(_ t: Double, _ a: Double, _ b: Double) -> Double { min(1, max(0, (t - a) / (b - a))) }
    private func smooth(_ x: Double) -> Double { x * x * (3 - 2 * x) }
    private func out(_ x: Double) -> Double { 1 - pow(1 - x, 3) }
    private var color: Color { RankVisual.color(rank) }
    var body: some View {
        Canvas { context, size in
            var c = context; c.scaleBy(x: size.width / 390, y: size.height / 420)
            let image = c.resolve(Image("Rank-" + rank))
            if progress >= 1 { c.draw(image, in: CGRect(x: 35, y: 50, width: 320, height: 320)); return }
            switch rank {
            case "D", "C": metals(c, image, progress)
            case "B": resonance(c, image, progress)
            case "A": amethyst(c, image, progress)
            default: sovereign(c, image, progress)
            }
        }.allowsHitTesting(false)
    }
    private func path(_ points: [[Double]]) -> Path {
        Path { p in guard let first = points.first else { return }; p.move(to: CGPoint(x: first[0], y: first[1])); for point in points.dropFirst() { p.addLine(to: CGPoint(x: point[0], y: point[1])) }; p.closeSubpath() }
    }
    private func full(_ context: GraphicsContext, _ image: GraphicsContext.ResolvedImage, _ alpha: Double = 1, _ scale: Double = 1) {
        var c = context; c.opacity = min(1, max(0, alpha)); c.translateBy(x: 195, y: 210); c.scaleBy(x: scale, y: scale)
        c.draw(image, in: CGRect(x: -160, y: -160, width: 320, height: 320))
    }
    private func glow(_ context: GraphicsContext, _ x: Double, _ y: Double, _ radius: Double, _ alpha: Double) {
        guard radius > 0, alpha > 0 else { return }
        var c = context; c.opacity = min(1, alpha)
        c.fill(Path(ellipseIn: CGRect(x: x-radius, y: y-radius, width: radius*2, height: radius*2)), with: .radialGradient(Gradient(colors: [color, color.opacity(0)]), center: CGPoint(x: x,y: y), startRadius: 0,endRadius: radius))
    }
    private func diamond(_ context: GraphicsContext, _ x: Double, _ y: Double, _ size: Double, _ angle: Double, _ alpha: Double) {
        var c = context; c.opacity = max(0,min(1,alpha)); c.translateBy(x: x,y: y); c.rotate(by: .radians(angle))
        c.fill(path([[0,-size],[size*0.47,0],[0,size],[-size*0.47,0]]), with: .color(color))
    }
    private func part(_ context: GraphicsContext, _ image: GraphicsContext.ResolvedImage, _ shape: [[Double]], _ x: Double, _ y: Double, _ angle: Double, _ alpha: Double) {
        var c = context; c.opacity = max(0,min(1,alpha)); c.translateBy(x: 195+x,y: 210+y); c.rotate(by: .radians(angle)); c.translateBy(x: -195,y: -210)
        c.clip(to: path(shape.map { [35+$0[0]*320,50+$0[1]*320] })); c.draw(image,in: CGRect(x:35,y:50,width:320,height:320))
    }
    private func metals(_ c: GraphicsContext, _ image: GraphicsContext.ResolvedImage, _ t: Double) {
        let pieces = rank == "D" ? RankParts.bronze : RankParts.silver
        for (i,piece) in pieces.enumerated() {
            let start = rank == "D" ? 0.08+Double(i)*0.055 : 0.065+Double(i)*0.082
            let end = rank == "D" ? 0.42+Double(i)*0.05 : start+0.055
            let v = q(t,start,end), move = rank == "D" ? smooth(v) : out(v)
            part(c,image,piece.points,piece.x*(1-move),piece.y*(1-move),piece.angle*(1-move),rank == "D" ? q(v,0,0.3) : v > 0 ? 1 : 0)
            if rank == "C", t >= end && t < end+0.07 {
                let impact = q(t,end,end+0.07), x = 195+Double(i%3-1)*65, y = 150+Double(i%3)*55
                glow(c,x,y,54,(1-impact)*0.65)
                for k in 0..<9 { let a = Double(k)*0.72+Double(i), r = impact*Double(30+k*5); diamond(c,x+cos(a)*r,y+sin(a)*r,3,a,1-impact) }
            }
        }
        full(c,image,q(t,rank == "D" ? 0.63 : 0.55,rank == "D" ? 0.75 : 0.64))
        if rank == "D" {
            for i in 0..<23 { let v=q(t,0.03+Double(i%7)*0.018,0.58+Double(i%5)*0.025), x=Double(68+(i*83)%257), y=Double(360+(i*13)%35); diamond(c,x+(195-x)*smooth(v),y-(y-220)*smooth(v),2,v*2,sin(v * .pi)*0.65) }
        } else {
            var sheen=c; sheen.opacity=sin(q(t,0.65,0.88) * .pi)*0.22; sheen.blendMode = .screen
            let x=q(t,0.65,0.88)*520-120
            sheen.clip(to: Path(CGRect(x:x,y:50,width:30,height:320))); sheen.addFilter(.colorMultiply(.white)); full(sheen,image,0.5)
        }
    }
    private func resonance(_ c: GraphicsContext, _ image: GraphicsContext.ResolvedImage, _ t: Double) {
        glow(c,195,210,85,0.24+sin(t*20)*0.08)
        for i in 0..<28 {
            let v=q(t,0.015+Double(i%5)*0.012,0.59+Double(i%7)*0.019), a=Double(i)*2.399+v*(7.5+Double(i%4)*1.1), r=Double(128+(i%5)*12)*(1-pow(v,2.8))
            diamond(c,195+cos(a)*r,210+sin(a)*r*0.7,Double(3+i%4),a+0.5,sin(min(1,v*4) * .pi*0.5)*(1-q(v,0.86,1)))
        }
        let r=out(q(t,0.48,0.76))*260
        var clipped=c; clipped.clip(to: Path(ellipseIn:CGRect(x:195-r,y:210-r,width:r*2,height:r*2))); full(clipped,image)
        glow(c,195,210,100,sin(q(t,0.48,0.78) * .pi)*0.7)
    }
    private func amethyst(_ c: GraphicsContext, _ image: GraphicsContext.ResolvedImage, _ t: Double) {
        let tip=355-smooth(q(t,0.12,0.67))*310
        var clipped=c; clipped.clip(to:Path(CGRect(x:65,y:tip,width:260,height:420-tip)))
        clipped.clip(to:path([[96,71],[144,71],[144,155],[96,155]]),options:.inverse)
        clipped.clip(to:path([[246,71],[294,71],[294,155],[246,155]]),options:.inverse); full(clipped,image)
        let branches=[[[195.0,355],[195,245],[156,175],[195,58]],[[195.0,300],[131,260],[87,176]],[[195.0,300],[259,260],[303,176]]]
        for (i,points) in branches.enumerated() {
            let v=q(t,0.035+Double(i)*0.04,0.43+Double(i)*0.04)
            var line=Path(); line.move(to:CGPoint(x:points[0][0],y:points[0][1]))
            for j in 1..<points.count { let f=min(1,max(0,v*Double(points.count-1)-Double(j-1))); line.addLine(to:CGPoint(x:points[j-1][0]+(points[j][0]-points[j-1][0])*f,y:points[j-1][1]+(points[j][1]-points[j-1][1])*f)) }
            var ray=c; ray.opacity=(1-q(t,0.57,0.75))*0.9; ray.stroke(line,with:.color(color),lineWidth:1.2)
        }
        for side in [-1.0,1.0] { let v=q(t,0.5+(side==1 ? 0.07 : 0),0.76+(side==1 ? 0.07 : 0)), x=side<0 ? 0.19 : 0.66; part(c,image,[[x,0.065],[x+0.15,0.065],[x+0.15,0.34],[x,0.34]],0,-45*(1-out(v)),side*0.08*(1-v),v) }
        if t>0.12 && t<0.67 { glow(c,195,tip+15,62,0.5) }; full(c,image,q(t,0.76,0.84))
    }
    private func sovereign(_ c: GraphicsContext, _ image: GraphicsContext.ResolvedImage, _ t: Double) {
        let charge=q(t,0.015,0.35)
        if t<0.36 {
            let radius=105*(1-pow(charge,2.3))+5
            glow(c,195,210,radius+40,0.18+charge*0.25)
            for i in 0..<18 {
                let a=Double(i)*2.399, r=radius+28+Double(i%3)*9, p=q(t,0.015+Double(i%5)*0.012,0.31+Double(i%4)*0.012), outer=260*(1-p)+r, inner=max(3,outer-85)
                var line=Path(); line.move(to:CGPoint(x:195+cos(a)*outer,y:210+sin(a)*outer))
                line.addQuadCurve(to:CGPoint(x:195+cos(a+0.38)*r,y:210+sin(a+0.38)*r),control:CGPoint(x:195+cos(a+0.22)*inner,y:210+sin(a+0.22)*inner))
                var ray=c; ray.opacity=sin(p * .pi)*0.75; ray.stroke(line,with:.color(color),lineWidth:i%3==0 ? 1.5 : 0.65)
            }
            glow(c,195,210,20+30*charge,charge*0.65); diamond(c,195,210,4+charge*8,0,charge)
        }
        if t>=0.36 && t<0.445 { glow(c,195,210,14,0.35); diamond(c,195,210,3,0,0.85) }
        guard t>=0.445 else { return }
        for i in 0..<3 {
            let v=q(t,0.445+Double(i)*0.022,0.70+Double(i)*0.025), r=20+out(v)*250, h=r*(i==1 ? 0.34 : 0.78)
            var wave=c; wave.opacity=(1-v)*0.65; wave.translateBy(x:195,y:210); wave.rotate(by:.radians(i==2 ? -0.28 : 0.13))
            wave.stroke(Path(ellipseIn:CGRect(x:-r,y:-h,width:r*2,height:h*2)),with:.color(color),lineWidth:i==0 ? 1.5 : 0.7)
        }
        for i in 0..<12 {
            let a=Double(i) * .pi/6+0.12, v=q(t,0.445,0.68), r=40+out(v)*235
            var line=Path(); line.move(to:CGPoint(x:195+cos(a)*45,y:210+sin(a)*45))
            line.addLine(to:CGPoint(x:195+cos(a+0.09)*r*0.48,y:210+sin(a+0.09)*r*0.48)); line.addLine(to:CGPoint(x:195+cos(a-0.06)*r*0.65,y:210+sin(a-0.06)*r*0.65)); line.addLine(to:CGPoint(x:195+cos(a)*r,y:210+sin(a)*r))
            var ray=c; ray.opacity=(1-v)*0.65; ray.stroke(line,with:.color(color),lineWidth:i%3==0 ? 1.5 : 0.65)
        }
        let settle=q(t,0.5,0.67), scale=t<0.5 ? 0.58+out(q(t,0.445,0.5))*0.51 : 1+0.09*exp(-settle*6)*cos(settle*7)
        let kick=q(t,0.49,0.60), shake=t>=0.49 && t<0.6 ? sin(kick*22)*(1-kick)*3 : 0
        var crest=c; crest.translateBy(x:shake,y:shake*0.45); full(crest,image,q(t,0.445,0.465),scale)
        glow(c,195,210,85,(1-q(t,0.445,0.51))*0.85)
        for i in 0..<32 { let v=q(t,0.47+Double(i%4)*0.006,0.76+Double(i%5)*0.02), a=Double(i)*2.399, r=35+out(v)*Double(95+(i%7)*12); diamond(c,195+cos(a)*r,210+sin(a)*r*0.8+v*v*38,1+Double(i%3)*0.8,a,sin(v * .pi)*0.65) }
    }
}
