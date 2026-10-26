#if DEBUG && targetEnvironment(simulator)
import Foundation

extension AppModel {
    /// 전용 테스트 세이브에서만 사용한다. 설치용 Release에는 포함되지 않는다.
    func prepareGrowthPreview(arguments: [String]) {
        guard Self.testHarness, let marker = arguments.firstIndex(of: "--ui-testing-growth"), marker + 1 < arguments.count,
              let catalog = progressionCatalog else { return }
        save.profile.name = "민우"; save.profile.xp = 4250
        save.profile.growth.rank = "E"; save.profile.growth.departments["equipment"] = 2
        for id in ["resonance-blade", "barrier-coat", "trace-shoes", "archive-lens"] {
            if let item = catalog.equipment.first(where: { $0.id == id }) {
                save.profile.growth.owned.insert(id); save.profile.growth.equipped[item.slot.rawValue] = id
            }
        }
        try? CombatRelease.migrate(&save)
        save.profile.crystals = 80; save.profile.research = 35; save.profile.growth.cores = 1
        var journal = EquipmentJournal(); journal.targetID = "core-spear"
        journal.presets = [EquipmentPreset(id: 0, name: "탐색용", slots: save.profile.growth.equipped)]
        journal.memories["resonance-blade"] = EquipmentMemory(trackingSince: Date().addingTimeInterval(-86400 * 7))
        journal.memories["resonance-blade"]?.outdoorDistance = 12500; journal.memories["resonance-blade"]?.activities = 5
        save.profile.equipmentJournal = journal
        save.profile.discoveredEvents = ["beast", "iron-guard"]
        save.profile.runs = []
        for i in 0..<7 where i != 2 && i != 5 {
            let date = Calendar.current.date(byAdding: .day, value: -i, to: Date())!
            let record = EventRecord(id: "beast", title: "잔향 늑대", outcome: .perfect, damage: 180, defeated: true, kind: .ambush, monsterID: "echo-wolf", attacks: 2)
            var run = RunSummary(id: UUID(), date: date, seconds: 1620, elapsedSeconds: 1800, distance: Double(2900+i*130), xp: 205, crystals: 18, records: [record], runningSeconds: 1320, completedGoal: true, mode: .contract, research: 7, cores: 0)
            run.paceReport = PaceReport(stableSeconds: 520, medianSpeed: 2.7, goodSignalFraction: 0.93, referenceUsed: 2.5, referenceAfter: 2.6, learned: true)
            run.growthReport = ActivityGrowthReport(levelBefore: 14, levelAfter: 15, firstDefeats: i == 0 ? ["잔향 늑대"] : [], equipmentIDs: Array(save.profile.growth.equipped.values), targetID: "core-spear", targetBefore: [62,28,1], targetAfter: [80,35,1])
            save.profile.runs.append(run)
        }
        selectedTab = 1
        let scene = arguments[marker + 1]
        if scene.hasPrefix("rank-") { growthCelebration = GrowthCelebration(rank: String(scene.suffix(1)), unlocks: [UnlockNotice(id: "sample", title: "장비지원부 Lv.3", detail: "시설 확장 가능 · 화면 검증용 예시")]) }
        if scene == "acquired" { growthCelebration = GrowthCelebration(equipmentID: "resonance-blade") }
    }
}
#endif
