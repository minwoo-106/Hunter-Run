import XCTest

final class OperatorChatUITests: XCTestCase {
    override func setUp() { super.setUp(); continueAfterFailure = false }
    @MainActor private func launch(large: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing-skip-title", "--ui-testing-skip-welcome", "--ui-testing-silent-audio",
            "--ui-testing-save", UUID().uuidString, "-operatorMotionEnabled", "NO"]
        if large { app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"] }
        app.launch()
        XCTAssertTrue(app.buttons["home.operator"].waitForExistence(timeout: 15))
        app.buttons["home.operator"].tap()
        XCTAssertTrue(app.buttons["operator.continue"].waitForExistence(timeout: 8))
        return app
    }
    @MainActor private func tap(_ button: XCUIElement, app: XCUIApplication) {
        for _ in 0..<16 {
            if button.isHittable { break }
            app.scrollViews.firstMatch.swipeUp()
        }
        XCTAssertTrue(button.isHittable); button.tap()
    }
    @MainActor private func capture(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = name; shot.lifetime = .keepAlways; add(shot)
    }
    @MainActor private func exerciseConversation(large: Bool) {
        let app = launch(large: large)
        app.buttons["operator.continue"].tap()
        tap(app.buttons["오늘은 다른 이야기도 하고 싶어요."], app: app)
        app.buttons["operator.continue"].tap()
        let topics = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "operator.chat.topic."))
        XCTAssertEqual(topics.count, 3)
        let selected = topics.element(boundBy: 0)
        let oldTopic = selected.identifier
        capture(app, "Chat topics \(large ? "large text" : "normal")")
        tap(selected, app: app)
        let line = app.buttons["operator.continue"]
        let firstLine = line.label
        let answers = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "operator.chat.reply."))
        XCTAssertEqual(answers.count, 0)
        line.tap()
        XCTAssertNotEqual(firstLine, line.label)
        XCTAssertEqual(answers.count, 0, "Both lines must be read before choices appear")
        line.tap()
        XCTAssertEqual(answers.count, 2)
        tap(answers.element(boundBy: 0), app: app)
        XCTAssertEqual(answers.count, 0)
        capture(app, "Chat selected response \(large ? "large text" : "normal")")
        let answer = line.label
        line.tap(); XCTAssertNotEqual(answer, line.label)
        line.tap()
        tap(app.buttons["다른 이야기도 듣고 싶어요."], app: app)
        line.tap()
        XCTAssertEqual(topics.count, 3)
        XCTAssertFalse(app.buttons[oldTopic].exists, "A topic just selected should rotate out")
        XCTAssertTrue(app.buttons["operator.memories"].isHittable)
        app.buttons["닫기"].tap()
        XCTAssertTrue(app.buttons["home.operator"].waitForExistence(timeout: 5))
    }
    @MainActor func testSmallTalkLinesRepliesAndTopicRotation() { exerciseConversation(large: false) }
    @MainActor func testLargeTextCanReadAndReplyWithoutLosingControls() { exerciseConversation(large: true) }
    @MainActor func testGiftIsConsumedAndRelationshipPageShowsSavedAffinity() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing-skip-title", "--ui-testing-skip-welcome", "--ui-testing-silent-audio",
            "--ui-testing-save", UUID().uuidString, "--ui-testing-operator-gifts", "-operatorMotionEnabled", "NO"]
        app.launch()
        XCTAssertTrue(app.buttons["home.operator"].waitForExistence(timeout: 15)); app.buttons["home.operator"].tap()
        XCTAssertTrue(app.buttons["operator.gifts"].waitForExistence(timeout: 8)); app.buttons["operator.gifts"].tap()
        let gift = app.buttons["operator.give.flower"]
        XCTAssertTrue(gift.waitForExistence(timeout: 5)); tap(gift, app: app)
        XCTAssertTrue(app.staticTexts["operator.gift-gain"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["operator.continue"].label.contains("첫 선물"))
        capture(app, "Gift reaction")
        app.buttons["operator.gifts"].tap()
        XCTAssertTrue(app.staticTexts["operator.gifts-empty"].waitForExistence(timeout: 5))
        app.buttons["operator.gifts-close"].tap()
        app.buttons["operator.memories"].tap()
        XCTAssertTrue(app.staticTexts["operator.relationship-affinity"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["operator.relationship-affinity"].label.contains("2"))
        capture(app, "Relationship overview")
        app.terminate(); app.launch()
        XCTAssertTrue(app.buttons["home.operator"].waitForExistence(timeout: 15)); app.buttons["home.operator"].tap()
        app.buttons["operator.gifts"].tap()
        XCTAssertTrue(app.staticTexts["operator.gifts-empty"].waitForExistence(timeout: 5))
    }
}
