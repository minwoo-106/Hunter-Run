import XCTest
@testable import HunterCore

final class DefenseWorkoutTests: XCTestCase {
    func catalog() throws -> DefenseWorkoutCatalog {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return try JSONDecoder().decode(DefenseWorkoutCatalog.self, from: Data(contentsOf: root.appendingPathComponent("Resources/defense-workouts.json")))
    }
    func testNinetyRoutinesHaveExactWarmupAndTwentyMinuteRemainder() throws {
        let c = try catalog(); try c.validate()
        for w in c.episodes { for intensity in DefenseIntensity.allCases { for standing in [false,true] {
            var totals: [DefensePhase:Int] = [:], work = 0
            var seen: [DefenseExercise] = []
            for second in 0..<1440 {
                let m = DefenseWorkoutTimeline.moment(at: Double(second), intensity: intensity, workout: w, standingOnly: standing)
                totals[m.phase, default:0] += 1
                if m.phase == .battle && !m.preparing { work += 1 }
                if m.phase == .battle && second % 60 == 0 { seen.append(m.exercise) }
                if standing { XCTAssertEqual(m.exercise.posture, .standing) }
                XCTAssertGreaterThan(m.intervalRemaining, 0)
            }
            XCTAssertEqual(totals[.warmup],240); XCTAssertEqual(totals[.battle],960)
            XCTAssertEqual(totals[.recovery],120); XCTAssertEqual(totals[.cooldown],120)
            XCTAssertEqual(work,16 * intensity.workoutSeconds)
            XCTAssertEqual(seen,w.moves(standingOnly: standing))
            XCTAssertEqual(DefenseWorkoutTimeline.moment(at: 1440, intensity: intensity, workout:w).phase,.complete)
        } } }
    }
    func testStandingThenKneelingThenSupineNeverBacktracksDuringCombat() throws {
        let c = try catalog()
        XCTAssertEqual(Set(c.episodes.map { $0.exercises.map(\.rawValue).joined(separator:",") }).count,30)
        for w in c.episodes {
            XCTAssertTrue(w.exercises.prefix(12).allSatisfy { $0.posture == .standing })
            XCTAssertTrue(w.exercises.suffix(4).allSatisfy { $0.posture != .standing })
            XCTAssertTrue(zip(w.exercises,w.exercises.dropFirst()).allSatisfy { $0.posture.rawValue <= $1.posture.rawValue })
        }
    }
    func testEveryBoundaryAndIntensityUsesCorrectDurationCue() throws {
        for w in try catalog().episodes { for intensity in DefenseIntensity.allCases {
            for t in [240.0,660,1080] {
                let m = DefenseWorkoutTimeline.moment(at:t,intensity:intensity,workout:w)
                XCTAssertTrue(m.preparing)
                let keys = DefenseWorkoutAudio.keys(moment:m,episode:w.episode,intensity:intensity,standingOnly:false)
                XCTAssertEqual(keys, ["defense_v2_move_"+m.exercise.rawValue,"defense_v2_seconds_"+intensity.rawValue])
                let go = DefenseWorkoutTimeline.moment(at:t+Double(60-intensity.workoutSeconds),intensity:intensity,workout:w)
                XCTAssertFalse(go.preparing); XCTAssertEqual(go.intervalRemaining,Double(intensity.workoutSeconds))
            }
            let before = DefenseWorkoutTimeline.moment(at:1020,intensity:intensity,workout:w)
            XCTAssertEqual(before.phase,.recovery)
            XCTAssertEqual(DefenseWorkoutAudio.keys(moment:before,episode:w.episode,intensity:intensity,standingOnly:false).last,"defense_v2_floor")
        } }
    }
    func testLegacyActiveSessionAndCompletedRecordsAreNotMigratedOrReset() throws {
        var save = SaveState(); save.profile.xp = 339
        try DefenseCampaign.begin(episode:1,intensity:.standard,in:&save)
        var old = try XCTUnwrap(save.profile.defense?.active)
        // 기존 버전의 실제 저장 형식에는 서서 하기 선택값이 없다.
        let encoder = JSONEncoder()
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with:encoder.encode(old)) as? [String:Any])
        json["contentVersion"] = 1; json["elapsed"] = 901; json.removeValue(forKey:"standingOnly")
        old = try JSONDecoder().decode(DefenseSession.self,from:JSONSerialization.data(withJSONObject:json))
        save.profile.defense?.active = old
        let restored = try JSONDecoder().decode(SaveState.self,from:encoder.encode(save))
        XCTAssertTrue(restored.profile.defense?.isValid == true)
        XCTAssertEqual(restored.profile.defense?.active?.contentVersion,1)
        XCTAssertNil(restored.profile.defense?.active?.standingOnly)
        XCTAssertEqual(restored.profile.defense?.active?.elapsed,901)
        XCTAssertEqual(restored.profile.xp,339)
        var changed = DefenseSession(episode:1,intensity:.standard)
        changed.elapsed=902
        XCTAssertThrowsError(try DefenseCampaign.checkpoint(changed,in:&save))
        old.elapsed=1440; XCTAssertTrue(try DefenseCampaign.complete(old,at:Date(),in:&save))
        save.profile.defense?.pendingReport=nil
        try DefenseCampaign.begin(episode:2,intensity:.challenge,standingOnly:true,in:&save)
        XCTAssertEqual(save.profile.defense?.active?.contentVersion,2)
        XCTAssertEqual(save.profile.defense?.active?.standingOnly,true)
        XCTAssertEqual(save.profile.defense?.records.count,1)
    }
}
