import XCTest

final class HomeLayoutTests: XCTestCase {
    @MainActor private func application(silent: Bool = true) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing-skip-welcome"]
        if silent { app.launchArguments.append("--ui-testing-silent-audio") }
        return app
    }
    @MainActor func testAudioStartupKeepsNavigationResponsive() {
        let app = application(silent: false); app.launch()
        XCTAssertTrue(app.buttons["nav.1"].waitForExistence(timeout: 10))
        for index in [1, 3, 4, 0] { app.buttons["nav.\(index)"].tap() }
        let run = app.buttons["home.run"]
        XCTAssertTrue(run.waitForExistence(timeout: 10)); XCTAssertTrue(run.isHittable); run.tap()
        XCTAssertTrue(app.buttons["mode.exploration"].waitForExistence(timeout: 5))
        app.buttons["nav.2"].tap()
        XCTAssertTrue(app.buttons["association.bosses"].waitForExistence(timeout: 5))
        app.buttons["닫기"].tap()
    }

    @MainActor func testStoryReadingLocksAndWelcomeReplay() {
        let app = application(); app.launch()
        XCTAssertTrue(app.buttons["nav.2"].waitForExistence(timeout: 10))
        app.buttons["nav.2"].tap()
        let archive = app.buttons["association.stories"]
        XCTAssertTrue(archive.waitForExistence(timeout: 5)); archive.tap()
        app.buttons["story.arrival"].tap()
        let read = app.buttons["story.read"]
        for _ in 0..<6 { if read.isHittable { break }; app.scrollViews.firstMatch.swipeUp() }
        XCTAssertTrue(read.isHittable)
        if read.isEnabled { read.tap() }
        XCTAssertFalse(read.isEnabled)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["story.signal"].tap()
        XCTAssertTrue(app.staticTexts["story.locked"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.buttons["닫기"].waitForExistence(timeout: 5))
        app.buttons["닫기"].tap()
        app.buttons["nav.4"].tap()
        let welcome = app.buttons["settings.welcome"]
        for _ in 0..<6 { if welcome.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(welcome.isHittable); welcome.tap()
        XCTAssertTrue(app.buttons["welcome.skip"].waitForExistence(timeout: 5))
        for _ in 0..<3 {
            let next = app.buttons["welcome.next"]
            for _ in 0..<4 { if next.isHittable { break }; app.scrollViews.firstMatch.swipeUp() }
            XCTAssertTrue(next.isHittable); next.tap()
            XCTAssertTrue(app.buttons["welcome.skip"].exists)
        }
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = "Welcome permissions"; shot.lifetime = .keepAlways; add(shot)
        app.buttons["welcome.skip"].tap()
        XCTAssertTrue(app.buttons["nav.0"].waitForExistence(timeout: 5)); app.buttons["nav.0"].tap()
        app.terminate(); app.launchArguments.removeAll { $0 == "--ui-testing-skip-welcome" }; app.launch()
        XCTAssertTrue(app.buttons["nav.0"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["welcome.skip"].exists)
    }

    @MainActor func testHomeFitsScreen() throws {
        let app = application()
        app.launch()
        let run = app.buttons["nav.2"]
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
        let version = app.staticTexts["home.version"]
        XCTAssertTrue(version.exists)
        print("LAYOUT home.version frame=\(version.frame) nav=\(run.frame)")
        XCTAssertLessThanOrEqual(version.frame.maxY, run.frame.minY, "Home content overlaps central association")
        XCTAssertLessThanOrEqual(app.buttons["home.run"].frame.maxY, run.frame.minY, "Association button overlaps central association")
        XCTAssertTrue(run.isHittable)
        app.buttons["home.run"].tap()
        XCTAssertTrue(app.buttons["mode.exploration"].waitForExistence(timeout: 5))
    }
    @MainActor func testGrowthNavigationAndModeLocks() {
        let app = application(); app.launch()
        let association = app.buttons["nav.2"]
        XCTAssertTrue(association.waitForExistence(timeout: 10)); association.tap()
        XCTAssertTrue(app.buttons["association.bosses"].waitForExistence(timeout: 5))
        app.buttons["닫기"].tap()
        app.buttons["nav.1"].tap()
        app.buttons["장비 보관함"].tap()
        XCTAssertTrue(app.staticTexts["협회 지급검"].waitForExistence(timeout: 5))
        app.buttons["nav.0"].tap()
        app.buttons["home.run"].tap()
        XCTAssertTrue(app.buttons["mode.exploration"].waitForExistence(timeout: 5))
        app.buttons["mode.exploration"].tap()
        XCTAssertTrue(app.staticTexts["도시 경계의 잔향"].exists)
        XCTAssertFalse(app.buttons["mode.gate"].isEnabled)
    }
    @MainActor func testGoalSelectionAndCentralNavigation() {
        let app = application(); app.launch()
        XCTAssertTrue(app.buttons["nav.2"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.tabBars.firstMatch.exists)
        XCTAssertGreaterThan(app.buttons["nav.2"].frame.height, app.buttons["nav.1"].frame.height)
        app.buttons["nav.0"].tap()
        app.buttons["home.run"].tap()
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
    @MainActor func testBossPreparationAndUndiscoveredArchive() {
        let app = application(); app.launch()
        XCTAssertTrue(app.buttons["nav.2"].waitForExistence(timeout: 10)); app.buttons["nav.2"].tap()
        app.buttons["association.bosses"].tap()
        let demo = app.buttons["boss.demo.boundary-lord"]
        for _ in 0..<7 { if demo.isHittable { break }; app.scrollViews.firstMatch.swipeUp() }
        XCTAssertTrue(demo.isHittable)
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = "Major boss board"; shot.lifetime = .keepAlways; add(shot)
        demo.tap()
        XCTAssertTrue(app.buttons["mode.exploration"].waitForExistence(timeout: 5))
        let mock = app.buttons["3분 모의 러닝"]
        for _ in 0..<10 { if mock.isHittable { break }; app.scrollViews.firstMatch.swipeUp() }
        XCTAssertFalse(app.buttons["START RUN"].isEnabled)
        XCTAssertTrue(mock.isHittable); mock.tap()
        XCTAssertTrue(app.staticTexts["경계의 군주"].waitForExistence(timeout: 5))
        let end = app.buttons["활동 종료"]
        for _ in 0..<6 { if end.isHittable { break }; app.scrollViews.firstMatch.swipeUp() }
        XCTAssertTrue(end.isHittable); end.tap()
        app.buttons["저장하고 종료"].tap()
        XCTAssertTrue(app.buttons["협회로 돌아가기"].waitForExistence(timeout: 5)); app.buttons["협회로 돌아가기"].tap()
        app.buttons["nav.3"].tap()
        let monster = app.buttons["monster.echo-wolf"]
        XCTAssertTrue(monster.waitForExistence(timeout: 5)); monster.tap()
        XCTAssertTrue(app.staticTexts["아직 발견하지 못했습니다"].waitForExistence(timeout: 5))
    }
    @MainActor func testEquipmentArtworkDetailsAndHistory() {
        let app = application(); app.launch()
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
