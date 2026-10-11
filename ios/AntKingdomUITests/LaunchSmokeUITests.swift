import XCTest

/// C04 UI 测试：HUD、点击挖掘、拖动不误挖、实体选中与面板。
/// 通过 Debug 构建的 `debug.probe` 读取地图在屏幕上的位置，再按格坐标点击（不假定机型尺寸）。
final class LaunchSmokeUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    private func launch(_ scenario: String = "fresh") {
        app.launchArguments = ["-ak-scenario", scenario]
        app.launch()
        XCTAssertTrue(app.staticTexts["hud.food"].waitForExistence(timeout: 15))
    }

    private struct Probe {
        let originX: Double, originY: Double, tile: Double, dug: Int, shown: [String]
    }

    private func probe() throws -> Probe {
        let element = app.staticTexts["debug.probe"]
        XCTAssertTrue(element.waitForExistence(timeout: 5))
        var values: [String: String] = [:]
        for part in element.label.split(separator: " ") {
            let pair = part.split(separator: "=", maxSplits: 1)
            if pair.count == 2 { values[String(pair[0])] = String(pair[1]) }
        }
        let origin = try XCTUnwrap(values["origin"]).split(separator: ",").compactMap { Double($0) }
        return Probe(originX: origin[0], originY: origin[1], tile: try XCTUnwrap(Double(values["tile"] ?? "")),
                     dug: try XCTUnwrap(Int(values["dug"] ?? "")),
                     shown: (values["shown"] ?? "").split(separator: ",").map(String.init))
    }

    private func waitProbe(timeout: Double = 5, _ condition: (Probe) -> Bool) throws -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            if condition(try probe()) { return true }
            usleep(200_000)
        } while Date() < deadline
        return condition(try probe())
    }

    private func tapCell(_ x: Int, _ y: Int) throws {
        let p = try probe()
        let point = CGVector(dx: p.originX + (Double(x) + 0.5) * p.tile, dy: p.originY + (Double(y) + 0.5) * p.tile)
        app.coordinate(withNormalizedOffset: .zero).withOffset(point).tap()
    }

    private func screenshot(_ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    func testColdLaunchShowsEnglishHUD() {
        launch()
        // 开局 0 Food，但地面兜底立刻开始搬运，读到 HUD 时可能已有几粒
        let food = app.staticTexts["hud.food"].label
        XCTAssertTrue(food.hasPrefix("Food: ") && food.hasSuffix("/100"), food)
        XCTAssertLessThan(Int(food.dropFirst(6).prefix { $0.isNumber }) ?? 999, 20)
        XCTAssertEqual(app.staticTexts["hud.ants"].label, "Ants: 5/24")
        XCTAssertEqual(app.staticTexts["hud.eggs"].label, "Eggs: 0")
        XCTAssertTrue(app.staticTexts["hint.tutorial.dig"].exists || app.otherElements["hint.tutorial.dig"].exists)
        screenshot("C04-cold-launch")
    }

    func testThreeTapsPerCellConnectCookie() throws {
        launch()
        for cell in [(2, 4), (2, 5), (2, 6)] {
            for _ in 0..<3 {
                try tapCell(cell.0, cell.1)
                usleep(200_000)   // 低于每秒 8 次的逻辑上限
            }
        }
        // 提示条只显示约 2.6 秒，慢 runner 上一次元素查询可能更久（CI 38174451505）：由探针确认提示已发出（T-04）
        XCTAssertTrue(try waitProbe { $0.shown.contains("feedback.connected") }, "connected feedback shown")
        XCTAssertEqual(try probe().dug, 3)
        XCTAssertTrue(app.staticTexts["hud.source"].label.contains("Cookie Crumb") ||
                      app.otherElements["hud.source"].label.contains("Cookie Crumb"))
        screenshot("C04-cookie-connected")
    }

    func testDraggingTheMapNeverDigs() throws {
        launch()
        let map = app.otherElements["map"].exists ? app.otherElements["map"] : app.windows.firstMatch
        let start = map.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(forDuration: 0.05, thenDragTo: map.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.45)))
        start.press(forDuration: 0.05, thenDragTo: map.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.55)))
        sleep(1)
        XCTAssertEqual(try probe().dug, 0)
    }

    func testSelectingSourceAndQueenShowsPanels() throws {
        launch()
        try tapCell(0, 6)
        XCTAssertTrue(app.staticTexts["panel.source.title"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["panel.source.title"].label, "Cookie Crumb")
        XCTAssertTrue(app.staticTexts["Remaining: 600"].exists)
        screenshot("C04-source-panel")
        app.buttons["panel.source.close"].tap()
        XCTAssertFalse(app.staticTexts["panel.source.title"].waitForExistence(timeout: 1))
        XCTAssertEqual(try probe().dug, 0, "closing a panel over the map must not dig")

        try tapCell(4, 3)
        XCTAssertTrue(app.staticTexts["panel.queen.title"].waitForExistence(timeout: 5))
        let toggle = app.buttons["panel.queen.toggle"]
        XCTAssertEqual(toggle.label, "Pause Hatching")
        toggle.tap()
        XCTAssertEqual(app.buttons["panel.queen.toggle"].label, "Resume Hatching")
        screenshot("C04-queen-panel")
    }

    func testBusyTunnelIsMarked() {
        launch("busy")
        XCTAssertTrue(app.staticTexts["hud.busy"].waitForExistence(timeout: 5)
                      || app.otherElements["hud.busy"].waitForExistence(timeout: 1))
        screenshot("C04-busy-tunnel")
    }
}
