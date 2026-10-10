import Foundation

public enum DefensePosture: Int { case standing, kneeling, supine }

extension DefenseExercise {
    public var posture: DefensePosture {
        switch self {
        case .kneePush, .birdDog, .plank: return .kneeling
        case .bridge, .deadBug, .heelTouch: return .supine
        default: return .standing
        }
    }
    public var standingAlternative: DefenseExercise {
        switch self {
        case .kneePush: return .wallPush
        case .birdDog: return .hipHinge
        case .plank: return .wallPush
        case .bridge: return .squat
        case .deadBug: return .crossKnee
        case .heelTouch: return .sideCrunch
        default: return self
        }
    }
    var workoutInfo: (String, String, String) {
        switch self {
        case .fastMarch: return ("빠른 제자리 걷기", "팔을 함께 흔들며 발을 조용히 딛어요. 점프하지 않고 편한 리듬을 유지해요.", "보폭과 팔 움직임을 줄인 제자리 걷기")
        case .crossKnee: return ("서서 교차 무릎 올리기", "무릎과 반대쪽 손을 번갈아 가까이 가져와요. 허리를 크게 비틀지 않고 낮게 올려도 좋아요.", "벽을 짚고 낮게 무릎 올리기")
        case .skater: return ("점프 없는 스케이터 스텝", "좌우로 한 걸음씩 옮기며 반대 발을 가볍게 뒤로 짚어요. 발을 쿵 내려놓거나 뛰지 않아요.", "좁은 좌우 스텝")
        case .squatReach: return ("스쿼트와 팔 뻗기", "얕게 앉았다 일어나며 양팔을 편한 높이로 뻗어요. 무릎을 잠그거나 뛰어오르지 않아요.", "얕은 스쿼트 또는 앉아서 팔 뻗기")
        case .backLunge: return ("번갈아 백 런지", "한 발씩 뒤로 짚고 양 무릎을 조금 굽혔다 돌아와요. 좌우를 번갈아 하고 균형이 어렵다면 벽을 짚어요.", "무릎을 굽히지 않고 한 발씩 뒤로 짚기")
        case .sideCrunch: return ("서서 옆구리 접기", "한쪽 무릎과 같은 쪽 팔꿈치를 가까이 가져와요. 좌우를 번갈아 하고 목을 잡아당기지 않아요.", "앉아서 작게 옆으로 기울이기")
        case .hipHinge: return ("힙 힌지", "무릎을 살짝 굽히고 엉덩이를 뒤로 보내요. 등을 둥글게 말지 않고 편한 범위에서 돌아와요.", "벽 앞에서 엉덩이를 조금만 뒤로 보내기")
        case .kneePush: return ("무릎 푸시업", "매트에 손과 무릎을 대고 팔을 천천히 굽혔다 펴요. 허리가 꺾이지 않는 범위만 내려가요.", "네 발 자세에서 팔을 작게 굽히기 또는 시작 전 서서 하기 선택")
        case .birdDog: return ("버드독", "손과 무릎을 짚고 반대쪽 팔과 다리를 번갈아 뻗어요. 골반을 비틀지 않고 천천히 돌아와요.", "한 번에 팔만 또는 다리만 작게 뻗기")
        case .plank: return ("무릎 플랭크", "팔꿈치와 무릎을 매트에 대고 몸통을 편하게 유지해요. 숨을 참지 말고 힘들면 바로 쉬어요.", "네 발 자세에서 짧게 유지하기")
        case .bridge: return ("힙 브리지", "누워 무릎을 세우고 엉덩이를 천천히 들었다 내려요. 허리를 과하게 젖히지 않아요.", "높이를 낮추거나 누운 채 엉덩이에 가볍게 힘주기")
        case .deadBug: return ("데드버그", "누워 무릎을 굽히고 반대쪽 팔과 다리를 번갈아 천천히 내려요. 허리가 뜨면 움직임을 줄여요.", "발을 바닥에 두고 한쪽 발만 천천히 미끄러뜨리기")
        case .heelTouch: return ("누워 뒤꿈치 터치", "누워 무릎을 세우고 손을 좌우 뒤꿈치 쪽으로 번갈아 뻗어요. 목에 힘이 들면 머리를 바닥에 두세요.", "머리를 바닥에 둔 채 손만 번갈아 뻗기")
        default: return (title, instruction, "작고 느린 제자리 걷기 또는 앉아서 발 움직이기")
        }
    }
}

