import Foundation

/// Optional, spoiler-free small talk. Reading it never changes progression or affinity.
public struct OperatorChatReply: Codable, Identifiable {
    public var id: String
    public var text: String
    public var next: String
}
public struct OperatorChatNode: Codable, Identifiable {
    public var id: String
    public var lines: [String]
    public var expression: String
    public var replies: [OperatorChatReply]
}
public struct OperatorChatEpisode: Codable, Identifiable {
    public var id: String
    public var prompt: String
    public var minimumTier: Int
    public var activity: String?
    public var requiresRecentActivity: Bool
    public var start: String
    public var nodes: [OperatorChatNode]
    public func node(_ id: String) -> OperatorChatNode? { nodes.first { $0.id == id } }
}
public struct OperatorChatCatalog: Codable {
    public var schema: Int
    public var episodes: [OperatorChatEpisode]
    public func validate() throws {
        guard schema == 1, !episodes.isEmpty, Set(episodes.map(\.id)).count == episodes.count else { throw NarrativeError.invalidContent }
        for episode in episodes {
            guard !episode.prompt.isEmpty, (1...5).contains(episode.minimumTier),
                  Set(episode.nodes.map(\.id)).count == episode.nodes.count else { throw NarrativeError.invalidContent }
            var reached: Set<String> = []
            func visit(_ id: String, path: Set<String>) throws {
                guard !path.contains(id), let node = episode.node(id), !node.lines.isEmpty,
                      node.lines.allSatisfy({ !$0.isEmpty }),
                      ["calm", "smile", "playful", "thoughtful", "worried", "relieved"].contains(node.expression),
                      node.replies.count <= 3, Set(node.replies.map(\.id)).count == node.replies.count,
                      node.replies.allSatisfy({ !$0.text.isEmpty }) else { throw NarrativeError.invalidContent }
                reached.insert(id)
                for reply in node.replies { try visit(reply.next, path: path.union([id])) }
            }
            try visit(episode.start, path: [])
            guard reached.count == episode.nodes.count else { throw NarrativeError.invalidContent }
        }
    }
    /// Caller supplies a shuffled deck. Keep one contextually relevant topic, then
    /// rotate others without immediately repeating the previous selected topics.
    public func suggestions(tier: Int, activity: String, hasRecentActivity: Bool,
                            recent: [String], deck: [String]) -> [OperatorChatEpisode] {
        let available = episodes.filter { $0.minimumTier <= tier && (!$0.requiresRecentActivity || hasRecentActivity) }
        let shuffled = deck.compactMap { id in available.first { $0.id == id } }
        let ordered = shuffled + available.filter { !deck.contains($0.id) }
        let fresh = ordered.filter { !recent.contains($0.id) }
        var selected: [OperatorChatEpisode] = []
        if let contextual = fresh.first(where: { $0.activity == activity }) { selected.append(contextual) }
        for episode in fresh + ordered where selected.count < 3 && !selected.contains(where: { $0.id == episode.id }) {
            selected.append(episode)
        }
        return selected
    }
    public static func recentActivity(_ profile: Profile, now: Date) -> RunSummary? {
        profile.runs.first { now.timeIntervalSince($0.date) >= 0 && now.timeIntervalSince($0.date) < 48 * 3600 }
    }
}
