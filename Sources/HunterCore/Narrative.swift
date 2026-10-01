import Foundation

/// Story, relationship and quest changes are written with the containing SaveState.
/// Optional on Profile so previously installed versions migrate without losing progress.
public struct JourneyState: Codable, Equatable {
    public var version = 1
    public var operatorName = "서윤"
    public var registered = false
    public var affinity = 0
    public var unlocked: Set<String> = []
    public var completed: Set<String> = []
    public var milestones: Set<String> = []
    public var memories: [String: String] = [:]
    public var cursor: DialogueCursor?
    public var completedQuests: Set<String> = []
    public var claimedQuests: Set<String> = []
    public var selectedQuest: String?
    public var questRecords: [String: QuestRecord] = [:]
    public var gifts: OperatorGiftState? = nil
    public init() {}
    public var isValid: Bool {
        version == 1 && Names.valid(operatorName) && (0...1000).contains(affinity)
        && [unlocked, completed, milestones, completedQuests, claimedQuests].allSatisfy { set in
            set.count <= 500 && set.allSatisfy { !$0.isEmpty && $0.count <= 100 }
        } && memories.count <= 100 && memories.allSatisfy { !$0.key.isEmpty && $0.key.count <= 80 && $0.value.count <= 100 }
        && (cursor?.isValid ?? true) && (selectedQuest.map { !$0.isEmpty && $0.count <= 100 } ?? true)
        && questRecords.count <= 100 && questRecords.allSatisfy { $0.value.isValid }
        && (gifts?.isValid ?? true)
    }
}

public struct DialogueCursor: Codable, Equatable {
    public var sceneID: String
    public var nodeID: String
    // Choices are provisional until the scene's final node is acknowledged.
    public var choices: [String: String] = [:]
    public var pendingMemory: [String: String] = [:]
    public var isValid: Bool {
        !sceneID.isEmpty && sceneID.count <= 100 && !nodeID.isEmpty && nodeID.count <= 100
        && choices.count <= 200 && pendingMemory.count <= 100
        && choices.allSatisfy { $0.key.count <= 100 && $0.value.count <= 100 }
        && pendingMemory.allSatisfy { $0.key.count <= 80 && $0.value.count <= 100 }
    }
}

public enum Names {
    public static func clean(_ value: String) -> String { value.trimmingCharacters(in: .whitespacesAndNewlines) }
    public static func valid(_ value: String) -> Bool {
        let name = clean(value)
        return name == value && (1...16).contains(name.count)
        && !name.unicodeScalars.contains { CharacterSet.controlCharacters.contains($0) || "{}<>".unicodeScalars.contains($0) }
    }
    public static func hasFinal(_ name: String) -> Bool {
        guard let scalar = name.unicodeScalars.last?.value else { return false }
        if (0xAC00...0xD7A3).contains(scalar) { return (scalar - 0xAC00) % 28 != 0 }
        return "013678LMNRlmnr".unicodeScalars.contains { $0.value == scalar }
    }
    public static func render(_ text: String, profile: Profile) -> String {
        var result = text
        for (key, name) in [("hunterName", profile.name), ("operatorName", profile.journey?.operatorName ?? "서윤")] {
            // Older authored lines use literal 예요. Normalize before replacing the name.
            result = result.replacingOccurrences(of: "{\(key)}예요", with: name + (hasFinal(name) ? "이에요" : "예요"))
            for (particle, consonant, vowel) in [("subject", "이", "가"), ("topic", "은", "는"), ("object", "을", "를"), ("copula", "이에요", "예요")] {
                result = result.replacingOccurrences(of: "{\(key):\(particle)}", with: name + (hasFinal(name) ? consonant : vowel))
            }
            result = result.replacingOccurrences(of: "{\(key)}", with: name)
        }
        return result.replacingOccurrences(of: "{address}", with: profile.journey?.memories["address"] == "name" ? profile.name + "님" : "헌터님")
    }
}

public struct StoryRequirement: Codable, Equatable {
    public var kind: String
    public var key: String?
    public var value: Int
    public var hint: String
    public func progress(_ profile: Profile) -> Int {
        switch kind {
        case "seconds": return Int(min(100_000_000, profile.runs.reduce(0) { $0 + max(0, $1.seconds) }))
        case "defeat": return profile.runs.flatMap(\.records).filter { $0.catalogID == key && $0.defeated == true && $0.outcome != .neutral }.count
        case "discover": return FieldDiscovery.events(in: profile).contains(key ?? "") ? 1 : 0
        case "rank": return Progression.ranks.firstIndex(of: profile.growth.rank) ?? 0
        case "departments": return AssociationStage.upgrades(profile)
        case "quest": return profile.journey?.completedQuests.contains(key ?? "") == true ? 1 : 0
        case "boss":
            let firstClear = (profile.bosses?[key ?? ""]?.clears ?? 0) > 0
                || profile.runs.contains { $0.majorBoss?.bossID == key && $0.majorBoss?.cleared == true }
            return firstClear ? 1 : 0
        case "story": return profile.journey?.completed.contains(key ?? "") == true ? 1 : 0
        case "memory": return profile.journey?.memories[key ?? ""] == "yes" ? 1 : 0
        case "vanguard": return ["warrior", "mage", "archer", "cleric"].filter { FieldDiscovery.defeated("corrupted-vanguard-" + $0, in: profile) }.count
        default: return 0
        }
    }
    public func satisfied(_ profile: Profile) -> Bool { progress(profile) >= value }
}

