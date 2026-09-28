import Foundation

/// Presentation-only pace from accepted outdoor distance; never used for
/// distance, rewards, or combat. Core Location's instantaneous speed can be
/// much noisier than the measured distance on a steady walk.
public struct DisplayedPace {
    public private(set) var speed: Double?
    private struct Segment { var start: Double; var end: Double; var meters: Double }
    private var segments: [Segment] = []
    private var lastTime: Double?
    private var lastDistanceAt: Double?
    private static let window: Double = 40
    public init() {}
    public mutating func reset() { speed = nil; segments = []; lastTime = nil; lastDistanceAt = nil }
    public mutating func update(_ frame: SensorFrame, paused: Bool = false) {
        guard !paused, frame.timestamp.isFinite, frame.distance.isFinite,
              frame.signal == .good, frame.movement == .walking || frame.movement == .running,
              frame.distance >= 0 else { reset(); return }
        let now = frame.timestamp
        guard let previous = lastTime else { lastTime = now; return }
        let dt = now - previous
        guard dt > 0 else { return } // Location callbacks and timer may deliver the same instant.
        guard dt <= 5 else { reset(); lastTime = now; return }
        lastTime = now
        if frame.distance > 0 {
            let duration = frame.distanceDuration.flatMap { $0.isFinite && $0 > 0 && $0 <= 60 ? $0 : nil } ?? dt
            let measuredSpeed = frame.distance / duration
            guard measuredSpeed > 0.5, measuredSpeed <= 8 else { reset(); lastTime = now; return }
            segments.append(Segment(start: now - duration, end: now, meters: frame.distance))
            lastDistanceAt = now
        }
        guard let lastDistanceAt, now - lastDistanceAt <= 8 else { speed = nil; return }
        let cutoff = now - Self.window
        segments.removeAll { $0.end <= cutoff }
        // Weight the time represented by each GPS segment, not callback count.
        var seconds = 0.0, meters = 0.0
        for sample in segments {
            let duration = sample.end - max(cutoff, sample.start)
            seconds += duration
            meters += sample.meters * duration / (sample.end - sample.start)
        }
        guard seconds >= 3 else { speed = nil; return }
        let target = meters / seconds
        speed = target
    }
}
