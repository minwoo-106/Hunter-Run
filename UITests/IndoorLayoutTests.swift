import XCTest

final class IndoorLayoutTests: XCTestCase {
    override func setUp() { super.setUp(); continueAfterFailure = false }
    @MainActor private func app() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing-skip-title", "--ui-testing-skip-welcome", "--ui-testing-silent-audio", "--ui-testing-simulations", "--ui-testing-save", UUID().uuidString, "-operatorMotionEnabled", "NO"]
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
        app.segmentedControls["activity.environment"].buttons["제자리 운동"].tap()
        reach(app.segmentedControls["goal.kind"], in: app)
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
        app.segmentedControls["activity.environment"].buttons["러닝머신"].tap()
        reach(app.buttons["activity.mock"], in: app); app.buttons["activity.mock"].tap()
        XCTAssertTrue(app.staticTexts["실내 · 러닝머신"].waitForExistence(timeout: 5))
        allowMotionPrompt(app)
        if app.buttons["계속"].exists { reach(app.buttons["계속"], in: app); app.buttons["계속"].tap() }
        XCTAssertFalse(app.staticTexts["KILOMETERS"].exists)
        XCTAssertFalse(app.staticTexts["최근 페이스"].exists)
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = "Indoor-activity"; shot.lifetime = .keepAlways; add(shot)
        XCUIDevice.shared.press(.home); app.activate()
        reach(app.buttons["계속"], in: app)
        app.buttons["계속"].tap()
        XCTAssertTrue(app.buttons["일시정지"].waitForExistence(timeout: 5))
    }
}
