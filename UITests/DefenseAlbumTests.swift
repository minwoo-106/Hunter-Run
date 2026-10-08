import XCTest

final class DefenseAlbumTests: XCTestCase {
    override func setUp() { super.setUp(); continueAfterFailure = false }
    @MainActor private func openAlbum(largeText: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing-skip-title", "--ui-testing-skip-welcome", "--ui-testing-silent-audio", "--ui-testing-simulations", "--ui-testing-defense-album", "--ui-testing-save", UUID().uuidString, "-operatorMotionEnabled", "NO"]
        if largeText { app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"] }
        app.launch()
        XCTAssertTrue(app.buttons["nav.2"].waitForExistence(timeout: 10)); app.buttons["nav.2"].tap()
        let picker = app.segmentedControls["activity.destination"]
        XCTAssertTrue(picker.waitForExistence(timeout: 5)); picker.buttons["지부 방어 작전"].tap()
        let album = app.buttons["지켜낸 일상 · 생활 앨범"]
        reach(album, in: app); album.tap()
        return app
    }
    @MainActor private func reach(_ item: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<25 {
            if item.isHittable { break }
            app.scrollViews.firstMatch.swipeUp()
        }
        XCTAssertTrue(item.isHittable)
    }
    @MainActor private func capture(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = name; shot.lifetime = .keepAlways; add(shot)
    }
    @MainActor private func assertFits(_ app: XCUIApplication) {
        let image = app.images["defense.art.image"]
        let caption = app.staticTexts["defense.art.caption"]
        XCTAssertTrue(caption.waitForExistence(timeout: 5))
        XCTAssertTrue(image.exists)
        XCTAssertGreaterThan(image.frame.height, 120)
        XCTAssertLessThanOrEqual(image.frame.maxY, caption.frame.minY + 1)
        XCTAssertTrue(app.windows.firstMatch.frame.insetBy(dx: 0, dy: 1).contains(caption.frame))
        XCTAssertFalse(app.scrollViews["defense.art.accessibleScroll"].exists)
        XCTAssertTrue(app.buttons["닫기"].isHittable)
    }
    @MainActor func testAllEightIllustrationsFitWithoutScrolling() {
        let app = openAlbum()
        for episode in [1,5,10,15,20,25,30] {
            let tile = app.buttons["defense.album.\(episode)"]
            reach(tile, in: app); tile.tap(); assertFits(app)
            capture(app, "Album-\(episode)")
            if episode == 30 {
                XCTAssertTrue(app.buttons["defense.behind"].isHittable)
                app.buttons["defense.behind"].tap(); assertFits(app)
                XCTAssertEqual(app.buttons["defense.behind"].label, "메인 일러스트")
                XCTAssertTrue(app.buttons["defense.behind"].isHittable)
                capture(app, "Album-30-behind")
            }
            app.buttons["닫기"].tap()
        }
    }
    @MainActor func testAccessibilityCaptionAndCloseRemainReachable() {
        let app = openAlbum(largeText: true)
        let tile = app.buttons["defense.album.30"]
        reach(tile, in: app); tile.tap()
        XCTAssertTrue(app.scrollViews["defense.art.accessibleScroll"].waitForExistence(timeout: 5))
        reach(app.buttons["defense.behind"], in: app); app.buttons["defense.behind"].tap()
        reach(app.buttons["defense.behind"], in: app)
        XCTAssertTrue(app.staticTexts["defense.art.caption"].exists)
        XCTAssertTrue(app.buttons["닫기"].isHittable)
        capture(app, "Album-large-text")
        app.buttons["닫기"].tap()
        XCTAssertTrue(app.buttons["defense.album.30"].exists)
    }
}
