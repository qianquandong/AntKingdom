import XCTest

/// C07 UI 测试（QA T31 的模拟器部分）：音效关、触觉关、减少动态时，挖掘与连通照常进行。
/// 真机上的静音开关、系统“减少动态”与触觉强度仍需用户在设备上验证。
final class FeedbackSettingsUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    private func probe() throws -> (origin: CGPoint, tile: Double, dug: Int) {
        let element = app.staticTexts["debug.probe"]
        XCTAssertTrue(element.waitForExistence(timeout: 5))
        var values: [String: String] = [:]
        for part in element.label.split(separator: " ") {
            let pair = part.split(separator: "=", maxSplits: 1)
            if pair.count == 2 { values[String(pair[0])] = String(pair[1]) }
        }
        let origin = try XCTUnwrap(values["origin"]).split(separator: ",").compactMap { Double($0) }
        let tile = try XCTUnwrap(Double(values["tile"] ?? ""))
        let dug = try XCTUnwrap(Int(values["dug"] ?? ""))
        return (CGPoint(x: origin[0], y: origin[1]), tile, dug)
    }

    private func tapCell(_ x: Int, _ y: Int) throws {
        let p = try probe()
        app.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: p.origin.x + (Double(x) + 0.5) * p.tile, dy: p.origin.y + (Double(y) + 0.5) * p.tile))
            .tap()
    }

    private func screenshot(_ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    func testFeedbackOffAndReduceMotionStillConnectCookie() throws {
        app.launchArguments = ["-ak-scenario", "fresh", "-ak-reduce-motion"]
        app.launch()
        XCTAssertTrue(app.staticTexts["hud.food"].waitForExistence(timeout: 15))

        app.buttons["hud.settings"].tap()
        let sound = app.segmentedControls["settings.sound"]
        XCTAssertTrue(sound.waitForExistence(timeout: 5))
        sound.buttons["Off"].tap()
        app.segmentedControls["settings.haptics"].buttons["Off"].tap()
        XCTAssertTrue(sound.buttons["Off"].isSelected)
        XCTAssertTrue(app.segmentedControls["settings.haptics"].buttons["Off"].isSelected)
        screenshot("C07-feedback-off")
        app.buttons["settings.close"].tap()
        XCTAssertTrue(app.staticTexts["hud.food"].waitForExistence(timeout: 5))

        try tapCell(0, 3)   // 不相邻通道的土：不可挖；减少动态下为闪框提示，不改变任何状态
        XCTAssertEqual(try probe().dug, 0)
        for cell in [(2, 4), (2, 5), (2, 6)] {
            for _ in 0..<3 {
                try tapCell(cell.0, cell.1)
                usleep(200_000)
            }
        }
        XCTAssertTrue(app.staticTexts["toast.feedback.connected"].waitForExistence(timeout: 5))
        XCTAssertEqual(try probe().dug, 3)
        screenshot("C07-reduce-motion-connected")
    }
}
