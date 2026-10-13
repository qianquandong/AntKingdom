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

    /// 食物源在正式土层上、空源、Pantry、通路、卵（A02 正式卵）、四向路线上的工蚁与货物；
    /// connected / tunnel_gallery 另截最大缩放与总览（Debug `-ak-zoom` 直接设定，CI 上捏合缩小不可靠）
    func testReleaseTargetArtScenes() {
        for scenario in ["connected", "source_cycle_cookie", "pantry_built", "tunnel_gallery", "eggs_two", "ant_four_way",
                         "replay600"] {
            var zooms: [(String, [String])] = [("", [])]
            if scenario == "connected" || scenario == "tunnel_gallery" {
                zooms += [("-zoom-max", ["-ak-zoom", "9"]), ("-overview", ["-ak-zoom", "0"])]
            }
            for (suffix, extra) in zooms {
                let app = XCUIApplication()
                app.launchArguments = ["-ak-scenario", scenario] + extra
                app.launch()
                XCTAssertTrue(app.staticTexts["hud.food"].waitForExistence(timeout: 20), scenario)
                sleep(2)
                shot(app, scenario + suffix)
                app.terminate()
            }
        }
    }
}
