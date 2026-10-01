import XCTest

final class OperatorLifeUITests: XCTestCase {
    override func setUp() { super.setUp(); continueAfterFailure = false }
    @MainActor private func app(_ extra: [String] = [], moving: Bool = true) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing-skip-title", "--ui-testing-skip-welcome", "--ui-testing-silent-audio",
            "--ui-testing-save", UUID().uuidString, "-operatorMotionEnabled", moving ? "YES" : "NO"] + extra
        app.launch()
        XCTAssertTrue(app.buttons["home.operator"].waitForExistence(timeout: 15))
        return app
    }
    @MainActor private func wait(_ phase: String, _ app: XCUIApplication, seconds: Double = 20) {
        let predicate = NSPredicate(format: "value == %@ OR value BEGINSWITH %@", phase, phase + "|")
        expectation(for: predicate, evaluatedWith: app.buttons["home.operator"])
        waitForExpectations(timeout: seconds)
    }
    @MainActor private func capture(_ name: String, _ app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
    @MainActor func testNaturalSequenceConsumesWakeTapAndReturnsToIdle() {
        let app = app()
        wait("dozing", app)
        Thread.sleep(forTimeInterval: 4) // capture settled shoulders/eyes, not the beginning of dozing
        capture("Natural dozing", app)
        app.buttons["home.operator"].tap()
        wait("embarrassed", app, seconds: 8)
        app.buttons["home.operator"].tap()
        XCTAssertFalse(app.buttons["operator.continue"].exists)
        XCTAssertTrue(app.staticTexts["home.greeting"].label.contains("오셨어요") || app.staticTexts["home.greeting"].label.contains("저 안 잤어요"))
        capture("Wake reaction", app)
        wait("idle", app, seconds: 10)
        XCTAssertFalse(app.staticTexts["home.greeting"].label.contains("저 안 잤어요"))
    }
    @MainActor func testBackgroundAndSettingsDoNotStealCharacterTap() {
        let app = app(["--life-inspect-clock"]); wait("idle", app)
        let before = activeTime(app)
        XCUIDevice.shared.press(.home)
        XCTAssertTrue(app.wait(for: .runningBackground, timeout: 2)
                      || app.wait(for: .runningBackgroundSuspended, timeout: 3))
        Thread.sleep(forTimeInterval: 10) // longer than idle duration; offscreen time must not count
        app.activate()
        let elapsed = activeTime(app) - before
        print("LIFE_BACKGROUND active-time increase: \(elapsed), suspended seconds: 10")
        XCTAssertGreaterThanOrEqual(elapsed, 0)
        XCTAssertLessThan(elapsed, 8, "Suspended time must not enter the life clock")
        // Slow automation may reach the idle/doze boundary before pressing Home.
        // Assert the clock rather than demanding one short-lived pose on return.
        wait("dozing", app)
        app.buttons["home.settings"].tap()
        XCTAssertTrue(app.navigationBars["설정"].waitForExistence(timeout: 5))
        app.buttons["닫기"].tap(); wait("dozing", app, seconds: 5)
        app.buttons["home.operator"].tap(); wait("embarrassed", app, seconds: 8)
        capture("Resumed reaction", app)
    }
    @MainActor private func activeTime(_ app: XCUIApplication) -> Double {
        let parts = (app.buttons["home.operator"].value as? String ?? "").split(separator: "|")
        XCTAssertEqual(parts.count, 2, "Life clock diagnostic must be available")
        return Double(parts.last.map(String.init) ?? "") ?? .nan
    }
    @MainActor func testReducedMotionAndMotionOffPreserveInteraction() {
        let reduced = app(["--life-reduce-motion"])
        wait("dozing", reduced); capture("Reduce Motion static doze", reduced)
        reduced.buttons["home.operator"].tap(); wait("embarrassed", reduced, seconds: 8)
        reduced.terminate()
        let stopped = app(moving: false)
        XCTAssertEqual(stopped.buttons["home.operator"].value as? String, "idle")
        stopped.buttons["home.operator"].tap()
        XCTAssertTrue(stopped.buttons["operator.continue"].waitForExistence(timeout: 5))
    }
    @MainActor func testPoseCanvasAndHomeControls() {
        for phase in ["stretching", "idle", "dozing", "surprised", "embarrassed", "coffee", "tablet", "spacingOut", "hairSweep", "burger", "burgerSurprised", "burgerFlustered", "cola"] {
            let app = app(["--life-inspect-phase", phase])
            let character = app.buttons["home.operator"]
            for id in ["home.settings", "home.stories", "nav.0", "nav.2"] {
                let control = app.buttons[id]
                XCTAssertTrue(control.isHittable, id)
                XCTAssertFalse(character.frame.intersects(control.frame), id)
            }
            capture("Home pose " + phase, app)
            app.terminate()
        }
    }
    @MainActor func testLunchInterruptionAndBackgroundRecovery() {
        let app = app(["--life-start-phase", "burger"])
        wait("burger", app); capture("Lunch eating", app)
        XCUIDevice.shared.press(.home); Thread.sleep(forTimeInterval: 6)
        app.activate(); wait("burger", app, seconds: 3)
        app.buttons["home.operator"].tap()
        wait("burgerFlustered", app, seconds: 5)
        app.buttons["home.operator"].tap()
        XCTAssertFalse(app.buttons["operator.continue"].exists)
        capture("Lunch chest pat", app)
        wait("cola", app, seconds: 5)
        app.buttons["home.operator"].tap()
        XCTAssertFalse(app.buttons["operator.continue"].exists)
        capture("Lunch cola", app)
        wait("idle", app, seconds: 8)
    }

    @MainActor func testFullActivityRotationAndNavigationRecovery() {
        // Exercise real consecutive textures in one process, rather than
        // treating isolated pose screenshots as a full-cycle memory check.
        // Enter the rotation through the real wake path. A forced coffee pose
        // does not seed the activity cursor and would replay coffee first.
        let app = app(["--life-inspect-history"])
        let rotation = ["coffee", "tablet", "spacingOut", "hairSweep", "burger"]
        wait("dozing", app)
        app.buttons["home.operator"].tap()
        wait("idle", app, seconds: 10)
        for phase in rotation {
            // A simulator AX snapshot can take longer than coffee/hairSweep.
            // Observe the runtime's real publication history, not an expected
            // sequence generated by the fixture or artificially longer poses.
            expectation(for: NSPredicate(format: "value CONTAINS %@", "," + phase + ","),
                        evaluatedWith: app.buttons["home.operator"])
            waitForExpectations(timeout: 30)
        }
        let value = app.buttons["home.operator"].value as? String ?? ""
        let history = value.components(separatedBy: "|seen=,").last ?? ""
        let observed = history.split(separator: ",").map(String.init).filter { rotation.contains($0) }
        XCTAssertEqual(observed, rotation, "Every live activity must appear once in the authored order")
        wait("burger", app, seconds: 5)
        app.buttons["nav.1"].tap()
        XCTAssertFalse(app.buttons["home.operator"].isHittable)
        app.buttons["nav.0"].tap()
        wait("burger", app, seconds: 5)
        app.buttons["home.operator"].tap()
        wait("cola", app, seconds: 10)
        capture("Full cycle cola", app)
        wait("idle", app, seconds: 8)
    }

}
