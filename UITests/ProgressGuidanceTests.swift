import XCTest

final class ProgressGuidanceTests: XCTestCase {
    override func setUp() { super.setUp(); continueAfterFailure = false }
    @MainActor private func launch(_ scenario: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing-skip-title", "--ui-testing-skip-welcome", "--ui-testing-silent-audio",
            "--ui-testing-simulations", "--ui-testing-save", UUID().uuidString,
            "--ui-testing-progress-guidance", scenario, "-operatorMotionEnabled", "NO"]
        app.launch()
        return app
    }
    @MainActor private func reach(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<20 {
            if element.isHittable { break }
            app.scrollViews.firstMatch.swipeUp()
        }
        XCTAssertTrue(element.isHittable)
    }
    @MainActor private func rank(_ scenario: String) -> XCUIApplication {
        let app = launch(scenario)
        XCTAssertTrue(app.buttons["nav.1"].waitForExistence(timeout: 15)); app.buttons["nav.1"].tap()
        reach(app.buttons["hunter.rank"], in: app); app.buttons["hunter.rank"].tap()
        XCTAssertTrue(app.staticTexts["rank.readiness"].waitForExistence(timeout: 5))
        return app
    }
    @MainActor private func capture(_ name: String, app: XCUIApplication) {
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = name; shot.lifetime = .keepAlways; add(shot)
    }
    @MainActor func testWalkingEnduranceShowsItsOwnDistanceAndHoldReason() {
        let app = launch("endurance")
        XCTAssertTrue(app.staticTexts["activity.endurance.distance"].waitForExistence(timeout: 15))
        reach(app.staticTexts["activity.endurance.status"], in: app)
        XCTAssertTrue(app.staticTexts["activity.endurance.distance"].label.contains("93 / 400 m"))
        XCTAssertTrue(app.staticTexts["activity.endurance.status"].label.contains("걷기 판정"))
        capture("Endurance walking explanation", app: app)
    }
    @MainActor func testPromotionExplainsStoryAccessInsteadOfOnlyGreenNumbers() {
        let app = rank("story")
        XCTAssertTrue(app.staticTexts["rank.readiness"].label.contains("지부 이야기"))
        reach(app.buttons["rank.promote"], in: app); XCTAssertFalse(app.buttons["rank.promote"].isEnabled)
        capture("Promotion story requirement", app: app)
    }
    @MainActor func testQualifiedHunterCanFindTheRequiredExam() {
        let app = rank("exam")
        XCTAssertTrue(app.staticTexts["rank.readiness"].label.contains("전용 감시체"))
        XCTAssertFalse(app.buttons["rank.promote"].isEnabled)
        reach(app.buttons["rank.exam.open"], in: app); capture("Promotion exam requirement", app: app)
        app.buttons["rank.exam.open"].tap()
        reach(app.buttons["quest.select.exam-D"], in: app)
        XCTAssertTrue(app.buttons["quest.select.exam-D"].isEnabled)
    }
    @MainActor func testCompletedExamEnablesPromotion() {
        let app = rank("ready")
        reach(app.buttons["rank.promote"], in: app)
        XCTAssertTrue(app.buttons["rank.promote"].isEnabled); app.buttons["rank.promote"].tap()
        XCTAssertTrue(app.alerts["안내"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.alerts.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "D급 헌터")).firstMatch.exists)
    }
    @MainActor func testSavedDefenseExplainsActivityLockAfterExamComplete() {
        let app = rank("locked")
        reach(app.staticTexts["rank.activity-lock"], in: app)
        XCTAssertTrue(app.staticTexts["rank.activity-lock"].label.contains("저장해둔 활동"))
        reach(app.buttons["rank.promote"], in: app); XCTAssertFalse(app.buttons["rank.promote"].isEnabled)
        capture("Promotion saved activity lock", app: app)
    }
}