public struct DialogueVariant: Codable {
    public var key: String
    public var value: String
    public var text: String
}
public struct DialogueChoice: Codable, Identifiable {
    public var id: String
    public var text: String
    public var next: String
    public var memory: [String: String]?
    public var requiresMemory: [String: String]?
    public func available(_ memory: [String: String]) -> Bool {
        (requiresMemory ?? [:]).allSatisfy { memory[$0.key] == $0.value }
    }
}
public struct DialogueNode: Codable, Identifiable {
    public var id: String
    public var speaker: String
    public var speakerLabel: String?
    public var text: String
    public var expression: String
    public var next: String?
    public var choices: [DialogueChoice]?
    public var variants: [DialogueVariant]?
    public var voiceKey: String?
    public func rendered(profile: Profile, pending: [String: String] = [:]) -> String {
        let memory = (profile.journey?.memories ?? [:]).merging(pending) { _, new in new }
        let chosen = variants?.first { memory[$0.key] == $0.value }?.text ?? text
        return Names.render(chosen, profile: profile)
    }
}
public struct NarrativeScene: Codable, Identifiable {
    public var id: String
    public var title: String
    public var kind: String
    public var order: Int
    public var artwork: String
    public var requiredMain: Int
    public var requiredTier: Int
    public var prerequisite: [String]
    public var requirements: [StoryRequirement]
    public var start: String
    public var nodes: [DialogueNode]
    public func node(_ id: String) -> DialogueNode? { nodes.first { $0.id == id } }
}
public enum NarrativeError: Error { case invalidContent, locked, invalidChoice, noDialogue, invalidName }

public struct NarrativeCatalog: Codable {
    public var schema: Int
    public var scenes: [NarrativeScene]
    public var main: [NarrativeScene] { scenes.filter { $0.kind == "main" }.sorted { $0.order < $1.order } }
    public var bonds: [NarrativeScene] { scenes.filter { $0.kind == "bond" }.sorted { $0.order < $1.order } }
    public func scene(_ id: String) -> NarrativeScene? { scenes.first { $0.id == id } }
    public func validate() throws {
        guard schema == 1, !main.isEmpty, !bonds.isEmpty, Set(scenes.map(\.id)).count == scenes.count,
              main.map(\.order) == Array(1...main.count), bonds.map(\.order) == Array(1...bonds.count) else { throw NarrativeError.invalidContent }
        for scene in scenes {
            guard ["main", "bond"].contains(scene.kind), !scene.title.isEmpty,
                  (0...main.count).contains(scene.requiredMain), (1...5).contains(scene.requiredTier),
                  Set(scene.nodes.map(\.id)).count == scene.nodes.count, scene.node(scene.start) != nil,
                  scene.prerequisite.allSatisfy({ id in self.scene(id).map { $0.kind == scene.kind && $0.order < scene.order } ?? false }),
                  scene.requirements.allSatisfy({ ["seconds", "defeat", "discover", "rank", "departments", "quest", "boss", "story", "memory", "vanguard"].contains($0.kind) && $0.value > 0 && !$0.hint.isEmpty }) else { throw NarrativeError.invalidContent }
            var reached: Set<String> = []
            func visit(_ id: String, path: Set<String>) throws {
                guard !path.contains(id), let node = scene.node(id), !node.text.isEmpty,
                      ["operator", "hunter", "narrator", "report"].contains(node.speaker) else { throw NarrativeError.invalidContent }
                if let voiceKey = node.voiceKey {
                    let haesol = node.speaker == "report" && voiceKey.hasPrefix("haesol_h")
                        && (1...16).contains(Int(voiceKey.suffix(2)) ?? 0)
                    let storyOperator = node.speaker == "operator" && voiceKey.hasPrefix("operator_o")
                        && (1...23).contains(Int(voiceKey.suffix(2)) ?? 0)
                    guard haesol || storyOperator else { throw NarrativeError.invalidContent }
                }
                reached.insert(id)
                let choices = node.choices ?? []
                guard choices.isEmpty || (node.next == nil && Set(choices.map(\.id)).count == choices.count && choices.contains { $0.requiresMemory == nil || $0.requiresMemory?.isEmpty == true }) else { throw NarrativeError.invalidContent }
                for next in ([node.next].compactMap { $0 } + choices.map(\.next)) { try visit(next, path: path.union([id])) }
            }
            try visit(scene.start, path: [])
            guard reached.count == scene.nodes.count else { throw NarrativeError.invalidContent }
        }
    }

