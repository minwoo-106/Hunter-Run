import Foundation

public final class SaveRepository {
    private let directory: URL
    public init(directory: URL) { self.directory = directory }
    public enum Failure: Error { case damaged, incompatible, invalid }
    private var current: URL { directory.appendingPathComponent("save.json") }
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
        if let run = save.active {
            guard run.targetSeconds.isFinite, run.targetSeconds >= 60, run.activeSeconds.isFinite,
                  run.activeSeconds >= 0, run.activeSeconds <= run.targetSeconds,
                  run.distance.isFinite, run.distance >= 0, run.hp.isFinite, run.hp >= 0 else { throw Failure.invalid }
        }
    }
}

