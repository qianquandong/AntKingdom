import XCTest

/// C06 UI 测试：离线结算总结、前后台循环、杀进程后存档恢复（QA T22、T23、T30 的模拟器部分）。
/// 真机后台一小时/两小时、系统时间回拨由核心包测试覆盖逻辑，真机行为仍需用户验证。
final class LifecycleUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    private func screenshot(_ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    private func probeDug() -> Int? {
        let probe = app.staticTexts["debug.probe"]
        guard probe.waitForExistence(timeout: 5) else { return nil }
        return probe.label.split(separator: " ").first { $0.hasPrefix("dug=") }.flatMap { Int($0.dropFirst(4)) }
    }

    func testOfflineSummaryAfterFifteenMinutesAway() {
        app.launchArguments = ["-ak-scenario", "connected", "-ak-away", "900"]
        app.launch()
        let title = app.staticTexts["offline.title"]
        XCTAssertTrue(title.waitForExistence(timeout: 15))
        XCTAssertEqual(title.label, "Welcome Back")
        let summary = app.staticTexts["offline.summary"].label
        XCTAssertTrue(summary.hasPrefix("Your ants brought in "), summary)
        XCTAssertTrue(summary.hasSuffix(" Food."), summary)
        XCTAssertNotEqual(summary, "Your ants brought in 0 Food.")
        XCTAssertTrue(app.staticTexts["Up to 1 hour at 25% transport rate."].exists)
        screenshot("C06-offline-summary")
        app.buttons["offline.ok"].tap()
        // 等待 sheet 收起动画结束后标题消失（waitForExistence 在元素仍存在时会立刻返回 true）
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: title)
        XCTAssertEqual(XCTWaiter().wait(for: [gone], timeout: 5), .completed, "OK must close the summary")
    }

    /// 回前台路径：后台超过 60 秒再回来，弹出离线总结且 OK 能关闭（QA T23 的模拟器部分，真实等待 65 秒）。
    func testSummaryAppearsAfterReturningFromBackground() {
        app.launchArguments = ["-ak-scenario", "connected"]
        app.launch()
        XCTAssertTrue(app.staticTexts["hud.food"].waitForExistence(timeout: 15))
        let left = Date()
        XCUIDevice.shared.press(.home)
        sleep(65)
        app.activate()
        let away = Date().timeIntervalSince(left)
        let title = app.staticTexts["offline.title"]
        XCTAssertTrue(title.waitForExistence(timeout: 10), "returning after 65 s must show the summary")
        screenshot("C06-offline-after-background")
        // D-13：总结内容必须等于这一次离开的实际结算（Debug 生命周期日志），且只结算一次
        let lines = app.staticTexts["debug.lifecycle"].label.components(separatedBy: " | ")
        let paid = lines.filter { ($0.contains(" settle active ") || $0.contains(" settle gap ")) && !$0.contains("settled=0") }
        XCTAssertEqual(paid.count, 1, lines.joined(separator: " / "))
        if let line = paid.first {
            func value(_ key: String) -> Double? {
                line.split(separator: " ").first { $0.hasPrefix(key + "=") }.flatMap { Double($0.dropFirst(key.count + 1)) }
            }
            let settled = value("settled") ?? 0
            XCTAssertEqual(settled, away, accuracy: 3, line)
            XCTAssertEqual(app.staticTexts["offline.summary"].label,
                           "Your ants brought in \(Int((value("hauled") ?? -1).rounded(.down))) Food.")
        }
        app.buttons["offline.ok"].tap()
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: title)
        XCTAssertEqual(XCTWaiter().wait(for: [gone], timeout: 5), .completed, "OK must close the summary")
    }

    func testBackgroundForegroundCyclesStayResponsive() {
        app.launchArguments = ["-ak-scenario", "connected"]
        app.launch()
        XCTAssertTrue(app.staticTexts["hud.food"].waitForExistence(timeout: 15))
        for _ in 0..<5 {
            XCUIDevice.shared.press(.home)
            sleep(1)
            app.activate()
            XCTAssertTrue(app.staticTexts["hud.food"].waitForExistence(timeout: 10))
        }
        XCTAssertFalse(app.staticTexts["offline.title"].exists, "short trips away must not show a summary")
        XCTAssertEqual(probeDug(), 3)
    }

    func testDugCellSurvivesProcessKill() throws {
        app.launchArguments = ["-ak-reset-save"]
        app.launch()
        XCTAssertTrue(app.staticTexts["hud.food"].waitForExistence(timeout: 15))
        let probe = app.staticTexts["debug.probe"]
        XCTAssertTrue(probe.waitForExistence(timeout: 5))
        var values: [String: String] = [:]
        for part in probe.label.split(separator: " ") {
            let pair = part.split(separator: "=", maxSplits: 1)
            if pair.count == 2 { values[String(pair[0])] = String(pair[1]) }
        }
        let origin = try XCTUnwrap(values["origin"]).split(separator: ",").compactMap { Double($0) }
        let tile = try XCTUnwrap(Double(values["tile"] ?? ""))
        for _ in 0..<3 {
            app.coordinate(withNormalizedOffset: .zero)
                .withOffset(CGVector(dx: origin[0] + 3.5 * tile, dy: origin[1] + 1.5 * tile)).tap()   // (3,1)
            usleep(250_000)
        }
        XCTAssertEqual(probeDug(), 1)
        app.terminate()
        app.launchArguments = []
        app.launch()
        XCTAssertTrue(app.staticTexts["hud.food"].waitForExistence(timeout: 15))
        XCTAssertEqual(probeDug(), 1, "the dug cell must survive a process kill")
        screenshot("C06-after-relaunch")
    }
}
