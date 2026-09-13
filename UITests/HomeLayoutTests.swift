import XCTest

final class HomeLayoutTests: XCTestCase {
    @MainActor private func application(silent: Bool = true) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing-skip-welcome", "--ui-testing-simulations", "--ui-testing-save", UUID().uuidString]
        if silent { app.launchArguments.append("--ui-testing-silent-audio") }
        return app
    }
    @MainActor private func openSettings(_ app: XCUIApplication) {
        app.buttons["nav.0"].tap()
        XCTAssertTrue(app.buttons["home.settings"].waitForExistence(timeout: 5))
        app.buttons["home.settings"].tap()
        XCTAssertTrue(app.navigationBars["설정"].waitForExistence(timeout: 5))
    }
    @MainActor func testAudioStartupKeepsNavigationResponsive() {
        let app = application(silent: false); app.launch()
        XCTAssertTrue(app.buttons["nav.1"].waitForExistence(timeout: 10))
        for index in [1, 4, 0] { app.buttons["nav.\(index)"].tap() }
        let run = app.buttons["nav.2"]
        XCTAssertTrue(run.waitForExistence(timeout: 10)); XCTAssertTrue(run.isHittable); run.tap()
        XCTAssertTrue(app.buttons["mode.exploration"].waitForExistence(timeout: 5))
        app.buttons["nav.3"].tap()
        XCTAssertTrue(app.buttons["association.bosses"].waitForExistence(timeout: 5))
        app.buttons["닫기"].tap()
    }

    @MainActor func testStoryCursorChoicesAndLockedChapters() {
        let app = application(); app.launch()
        XCTAssertTrue(app.buttons["nav.3"].waitForExistence(timeout: 10)); app.buttons["nav.3"].tap()
        let archive = app.buttons["association.stories"]
        XCTAssertTrue(archive.waitForExistence(timeout: 5)); archive.tap()
        let story = app.buttons["story.M01"]
        for _ in 0..<4 { if story.isHittable { break }; app.scrollViews.firstMatch.swipeUp() }
        XCTAssertTrue(story.isHittable); story.tap()
        XCTAssertTrue(app.staticTexts["dialogue.text"].waitForExistence(timeout: 5))
        for _ in 0..<30 {
            if app.staticTexts["이야기를 간직했어요"].exists { break }
            let choice = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "dialogue.choice.")).firstMatch
            let advance = choice.exists ? choice : app.buttons["dialogue.next"]
            for _ in 0..<4 { if advance.isHittable { break }; app.scrollViews.firstMatch.swipeUp() }
            XCTAssertTrue(advance.isHittable); advance.tap()
        }
        XCTAssertTrue(app.staticTexts["이야기를 간직했어요"].exists)
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = "Story completion"; shot.lifetime = .keepAlways; add(shot)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.staticTexts["story.counts"].exists)
        XCTAssertFalse(app.buttons["story.M02"].exists)
    }
    @MainActor func testProductionEntryHasNoSimulationButtons() {
        let app = application(); app.launchArguments.removeAll { $0 == "--ui-testing-simulations" }; app.launch()
        XCTAssertTrue(app.buttons["nav.2"].waitForExistence(timeout: 10)); app.buttons["nav.2"].tap()
        for _ in 0..<8 { app.scrollViews.firstMatch.swipeUp() }
        XCTAssertTrue(app.buttons["activity.start"].exists)
        XCTAssertFalse(app.buttons["activity.mock"].exists)
        XCTAssertFalse(app.buttons["activity.mock.boss"].exists)
        XCTAssertFalse(app.buttons["activity.mock.encounter"].exists)
    }
    @MainActor func testFirstRegistrationAcceptsCustomNamesAndOpensStory() {
        let app = application(); app.launchArguments.removeAll { $0 == "--ui-testing-skip-welcome" }; app.launch()
        let hunter = app.textFields["registration.hunter"]
        XCTAssertTrue(hunter.waitForExistence(timeout: 10)); hunter.tap(); hunter.typeText("Nova")
        let confirm = app.buttons["registration.confirm"]
        for _ in 0..<5 { if confirm.isHittable { break }; app.scrollViews.firstMatch.swipeUp() }
        XCTAssertTrue(confirm.isEnabled); confirm.tap()
        XCTAssertTrue(app.buttons["welcome.skip"].waitForExistence(timeout: 5)); app.buttons["welcome.skip"].tap()
        XCTAssertTrue(app.staticTexts["story.counts"].waitForExistence(timeout: 5))
    }

    @MainActor func testActivityNamingAndPaceProfile() {
        let app = application(); app.launch()
        XCTAssertTrue(app.buttons["nav.1"].waitForExistence(timeout: 10)); app.buttons["nav.1"].tap()
        app.buttons["hunter.pace"].tap()
        XCTAssertTrue(app.staticTexts["pace.reference"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["pace.reference"].label, "표본 수집 중")
        app.buttons["nav.0"].tap(); app.buttons["nav.2"].tap()
        XCTAssertTrue(app.navigationBars["헌터 활동 준비"].waitForExistence(timeout: 5))
        app.buttons["mode.exploration"].tap()
        let start = app.buttons["activity.start"]
        for _ in 0..<8 { if start.isHittable { break }; app.scrollViews.firstMatch.swipeUp() }
        XCTAssertTrue(start.exists); XCTAssertEqual(start.label, "현장 탐험 시작")
        XCTAssertTrue(app.buttons["activity.mock"].exists)
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
        for id in ["home.profile", "home.greeting", "home.settings"] {
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
        XCTAssertLessThanOrEqual(version.frame.maxY, run.frame.minY, "Home content overlaps central activity")
        XCTAssertFalse(app.buttons["home.run"].exists)
        let labels = ["홈", "헌터", "헌터 활동", "협회 관리", "도감"]
        for index in 0..<5 {
            XCTAssertEqual(app.buttons["nav.\(index)"].label, labels[index])
            if index > 0 { XCTAssertGreaterThan(app.buttons["nav.\(index)"].frame.midX, app.buttons["nav.\(index - 1)"].frame.midX) }
        }
        XCTAssertGreaterThanOrEqual(app.buttons["home.settings"].frame.width, 44)
        XCTAssertTrue(run.isHittable)
        app.buttons["nav.2"].tap()
        XCTAssertTrue(app.buttons["mode.exploration"].waitForExistence(timeout: 5))
    }
    @MainActor func testGrowthNavigationAndModeLocks() {
        let app = application(); app.launch()
        let association = app.buttons["nav.3"]
        XCTAssertTrue(association.waitForExistence(timeout: 10)); association.tap()
        XCTAssertTrue(app.buttons["association.bosses"].waitForExistence(timeout: 5))
        app.buttons["닫기"].tap()
        app.buttons["nav.1"].tap()
        app.buttons["장비 보관함"].tap()
        XCTAssertTrue(app.staticTexts["협회 지급검"].waitForExistence(timeout: 5))
        app.buttons["nav.0"].tap()
        app.buttons["nav.2"].tap()
        XCTAssertTrue(app.buttons["mode.exploration"].waitForExistence(timeout: 5))
        app.buttons["mode.exploration"].tap()
        XCTAssertTrue(app.staticTexts["도시 경계의 잔향"].exists)
        XCTAssertFalse(app.buttons["mode.gate"].isEnabled)
    }
    @MainActor func testGoalSelectionAndCentralNavigation() {
        let app = application(); app.launch()
        XCTAssertTrue(app.buttons["nav.3"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.tabBars.firstMatch.exists)
        XCTAssertGreaterThan(app.buttons["nav.2"].frame.height, app.buttons["nav.1"].frame.height)
        app.buttons["nav.0"].tap()
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
    @MainActor func testBossPreparationAndUndiscoveredArchive() {
        let app = application(); app.launch()
        XCTAssertTrue(app.buttons["nav.3"].waitForExistence(timeout: 10)); app.buttons["nav.3"].tap()
        app.buttons["association.bosses"].tap()
        let demo = app.buttons["boss.demo.boundary-lord"]
        for _ in 0..<7 { if demo.isHittable { break }; app.scrollViews.firstMatch.swipeUp() }
        XCTAssertTrue(demo.isHittable)
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = "Major boss board"; shot.lifetime = .keepAlways; add(shot)
        demo.tap()
        XCTAssertTrue(app.buttons["mode.exploration"].waitForExistence(timeout: 5))
        let mock = app.buttons["activity.mock.boss"]
        for _ in 0..<10 { if mock.isHittable { break }; app.scrollViews.firstMatch.swipeUp() }
        XCTAssertFalse(app.buttons["activity.start"].isEnabled)
        XCTAssertTrue(mock.isHittable); mock.tap()
        XCTAssertTrue(app.staticTexts["경계의 군주"].waitForExistence(timeout: 5))
        let end = app.buttons["활동 종료"]
        for _ in 0..<6 { if end.isHittable { break }; app.scrollViews.firstMatch.swipeUp() }
        XCTAssertTrue(end.isHittable); end.tap()
        app.buttons["저장하고 종료"].tap()
        XCTAssertTrue(app.buttons["협회로 돌아가기"].waitForExistence(timeout: 5)); app.buttons["협회로 돌아가기"].tap()
        app.buttons["nav.4"].tap()
        let monster = app.buttons["monster.echo-wolf"]
        XCTAssertTrue(monster.waitForExistence(timeout: 5)); monster.tap()
        XCTAssertTrue(app.staticTexts["아직 발견하지 못했습니다"].waitForExistence(timeout: 5))
    }
    @MainActor func testNewEncounterGuideIsReachableFromPreparation() {
        let app = application(); app.launch()
        XCTAssertTrue(app.buttons["nav.2"].waitForExistence(timeout: 10)); app.buttons["nav.2"].tap()
        let guide = app.buttons["setup.encounters"]
        for _ in 0..<6 { if guide.isHittable { break }; app.scrollViews.firstMatch.swipeUp() }
        XCTAssertTrue(guide.isHittable); guide.tap()
        XCTAssertTrue(app.navigationBars["현장 사건 안내"].waitForExistence(timeout: 5))
        let endurance = app.staticTexts["장기전 · 400m 전진"]
        for _ in 0..<6 { if endurance.isHittable { break }; app.scrollViews.firstMatch.swipeUp() }
        XCTAssertTrue(endurance.isHittable)
        let ambush = app.staticTexts["기습 대응 · 25초 유지"]
        for _ in 0..<4 { if ambush.isHittable { break }; app.scrollViews.firstMatch.swipeUp() }
        XCTAssertTrue(ambush.isHittable)
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
        openSettings(app)
        let guide = app.buttons["활동과 성장 가이드"]
        for _ in 0..<5 { if guide.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(guide.isHittable); guide.tap()
        XCTAssertTrue(app.staticTexts["01 · 나에게 맞는 활동"].waitForExistence(timeout: 5))
    }
    @MainActor func testFieldBoardPreparesMockWithoutUnlockingRealContent() {
        let app = application(); app.launch()
        XCTAssertTrue(app.buttons["nav.2"].waitForExistence(timeout: 10)); app.buttons["nav.2"].tap()
        let board = app.buttons["setup.field-intel"]
        XCTAssertTrue(board.waitForExistence(timeout: 5)); board.tap()
        let demo = app.buttons["encounter.demo.dark-elf-scout"]
        for _ in 0..<6 { if demo.isHittable { break }; app.scrollViews.firstMatch.swipeUp() }
        XCTAssertTrue(demo.isHittable)
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = "Field expansion board"; shot.lifetime = .keepAlways; add(shot)
        demo.tap()
        let mock = app.buttons["activity.mock.encounter"]
        for _ in 0..<6 { if mock.isHittable { break }; app.scrollViews.firstMatch.swipeUp() }
        XCTAssertTrue(mock.isHittable); mock.tap()
        let end = app.buttons["활동 종료"]
        XCTAssertTrue(end.waitForExistence(timeout: 5))
        for _ in 0..<6 { if end.isHittable { break }; app.scrollViews.firstMatch.swipeUp() }
        XCTAssertTrue(end.isHittable); end.tap()
        app.buttons["저장하고 종료"].tap()
        let back = app.buttons["협회로 돌아가기"]
        XCTAssertTrue(back.waitForExistence(timeout: 5)); back.tap()
        XCTAssertTrue(app.buttons["nav.0"].waitForExistence(timeout: 5))
    }

}
