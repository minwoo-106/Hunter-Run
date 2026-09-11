import Foundation

/// Presentation-only speed; never used for distance, rewards, or combat.
public struct DisplayedPace {
    public private(set) var speed: Double?
    private struct Segment { var start: Double; var end: Double; var speed: Double }
    private var segments: [Segment] = []
    private var lastTime: Double?
    public init() {}
    public mutating func reset() { speed = nil; segments = []; lastTime = nil }
    public mutating func update(_ frame: SensorFrame, paused: Bool = false) {
        guard !paused, frame.timestamp.isFinite, frame.speed.isFinite,
              frame.signal == .good, frame.movement == .walking || frame.movement == .running,
              frame.speed > 0.5, frame.speed <= 8 else { reset(); return }
        let now = frame.timestamp
        guard let previous = lastTime else { lastTime = now; return }
        let dt = now - previous
        guard dt > 0 else { return } // Location callbacks and timer may deliver the same instant.
        guard dt <= 5 else { reset(); lastTime = now; return }
        lastTime = now
        segments.append(Segment(start: previous, end: now, speed: frame.speed))
        let cutoff = now - 12
        segments.removeAll { $0.end <= cutoff }
        // Weight elapsed time, not callback count; trim partially expired segments exactly.
        var seconds = 0.0, meters = 0.0
        for sample in segments {
            let duration = sample.end - max(cutoff, sample.start)
            seconds += duration; meters += duration * sample.speed
        }
        guard seconds >= 3 else { speed = nil; return }
        let target = meters / seconds
        if let current = speed {
            // Bound a display jump without changing the raw gameplay/sensor values.
            speed = min(current + 0.15 * dt, max(current - 0.15 * dt, target))
        } else { speed = target }
    }
}