public struct DefenseWorkout: Codable {
    public let episode: Int
    public let focus: String
    public let exercises: [DefenseExercise]
    public func moves(standingOnly: Bool) -> [DefenseExercise] {
        standingOnly ? exercises.map(\.standingAlternative) : exercises
    }
}

public struct DefenseWorkoutCatalog: Codable {
    public let version: Int
    public let episodes: [DefenseWorkout]
    public func workout(_ episode: Int) -> DefenseWorkout? { episodes.first { $0.episode == episode } }
    public func validate() throws {
        guard version == 2, episodes.map(\.episode) == Array(1...30) else { throw DefenseError.invalid }
        for w in episodes {
            guard !w.focus.isEmpty, w.exercises.count == 16,
                  w.exercises.prefix(12).allSatisfy({ $0.posture == .standing }),
                  w.exercises.suffix(4).allSatisfy({ $0.posture != .standing }),
                  zip(w.exercises, w.exercises.dropFirst()).allSatisfy({ $0.posture.rawValue <= $1.posture.rawValue })
            else { throw DefenseError.invalid }
        }
    }
}

/// 준비 4분 + (교전 6분 / 회복 1분 / 교전 6분 / 전환 1분 / 교전 4분 / 정리 2분).
/// 기존 진행 중 세션은 DefenseTimeline의 1차 루틴을 그대로 사용한다.
public enum DefenseWorkoutTimeline {
    public static func moment(at elapsed: Double, intensity: DefenseIntensity, workout: DefenseWorkout,
                              standingOnly: Bool = false) -> DefenseMoment {
        let t = min(1440, max(0, elapsed.isFinite ? elapsed : 0))
        if t >= 1440 { return DefenseMoment(phase: .complete, phaseIndex: 0, phaseRemaining: 0, intervalRemaining: 0, preparing: false, exercise: .march, slot: 0) }
        let sections: [(Double, Double, DefensePhase, Int, Int)] = [
            (0,240,.warmup,0,0),(240,600,.battle,1,0),(600,660,.recovery,1,0),
            (660,1020,.battle,2,6),(1020,1080,.recovery,2,0),
            (1080,1320,.battle,3,12),(1320,1440,.cooldown,0,0)]
        let s = sections.first { t >= $0.0 && t < $0.1 }!
        let local = t - s.0, slot = Int(local / 60), within = local.truncatingRemainder(dividingBy: 60)
        let lead = Double(60 - intensity.workoutSeconds)
        let moves = workout.moves(standingOnly: standingOnly)
        let exercise: DefenseExercise
        switch s.2 {
        case .battle: exercise = moves[s.4 + slot]
        case .warmup: exercise = [.march,.step,.heel,.squat][min(slot,3)]
        case .recovery: exercise = .march
        case .cooldown: exercise = slot == 0 && !standingOnly ? .bridge : .march
        case .complete: exercise = .march
        }
        return DefenseMoment(phase: s.2, phaseIndex: s.3, phaseRemaining: s.1-t,
            intervalRemaining: s.2 == .battle ? (within < lead ? lead-within : 60-within) : 60-within,
            preparing: s.2 == .battle && within < lead, exercise: exercise, slot: slot)
    }
}

public enum DefenseWorkoutAudio {
    public static func keys(moment m: DefenseMoment, episode: Int, intensity: DefenseIntensity,
                            standingOnly: Bool) -> [String] {
        let prefix = String(format: "defense_%02d", episode)
        switch m.phase {
        case .warmup:
            return [[prefix + "_brief"], ["defense_warm_step"], ["defense_warm_heel"], ["defense_v2_warm_last"]][min(m.slot,3)]
        case .battle:
            return m.preparing ? ["defense_v2_move_" + m.exercise.rawValue, "defense_v2_seconds_" + intensity.rawValue] : ["defense_go"]
        case .recovery:
            return m.phaseIndex == 2 ? [prefix + "_rest2", standingOnly ? "defense_v2_standing" : "defense_v2_floor"] : [prefix + "_rest1"]
        case .cooldown:
            return m.slot == 0 ? [standingOnly ? "defense_cool" : "defense_v2_cool_floor", prefix + "_outro"] : [standingOnly ? "defense_cool_last" : "defense_v2_cool_stand"]
        case .complete: return []
        }
    }
}
