import Foundation

/// Rotate equivalent lines without changing the logical instruction/completion key.
public struct VoiceVariants {
    private var next: [String: Int] = [:]
    public init() {}
    public mutating func select(_ key: String, catalog: [String: [String]]) -> String {
        guard let clips = catalog[key], !clips.isEmpty else { return key }
        let index = (next[key] ?? 0) % clips.count
        next[key] = (index + 1) % clips.count
        return clips[index]
    }
}
