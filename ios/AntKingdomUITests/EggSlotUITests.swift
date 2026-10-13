import XCTest

/// D-16 E01 / E02（真实 App，Debug 场景）：读调试探针的 `eggs=`（活着的卵占用的槽，按创建顺序），
/// 确认先孵化的那枚只移除自己、另一枚留在原槽，新订单占空出的槽。节点位置与身份由 EggClutchTests 断言；
/// 这里另截固定镜头原尺寸（24 pt 卵）与最大缩放截图。CI 另录 eggs_two / eggs_refill 两段录像。
final class EggSlotUITests: XCTestCase {
    private var device: String { ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"] ?? "device" }

    private func eggSlots(_ app: XCUIApplication) -> String? {
        app.staticTexts["debug.probe"].label.split(separator: " ")
            .first { $0.hasPrefix("eggs=") }.map { String($0.dropFirst(5)) }
    }

    private func shot(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "D16-\(name)-\(device)"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// 每 0.5 秒记录一次槽序列的变化，直到出现 `until` 或超时
    private func observe(_ app: XCUIApplication, until: String, timeout: TimeInterval) -> [String] {
        var seen: [String] = []
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if let value = eggSlots(app), value != seen.last { seen.append(value) }
            if seen.last == until { break }
            usleep(500_000)
        }
        return seen
    }

    func testE01SecondEggStaysInItsSlotWhileTheFirstHatches() {
        let app = XCUIApplication()
        app.launchArguments = ["-ak-scenario", "eggs_two"]
        app.launch()
        XCTAssertTrue(app.staticTexts["hud.food"].waitForExistence(timeout: 20))
        XCTAssertEqual(eggSlots(app), "0,1")
        shot(app, "E01-two-eggs")
        let seen = observe(app, until: "-", timeout: 40)
        XCTAssertEqual(seen.first, "0,1", seen.joined(separator: " → "))
        XCTAssertTrue(seen.contains("1"), "after the left egg hatches only slot 1 remains: \(seen)")
        XCTAssertFalse(seen.contains("0"), "the right egg must never be redrawn in the left slot: \(seen)")
        XCTAssertEqual(seen.last, "-", seen.joined(separator: " → "))
        app.terminate()
    }

    func testE02NewEggTakesTheFreedSlot() {
        let app = XCUIApplication()
        app.launchArguments = ["-ak-scenario", "eggs_refill"]
        app.launch()
        XCTAssertTrue(app.staticTexts["hud.food"].waitForExistence(timeout: 20))
        let seen = observe(app, until: "1,0", timeout: 35)
        XCTAssertEqual(seen.first, "0,1", seen.joined(separator: " → "))
        XCTAssertEqual(seen.last, "1,0", "old right egg first, new egg in the freed left slot: \(seen)")
        XCTAssertFalse(seen.contains("0"), "no compaction into the left slot: \(seen)")
        shot(app, "E02-refilled")
        app.terminate()
    }

    /// 固定镜头：原尺寸（默认缩放，卵 24 pt）与最大缩放（1.6 倍）
    func testEggCloseUps() {
        for (label, zoom) in [("default", [String]()), ("zoom-max", ["-ak-zoom", "9"])] {
            let app = XCUIApplication()
            app.launchArguments = ["-ak-scenario", "eggs_two"] + zoom
            app.launch()
            XCTAssertTrue(app.staticTexts["hud.food"].waitForExistence(timeout: 20))
            sleep(1)
            shot(app, "eggs_two-\(label)")
            app.terminate()
        }
    }
}
