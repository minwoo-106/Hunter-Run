import XCTest

final class FacilityLayoutTests: XCTestCase {
    override func setUp() { super.setUp(); continueAfterFailure = false }
    @MainActor private func application(_ extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing-skip-title", "--ui-testing-skip-welcome", "--ui-testing-silent-audio",
            "--ui-testing-simulations", "--ui-testing-save", UUID().uuidString, "--ui-testing-facilities", "-operatorMotionEnabled", "NO"] + extra
        app.launch(); XCTAssertTrue(app.buttons["nav.3"].waitForExistence(timeout: 15))
        app.buttons["nav.3"].tap()
        XCTAssertTrue(app.buttons["facility.observation"].waitForExistence(timeout: 8))
        return app
    }
    @MainActor private func reach(_ element: XCUIElement, app: XCUIApplication) {
        for _ in 0..<12 {
            let scroll = app.scrollViews.firstMatch
            let top = max(scroll.frame.minY, app.navigationBars.firstMatch.frame.maxY) + 12
            let bottom = min(scroll.frame.maxY, app.buttons["nav.2"].frame.minY) - 12
            let frame = element.frame
            // A one-pixel edge can be "hittable" while the synthesized center tap lands on the tab bar.
            if element.isHittable && frame.minY >= top && frame.maxY <= bottom { return }
            if frame.minY < top && frame.maxY > 0 { scroll.swipeDown() }
            else { scroll.swipeUp() }
        }
        XCTFail("Facility control did not fit inside the visible content area: " + element.identifier)
    }
    @MainActor private func capture(_ name: String, app: XCUIApplication) {
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = name; shot.lifetime = .keepAlways; add(shot)
    }
    @MainActor private func backToMap(_ app: XCUIApplication) {
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.buttons["facility.observation"].waitForExistence(timeout: 5))
        for _ in 0..<5 { if app.buttons["facility.observation"].isHittable { break }; app.scrollViews.firstMatch.swipeDown() }
    }
    @MainActor func testFacilityRoomsGrowAndHiddenTerraceHasNoControl() {
        let app = application()
        XCTAssertFalse(app.buttons["facility.sanctum"].exists)
        XCTAssertFalse(app.staticTexts["빈 부지"].exists)
        capture("Facility map before story", app: app)
        reach(app.buttons["facility.observation"], app: app); app.buttons["facility.observation"].tap()
        capture("Observatory Lv1", app: app)
        reach(app.buttons["facility.work"], app: app); app.buttons["facility.work"].tap()
        XCTAssertTrue(app.navigationBars["현장 관측 기록"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.buttons["facility.upgrade"].waitForExistence(timeout: 5))
        for level in 2...3 {
            let expand = app.buttons["facility.upgrade"]; reach(expand, app: app); XCTAssertTrue(expand.isEnabled); expand.tap()
            let alert = app.alerts.firstMatch; XCTAssertTrue(alert.waitForExistence(timeout: 5)); alert.buttons["확인"].tap()
            XCTAssertTrue(app.staticTexts["Lv.\(level)"].exists)
            app.scrollViews.firstMatch.swipeDown(); capture("Observatory Lv\(level)", app: app)
        }
        XCTAssertFalse(app.buttons["facility.upgrade"].exists)
        backToMap(app)
        for id in ["research", "equipment", "contracts"] {
            let room = app.buttons["facility." + id]; reach(room, app: app); room.tap()
            XCTAssertTrue(app.buttons["facility.work"].exists)
            capture("Facility room " + id, app: app); backToMap(app)
        }
    }
    @MainActor func testSanctumConstructionPersistsAndRestorationIsOneTime() {
        let app = application(["--ui-testing-sanctum-ready"])
        reach(app.buttons["facility.sanctum"], app: app); app.buttons["facility.sanctum"].tap()
        let build = app.buttons["association.sanctum.build"]; reach(build, app: app); XCTAssertTrue(build.isEnabled); build.tap()
        XCTAssertFalse(build.exists); XCTAssertTrue(app.buttons["association.sanctum.restore"].waitForExistence(timeout: 5))
        capture("Sanctum built", app: app)
        app.terminate(); app.launch()
        XCTAssertTrue(app.buttons["nav.3"].waitForExistence(timeout: 10)); app.buttons["nav.3"].tap()
        reach(app.buttons["facility.sanctum"], app: app); app.buttons["facility.sanctum"].tap()
        XCTAssertFalse(app.buttons["association.sanctum.build"].exists)
        let restore = app.buttons["association.sanctum.restore"]; reach(restore, app: app); restore.tap()
        XCTAssertTrue(app.staticTexts["정화 완료"].waitForExistence(timeout: 5))
        XCTAssertFalse(restore.exists); XCTAssertFalse(app.buttons["facility.upgrade"].exists)
        capture("Sanctum restored", app: app)
    }
    @MainActor func testLegacyRestoredSaveRequiresNoConstruction() {
        let app = application(["--ui-testing-sanctum-legacy"])
        reach(app.buttons["facility.sanctum"], app: app); app.buttons["facility.sanctum"].tap()
        XCTAssertTrue(app.staticTexts["정화 완료"].exists)
        XCTAssertFalse(app.buttons["association.sanctum.build"].exists)
        XCTAssertFalse(app.buttons["association.sanctum.restore"].exists)
        capture("Legacy restored room", app: app)
    }
}
