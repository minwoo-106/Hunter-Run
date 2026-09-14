import XCTest

final class ExpeditionLayoutTests: XCTestCase {
    override func setUp() { super.setUp(); continueAfterFailure = false }
    @MainActor private func application() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing-skip-title", "--ui-testing-skip-welcome", "--ui-testing-silent-audio", "--ui-testing-simulations", "--ui-testing-save", UUID().uuidString, "--ui-testing-expedition", "-operatorMotionEnabled", "NO"]
        app.launch(); XCTAssertTrue(app.buttons["nav.2"].waitForExistence(timeout: 15)); return app
    }
    @MainActor private func reach(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<20 {
            if element.isHittable { break }
            let scroll = app.scrollViews.firstMatch
            scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.03, dy: 0.8)).press(forDuration: 0.1, thenDragTo: scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.03, dy: 0.3)))
        }
        if !element.isHittable {
            print(app.debugDescription)
            let image = XCTAttachment(screenshot: app.screenshot()); image.name = "Unreachable element"; image.lifetime = .keepAlways; add(image)
        }
        XCTAssertTrue(element.isHittable)
    }
    @MainActor private func capture(_ name: String, app: XCUIApplication) {
        let image = XCTAttachment(screenshot: app.screenshot()); image.name = name; image.lifetime = .keepAlways; add(image)
    }
    @MainActor func testTrackedQuestKeepsModesSelectableAndNavigationDistinct() {
        let app = application(); app.buttons["nav.2"].tap()
        let exploration = app.buttons["mode.exploration"]
        reach(exploration, in: app); XCTAssertTrue(exploration.isEnabled); exploration.tap()
        XCTAssertTrue(app.buttons["mode.contract"].isEnabled); app.buttons["mode.contract"].tap()
        capture("Activity modes with ordinary assignment", app: app)
        reach(app.staticTexts["quest.focus"], in: app)
        XCTAssertEqual(app.staticTexts["quest.focus"].label, "첫 잔향 토벌")
        app.buttons["nav.1"].tap()
        for _ in 0..<5 { app.scrollViews.firstMatch.swipeUp() }
        XCTAssertFalse(app.buttons["협회 부서 관리"].exists)
        XCTAssertFalse(app.buttons["hunter.association"].exists)
        capture("Hunter focused navigation", app: app)
        app.buttons["nav.3"].tap()
        XCTAssertTrue(app.segmentedControls["association.section"].waitForExistence(timeout: 5))
        app.segmentedControls["association.section"].buttons["시설"].tap()
        XCTAssertFalse(app.buttons["association.quests"].exists)
        XCTAssertFalse(app.buttons["association.stories"].exists)
        capture("Association facilities and beacons", app: app)
    }
    @MainActor func testWeeklyRewardAndReturnConversation() {
        let app = application()
        reach(app.buttons["home.return"], in: app); app.buttons["home.return"].tap()
        XCTAssertTrue(app.staticTexts["return.line"].waitForExistence(timeout: 5))
        capture("Return briefing", app: app)
        for _ in 0..<6 {
            let next = app.buttons["return.next"]
            if !next.exists { break }; reach(next, in: app); next.tap()
        }
        XCTAssertTrue(app.buttons["nav.3"].waitForExistence(timeout: 5)); app.buttons["nav.3"].tap()
        app.segmentedControls["association.section"].buttons["주간 조사"].tap()
        capture("Weekly survey objectives", app: app)
        let claim = app.buttons["weekly.claim"]; reach(claim, in: app)
        XCTAssertTrue(claim.isEnabled); claim.tap()
        XCTAssertEqual(claim.label, "이번 주 인장 받음"); XCTAssertFalse(claim.isEnabled)
        capture("Weekly survey claimed", app: app)
    }
    @MainActor func testPostClearMutationCanBePreparedWithoutLockingOrdinaryMode() {
        let app = application(); app.buttons["nav.2"].tap()
        reach(app.buttons["mode.gate"], in: app); XCTAssertTrue(app.buttons["mode.gate"].isEnabled); app.buttons["mode.gate"].tap()
        reach(app.buttons["setup.bosses"], in: app); app.buttons["setup.bosses"].tap()
        let close = app.buttons["boss.close"]
        XCTAssertTrue(close.waitForExistence(timeout: 5)); XCTAssertTrue(close.isHittable)
        close.tap(); XCTAssertTrue(app.buttons["setup.bosses"].waitForExistence(timeout: 5))
        app.buttons["setup.bosses"].tap()
        let category = app.segmentedControls["boss.category"]
        reach(category, in: app); category.buttons["변이 의뢰"].tap()
        let variant = app.buttons["boss.prepare.mutation-boundary-lord-echo"]
        reach(variant, in: app); XCTAssertTrue(variant.isEnabled)
        capture("Post-clear mutation assignment", app: app); variant.tap()
        XCTAssertTrue(app.buttons["mode.exploration"].waitForExistence(timeout: 5))
        reach(app.buttons["activity.start"], in: app); XCTAssertTrue(app.buttons["activity.start"].isEnabled)
        capture("Mutation prepared", app: app)
    }
}
