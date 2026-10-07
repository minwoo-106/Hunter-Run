import Foundation

/// Describes the distance battle's existing input gates without changing its rules.
public enum EnduranceGuidance: Equatable {
    case paused, briefing, signal, walking, stopped, counting

    public static func state(for run: RunSession, movement: Movement, signal: Signal) -> Self {
        if run.manualPause || run.interruption || run.phase == .paused || run.phase == .interrupted { return .paused }
        if run.event?.stage == .briefing { return .briefing }
        if signal != .good { return .signal }
        if movement == .walking { return .walking }
        if movement != .running { return .stopped }
        return .counting
    }

    public var message: String {
        switch self {
        case .paused: return "일시정지 · 확보한 전투 거리는 유지돼요."
        case .briefing: return "안내가 끝나면 전투 거리 누적을 시작해요."
        case .signal: return "GPS 확인 대기 · 신호가 회복되면 이어져요."
        case .walking: return "걷기 판정 · 전체 이동거리는 늘지만 전투 거리는 잠시 멈춰요."
        case .stopped: return "달리기 확인 대기 · 확보한 전투 거리는 유지돼요."
        case .counting: return "달리기 인정 거리 누적 중 · 가속할 필요는 없어요."
        }
    }
}
