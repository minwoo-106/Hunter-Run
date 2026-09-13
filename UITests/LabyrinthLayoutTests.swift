import XCTest

final class LabyrinthLayoutTests: XCTestCase {
    override func setUp() { super.setUp(); continueAfterFailure = false }
    @MainActor private func app(skipTitle: Bool = true, largeText: Bool = false, motion: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing-skip-welcome", "--ui-testing-silent-audio", "--ui-testing-save", UUID().uuidString]
        if skipTitle { app.launchArguments.append("--ui-testing-skip-title") }
        // Layout checks need a stable idle frame. The real portrait-tap test and separate
        // Metal render checks keep motion enabled, so input while animating is still covered.
        if !motion { app.launchArguments += ["-operatorMotionEnabled", "NO"] }
        if largeText { app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"] }
        return app
    }
    @MainActor private func capture(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = name; shot.lifetime = .keepAlways; add(shot)
    }
    @MainActor func testTitleRequiresEntryAndDoesNotReappearOnResume() {
        let app = app(skipTitle: false); app.launch()
        let enter = app.buttons["title.enter"]
        XCTAssertTrue(enter.waitForExistence(timeout: 10)); XCTAssertFalse(app.buttons["nav.0"].exists)
        capture(app, "Labyrinth-title")
        enter.tap(); XCTAssertTrue(app.buttons["nav.0"].waitForExistence(timeout: 5))
        XCUIDevice.shared.press(.home); app.activate()
        XCTAssertTrue(app.buttons["nav.0"].waitForExistence(timeout: 5)); XCTAssertFalse(enter.exists)
    }
    @MainActor func testOperatorReplyAndMemoriesStayReachable() {
        let app = app(motion: true); app.launch()
        XCTAssertTrue(app.buttons["home.operator"].waitForExistence(timeout: 10)); app.buttons["home.operator"].tap()
        XCTAssertTrue(app.staticTexts["operator.reply"].waitForExistence(timeout: 5))
        capture(app, "Labyrinth-conversation")
        XCTAssertFalse(app.buttons["잠깐 쉬어요"].exists)
        app.buttons["operator.continue"].tap()
        let rest = app.buttons["잠깐 쉬어요"]
        for _ in 0..<6 { if rest.isHittable { break }; app.scrollViews.firstMatch.swipeUp() }
        XCTAssertTrue(rest.isHittable); rest.tap()
        XCTAssertFalse(rest.exists, "Choices should disappear while the operator replies")
        XCTAssertTrue(app.staticTexts["operator.reply"].isHittable, "Reply must scroll back into view after a choice")
        let memories = app.buttons["operator.memories"]
        XCTAssertTrue(memories.isHittable); memories.tap()
        XCTAssertTrue(app.staticTexts["함께 나눌 이야기"].waitForExistence(timeout: 5))
        capture(app, "Labyrinth-memories")
        app.buttons["이전"].tap()
        app.buttons["닫기"].tap()
        XCTAssertTrue(app.buttons["home.operator"].waitForExistence(timeout: 5))
    }
    @MainActor func testLargeTextConversationCanReadAndChoose() {
        let app = app(largeText: true); app.launch()
        XCTAssertTrue(app.buttons["home.operator"].waitForExistence(timeout: 10)); app.buttons["home.operator"].tap()
        app.buttons["operator.continue"].tap()
        let rest = app.buttons["잠깐 쉬어요"]
        let panel = app.scrollViews.firstMatch
        for _ in 0..<16 {
            if rest.isHittable { break }
            panel.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.7))
                .press(forDuration: 0.1, thenDragTo: panel.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.4)))
        }
        capture(app, "Labyrinth-large-text-choice-access")
        XCTAssertTrue(rest.isHittable); rest.tap()
        let reply = app.staticTexts["operator.reply"]
        XCTAssertTrue(reply.exists)
        let screen = app.windows.firstMatch.frame
        XCTAssertGreaterThanOrEqual(reply.frame.minX, screen.minX)
        XCTAssertLessThanOrEqual(reply.frame.maxX, screen.maxX)
        capture(app, "Labyrinth-conversation-large-text")
    }
    @MainActor func testMenuVisualTour() {
        let app = app(); app.launch()
        XCTAssertTrue(app.buttons["nav.1"].waitForExistence(timeout: 10)); app.buttons["nav.1"].tap()
        capture(app, "Labyrinth-hunter")
        app.buttons["장비 보관함"].tap()
        XCTAssertTrue(app.navigationBars["장비 보관함"].waitForExistence(timeout: 5)); capture(app, "Labyrinth-equipment")
        app.buttons["nav.2"].tap(); capture(app, "Labyrinth-preparation")
        app.buttons["nav.3"].tap()
        XCTAssertTrue(app.buttons["association.stories"].waitForExistence(timeout: 5)); capture(app, "Labyrinth-association")
        app.buttons["association.stories"].tap()
        let story = app.buttons["story.M01"]
        for _ in 0..<5 { if story.isHittable { break }; app.scrollViews.firstMatch.swipeUp() }
        capture(app, "Labyrinth-archive"); XCTAssertTrue(story.isHittable); story.tap()
        XCTAssertTrue(app.staticTexts["dialogue.text"].waitForExistence(timeout: 5)); capture(app, "Labyrinth-story")
        app.buttons["이전"].tap()
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["닫기"].tap(); app.buttons["nav.0"].tap(); app.buttons["home.settings"].tap()
        XCTAssertTrue(app.navigationBars["설정"].waitForExistence(timeout: 5)); capture(app, "Labyrinth-settings")
    }
}
