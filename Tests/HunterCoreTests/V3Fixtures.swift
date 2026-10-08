import Foundation
import XCTest
@testable import HunterCore

enum V3Fixtures {
    static let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    static func load<T: Decodable>(_ path: String, as: T.Type) throws -> T {
        try JSONDecoder().decode(T.self, from: Data(contentsOf: root.appendingPathComponent(path)))
    }
    static func rules() throws -> CombatRules { try load("Resources/combat-v3.json", as: CombatRules.self) }
    static func actualSave(level: Int = 15, progress: Int = 50) -> SaveState {
        var save = SaveState(); save.profile.xp = (level-1)*300+progress
        var growth = save.profile.growth
        growth.owned = ["resonance-blade","barrier-coat","trace-shoes","archive-lens"]
        growth.equipped = ["weapon":"resonance-blade","armor":"barrier-coat","shoes":"trace-shoes","relic":"archive-lens"]
        growth.departments = ["observation":2,"research":2,"equipment":2,"contracts":2]
        save.profile.growth = growth; save.profile.crystals = 203; save.profile.research = 200
        var journey = JourneyState(); journey.completedQuests = ["wolf-first"]; journey.unlocked = ["M01","M02","M03"]
        save.profile.journey = journey
        return save
    }
    static func engine(eventID: String = "beast", attack: Double = 2.915, boss: BossEncounter? = nil) throws -> RunEngine {
        let template = MissionTemplate(id: eventID, title: "검증 대상", kind: boss == nil ? .ambush : .boss, startFraction: 0.3, duration: 25, hp: 180, audio: "wolf_intro")
        let content = GameContent(schema: 1, missionTitle: "거리 전투 검증", events: [template])
        var session = RunSession(targetSeconds: 1800, simulated: false, allowPursuit: false, mode: boss == nil ? .contract : .gate, loadout: CombatStats(attack: attack))
        session.activeSeconds = 180; session.phase = .moving; session.lastTimestamp = 0
        session.rulesVersion = 2; session.combatRules = try rules(); session.boss = boss
        var event = RunEvent(template: template, hp: 180, startingHP: 180, baseline: 2.5)
        event.stage = .active; session.event = event; session.missionSnapshot = content
        return RunEngine(session: session, content: content)
    }
    static func boss() throws -> BossDefinition {
        var world: WorldContent = try load("Resources/world.json", as: WorldContent.self)
        var boss = world.bosses.removeFirst()
        boss.maximumHP = 2200
        return boss
    }
    static func frame(_ time: Double, _ distance: Double = 0, movement: Movement = .running, signal: Signal = .good) -> SensorFrame {
        SensorFrame(timestamp: time, speed: 2.5, distance: distance, movement: movement, signal: signal,
            distanceDuration: distance > 8 ? distance/2.5 : nil)
    }
}
