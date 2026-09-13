import XCTest
@testable import HunterCore

final class ReleasePersistenceTests: XCTestCase {
    func testConfirmedResetCannotRestoreOldProgressFromAutomaticBackup() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = SaveRepository(directory: directory)
        var old = SaveState(); old.profile.xp = 5000; old.profile.journey = JourneyState()
        old.profile.journey?.memories["desk"] = "cup"
        try repository.write(old); old.profile.xp = 6000; try repository.write(old)
        _ = try repository.reset()
        XCTAssertEqual(try repository.load().profile.xp, 0)
        try Data("damaged".utf8).write(to: directory.appendingPathComponent("save.json"))
        let recovered = try repository.load()
        XCTAssertEqual(recovered.profile.xp, 0); XCTAssertNil(recovered.profile.journey)
    }
}
