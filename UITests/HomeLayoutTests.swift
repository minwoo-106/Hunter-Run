import XCTest

final class HomeLayoutTests: XCTestCase {
    @MainActor func testHomeFitsScreen() throws {
        let app = XCUIApplication()
        app.launch()
        let run = app.buttons["nav.2"]
        XCTAssertTrue(run.waitForExistence(timeout: 15))
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Home layout"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        let screen = app.windows.firstMatch.frame
        for id in ["home.profile", "home.greeting", "home.association"] {
            let element = app.descendants(matching: .any).matching(identifier: id).firstMatch
            XCTAssertTrue(element.exists, id)
            let frame = element.frame
            print("LAYOUT \(id) frame=\(frame) screen=\(screen)")
            XCTAssertGreaterThan(frame.width, 0, id)
            XCTAssertGreaterThanOrEqual(frame.minX, screen.minX + 15, id + " left overflow")
            XCTAssertLessThanOrEqual(frame.maxX, screen.maxX - 15, id + " right overflow")
            XCTAssertGreaterThanOrEqual(frame.minY, screen.minY, id + " top overflow")
            XCTAssertLessThanOrEqual(frame.maxY, screen.maxY, id + " bottom overflow")
        }
        XCTAssertTrue(run.isHittable)
        run.tap()
        XCTAssertTrue(app.buttons["mode.exploration"].waitForExistence(timeout: 5))
    }
    @MainActor func testGrowthNavigationAndModeLocks() {
        let app = XCUIApplication(); app.launch()
        let association = app.buttons["home.association"]
        XCTAssertTrue(association.waitForExistence(timeout: 10)); association.tap()
        XCTAssertTrue(app.staticTexts["관측부"].waitForExistence(timeout: 5))
        app.buttons["닫기"].tap()
        app.buttons["nav.1"].tap()
        app.buttons["장비 보관함"].tap()
        XCTAssertTrue(app.staticTexts["협회 지급검"].waitForExistence(timeout: 5))
        app.buttons["nav.2"].tap()
        XCTAssertTrue(app.buttons["mode.exploration"].waitForExistence(timeout: 5))
        app.buttons["mode.exploration"].tap()
        XCTAssertTrue(app.staticTexts["도시 경계의 잔향"].exists)
        XCTAssertFalse(app.buttons["mode.gate"].isEnabled)
    }
    @MainActor func testGoalSelectionAndCentralNavigation() {
        let app = XCUIApplication(); app.launch()
        XCTAssertTrue(app.buttons["nav.2"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.tabBars.firstMatch.exists)
        XCTAssertGreaterThan(app.buttons["nav.2"].frame.height, app.buttons["nav.1"].frame.height)
        app.buttons["nav.2"].tap()
        let goals = app.segmentedControls["goal.kind"]
        for _ in 0..<5 { if goals.isHittable { break }; app.scrollViews.firstMatch.swipeUp() }
        XCTAssertTrue(goals.isHittable)
        goals.buttons["거리"].tap()
        XCTAssertTrue(app.segmentedControls["goal.distance"].exists)
        app.segmentedControls["goal.distance"].buttons["5 km"].tap()
        goals.buttons["자유"].tap()
        XCTAssertTrue(app.staticTexts["goal.free.help"].exists)
        XCTAssertFalse(app.segmentedControls["goal.distance"].exists)
        goals.buttons["시간"].tap()
        XCTAssertFalse(app.staticTexts["goal.free.help"].exists)
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = "Activity goals"; shot.lifetime = .keepAlways; add(shot)
    }
    @MainActor func testEquipmentArtworkDetailsAndHistory() {
        let app = XCUIApplication(); app.launch()
        XCTAssertTrue(app.buttons["nav.1"].waitForExistence(timeout: 10)); app.buttons["nav.1"].tap()
        app.buttons["장비 보관함"].tap()
        let item = app.buttons["gear.field-blade"]
        XCTAssertTrue(item.waitForExistence(timeout: 5)); item.tap()
        XCTAssertTrue(app.navigationBars["장비 상세"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.images["협회 지급검 장비 이미지"].exists)
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = "Equipment illustration"; shot.lifetime = .keepAlways; add(shot)
        app.buttons["nav.4"].tap()
        let guide = app.buttons["활동과 성장 가이드"]
        for _ in 0..<5 { if guide.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(guide.isHittable); guide.tap()
        XCTAssertTrue(app.staticTexts["01 · 나에게 맞는 활동"].waitForExistence(timeout: 5))
    }
}
