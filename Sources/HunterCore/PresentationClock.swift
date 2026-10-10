import Foundation

/// 화면 연출의 시간과 화면 인계는 동일한 활성 시간만 사용한다.
public struct PresentationClock {
    public let duration: Double
    public let handoff: Double
    public private(set) var elapsed: Double = 0
    private var last: Double?
    public init(duration: Double, handoff: Double, at uptime: Double) {
        self.duration = duration; self.handoff = handoff; last = uptime
    }
    public var progress: Double { min(1, elapsed / duration) }
    public var handedOff: Bool { progress >= handoff }
    public var complete: Bool { elapsed >= duration - 0.000000001 }
    public mutating func advance(to uptime: Double) {
        guard let previous = last, uptime.isFinite, uptime >= previous else { return }
        elapsed = min(duration, elapsed + uptime - previous); last = uptime
    }
    public mutating func setActive(_ active: Bool, at uptime: Double) {
        guard uptime.isFinite else { return }
        if active {
            if last == nil { last = uptime }
        } else {
            advance(to: uptime); last = nil
        }
    }
}
