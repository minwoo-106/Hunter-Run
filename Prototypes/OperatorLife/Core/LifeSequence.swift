import Foundation

// Throwaway, in-memory PoC. No game/save types or rendering assets are referenced here.
public enum LifePhase: String, Codable, CaseIterable { case stretching, idle, dozing, surprised, embarrassed, coffee, tablet, spacingOut, hairSweep, burger, burgerSurprised, burgerFlustered, cola }
public struct LifeCue: Codable, Equatable {
    public var phase: LifePhase
    public var at: Double
    public var text: String
}
public struct LifeSequence: Codable {
    public var stretchSeconds: Double
    public var idleSeconds: Double
    public var idleAfterWakeSeconds: Double
    public var dozeSettleSeconds: Double
    public var surprisedSeconds: Double
    public var embarrassedSeconds: Double
    public var activities: [LifePhase]?
    public var activitySeconds: [String: Double]?
    public var cues: [LifeCue]
}

// Semantic input to a renderer. A future Cubism adapter maps these values to rig
// parameters/motions; the controller does not know which artwork/engine is used.
public struct LifeRenderFrame {
    public let phase: LifePhase
    public let elapsed: Double
    public let activeTime: Double
    public let progress: Double
    public let dozeProgress: Double
    public let reducedMotion: Bool
}

public struct LifeStateMachine {
    public let sequence: LifeSequence
    public private(set) var phase: LifePhase = .stretching
    public private(set) var elapsed: Double = 0
    public private(set) var activeTime: Double = 0
    public private(set) var available = false
    public private(set) var motionEnabled = true
    public private(set) var reducedMotion = false
    private var hasWoken = false
    private var nextActivityIndex = 0

    public init(sequence: LifeSequence, initialPhase: LifePhase = .stretching, initialElapsed: Double = 0) {
        self.sequence = sequence; phase = initialPhase; elapsed = initialElapsed
    }
    public mutating func configure(available: Bool, motionEnabled: Bool, reducedMotion: Bool) {
        self.available = available; self.motionEnabled = motionEnabled; self.reducedMotion = reducedMotion
        if !motionEnabled || (reducedMotion && phase == .stretching) { phase = .idle; elapsed = 0 }
    }
    public mutating func advance(_ seconds: Double) {
        guard available, motionEnabled, seconds.isFinite, seconds > 0 else { return }
        activeTime += seconds
        var remaining = seconds
        while remaining > 0 {
            let duration = phaseDuration
            if duration.isInfinite { elapsed += remaining; return }
            let step = min(remaining, max(0, duration - elapsed))
            elapsed += step; remaining -= step
            if elapsed >= duration {
                switch phase {
                case .stretching: phase = .idle
                case .idle:
                    if hasWoken, let activities = sequence.activities, !activities.isEmpty {
                        phase = activities[nextActivityIndex % activities.count]
                        nextActivityIndex += 1
                    } else { phase = .dozing }
                case .surprised: phase = .embarrassed
                case .embarrassed: phase = .idle; hasWoken = true
                case .coffee, .tablet, .spacingOut, .hairSweep, .cola:
                    phase = .idle; hasWoken = true
                case .burgerSurprised: phase = .burgerFlustered
                case .burgerFlustered: phase = .cola
                case .dozing, .burger: return
                }
                elapsed = 0
            }
        }
    }
    // true means this tap must NOT also open the ordinary conversation sheet.
    public mutating func consumeTap() -> Bool {
        guard available, motionEnabled else { return false }
        switch phase {
        case .dozing: phase = .surprised; elapsed = 0; return true
        case .burger: phase = .burgerSurprised; elapsed = 0; return true
        case .surprised, .embarrassed, .burgerSurprised, .burgerFlustered, .cola: return true // repeated taps cannot restart the reaction
        default: return false
        }
    }
    public var cue: String? {
        sequence.cues.filter { $0.phase == phase && $0.at <= elapsed }.max { $0.at < $1.at }?.text
    }
    public var frame: LifeRenderFrame {
        LifeRenderFrame(phase: phase, elapsed: elapsed, activeTime: activeTime,
                        progress: phaseDuration.isInfinite ? 0 : min(1, elapsed / phaseDuration),
                        dozeProgress: min(1, elapsed / max(0.1, sequence.dozeSettleSeconds)), reducedMotion: reducedMotion)
    }
    private var phaseDuration: Double {
        switch phase {
        case .stretching: return max(0.1, sequence.stretchSeconds)
        case .idle: return max(0.1, hasWoken ? sequence.idleAfterWakeSeconds : sequence.idleSeconds)
        case .dozing, .burger: return .infinity
        case .surprised: return max(0.1, sequence.surprisedSeconds)
        case .embarrassed: return max(0.1, sequence.embarrassedSeconds)
        case .coffee, .tablet, .spacingOut, .hairSweep, .burgerSurprised, .burgerFlustered, .cola:
            return max(0.1, sequence.activitySeconds?[phase.rawValue] ?? 4)
        }
    }
}
