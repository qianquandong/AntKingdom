import XCTest

/// A02-T02 / A02-T03 的录像动作（CI 用 simctl 录屏）：把 Cookie 路线平移到屏幕中央，放大观察工蚁 idle/walk/carry
/// 循环、货物随身体转向与装卸，再回到默认 32 pt 观察；最后看满载往返。模拟器录像只是预检，真机另测。
/// 断言只检查手势没有挖土（dug 不变）；动作好坏由 Codex 看录像复核。
final class AntMotionUITests: XCTestCase {
    private func probe(_ app: XCUIApplication) throws -> (originX: Double, originY: Double, tile: Double, dug: Int) {
        let element = app.staticTexts["debug.probe"]
        XCTAssertTrue(element.waitForExistence(timeout: 5))
        var values: [String: String] = [:]
        for part in element.label.split(separator: " ") {
            let pair = part.split(separator: "=", maxSplits: 1)
            if pair.count == 2 { values[String(pair[0])] = String(pair[1]) }
        }
        let origin = try XCTUnwrap(values["origin"]).split(separator: ",").compactMap { Double($0) }
        return (origin[0], origin[1], try XCTUnwrap(Double(values["tile"] ?? "")), try XCTUnwrap(Int(values["dug"] ?? "")))
    }

    func testAntLoopsAtDefaultAndZoomedScale() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-ak-scenario", "connected"]
        app.launch()
        XCTAssertTrue(app.staticTexts["hud.food"].waitForExistence(timeout: 20))
        let map = app.otherElements["map"]
        XCTAssertTrue(map.waitForExistence(timeout: 5))
        let start = try probe(app)
        sleep(6)                                          // 默认缩放（32 pt）下的循环
        // 把路线中段 (2,5) 慢速拖到地图中央，再以中央为准放大
        let window = app.coordinate(withNormalizedOffset: .zero)
        let route = window.withOffset(CGVector(dx: start.originX + 2.5 * start.tile, dy: start.originY + 5.5 * start.tile))
        let center = map.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        route.press(forDuration: 0.05, thenDragTo: center, withVelocity: .slow, thenHoldForDuration: 0.3)
        map.pinch(withScale: 3, velocity: 1)
        sleep(12)                                         // 放大：walk/carry 6 帧 10fps、idle 2 帧 4fps，各远超 5 个循环
        map.pinch(withScale: 0.34, velocity: -1)
        sleep(6)
        XCTAssertEqual(try probe(app).dug, start.dug, "camera gestures must not dig")
    }
}
