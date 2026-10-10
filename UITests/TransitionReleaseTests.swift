import XCTest

final class TransitionReleaseTests: XCTestCase {
    override func setUp() { super.setUp(); continueAfterFailure = false }
    @MainActor private func app(title: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing-skip-welcome", "--ui-testing-silent-audio", "--ui-testing-save", UUID().uuidString,
            "--ui-testing-transitions", "-operatorMotionEnabled", "NO"]
        if !title { app.launchArguments.append("--ui-testing-skip-title") }
        return app
    }
    @MainActor private func ready(_ element: XCUIElement) {
        let predicate = NSPredicate { _, _ in element.exists && element.isEnabled && element.isHittable }
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: predicate, object: nil)], timeout: 15), .completed)
    }
    @MainActor private func capture(_ name: String, _ app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot()); attachment.name = name
        attachment.lifetime = .keepAlways; add(attachment)
    }
    @MainActor func testTitleEntersActualHome() {
        let app = app(title: true); app.launch()
        ready(app.buttons["title.enter"]); capture("시작 화면",app)
        app.buttons["title.enter"].tap()
        ready(app.buttons["home.settings"])
        XCTAssertFalse(app.buttons["title.enter"].exists)
        capture("게이트 진입 후 실제 홈",app)
    }
    @MainActor func testAllDestinationsRemainUsableAfterAnimation() {
        let app = app(); app.launch()
        for index in [1,2,3,4,0] {
            ready(app.buttons["nav.\(index)"]); app.buttons["nav.\(index)"].tap()
            ready(app.buttons["nav.\((index+1)%5)"])
            if index == 0 { ready(app.buttons["home.settings"]) }
            if index == 2 { ready(app.segmentedControls["activity.destination"]) }
            if index == 3 { ready(app.segmentedControls["association.section"]) }
            capture("전환 완료 \(index)",app)
        }
    }
    @MainActor func testBackgroundDuringEntranceReturnsToUsableHome() {
        let app = app(title: true); app.launch(); ready(app.buttons["title.enter"])
        app.buttons["title.enter"].tap(); XCUIDevice.shared.press(.home); app.activate()
        ready(app.buttons["home.settings"]); XCTAssertFalse(app.buttons["title.enter"].exists)
    }
    @MainActor func testBackgroundDuringTabChangeCompletesDestination() {
        let app = app(); app.launch(); ready(app.buttons["nav.3"])
        app.buttons["nav.3"].tap(); XCUIDevice.shared.press(.home); app.activate()
        ready(app.segmentedControls["association.section"])
        ready(app.buttons["nav.0"]); app.buttons["nav.0"].tap(); ready(app.buttons["home.settings"])
    }
    @MainActor func testLongBackgroundDoesNotSkipRemainingTransition() {
        let app = app(); app.launchArguments.append("--ui-testing-transition-clock"); app.launch()
        ready(app.buttons["nav.3"]); app.buttons["nav.3"].tap()
        XCUIDevice.shared.press(.home)
        // 앱 바깥에서 연출 전체 길이보다 오래 기다려도 활성 시간은 흐르지 않는다.
        Thread.sleep(forTimeInterval: 13)
        app.activate()
        XCTAssertTrue(app.staticTexts["transition.elapsed"].waitForExistence(timeout: 3))
        let elapsed = Double(app.staticTexts["transition.elapsed"].label) ?? -1
        XCTAssertGreaterThanOrEqual(elapsed, 0)
        XCTAssertLessThan(elapsed, 10, "복귀 즉시 연출이 완료되면 안 됩니다")
        ready(app.segmentedControls["association.section"])
    }
    @MainActor func testApprovedArtworkKeyFrames() {
        for (scene, progress) in [("launch","0.4"),("launch","0.63"),("hunter","0.2"),("activity","0.6"),("association","0.25"),("association","0.63")] {
            let app = app(); app.launchArguments += ["--ui-testing-transition-frame",scene,progress]; app.launch()
            XCTAssertTrue(app.staticTexts["transition.frame"].waitForExistence(timeout:15))
            capture("연출 \(scene) \(progress)",app); app.terminate()
        }
    }
}
