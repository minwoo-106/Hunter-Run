import XCTest

/// Replaces the retired indoor daily-limit/sensor-start UI checks.
final class IndoorLayoutTests: XCTestCase {
    override func setUp() { super.setUp(); continueAfterFailure = false }
    @MainActor private func launch(finale: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing-skip-title", "--ui-testing-skip-welcome", "--ui-testing-silent-audio", "--ui-testing-save", UUID().uuidString, "-operatorMotionEnabled", "NO"]
        if finale { app.launchArguments += ["--ui-testing-simulations", "--ui-testing-defense-final"] }
        app.launch()
        XCTAssertTrue(app.buttons["nav.2"].waitForExistence(timeout: 10)); app.buttons["nav.2"].tap()
        let picker = app.segmentedControls["activity.destination"]
        XCTAssertTrue(picker.waitForExistence(timeout: 10)); picker.buttons["지부 방어 작전"].tap()
        return app
    }
    @MainActor private func reach(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<30 {
            if element.isHittable { break }
            let scroll = app.scrollViews.firstMatch
            scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.04, dy: 0.8))
                .press(forDuration: 0.1, thenDragTo: scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.04, dy: 0.3)))
        }
        XCTAssertTrue(element.isHittable)
    }
    @MainActor private func prepare(_ app: XCUIApplication) {
        reach(app.buttons["defense.next"], in: app); app.buttons["defense.next"].tap()
        XCTAssertTrue(app.buttons["defense.intensity.standard"].waitForExistence(timeout: 5))
        reach(app.switches["defense.ready"], in: app); app.switches["defense.ready"].tap()
        reach(app.buttons["defense.start"], in: app)
        XCTAssertTrue(app.buttons["defense.start"].isEnabled); app.buttons["defense.start"].tap()
        XCTAssertTrue(app.buttons["defense.pause"].waitForExistence(timeout: 5))
    }
    @MainActor private func waitRunning(_ app: XCUIApplication) {
        reach(app.buttons["defense.pause"], in: app); app.buttons["defense.pause"].tap()
        let running = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", "일시정지"), object: app.buttons["defense.pause"])
        XCTAssertEqual(XCTWaiter.wait(for: [running], timeout: 8), .completed)
    }
    @MainActor func testRunningSessionPausesOnBackgroundAndSurvivesRelaunch() {
        let app = launch(); prepare(app); waitRunning(app)
        let ticking = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label != %@", "00:00 / 24:00"), object: app.staticTexts["defense.elapsed"])
        XCTAssertEqual(XCTWaiter.wait(for: [ticking], timeout: 5), .completed)
        XCUIDevice.shared.press(.home); app.activate()
        let paused = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", "준비됐어요 · 계속"), object: app.buttons["defense.pause"])
        XCTAssertEqual(XCTWaiter.wait(for: [paused], timeout: 5), .completed)
        let elapsed = app.staticTexts["defense.elapsed"].label
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = "Defense-paused-session"; shot.lifetime = .keepAlways; add(shot)
        app.terminate(); app.launch() // Same isolated save identifier, not a new fixture.
        XCTAssertTrue(app.buttons["nav.2"].waitForExistence(timeout: 10)); app.buttons["nav.2"].tap()
        XCTAssertTrue(app.buttons["defense.restore"].waitForExistence(timeout: 10))
        reach(app.buttons["defense.restore"], in: app); app.buttons["defense.restore"].tap()
        XCTAssertTrue(app.staticTexts["defense.elapsed"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["defense.elapsed"].label, elapsed)
        XCTAssertEqual(app.buttons["defense.pause"].label, "준비됐어요 · 계속")
    }
    @MainActor func testIndoorPreparationDoesNotOfferGPSDistanceOrAcceleration() {
        let app = launch()
        XCTAssertFalse(app.segmentedControls["activity.environment"].exists)
        XCTAssertFalse(app.staticTexts["indoor.budget"].exists)
        reach(app.buttons["defense.next"], in: app); app.buttons["defense.next"].tap()
        for mode in ["light", "standard", "challenge"] {
            reach(app.buttons["defense.intensity." + mode], in: app); app.buttons["defense.intensity." + mode].tap()
        }
        XCTAssertFalse(app.segmentedControls["goal.kind"].exists)
        XCTAssertFalse(app.buttons["위치 권한 확인"].exists)
        reach(app.buttons["defense.start"], in: app); XCTAssertFalse(app.buttons["defense.start"].isEnabled)
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = "Defense-briefing"; shot.lifetime = .keepAlways; add(shot)
    }
    @MainActor func testPauseAndBackgroundKeepClockStopped() {
        let app = launch(); prepare(app); waitRunning(app); app.buttons["defense.pause"].tap()
        let elapsed = app.staticTexts["defense.elapsed"].label
        XCUIDevice.shared.press(.home); app.activate()
        XCTAssertTrue(app.buttons["defense.pause"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons["defense.pause"].label, "준비됐어요 · 계속")
        XCTAssertEqual(app.staticTexts["defense.elapsed"].label, elapsed)
        reach(app.buttons["저장하고 나중에 이어하기"], in: app); app.buttons["저장하고 나중에 이어하기"].tap()
        XCTAssertTrue(app.buttons["defense.restore"].waitForExistence(timeout: 5)); app.buttons["defense.restore"].tap()
        XCTAssertTrue(app.staticTexts["defense.elapsed"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["defense.elapsed"].label, elapsed)
    }
    @MainActor func testFinalReportAndSeparateBehindIllustration() {
        let app = launch(finale: true)
        XCTAssertTrue(app.buttons["defense.restore"].waitForExistence(timeout: 5)); app.buttons["defense.restore"].tap()
        XCTAssertTrue(app.buttons["defense.pause"].waitForExistence(timeout: 5)); waitRunning(app)
        XCTAssertTrue(app.staticTexts["작전 완료"].waitForExistence(timeout: 10))
        reach(app.buttons["defense.reward"], in: app); app.buttons["defense.reward"].tap()
        reach(app.buttons["defense.behind"], in: app); app.buttons["defense.behind"].tap()
        XCTAssertEqual(app.buttons["defense.behind"].label, "메인 일러스트")
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = "Defense-behind"; shot.lifetime = .keepAlways; add(shot)
        app.buttons["닫기"].tap(); reach(app.buttons["defense.return"], in: app); app.buttons["defense.return"].tap()
        XCTAssertTrue(app.staticTexts["30회 캠페인 완주"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["defense.next"].exists)
    }
}
