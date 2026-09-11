import XCTest

final class HomeLayoutTests: XCTestCase {
    @MainActor func testHomeFitsScreen() throws {
        let app = XCUIApplication()
        app.launch()
        let run = app.buttons["home.run"]
        XCTAssertTrue(run.waitForExistence(timeout: 15))
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Home layout"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        let screen = app.windows.firstMatch.frame
        for id in ["home.profile", "home.greeting", "home.run"] {
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
        XCTAssertTrue(app.staticTexts["활동 목표"].waitForExistence(timeout: 5))
    }
    @MainActor func testGrowthNavigationAndModeLocks() {
        let app = XCUIApplication(); app.launch()
        let association = app.buttons["home.association"]
        XCTAssertTrue(association.waitForExistence(timeout: 10)); association.tap()
        XCTAssertTrue(app.staticTexts["관측부"].waitForExistence(timeout: 5))
        app.buttons["닫기"].tap()
        app.tabBars.buttons["헌터"].tap()
        app.buttons["장비 보관함"].tap()
        XCTAssertTrue(app.staticTexts["협회 지급검"].waitForExistence(timeout: 5))
        app.tabBars.buttons["RUN"].tap()
        XCTAssertTrue(app.buttons["mode.exploration"].waitForExistence(timeout: 5))
        app.buttons["mode.exploration"].tap()
        XCTAssertTrue(app.staticTexts["도시 경계의 잔향"].exists)
        XCTAssertFalse(app.buttons["mode.gate"].isEnabled)
    }
}