    public func tier(_ profile: Profile) -> Int {
        let state = profile.journey ?? JourneyState()
        var tier = 1
        for (index, gate) in Self.relationshipGates.enumerated() {
            if state.affinity >= gate.0 && state.unlocked.contains(gate.1) { tier = index + 2 }
        }
        return tier
    }
    public static let tierNames = ["배정된 파트너", "익숙한 동료", "믿고 기대는 사이", "특별한 파트너", "서로의 편"]
    public static let relationshipGates = [(8, "M03"), (20, "M06"), (36, "M10"), (52, "M14")]
    @discardableResult public func refresh(_ profile: inout Profile) -> Bool {
        let before = profile.journey
        var state = before ?? JourneyState()
        for entry in main {
            guard entry.order == 1 || state.unlocked.contains(main[entry.order - 2].id) else { break }
            if entry.requirements.allSatisfy({ $0.satisfied(profile) }) { state.unlocked.insert(entry.id) }
            // Once unlocked, later spending or changed requirements must never relock a chapter.
            if !state.unlocked.contains(entry.id) { break }
        }
        for id in ["M03", "M06", "M10", "M13", "M16"] where state.unlocked.contains(id) && !state.milestones.contains(id) {
            state.milestones.insert(id); state.affinity = min(1000, state.affinity + 4)
        }
        if state.unlocked.contains("M18"), state.memories["firstVanguardRole"] == nil {
            let roles = ["warrior", "mage", "archer", "cleric"]
            if let first = profile.runs.reversed().flatMap(\.records).first(where: {
                $0.defeated == true && $0.outcome != .neutral && roles.contains($0.catalogID.replacingOccurrences(of: "corrupted-vanguard-", with: ""))
            }) {
                state.memories["firstVanguardRole"] = first.catalogID.replacingOccurrences(of: "corrupted-vanguard-", with: "")
            }
        }
        profile.journey = state
        let currentTier = tier(profile)
        for entry in bonds where entry.requiredTier <= currentTier {
            let mainReady = entry.requiredMain == 0 || state.unlocked.contains(String(format: "M%02d", entry.requiredMain))
            if mainReady && entry.prerequisite.allSatisfy(state.completed.contains) { state.unlocked.insert(entry.id) }
        }
        profile.journey = state
        return before != state
    }
    public func register(hunter: String, operatorName: String, profile: inout Profile) throws {
        let hunter = Names.clean(hunter), operatorName = Names.clean(operatorName)
        guard Names.valid(hunter), Names.valid(operatorName) else { throw NarrativeError.invalidName }
        var state = profile.journey ?? JourneyState()
        state.operatorName = operatorName; state.registered = true
        profile.name = hunter; profile.journey = state
        refresh(&profile)
    }
    public func begin(_ id: String, profile: inout Profile) throws {
        refresh(&profile)
        guard let entry = scene(id), var state = profile.journey, state.unlocked.contains(id), !state.completed.contains(id) else { throw NarrativeError.locked }
        if state.cursor?.sceneID != id { state.cursor = DialogueCursor(sceneID: id, nodeID: entry.start) }
        profile.journey = state
    }
    @discardableResult public func advance(choice id: String? = nil, profile: inout Profile) throws -> Bool {
        guard var state = profile.journey, var cursor = state.cursor,
              let scene = scene(cursor.sceneID), state.unlocked.contains(scene.id), !state.completed.contains(scene.id),
              let node = scene.node(cursor.nodeID) else { throw NarrativeError.noDialogue }
        let memory = state.memories.merging(cursor.pendingMemory) { _, new in new }
        let next: String?
        if !(node.choices ?? []).isEmpty {
            guard let choice = node.choices?.first(where: { $0.id == id && $0.available(memory) }) else { throw NarrativeError.invalidChoice }
            cursor.choices[node.id] = choice.id
            cursor.pendingMemory.merge(choice.memory ?? [:]) { _, new in new }
            next = choice.next
        } else {
            guard id == nil else { throw NarrativeError.invalidChoice }
            next = node.next
        }
        if let next {
            guard scene.node(next) != nil else { throw NarrativeError.invalidContent }
            cursor.nodeID = next; state.cursor = cursor; profile.journey = state
            return false
        }
        state.completed.insert(scene.id)
        state.memories.merge(cursor.pendingMemory) { _, new in new }
        if scene.kind == "bond" { state.affinity = min(1000, state.affinity + 4) }
        state.cursor = nil; profile.journey = state; refresh(&profile)
        return true
    }
}
