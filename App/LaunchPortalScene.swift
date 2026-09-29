import SwiftUI

/// The approved C entrance artwork, with independent orbiting motes and low mist.
struct LaunchPortalScene: View {
    let entering: Bool
    let entranceStartedAt: Date?
    let reduceMotion: Bool
    @State private var appearedAt = Date()

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
            let elapsed = reduceMotion ? 0 : context.date.timeIntervalSince(appearedAt)
            let progress = entering ? (entranceStartedAt.map {
                min(1, max(0, context.date.timeIntervalSince($0) / 1.3))
            } ?? 0) : 0
            GeometryReader { geometry in
                let size = geometry.size
                let portal = CGPoint(x: size.width * 0.5, y: size.height * 0.29)
                ZStack {
                    Image("LaunchPortal").resizable().scaledToFill()
                        .frame(width: size.width, height: size.height)
                        .scaleEffect(CGFloat(1 + progress * 1.5), anchor: UnitPoint(x: 0.5, y: 0.29))
                        .brightness(progress * 0.28)

                    if !reduceMotion {
                        Ellipse().fill(Color(red: 0.62, green: 0.84, blue: 0.90).opacity(0.27))
                            .frame(width: size.width * 1.1, height: size.height * 0.15)
                            .blur(radius: 28)
                            .position(x: size.width * CGFloat(0.28 + 0.08 * sin(elapsed * 0.43)),
                                      y: size.height * CGFloat(0.66 - progress * 0.12))
                        Ellipse().fill(Color(red: 0.68, green: 0.87, blue: 0.93).opacity(0.20))
                            .frame(width: size.width * 1.0, height: size.height * 0.13)
                            .blur(radius: 24)
                            .position(x: size.width * CGFloat(0.75 - 0.09 * sin(elapsed * 0.33)),
                                      y: size.height * CGFloat(0.57 - progress * 0.12))

                        Circle().stroke(Color(red: 0.60, green: 0.88, blue: 0.95).opacity(0.44), lineWidth: 1.5)
                            .overlay { Circle().stroke(Color(red: 0.70, green: 0.92, blue: 0.96).opacity(0.36), style: StrokeStyle(lineWidth: 1, dash: [3, 6])).padding(15) }
                            .frame(width: size.width * 0.60, height: size.width * 0.60)
                            .shadow(color: Theme.teal.opacity(0.6), radius: 21)
                            .rotationEffect(.degrees(elapsed * 24 + progress * 165))
                            .scaleEffect(CGFloat(1 + progress * 4))
                            .opacity(1 - progress)
                            .position(portal)

                        ForEach(0..<6, id: \.self) { index in
                            orbitingMote(index: index, elapsed: elapsed, progress: progress,
                                         center: portal, width: size.width)
                        }
                    }

                    LinearGradient(colors: [.clear, .black.opacity(0.17), Theme.ink.opacity(0.75)],
                                   startPoint: .top, endPoint: .bottom)
                    Color.black.opacity(max(0, (progress - 0.82) / 0.18) * 0.78)
                }
                .frame(width: size.width, height: size.height)
                .clipped()
            }
        }
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }

    private func orbitingMote(index: Int, elapsed: Double, progress: Double,
                              center: CGPoint, width: CGFloat) -> some View {
        let periods = [9.0, 13.0, 7.0, 16.0, 11.0, 18.0]
        let phases = [0.26, 1.92, 3.49, 4.89, 5.76, 1.13]
        let radii = [0.295, 0.32, 0.26, 0.34, 0.28, 0.31]
        let direction = index.isMultiple(of: 2) ? 1.0 : -1.0
        let angle = phases[index] + elapsed * 2 * .pi / periods[index] * direction + progress * 7
        let radius = width * CGFloat(radii[index]) * CGFloat(1 - progress)
        let diameter: CGFloat = index.isMultiple(of: 3) ? 6 : 4
        return Circle().fill(Color(red: 0.83, green: 0.99, blue: 1))
            .frame(width: diameter, height: diameter)
            .shadow(color: Theme.teal, radius: 8)
            .opacity((index.isMultiple(of: 2) ? 0.9 : 0.65) * (1 - progress))
            .position(x: center.x + CGFloat(cos(angle)) * radius,
                      y: center.y + CGFloat(sin(angle)) * radius)
    }
}
