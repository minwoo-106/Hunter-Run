import XCTest

final class CombatReleaseUITests: XCTestCase {
    override func setUp() { super.setUp(); continueAfterFailure = false }
    @MainActor private func launch(_ scenario: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing-skip-title","--ui-testing-skip-welcome","--ui-testing-silent-audio",
            "--ui-testing-simulations","--ui-testing-save",UUID().uuidString,"--ui-testing-combat",scenario,
            "-operatorMotionEnabled","NO"]
        app.launch()
        return app
    }
    @MainActor private func reach(_ element: XCUIElement, app: XCUIApplication) {
        XCTAssertTrue(element.waitForExistence(timeout:15))
        for _ in 0..<10 { if element.isHittable { break }; app.scrollViews.firstMatch.swipeUp() }
        XCTAssertTrue(element.isHittable)
    }
    @MainActor private func capture(_ name: String, app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot:app.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
    @MainActor func testRealEquipmentAttackAndDistanceLabels() {
        let app = launch("active")
        reach(app.staticTexts["activity.combat.hp"],app:app)
        XCTAssertTrue(app.staticTexts["activity.combat.hp"].label.contains("21 / 180"))
        XCTAssertTrue(app.staticTexts["activity.combat.hp"].label.contains("공격 1회"))
        XCTAssertTrue(app.staticTexts["activity.combat.distance"].label.contains("0 / 75 m"))
        capture("75m 공격 후 실제 전투 화면",app:app)
    }
    @MainActor func testWalkingExplainsHeldCombatProgress() {
        let app = launch("walking")
        reach(app.staticTexts["activity.combat.status"],app:app)
        XCTAssertTrue(app.staticTexts["activity.combat.status"].label.contains("걷기 판정"))
        XCTAssertTrue(app.staticTexts["activity.combat.hp"].label.contains("21 / 180"))
        capture("걷기 중 전투 거리 보류",app:app)
    }
    @MainActor func testPausedCombatShowsResumeAndKeepsHP() {
        let app = launch("paused")
        reach(app.staticTexts["activity.combat.status"],app:app)
        XCTAssertTrue(app.staticTexts["activity.combat.status"].label.contains("일시정지"))
        XCTAssertTrue(app.staticTexts["activity.combat.hp"].label.contains("21 / 180"))
        reach(app.buttons["계속"],app:app)
        capture("일시정지 후 전투 HP 유지",app:app)
    }
}
