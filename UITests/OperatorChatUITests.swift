import XCTest

final class OperatorChatUITests: XCTestCase {
    override func setUp() { super.setUp(); continueAfterFailure = false }
    @MainActor private func launch(large: Bool = false, extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing-skip-title", "--ui-testing-skip-welcome", "--ui-testing-silent-audio",
            "--ui-testing-save", UUID().uuidString, "-operatorMotionEnabled", "NO"]
        if large { app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"] }
        app.launchArguments += extra
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
    @MainActor func testRelationshipAndAffinityMaxAreDistinctAndCheckpointsRemainReachable() {
        let final = launch(extra: ["--ui-testing-operator-relationship", "final"])
        final.buttons["operator.memories"].tap()
        XCTAssertTrue(final.staticTexts["operator.relationship-max"].waitForExistence(timeout: 5))
        XCTAssertFalse(final.staticTexts["operator.affinity-max"].exists, "Final relationship does not mean affinity is capped")
        capture(final, "Relationship final below affinity cap")
        final.terminate()

        let capped = launch(large: true, extra: ["--ui-testing-operator-relationship", "waiting", "--ui-testing-operator-gifts"])
        capped.buttons["operator.memories"].tap()
        XCTAssertTrue(capped.staticTexts["operator.affinity-max"].waitForExistence(timeout: 5))
        XCTAssertFalse(capped.staticTexts["operator.relationship-max"].exists, "High affinity must not skip story gates")
        capture(capped, "Affinity MAX waiting for story large text")
        let checkpoint = capped.staticTexts["operator.relationship-checkpoint.5"]
        for _ in 0..<16 { if checkpoint.isHittable { break }; capped.scrollViews.firstMatch.swipeUp() }
        XCTAssertTrue(checkpoint.isHittable)
        XCTAssertTrue(checkpoint.label.contains("이야기 진행 필요"))
        capture(capped, "Relationship checkpoints large text")
        capped.buttons["이전"].tap()
        capped.buttons["operator.gifts"].tap()
        XCTAssertTrue(capped.staticTexts["operator.gifts-max"].waitForExistence(timeout: 5))
        let gift = capped.buttons["operator.give.flower"]
        XCTAssertTrue(gift.label.contains("친밀도 MAX")); tap(gift, app: capped)
        XCTAssertTrue(capped.staticTexts["operator.gift-gain"].waitForExistence(timeout: 5))
        XCTAssertEqual(capped.staticTexts["operator.gift-gain"].label, "친밀도 MAX")
        capture(capped, "Gift affinity MAX")
    }
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
