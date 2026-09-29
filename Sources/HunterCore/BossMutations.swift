import Foundation

/// Optional post-clear patterns reuse the world creature and have independent saved HP/rounds.
public enum BossMutations {
    public static func all(_ world: WorldContent) -> [BossDefinition] {
        world.bosses.filter(BossCampaign.allowsReplay).flatMap { parent in
            (0...1).map { variant in
                let id = "mutation-" + parent.id + (variant == 0 ? "-echo" : "-seal")
                let label = variant == 0 ? "잔향 분열" : "봉인 역류"
                let attack = MissionTemplate(id: "major-strike-" + id + "-a", title: label + " · 외피 공략", kind: .boss,
                    startFraction: 0.35, duration: variant == 0 ? 45 : 30, hp: 80, audio: variant == 1 ? (parent.id == "boundary-lord" ? "lord_burst2" : parent.id == "void-librarian" ? "librarian_burst2" : "corrupted-hunter_phase3") : "boss",
                    burstSeconds: variant == 1 ? 10 : nil, steadyAudio: variant == 1 ? "boss" : nil)
                let phase = GameContent(schema: 1, missionTitle: label, events: [
                    MissionTemplate(id: "mutation-trace-" + id, title: "변이 흔적 관측", kind: .discovery, startFraction: 0.12, duration: 25, hp: 0, audio: "investigate"),
                    attack,
                    MissionTemplate(id: "major-strike-" + id + "-b", title: label + " · 핵심 공략", kind: .boss,
                        startFraction: 0.7, duration: variant == 0 ? 45 : 30, hp: 80, audio: "boss")
                ])
                return BossDefinition(id: id, name: parent.name + " · " + label,
                    description: variant == 0 ? "야외 전용 · 두 번의 45초 유지 공격으로 분열된 잔향을 모아요. 가속을 요구하지 않아요." : "야외 전용 · 첫 공략에서 선택적 10초 가속을 제안해요. 가속을 끄거나 응하지 않으면 30초 유지 공격으로 진행해요.",
                    requiredRank: parent.requiredRank, maximumHP: min(100000, parent.maximumHP * 1.15),
                    phases: [phase, phase, phase], requiredMain: parent.requiredMain, requiredBossClear: parent.id)
            }
        }
    }
    public static func artwork(_ boss: BossDefinition) -> String { "Monster-" + (boss.requiredBossClear ?? boss.id) }
}
