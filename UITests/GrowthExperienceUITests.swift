import XCTest

final class GrowthExperienceUITests: XCTestCase {
    override func setUp() { super.setUp(); continueAfterFailure = false }
    @MainActor private func launch(_ scene: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing-skip-title", "--ui-testing-skip-welcome", "--ui-testing-silent-audio",
            "--ui-testing-simulations", "--ui-testing-save", UUID().uuidString, "--ui-testing-growth", scene,
            "-operatorMotionEnabled", "NO"]
        app.launch(); return app
    }
    @MainActor private func reach(_ element: XCUIElement, app: XCUIApplication) {
        XCTAssertTrue(element.waitForExistence(timeout: 15))
        for _ in 0..<12 {
            if element.isHittable { return }
            let scroll = app.scrollViews.firstMatch
            let above = element.frame.midY < scroll.frame.midY
            let from = scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: above ? 0.35 : 0.7))
            let to = scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: above ? 0.65 : 0.4))
            from.press(forDuration: 0.05, thenDragTo: to)
        }
        XCTAssertTrue(element.isHittable)
    }
    @MainActor private func capture(_ name: String, app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot()); attachment.name = name
        attachment.lifetime = .keepAlways; add(attachment)
    }
    @MainActor func testWeeklyRunningAndGrowthReport() {
        let app = launch("report")
        reach(app.buttons["hunter.report"], app: app); app.buttons["hunter.report"].tap()
        XCTAssertTrue(app.staticTexts["나의 활동 리포트"].waitForExistence(timeout: 10))
        capture("운동 리포트_거리와활동일", app: app)
        app.scrollViews.firstMatch.swipeUp(); capture("운동 리포트_게임성장", app: app)
    }
    @MainActor func testEquipmentTargetAndRealCombatComparison() {
        let app = launch("equipment")
        reach(app.buttons["hunter.equipment"], app: app); app.buttons["hunter.equipment"].tap()
        XCTAssertTrue(app.staticTexts["다음 목표 장비"].waitForExistence(timeout: 10))
        capture("장비보관함_목표장비", app: app)
        let gear = app.buttons["gear.core-spear"]
        reach(gear, app: app); gear.tap()
        reach(app.buttons["gear.lab.open"], app: app); capture("장비상세_실제능력비교", app: app)
        app.buttons["gear.lab.open"].tap()
        reach(app.staticTexts["gear.lab.estimate"], app: app)
        capture("장비시험실_공격횟수와거리", app: app)
        reach(app.buttons["gear.lab.play"], app: app); app.buttons["gear.lab.play"].tap()
        XCTAssertTrue(app.staticTexts["gear.lab.estimate"].exists)
    }
    @MainActor func testEquipmentPresetsCanSaveAndApply() {
        let app = launch("equipment")
        reach(app.buttons["hunter.equipment"], app: app); app.buttons["hunter.equipment"].tap()
        let disclosure = app.buttons["장비 조합 · 출발 전에 한 번에 착용"]
        reach(disclosure, app: app); disclosure.tap()
        reach(app.buttons["gear.preset.save.1"], app: app); app.buttons["gear.preset.save.1"].tap()
        XCTAssertTrue(app.buttons["gear.preset.apply.1"].isEnabled)
        app.buttons["gear.preset.apply.1"].tap(); capture("장비조합_저장과착용", app: app)
    }
    @MainActor func testAllRankCeremoniesFinishAndShowUnlocks() {
        for rank in ["D", "C", "B", "A", "S"] {
            let app = launch("rank-" + rank)
            let done = app.buttons["growth.celebration.close"]
            reach(done, app: app)
            capture("승급_" + rank, app: app)
            reach(app.buttons["growth.unlocks"], app: app); app.buttons["growth.unlocks"].tap()
            reach(app.staticTexts["새로 열린 가능성"], app: app)
            if rank == "D" { capture("승급후_콘텐츠해금", app: app) }
            app.terminate()
        }
    }
    @MainActor func testRankPresentationCompletesAfterBackgroundResume() {
        let app = launch("rank-S")
        XCUIDevice.shared.press(.home)
        app.activate()
        reach(app.buttons["growth.celebration.close"], app: app)
        XCTAssertTrue(app.staticTexts["S급 헌터"].exists)
        app.buttons["growth.celebration.close"].tap()
        XCTAssertFalse(app.buttons["growth.celebration.close"].exists)
    }
    @MainActor func testAcquisitionAndActivityGrowth() {
        let app = launch("acquired")
        reach(app.buttons["growth.celebration.close"], app: app)
        capture("첫장비획득", app: app)
        app.buttons["growth.celebration.close"].tap()
        let history = app.buttons["활동 기록 전체 보기"]
        reach(history, app: app); history.tap()
        let first = app.scrollViews.buttons.matching(NSPredicate(format: "label CONTAINS %@", "목표 완료")).firstMatch
        reach(first, app: app); first.tap()
        reach(app.staticTexts["활동 보상 확보"], app: app)
        capture("활동상세_보상정산", app: app)
        reach(app.staticTexts["오늘의 성장"], app: app)
        capture("활동상세_오늘의성장", app: app)
    }
}
