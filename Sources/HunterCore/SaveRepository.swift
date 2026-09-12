import Foundation

public final class SaveRepository {
    private let directory: URL
    public init(directory: URL) { self.directory = directory }
    public enum Failure: Error { case damaged, incompatible, invalid }
    private var current: URL { directory.appendingPathComponent("save.json") }
    public var hasStoredSave: Bool {
        FileManager.default.fileExists(atPath: current.path) || FileManager.default.fileExists(atPath: directory.appendingPathComponent("backup.json").path)
    }
    public func load() throws -> SaveState {
        let fm = FileManager.default
        let candidates = [current, directory.appendingPathComponent("backup.json")]
        var found = false
        for url in candidates where fm.fileExists(atPath: url.path) {
            found = true
            if let data = try? Data(contentsOf: url), let save = try? JSONDecoder().decode(SaveState.self, from: data) {
                // Do not silently load an older backup over a save from a newer app.
                guard save.schema == 1 else { throw Failure.incompatible }
                if (try? validate(save)) != nil { return save }
            }
        }
        if found { throw Failure.damaged }
        return SaveState()
    }
    public func write(_ save: SaveState) throws {
        try validate(save)
        let fm = FileManager.default
        try fm.createDirectory(at: directory, withIntermediateDirectories: true)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(save)
        if let old = try? Data(contentsOf: current), let decoded = try? JSONDecoder().decode(SaveState.self, from: old),
           (try? validate(decoded)) != nil {
            try old.write(to: directory.appendingPathComponent("backup.json"), options: .atomic)
        }
        try data.write(to: current, options: .atomic)
    }
    public func validate(_ save: SaveState) throws {
        guard save.schema == 1 else { throw Failure.incompatible }
        guard save.profile.xp >= 0, save.profile.crystals >= 0, save.profile.research >= 0 else { throw Failure.invalid }
        guard (save.profile.discoveredEvents?.count ?? 0) <= 1000,
              (save.profile.discoveredEvents ?? []).allSatisfy({ !$0.isEmpty && $0.count <= 200 }) else { throw Failure.invalid }
        let growth = save.profile.growth
        guard save.profile.xp <= 100_000_000, save.profile.crystals <= 100_000_000, save.profile.research <= 100_000_000,
              Progression.ranks.contains(growth.rank), (0...1_000_000).contains(growth.cores),
              growth.departments.allSatisfy({ Department(rawValue: $0.key) != nil && (1...3).contains($0.value) }),
              growth.equipped.allSatisfy({ EquipmentSlot(rawValue: $0.key) != nil && growth.owned.contains($0.value) }) else { throw Failure.invalid }
        guard (save.profile.bosses ?? [:]).allSatisfy({ !$0.key.isEmpty && $0.value.isValid }) else { throw Failure.invalid }
        guard save.profile.paceMemory?.isValid ?? true, save.profile.runs.allSatisfy({ $0.paceReport?.isValid ?? true }) else { throw Failure.invalid }
        if let run = save.active {
            guard run.directorVersion == nil || run.directorVersion == 1 || run.directorVersion == 2,
                  run.event?.traveledDistance.map({ $0.isFinite && $0 >= 0 }) ?? true else { throw Failure.invalid }
            guard run.paceObservation?.isValid ?? true,
                  run.learnedReference.map(PaceLearning.validSpeed) ?? true,
                  run.paceCooldownUntil.map({ $0.isFinite && $0 >= 0 }) ?? true else { throw Failure.invalid }
            guard run.targetSeconds.isFinite, run.targetSeconds >= 60, run.activeSeconds.isFinite,
                  run.activeSeconds >= 0, run.activityGoal.isValid,
                  (run.activityGoal.kind != .time || run.activeSeconds <= run.activityGoal.value),
                  run.distance.isFinite, run.distance >= 0, run.hp.isFinite, run.hp >= 0 else { throw Failure.invalid }
            if let stats = run.loadout {
                guard stats.hp.isFinite, (100...600).contains(stats.hp), stats.attack.isFinite, (0.5...3).contains(stats.attack), stats.defense.isFinite, (0...0.65).contains(stats.defense), stats.eventBonus.isFinite, (0...0.2).contains(stats.eventBonus), (0...5).contains(stats.researchBonus) else { throw Failure.invalid }
            }
            if let boss = run.boss {
                guard boss.isValid, run.mode == .gate else { throw Failure.invalid }
                try boss.definition.validate()
            }
            try run.missionSnapshot?.validate()
        }
    }
}
