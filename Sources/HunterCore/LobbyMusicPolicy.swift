import Foundation

/// Preparation keeps music; a presented activity and voice checks take priority.
public struct LobbyMusicContext {
    public var tab = 0
    public var associationPresented = false
    public var runPresented = false
    public var hasRun = false
    public var foreground = true
    public var enabled = true
    public var testingVoice = false
    public init() {}
    public var shouldPlay: Bool {
        foreground && enabled && !testingVoice && !runPresented && !hasRun
    }
}
