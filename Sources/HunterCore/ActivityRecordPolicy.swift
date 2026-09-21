public enum ActivityRecordPolicy {
    public static let minimumActiveSeconds = 180.0

    public static func qualifies(_ activeSeconds: Double) -> Bool {
        activeSeconds.isFinite && activeSeconds >= minimumActiveSeconds
    }
}
