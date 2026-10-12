import XCTest

/// A01 / D-15 发行轨对照截图：CrumbKingdom target 与核心版共用 Assets.xcassets 与 GameScene，这里用发行轨实际运行
/// （CampaignModel → 章节）截图，证明发行 target 也载入同一批资源与 D-15 渲染修复，而不是只凭“共享目录”推断。
/// 只截图、不判断美术好坏；断言只检查场景载入、镜头操作发生。CI 在标准机型与小屏各运行一次。
final class ReleaseArtScreenshotsUITests: XCTestCase {
    private var device: String { ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"] ?? "device" }

    private func shot(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "A01-release-\(name)-\(device)"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// 食物源（Cookie 96pt、Sugar 48pt、Sap 48pt）在正式土层上；空源、Pantry、通路与卵；connected 另截最大放大与总览
    func testReleaseTargetArtScenes() {
        for scenario in ["connected", "source_cycle_cookie", "pantry_built", "tunnel_gallery", "eggs_two"] {
            let app = XCUIApplication()
            app.launchArguments = ["-ak-scenario", scenario]
            app.launch()
            XCTAssertTrue(app.staticTexts["hud.food"].waitForExistence(timeout: 20), scenario)
            sleep(2)
            shot(app, scenario)
            if scenario == "connected" {
                let map = app.otherElements["map"]
                XCTAssertTrue(map.waitForExistence(timeout: 5))
                map.pinch(withScale: 4, velocity: 2)
                sleep(1)
                shot(app, "\(scenario)-zoom-max")
                map.pinch(withScale: 0.15, velocity: -2)
                sleep(1)
                shot(app, "\(scenario)-overview")
            }
            app.terminate()
        }
    }
}
