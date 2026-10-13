import XCTest

/// C12 UI 测试（QA T40/T42 的模拟器部分，Debug 假广告 -ak-ads；-ak-reward-ready 代替真实等待 600 秒前台）。
/// 真实 AdMob 测试广告、UMP 表单、后台/跨日需要网络与设备（见 M5 报告）。
final class RewardFlowUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    private func launch(_ scenario: String, ads: String, ready: Bool = true, extra: [String] = []) {
        app.launchArguments = ["-ak-scenario", scenario, "-ak-ads", ads] + (ready ? ["-ak-reward-ready"] : []) + extra
        app.launch()
        XCTAssertTrue(app.staticTexts["hud.food"].waitForExistence(timeout: 20))
    }

    private func screenshot(_ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    private func waitGone(_ element: XCUIElement, timeout: Double = 8) -> Bool {
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: element)
        return XCTWaiter().wait(for: [gone], timeout: timeout) == .completed
    }

    private func openReward() {
        let entry = app.buttons["hud.reward"]
        XCTAssertTrue(entry.waitForExistence(timeout: 8))
        entry.tap()
        XCTAssertTrue(app.staticTexts["reward.title"].waitForExistence(timeout: 5))
    }

    func testWatchingGrantsTheBoostAndShowsItSeparately() {
        launch("pantry_built", ads: "twice")
        openReward()
        XCTAssertEqual(app.staticTexts["reward.title"].label, "Foraging Boost")
        screenshot("C12-reward-ready")
        app.buttons["reward.watch"].tap()
        // 获得后面板自动关闭；HUD 入口显示剩余时间
        XCTAssertTrue(waitGone(app.staticTexts["reward.title"]))
        let entry = app.buttons["hud.reward"]
        XCTAssertTrue(entry.label.hasPrefix("Boost: "), entry.label)
        XCTAssertTrue(entry.label.hasSuffix("remaining"), entry.label)
        screenshot("C12-boost-active")
        entry.tap()
        XCTAssertTrue(app.staticTexts["reward.active"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["reward.watch"].exists, "no stacking while active")
        screenshot("C12-reward-active-panel")
    }

    /// R04：已赚得奖励但写盘失败——boost 生效，面板不关闭，显示英文提示与 Try Again（只重试写盘，不再看广告）。
    /// 存储恢复后的写入、次数与冷却由 RewardModelTests / RewardTests 覆盖。
    func testSaveFailureKeepsTheBoostAndOffersRetry() {
        launch("pantry_built", ads: "earn", extra: ["-ak-fail-writes"])
        openReward()
        app.buttons["reward.watch"].tap()
        let note = app.staticTexts["reward.message"]
        XCTAssertTrue(note.waitForExistence(timeout: 10))
        XCTAssertEqual(note.label, "Your boost is on, but it couldn't be saved. Tap Try Again.")
        XCTAssertTrue(app.buttons["reward.retry_save"].exists)
        XCTAssertTrue(app.staticTexts["reward.active"].exists, "the earned boost is active")
        XCTAssertFalse(app.buttons["reward.watch"].exists, "no second ad needed")
        screenshot("R04-reward-save-failed")
        app.buttons["reward.retry_save"].tap()
        XCTAssertTrue(note.waitForExistence(timeout: 5), "storage still failing: prompt stays")
    }

    func testClosingEarlyGivesNothingAndFreePlayContinues() {
        launch("pantry_built", ads: "close")
        openReward()
        app.buttons["reward.watch"].tap()
        let watch = app.buttons["reward.watch"]
        XCTAssertTrue(watch.waitForExistence(timeout: 8), "still offered after closing early")
        XCTAssertFalse(app.buttons["hud.reward"].label.hasPrefix("Boost: "))
        app.buttons["reward.not_now"].tap()
        XCTAssertTrue(app.staticTexts["hud.food"].exists)
    }

    func testNoFillShowsAFriendlyMessage() {
        launch("pantry_built", ads: "nofill")
        openReward()
        app.buttons["reward.watch"].tap()
        let message = app.staticTexts["reward.message"]
        XCTAssertTrue(message.waitForExistence(timeout: 8))
        XCTAssertEqual(message.label, "No ad available. You can keep playing.")
        screenshot("C12-reward-nofill")
    }

    func testNoEntryBeforeUnlockOrWhenStorageIsFull() {
        launch("pantry_built", ads: "earn", ready: false)
        XCTAssertTrue(app.buttons["hud.shop"].waitForExistence(timeout: 8))
        XCTAssertFalse(app.buttons["hud.reward"].exists, "locked before 600 s of active play")
        app.terminate()
        launch("replay600", ads: "earn")
        XCTAssertTrue(app.buttons["hud.chapters"].waitForExistence(timeout: 8))
        XCTAssertFalse(app.buttons["hud.reward"].exists, "no ad prompt at full storage")
    }
}
