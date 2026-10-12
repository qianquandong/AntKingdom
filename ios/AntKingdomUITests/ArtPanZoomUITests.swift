import XCTest

/// A01 采样接缝与闪线检查的录像动作：在通路截图场景里慢速平移、缩放（CI 用 simctl 录屏）。
/// 模拟器录像只能作为预检，真机仍需另测；本测试只断言手势没有挖土（dug 不变）。
final class ArtPanZoomUITests: XCTestCase {
    func testSlowPanAndZoomOverTunnels() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-ak-scenario", "tunnel_gallery"]
        app.launch()
        XCTAssertTrue(app.staticTexts["hud.food"].waitForExistence(timeout: 20))
        let map = app.otherElements["map"]
        XCTAssertTrue(map.waitForExistence(timeout: 5))
        let dugBefore = app.staticTexts["debug.probe"].label.split(separator: " ").first { $0.hasPrefix("dug=") }
        sleep(1)
        map.pinch(withScale: 2.5, velocity: 0.5)
        sleep(1)
        let center = map.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        for (dx, dy) in [(-120.0, 0.0), (240.0, 0.0), (-120.0, -160.0), (0.0, 320.0), (0.0, -160.0)] {
            center.press(forDuration: 0.05, thenDragTo: center.withOffset(CGVector(dx: dx, dy: dy)),
                         withVelocity: .slow, thenHoldForDuration: 0.3)
        }
        map.pinch(withScale: 0.4, velocity: -0.5)
        sleep(1)
        map.pinch(withScale: 1.8, velocity: 0.3)
        sleep(2)
        let dugAfter = app.staticTexts["debug.probe"].label.split(separator: " ").first { $0.hasPrefix("dug=") }
        XCTAssertEqual(dugBefore, dugAfter, "camera gestures must not dig")
    }
}
