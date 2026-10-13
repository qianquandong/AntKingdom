import XCTest

/// C10 UI 测试（QA T33/T34 的模拟器部分）：章节页、完成卡片、解锁、切换隔离、重玩、全部重置。
/// 第二章使用仅 Debug 的测试地图（-ak-fixture-chapters），正式第二、三章等 Codex A04。
final class ChapterFlowUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    private func launch(_ scenario: String) {
        app.launchArguments = ["-ak-scenario", scenario, "-ak-fixture-chapters"]
        app.launch()
        XCTAssertTrue(app.staticTexts["hud.food"].waitForExistence(timeout: 20))
    }

    private func screenshot(_ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    /// 满仓 24 只时场景持续动画，单次元素查询可能超过 4 秒（CI run 38161170269），默认等 15 秒。
    private func waitLabel(_ element: XCUIElement, contains text: String, timeout: Double = 15) -> Bool {
        let predicate = NSPredicate(format: "label CONTAINS %@", text)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }

    /// 等元素消失（waitForExistence 在元素仍存在时会立即返回 true，不能用来断言消失）。
    private func waitGone(_ element: XCUIElement, timeout: Double = 5) -> Bool {
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: element)
        return XCTWaiter().wait(for: [gone], timeout: timeout) == .completed
    }

    private func openChapters() {
        let button = app.buttons["hud.chapters"]
        XCTAssertTrue(button.waitForExistence(timeout: 5))
        button.tap()
        XCTAssertTrue(app.buttons["chapter.row.backyard"].waitForExistence(timeout: 5))
    }

    func testFreshCampaignHasOnlyTheFirstChapterUnlocked() {
        launch("fresh")
        openChapters()
        let first = app.buttons["chapter.row.backyard"]
        let second = app.buttons["chapter.row.debug_fixture"]
        XCTAssertTrue(waitLabel(first, contains: "Playing"), first.label)
        XCTAssertTrue(second.label.contains("Complete the previous colony to unlock."), second.label)
        XCTAssertFalse(second.isEnabled, "locked chapter cannot be opened")
        screenshot("C10-chapters-fresh")
        app.buttons["chapters.close"].tap()
        XCTAssertEqual(app.staticTexts["hud.ants"].label, "Ants: 5/24")
    }

    func testCompletionUnlocksNextAndChaptersKeepSeparateState() {
        launch("replay600")
        // 600 秒固定回放后三个主目标全部达成：第一帧宣布完成
        XCTAssertTrue(app.staticTexts["chapter.complete"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.staticTexts["chapter.complete"].label, "Colony Ready!")
        screenshot("C10-colony-ready")

        app.buttons["chapter.next"].tap()
        XCTAssertTrue(waitGone(app.staticTexts["chapter.complete"]))
        XCTAssertTrue(waitLabel(app.staticTexts["hud.ants"], contains: "Ants: 5/24"))
        screenshot("C10-next-chapter")

        openChapters()
        XCTAssertTrue(waitLabel(app.buttons["chapter.row.backyard"], contains: "Completed"))
        XCTAssertTrue(waitLabel(app.buttons["chapter.row.debug_fixture"], contains: "Playing"))
        app.buttons["chapter.row.backyard"].tap()
        // 切回第一章：完成时的 24 只仍在（非活动期间不产粮，也不丢进度）
        XCTAssertTrue(waitLabel(app.staticTexts["hud.ants"], contains: "Ants: 24/24"))
        XCTAssertFalse(app.staticTexts["chapter.complete"].exists, "completion is announced once")
        XCTAssertFalse(app.staticTexts["Colony complete! Try a new layout."].exists, "core-only hint is replaced")
        screenshot("C10-back-to-backyard")
    }

    func testReplayResetsTheColonyButKeepsTheUnlock() {
        launch("replay600")
        XCTAssertTrue(app.staticTexts["chapter.complete"].waitForExistence(timeout: 10))
        app.buttons["chapter.replay"].tap()
        // iOS 26 的确认对话框里同一按钮可能匹配到多个元素：取第一个
        let confirm = app.buttons["chapter.replay.confirm"].firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        confirm.tap()
        XCTAssertTrue(waitLabel(app.staticTexts["hud.ants"], contains: "Ants: 5/24"))
        openChapters()
        XCTAssertTrue(waitLabel(app.buttons["chapter.row.backyard"], contains: "Playing"))
        XCTAssertTrue(app.buttons["chapter.row.debug_fixture"].isEnabled, "unlock stays after replay")
        screenshot("C10-replay-keeps-unlock")
    }

    func testResetAllProgressLocksChaptersAgain() {
        launch("replay600")
        XCTAssertTrue(app.staticTexts["chapter.complete"].waitForExistence(timeout: 10))
        app.buttons["chapter.keep_building"].tap()
        XCTAssertTrue(waitGone(app.staticTexts["chapter.complete"]))

        app.buttons["hud.settings"].tap()
        let reset = app.buttons["settings.reset"]
        XCTAssertTrue(reset.waitForExistence(timeout: 5))
        XCTAssertEqual(reset.label, "Reset All Progress")
        reset.tap()
        let confirm = app.buttons["dialog.reset.confirm"].firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        confirm.tap()
        XCTAssertTrue(waitLabel(app.staticTexts["hud.ants"], contains: "Ants: 5/24"))
        openChapters()
        XCTAssertFalse(app.buttons["chapter.row.debug_fixture"].isEnabled)
        screenshot("C10-reset-all")
    }
}
