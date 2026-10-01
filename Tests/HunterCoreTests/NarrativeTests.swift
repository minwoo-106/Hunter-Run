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
        XCTAssertEqual(catalog.main.count, 21); XCTAssertEqual(catalog.bonds.count, 12)
        XCTAssertEqual(catalog.scenes.flatMap(\.nodes).flatMap { $0.choices ?? [] }.count, 56)
    }
    func testHaesolIsKnownBeforeHerDisappearanceAndRecognizedBeforeFinalOperation() throws {
        let catalog = try catalog()
        for id in ["M01", "M06", "M13", "M17", "M19", "M20"] {
            XCTAssertTrue(catalog.scene(id)?.nodes.contains { $0.text.contains("해솔") } == true, id)
        }
        XCTAssertTrue(catalog.scene("M01")?.nodes.contains { $0.text.contains("1위로 알려진") } == true)
        XCTAssertTrue(catalog.scene("M17")?.nodes.contains { $0.text.contains("종이 기록") || $0.text.contains("통로") } == true)
        XCTAssertFalse(catalog.scene("M18")?.nodes.contains { $0.text.contains("강해솔 님이에요") } == true)
        XCTAssertTrue(catalog.scene("M19")?.nodes.contains { $0.text.contains("강해솔 헌터님") } == true)
        XCTAssertTrue(catalog.scene("M20")?.nodes.contains { $0.text.contains("정화된 건 아니에요") } == true)
        XCTAssertTrue(catalog.scene("M06")?.nodes.contains { $0.text.contains("첫 승급 때 남은 축하 기록") } == true)
    }
    func testEarlyChoicesReturnAsOptionalCallbacksWithoutBreakingOlderSaves() throws {
        let catalog = try catalog()
        var profile = Profile()
        try catalog.register(hunter: "새 헌터", operatorName: "하나", profile: &profile)
        try finish("M01", profile: &profile, catalog: catalog)
        XCTAssertEqual(profile.journey?.memories["firstOffice"], "teamwork")
        let closing = try XCTUnwrap(catalog.scene("M21")?.node("M21.firstOffice"))
        XCTAssertTrue(closing.rendered(profile: profile).contains("함께 왔네요"))

        let search = try XCTUnwrap(catalog.scene("M19")?.node("M19.search"))
        let vanguard = try XCTUnwrap(catalog.scene("M20")?.node("M20.vanguard"))
        var oldProfile = Profile()
        oldProfile.journey = JourneyState()
        XCTAssertEqual(closing.rendered(profile: oldProfile), closing.text)
        XCTAssertEqual(search.rendered(profile: oldProfile), search.text)
        XCTAssertEqual(vanguard.rendered(profile: oldProfile), vanguard.text)

        oldProfile.journey?.memories["searchPriority"] = "records"
        oldProfile.journey?.memories["vanguardMethod"] = "trace"
        XCTAssertTrue(search.rendered(profile: oldProfile).contains("봉인 이유"))
        XCTAssertTrue(vanguard.rendered(profile: oldProfile).contains("각각 추적"))
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
            journey.affinity = NarrativeCatalog.affinityMaximum
            profile.journey = journey; catalog.refresh(&profile)
            for entry in catalog.bonds {
                XCTAssertTrue(profile.journey!.unlocked.contains(entry.id), entry.id)
                try finish(entry.id, profile: &profile, catalog: catalog, lastChoice: preference == "undecided", preference: preference)
            }
            XCTAssertEqual(profile.journey?.affinity, NarrativeCatalog.affinityMaximum)
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
    func testFinalReturnRouteRequiresRealVanguardDefeatsAndOneTimeFacility() throws {
        let catalog = try catalog()
        XCTAssertEqual(catalog.scene("M21")?.artwork, "PurificationRoom")
        XCTAssertTrue(catalog.scene("M20")?.nodes.contains { $0.text.contains("강해솔") } == true)
        var profile = Profile()
        var journey = JourneyState(); journey.unlocked = Set(catalog.main.prefix(16).map(\.id)); journey.completed.insert("M16")
        profile.journey = journey
        XCTAssertFalse(HaesolSanctum.available(profile))
        catalog.refresh(&profile)
        XCTAssertTrue(profile.journey!.unlocked.contains("M17"))
        try finish("M17", profile: &profile, catalog: catalog)
        XCTAssertFalse(profile.journey!.unlocked.contains("M18"))

        func record(_ roles: [String], simulated: Bool, profile: inout Profile) {
            var run = RunSession(targetSeconds: 300, simulated: simulated, allowPursuit: false, mode: .contract)
            run.activeSeconds = 300; run.phase = .finished
            run.records = roles.map { EventRecord(id: "corrupted-vanguard-" + $0, title: "선발대", outcome: .success, damage: 100, defeated: true, kind: .maintain) }
            _ = Settlement.apply(run, to: &profile)
        }
        record(["warrior"], simulated: true, profile: &profile)
        catalog.refresh(&profile)
        XCTAssertFalse(profile.journey!.unlocked.contains("M18"))
        record(["warrior"], simulated: false, profile: &profile)
        catalog.refresh(&profile)
        XCTAssertTrue(profile.journey!.unlocked.contains("M18"))
        XCTAssertEqual(profile.journey?.memories["firstVanguardRole"], "warrior")
        let fragment = try XCTUnwrap(catalog.scene("M18")?.nodes.first { $0.variants?.contains { $0.key == "firstVanguardRole" } == true })
        XCTAssertTrue(fragment.rendered(profile: profile).contains("전사가"))
        try finish("M18", profile: &profile, catalog: catalog)
        record(["mage", "archer", "cleric"], simulated: false, profile: &profile)
        catalog.refresh(&profile)
        XCTAssertTrue(profile.journey!.unlocked.contains("M19"))
        try finish("M19", profile: &profile, catalog: catalog)
        XCTAssertFalse(profile.journey!.unlocked.contains("M20"))
        var bosses = profile.bosses ?? [:]
        var boss = BossState(maximumHP: 3200); boss.remainingHP = 0; boss.clears = 1
        bosses["corrupted-hunter"] = boss; profile.bosses = bosses
        catalog.refresh(&profile)
        XCTAssertTrue(profile.journey!.unlocked.contains("M20"))
        XCTAssertFalse(HaesolSanctum.available(profile))
        try finish("M20", profile: &profile, catalog: catalog)
        XCTAssertEqual(HaesolSanctum.stage(profile), .buildable)
        XCTAssertFalse(HaesolSanctum.available(profile))
        XCTAssertTrue(HaesolSanctum.build(&profile))
        XCTAssertTrue(HaesolSanctum.available(profile))
        XCTAssertTrue(HaesolSanctum.restore(&profile))
        XCTAssertFalse(HaesolSanctum.restore(&profile))
        catalog.refresh(&profile)
        XCTAssertTrue(profile.journey!.unlocked.contains("M21"))
        try finish("M21", profile: &profile, catalog: catalog)
    }
    func testInvalidChoiceCannotAdvanceOrMutateMemory() throws {
        let catalog = try catalog(); var profile = Profile()
        try catalog.begin("M01", profile: &profile)
        let before = profile.journey
        XCTAssertThrowsError(try catalog.advance(choice: "R11-A", profile: &profile))
        XCTAssertEqual(before, profile.journey)
        XCTAssertThrowsError(try catalog.begin("R12", profile: &profile))
    }
    func testNewRelationshipsRequireWiderCheckpointsAndStoryProgress() throws {
        let catalog = try catalog()
        for (index, gate) in NarrativeCatalog.relationshipGates.enumerated() {
            var profile = Profile(); var state = JourneyState()
            state.unlocked = Set(catalog.main.map(\.id)); state.affinity = gate.0 - 1
            profile.journey = state
            XCTAssertEqual(catalog.tier(profile), index + 1)
            profile.journey?.affinity = gate.0
            XCTAssertEqual(catalog.tier(profile), index + 2)
            profile.journey?.unlocked = ["M01"]
            XCTAssertEqual(catalog.tier(profile), 1, "Affinity alone cannot unlock a relationship")
        }
        var profile = Profile(); var state = JourneyState()
        state.affinity = 52; state.unlocked = Set(catalog.main.map(\.id)); profile.journey = state
        XCTAssertEqual(catalog.tier(profile), 3, "New profiles must not use legacy thresholds")
    }
    func testLegacyAchievedRelationshipsAndUnlockedStoriesSurviveUpgradeAndReload() throws {
        let catalog = try catalog()
        for (affinity, expectedTier) in [(8, 2), (20, 3), (36, 4), (52, 5), (1000, 5)] {
            var state = JourneyState(); state.affinity = affinity
            state.unlocked = Set(catalog.main.map(\.id)).union(["R01", "R02"])
            state.completed = ["M01", "R01"]; state.memories["desk"] = "cup"
            state.milestones = ["M03", "M06", "M10", "M13", "M16"]
            var raw = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(state)) as? [String: Any])
            raw.removeValue(forKey: "relationshipTier")
            var save = SaveState()
            save.profile.journey = try JSONDecoder().decode(JourneyState.self, from: JSONSerialization.data(withJSONObject: raw))
            XCTAssertNil(save.profile.journey?.relationshipTier)
            XCTAssertEqual(catalog.tier(save.profile), expectedTier)
            XCTAssertTrue(catalog.refresh(&save.profile))
            XCTAssertEqual(save.profile.journey?.relationshipTier, expectedTier)
            XCTAssertEqual(save.profile.journey?.affinity, affinity)
            XCTAssertTrue(state.unlocked.isSubset(of: save.profile.journey!.unlocked))
            XCTAssertEqual(save.profile.journey?.completed, state.completed)
            XCTAssertEqual(save.profile.journey?.memories, state.memories)
            let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            defer { try? FileManager.default.removeItem(at: directory) }
            let repository = SaveRepository(directory: directory)
            try repository.write(save)
            var restored = try repository.load()
            catalog.refresh(&restored.profile)
            XCTAssertEqual(catalog.tier(restored.profile), expectedTier)
            XCTAssertEqual(restored.profile.journey?.affinity, affinity)
            XCTAssertFalse(catalog.refresh(&restored.profile), "Migration and rewards must not repeat")
        }
    }
    func testAffinityStopsAtOneHundredAndLegacyExcessIsNeverReduced() throws {
        for (initial, expectedGain, final) in [(99, 1, 100), (100, 0, 100), (999, 0, 999)] {
            var state = JourneyState(); state.affinity = initial
            XCTAssertEqual(state.gainAffinity(4), expectedGain)
            XCTAssertEqual(state.affinity, final)
            XCTAssertTrue(state.isValid)
        }
        var invalid = JourneyState(); invalid.relationshipTier = 6
        XCTAssertFalse(invalid.isValid)
    }
}
