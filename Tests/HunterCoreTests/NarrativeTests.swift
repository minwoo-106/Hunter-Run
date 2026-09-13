import XCTest
@testable import HunterCore

final class NarrativeTests: XCTestCase {
    func catalog() throws -> NarrativeCatalog {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return try JSONDecoder().decode(NarrativeCatalog.self, from: Data(contentsOf: root.appendingPathComponent("Resources/narrative.json")))
    }
    func finish(_ id: String, profile: inout Profile, catalog: NarrativeCatalog, lastChoice: Bool = false, preference: String? = nil) throws {
        try catalog.begin(id, profile: &profile)
        for _ in 0..<100 {
            let cursor = try XCTUnwrap(profile.journey?.cursor)
            let node = try XCTUnwrap(catalog.scene(id)?.node(cursor.nodeID))
            let memory = (profile.journey?.memories ?? [:]).merging(cursor.pendingMemory) { _, new in new }
            let choices = (node.choices ?? []).filter { $0.available(memory) }
            let preferred = preference.flatMap { target in choices.first { $0.memory?["relationshipPreference"] == target } }
            if try catalog.advance(choice: (preferred ?? (lastChoice ? choices.last : choices.first))?.id, profile: &profile) { return }
        }
        XCTFail("Scene did not terminate: \(id)")
    }
    func testProductionGraphHasReachableAcyclicChoices() throws {
        let catalog = try catalog()
        try catalog.validate()
        XCTAssertEqual(catalog.main.count, 16); XCTAssertEqual(catalog.bonds.count, 12)
        XCTAssertEqual(catalog.scenes.flatMap(\.nodes).flatMap { $0.choices ?? [] }.count, 40)
    }
    func testRegistrationMigratesNamesWithoutErasingExistingProgress() throws {
        let catalog = try catalog(); var profile = Profile()
        profile.xp = 1234; profile.crystals = 456; profile.readStories = ["arrival"]
        try catalog.register(hunter: "  길잡이  ", operatorName: "서연", profile: &profile)
        XCTAssertEqual(profile.name, "길잡이"); XCTAssertEqual(profile.xp, 1234)
        XCTAssertEqual(profile.readStories, ["arrival"])
        XCTAssertEqual(Names.render("저는 {operatorName}예요. {hunterName:topic}", profile: profile), "저는 서연이에요. 길잡이는")
        XCTAssertThrowsError(try catalog.register(hunter: "\n", operatorName: "하나", profile: &profile))
        XCTAssertFalse(Names.valid("가\n나"))
    }
    func testAllThreeRelationshipDirectionsReachEndingWithoutRepeatingRewards() throws {
        let catalog = try catalog()
        for preference in ["closer", "partnership", "undecided"] {
            var profile = Profile(); var journey = JourneyState()
            // Isolate bond gating from field quest gating: all main milestones verified.
            journey.unlocked = Set(catalog.main.map(\.id)); journey.memories["relationshipPreference"] = preference
            profile.journey = journey; catalog.refresh(&profile)
            for entry in catalog.bonds {
                XCTAssertTrue(profile.journey!.unlocked.contains(entry.id), entry.id)
                try finish(entry.id, profile: &profile, catalog: catalog, lastChoice: preference == "undecided", preference: preference)
            }
            XCTAssertEqual(profile.journey?.affinity, 68)
            XCTAssertEqual(catalog.tier(profile), 5)
            XCTAssertEqual(profile.journey?.memories["relationshipPreference"], preference)
            let state = profile.journey
            catalog.refresh(&profile)
            XCTAssertThrowsError(try catalog.begin("R01", profile: &profile))
            XCTAssertEqual(profile.journey, state)
        }
    }
    func testDraftChoicesAndCursorSurviveSaveThenCommitOnlyOnce() throws {
        let catalog = try catalog(); var save = SaveState()
        try catalog.register(hunter: "헌터", operatorName: "하나", profile: &save.profile)
        try catalog.begin("R01", profile: &save.profile)
        while let cursor = save.profile.journey?.cursor, let node = catalog.scene("R01")?.node(cursor.nodeID), node.choices == nil {
            try catalog.advance(profile: &save.profile)
        }
        try catalog.advance(choice: "R01-A", profile: &save.profile)
        XCTAssertNil(save.profile.journey?.memories["desk"])
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = SaveRepository(directory: directory); try repository.write(save)
        var restored = try repository.load()
        XCTAssertEqual(restored.profile.journey?.cursor?.pendingMemory["desk"], "cup")
        try finish("R01", profile: &restored.profile, catalog: catalog)
        XCTAssertEqual(restored.profile.journey?.memories["desk"], "cup")
        XCTAssertEqual(restored.profile.journey?.affinity, 4)
        XCTAssertThrowsError(try catalog.advance(profile: &restored.profile))
    }
    func testMainConditionsAreOrderedAndSimulationDoesNotUnlock() throws {
        let catalog = try catalog(); var profile = Profile()
        catalog.refresh(&profile)
        XCTAssertTrue(profile.journey!.unlocked.contains("M01"))
        XCTAssertFalse(profile.journey!.unlocked.contains("M02"))
        var simulated = RunSession(targetSeconds: 300, simulated: true, allowPursuit: false)
        simulated.phase = .finished; simulated.activeSeconds = 300
        Settlement.apply(simulated, to: &profile); catalog.refresh(&profile)
        XCTAssertFalse(profile.journey!.unlocked.contains("M02"))
        simulated.simulated = false
        Settlement.apply(simulated, to: &profile); catalog.refresh(&profile)
        XCTAssertTrue(profile.journey!.unlocked.contains("M02"))
        XCTAssertFalse(profile.journey!.unlocked.contains("M03"))
        profile.runs = []; catalog.refresh(&profile)
        XCTAssertTrue(profile.journey!.unlocked.contains("M02"))
    }
    func testInvalidChoiceCannotAdvanceOrMutateMemory() throws {
        let catalog = try catalog(); var profile = Profile()
        try catalog.begin("M01", profile: &profile)
        let before = profile.journey
        XCTAssertThrowsError(try catalog.advance(choice: "R11-A", profile: &profile))
        XCTAssertEqual(before, profile.journey)
        XCTAssertThrowsError(try catalog.begin("R12", profile: &profile))
    }
}
