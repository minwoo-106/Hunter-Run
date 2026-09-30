import Foundation

/// One-time construction and restoration. State lives in existing optional journey memories.
public enum HaesolSanctum {
    // Keep the original persisted key so existing 1.3.8 saves still unlock M21.
    public static let restorationKey = "cheongwolRestored"
    public static let constructionKey = "returnSanctumBuilt"
    public enum Stage: Equatable { case hidden, buildable, operational, restored }
    public static func stage(_ profile: Profile) -> Stage {
        // Older completed saves never have to construct or restore a second time.
        if profile.journey?.memories[restorationKey] == "yes" { return .restored }
        guard (profile.bosses?["corrupted-hunter"]?.clears ?? 0) > 0,
              profile.journey?.completed.contains("M20") == true else { return .hidden }
        return profile.journey?.memories[constructionKey] == "yes" ? .operational : .buildable
    }
    @discardableResult public static func build(_ profile: inout Profile) -> Bool {
        guard stage(profile) == .buildable else { return false }
        profile.journey?.memories[constructionKey] = "yes"
        return true
    }
    public static func available(_ profile: Profile) -> Bool {
        stage(profile) == .operational
    }

    @discardableResult public static func restore(_ profile: inout Profile) -> Bool {
        guard available(profile) else { return false }
        profile.journey?.memories[restorationKey] = "yes"
        return true
    }
}
