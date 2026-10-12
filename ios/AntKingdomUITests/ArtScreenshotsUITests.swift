import XCTest

/// A01 美术接入对照截图：同一组场景在标准机型与小屏各截一组（CI 的两个 UI 测试步骤都会运行本类）。
/// 只截图、不判断美术好坏；画面正确与否由 Codex 复核附件。
final class ArtScreenshotsUITests: XCTestCase {
    func testArtReviewScenes() {
        let device = ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"] ?? "device"
        for scenario in ["connected", "pantry_built", "tunnel_gallery"] {
            let app = XCUIApplication()
            app.launchArguments = ["-ak-scenario", scenario]
            app.launch()
            XCTAssertTrue(app.staticTexts["hud.food"].waitForExistence(timeout: 20), scenario)
            sleep(2)
            let shot = XCTAttachment(screenshot: app.screenshot())
            shot.name = "A01-\(scenario)-\(device)"
            shot.lifetime = .keepAlways
            add(shot)
            app.terminate()
        }
    }
}
