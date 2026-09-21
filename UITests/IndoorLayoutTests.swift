import XCTest

final class IndoorLayoutTests: XCTestCase {
    override func setUp() { super.setUp(); continueAfterFailure = false }
    @MainActor private func app(exhausted: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing-skip-title", "--ui-testing-skip-welcome", "--ui-testing-silent-audio", "--ui-testing-simulations", "--ui-testing-save", UUID().uuidString, "-operatorMotionEnabled", "NO"]
        if exhausted { app.launchArguments.append("--ui-testing-indoor-exhausted") }
        app.launch(); return app
    }
    @MainActor private func reach(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<24 {
            if element.isHittable { break }
            let scroll = app.scrollViews.firstMatch
            scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.04, dy: 0.8))
                .press(forDuration: 0.1, thenDragTo: scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.04, dy: 0.3)))
        }
        XCTAssertTrue(element.isHittable)
    }
    @MainActor private func allowMotionPrompt(_ app: XCUIApplication) {
        let alert = app.alerts.firstMatch
        if alert.waitForExistence(timeout: 2), alert.buttons["Allow"].exists { alert.buttons["Allow"].tap() }
    }
    @MainActor func testIndoorPreparationDoesNotOfferGPSDistanceOrAcceleration() {
        let app = app(); XCTAssertTrue(app.buttons["nav.2"].waitForExistence(timeout: 10)); app.buttons["nav.2"].tap()
        app.segmentedControls["activity.environment"].buttons["실내 러닝"].tap()
        XCTAssertEqual(app.segmentedControls["activity.environment"].buttons.count, 2)
        XCTAssertTrue(app.staticTexts["indoor.budget"].label.contains("60분 0초"))
        XCTAssertTrue(app.staticTexts["indoor.policy"].label.contains("50%"))
        XCTAssertTrue(app.staticTexts["indoor.policy"].label.contains("60분"))
        reach(app.segmentedControls["goal.kind"], in: app)
        app.segmentedControls["goal.kind"].buttons["자유"].tap()
        XCTAssertTrue(app.staticTexts["goal.free.help"].label.contains("하루 합산 60분"))
        XCTAssertFalse(app.staticTexts["goal.free.help"].label.contains("제한 없이"))
        XCTAssertFalse(app.segmentedControls["goal.kind"].buttons["거리"].exists)
        XCTAssertFalse(app.switches["선택적 가속 허용"].exists)
        reach(app.buttons["activity.start"], in: app)
        XCTAssertTrue(app.staticTexts["indoor.no-gps"].exists)
        XCTAssertFalse(app.buttons["위치 권한 확인"].exists)
        app.buttons["activity.start"].tap()
        XCTAssertTrue(app.staticTexts["실내 훈련 게이트"].waitForExistence(timeout: 5))
        allowMotionPrompt(app)
        XCTAssertFalse(app.buttons["indoor.start"].isEnabled, "A stationary simulator cannot pass the real sensor check")
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = "Indoor-sensor-check"; shot.lifetime = .keepAlways; add(shot)
    }
    @MainActor func testIndoorActivityUsesTimeAndPausesOnBackground() {
        let app = app(); XCTAssertTrue(app.buttons["nav.2"].waitForExistence(timeout: 10)); app.buttons["nav.2"].tap()
        app.segmentedControls["activity.environment"].buttons["실내 러닝"].tap()
        XCTAssertTrue(app.staticTexts["indoor.policy"].exists)
        reach(app.segmentedControls["goal.kind"], in: app)
        app.segmentedControls["goal.kind"].buttons["자유"].tap()
        XCTAssertTrue(app.staticTexts["goal.free.help"].label.contains("하루 합산 60분"))
        reach(app.buttons["activity.mock"], in: app); app.buttons["activity.mock"].tap()
        XCTAssertTrue(app.staticTexts["실내 러닝"].waitForExistence(timeout: 5))
        allowMotionPrompt(app)
        if app.buttons["계속"].exists { reach(app.buttons["계속"], in: app); app.buttons["계속"].tap() }
        XCTAssertFalse(app.staticTexts["KILOMETERS"].exists)
        XCTAssertFalse(app.staticTexts["현재 페이스"].exists)
        XCTAssertFalse(app.staticTexts["활동 평균 페이스"].exists)
        XCTAssertTrue(app.staticTexts["activity.indoor-limit"].exists)
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = "Indoor-activity"; shot.lifetime = .keepAlways; add(shot)
        XCUIDevice.shared.press(.home); app.activate()
        reach(app.buttons["계속"], in: app)
        app.buttons["계속"].tap()
        XCTAssertTrue(app.buttons["일시정지"].waitForExistence(timeout: 5))
    }
    @MainActor func testDailyIndoorLimitBlocksNewSessionButNotOutdoor() {
        let app = app(exhausted: true)
        XCTAssertTrue(app.buttons["nav.2"].waitForExistence(timeout: 10)); app.buttons["nav.2"].tap()
        app.segmentedControls["activity.environment"].buttons["실내 러닝"].tap()
        XCTAssertTrue(app.staticTexts["indoor.budget"].label.contains("모두 마쳤어요"))
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = "Indoor-daily-limit-used"; shot.lifetime = .keepAlways; add(shot)
        reach(app.buttons["activity.start"], in: app); XCTAssertFalse(app.buttons["activity.start"].isEnabled)
        for _ in 0..<24 {
            if app.segmentedControls["activity.environment"].isHittable { break }
            app.scrollViews.firstMatch.swipeDown()
        }
        app.segmentedControls["activity.environment"].buttons["야외"].tap()
        reach(app.buttons["activity.start"], in: app); XCTAssertTrue(app.buttons["activity.start"].isEnabled)
    }
}
