import Foundation

/// The sealed association room is a one-time narrative action, never an activity reward.
public enum HaesolSanctum {
    // Keep the original persisted key so existing 1.3.8 saves still unlock M21.
    public static let restorationKey = "cheongwolRestored"
    public static func available(_ profile: Profile) -> Bool {
        (profile.bosses?["corrupted-hunter"]?.clears ?? 0) > 0
        && profile.journey?.completed.contains("M20") == true
        && profile.journey?.memories[restorationKey] != "yes"
    }

    @discardableResult public static func restore(_ profile: inout Profile) -> Bool {
        guard available(profile) else { return false }
        profile.journey?.memories[restorationKey] = "yes"
        return true
    }
}
