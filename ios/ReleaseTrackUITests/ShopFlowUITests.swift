import XCTest

/// C11 UI 测试（QA T35–T37 的模拟器部分，Debug 假商店 -ak-store）：入口时机、预览、购买、失败分支、不可用、恢复。
/// 真实 StoreKit 由单元测试的 SKTestSession 覆盖；Apple Sandbox / TestFlight 需要用户账号（BLOCKED）。
final class ShopFlowUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    private func launch(_ scenario: String, store: String, extra: [String] = []) {
        app.launchArguments = ["-ak-scenario", scenario, "-ak-store", store] + extra
        app.launch()
        XCTAssertTrue(app.staticTexts["hud.food"].waitForExistence(timeout: 20))
    }

    private func screenshot(_ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    private func openShop() {
        let entry = app.buttons["hud.shop"]
        XCTAssertTrue(entry.waitForExistence(timeout: 5), "shop entry appears after the first Pantry")
        entry.tap()
        XCTAssertTrue(app.staticTexts["shop.garden_pack"].waitForExistence(timeout: 5))
    }

    /// R03：购买已验证但权益写盘失败——显示英文提示与 Try Again，不显示 Owned、不再显示购买按钮。
    /// 存储恢复后的重试与“只完成一次”由 ShopModelTests 覆盖。
    func testSaveFailureShowsThePromptInsteadOfSuccess() {
        launch("pantry_built", store: "ok", extra: ["-ak-fail-writes"])
        openShop()
        let buy = app.buttons["shop.buy"]
        XCTAssertTrue(buy.waitForExistence(timeout: 5))
        buy.tap()
        let note = app.staticTexts["shop.message"]
        XCTAssertTrue(note.waitForExistence(timeout: 10))
        XCTAssertEqual(note.label, "Purchase received but not saved yet. Tap Try Again. You won't be charged twice.")
        XCTAssertTrue(app.buttons["shop.retry_save"].exists)
        XCTAssertFalse(app.staticTexts["shop.owned"].exists, "not shown as delivered")
        XCTAssertFalse(app.buttons["shop.buy"].exists, "no second purchase")
        screenshot("R03-shop-save-failed")
        app.buttons["shop.retry_save"].tap()
        XCTAssertTrue(note.waitForExistence(timeout: 5), "storage still failing: prompt stays")
        XCTAssertFalse(app.staticTexts["shop.owned"].exists)
    }

    func testNoShopEntryBeforeTheFirstPantry() {
        launch("connected", store: "ok")
        XCTAssertTrue(app.buttons["hud.chapters"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["hud.shop"].exists)
    }

    func testPreviewThenBuyEquipsTheGardenStyle() {
        launch("pantry_built", store: "ok")
        openShop()
        let buy = app.buttons["shop.buy"]
        XCTAssertTrue(buy.waitForExistence(timeout: 5))
        XCTAssertEqual(buy.label, "Buy for $2.99", "price comes from the store")
        screenshot("C11-shop-ready")

        app.buttons["shop.preview"].tap()
        XCTAssertEqual(app.buttons["shop.preview"].label, "End Preview")
        screenshot("C11-shop-preview")
        app.buttons["shop.preview"].tap()

        buy.tap()
        XCTAssertTrue(app.staticTexts["shop.owned"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["shop.default"].exists, "garden style is now in use")
        screenshot("C11-shop-owned")

        app.buttons["shop.default"].tap()
        XCTAssertTrue(app.buttons["shop.equip"].waitForExistence(timeout: 3))
        app.buttons["shop.equip"].tap()
        XCTAssertTrue(app.buttons["shop.default"].waitForExistence(timeout: 3))
    }

    func testPendingAndFailedPurchasesGrantNothing() {
        for (mode, message) in [("pending", "Your purchase is awaiting approval."),
                                ("fail", "Purchase not completed. Please try again.")] {
            launch("pantry_built", store: mode)
            openShop()
            let buy = app.buttons["shop.buy"]
            XCTAssertTrue(buy.waitForExistence(timeout: 5))
            buy.tap()
            let note = app.staticTexts["shop.message"]
            XCTAssertTrue(note.waitForExistence(timeout: 5), mode)
            XCTAssertEqual(note.label, message)
            XCTAssertFalse(app.staticTexts["shop.owned"].exists, mode)
            XCTAssertTrue(app.buttons["shop.buy"].exists, "still purchasable: \(mode)")
            screenshot("C11-shop-\(mode)")
            app.terminate()
        }
    }

    func testUnavailableStoreShowsRetryAndNoPrice() {
        launch("pantry_built", store: "unavailable")
        openShop()
        XCTAssertTrue(app.staticTexts["shop.unavailable"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["shop.buy"].exists, "no fake price, no dead buy button")
        XCTAssertTrue(app.buttons["shop.retry"].exists)
        screenshot("C11-shop-unavailable")
        app.buttons["shop.close"].tap()
        // 免费游戏照常：HUD 仍在运行
        XCTAssertTrue(app.staticTexts["hud.food"].exists)
    }

    func testRestorePurchasesFromTheShop() {
        launch("pantry_built", store: "owned")
        openShop()
        app.buttons["shop.restore"].tap()
        let note = app.staticTexts["shop.message"]
        XCTAssertTrue(note.waitForExistence(timeout: 5))
        XCTAssertEqual(note.label, "Purchases restored.")
        XCTAssertTrue(app.staticTexts["shop.owned"].exists)
        screenshot("C11-shop-restored")
    }
}
