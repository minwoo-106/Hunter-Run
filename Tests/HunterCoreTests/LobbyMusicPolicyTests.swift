import XCTest
@testable import HunterCore

final class LobbyMusicPolicyTests: XCTestCase {
    func testBrowsingKeepsMusicAcrossEveryNonRunScreen() {
        var context = LobbyMusicContext()
        // Home -> hunter -> archive -> menu -> association -> underlying menu.
        for tab in [0, 1, 3, 4] {
            context.tab = tab
            XCTAssertTrue(context.shouldPlay, "Music must continue on tab \(tab)")
        }
        context.associationPresented = true
        XCTAssertTrue(context.shouldPlay)
        context.associationPresented = false
        XCTAssertTrue(context.shouldPlay)
    }
    func testAssociationOverSetupUsesVisibleScreen() {
        var context = LobbyMusicContext(); context.tab = 2
        XCTAssertFalse(context.shouldPlay)
        context.associationPresented = true
        XCTAssertTrue(context.shouldPlay)
        context.runPresented = true
        XCTAssertFalse(context.shouldPlay)
    }
    func testActivityAndAudioExclusionsTakePriority() {
        var context = LobbyMusicContext(); context.hasRun = true
        XCTAssertFalse(context.shouldPlay)
        context.hasRun = false; context.foreground = false
        XCTAssertFalse(context.shouldPlay)
        context.foreground = true; context.enabled = false
        XCTAssertFalse(context.shouldPlay)
        context.enabled = true; context.testingVoice = true
        XCTAssertFalse(context.shouldPlay)
    }
}
