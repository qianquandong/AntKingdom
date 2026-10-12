import XCTest

/// A01 美术接入对照截图：同一组场景在标准机型与小屏各截一组（CI 的两个 UI 测试步骤都会运行本类）。
/// 只截图、不判断美术好坏；画面正确与否由 Codex 复核附件。断言只检查场景确实载入、操作确实发生。
final class ArtScreenshotsUITests: XCTestCase {
    private var device: String { ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"] ?? "device" }

    private func shot(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "A01-\(name)-\(device)"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func launch(_ arguments: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = arguments
        app.launch()
        return app
    }

    /// 默认视图；通路截图场景与 connected 另截最大放大与总览（双指缩放，镜头自动钳制到上下限）
    func testArtReviewScenes() {
        for scenario in ["connected", "pantry_built", "tunnel_gallery", "eggs_one", "eggs_two", "replay600"] {
            let app = launch(["-ak-scenario", scenario])
            XCTAssertTrue(app.staticTexts["hud.food"].waitForExistence(timeout: 20), scenario)
            sleep(2)
            shot(app, scenario)
            if scenario == "tunnel_gallery" || scenario == "connected" {
                let map = app.otherElements["map"]
                XCTAssertTrue(map.waitForExistence(timeout: 5))
                map.pinch(withScale: 4, velocity: 2)       // 最大 1.6 倍（镜头钳制）
                sleep(1)
                shot(app, "\(scenario)-zoom-max")
                // 总览 = 最小缩放（整图按宽度装下）。快速的一次大幅捏合在 CI 上只缩回一部分（run 38205368547），
                // 改为两次较慢的捏合，镜头钳制到下限
                map.pinch(withScale: 0.5, velocity: -0.5)
                map.pinch(withScale: 0.5, velocity: -0.5)
                sleep(1)
                shot(app, "\(scenario)-overview")
            }
            app.terminate()
        }
    }

    /// 16 种遮罩（含游戏中不会出现的 0 号）与土层 3×3 的逐格检视页
    func testTunnelMaskGallery() {
        let app = launch(["-ak-gallery"])
        XCTAssertTrue(app.otherElements["gallery.mask.0"].waitForExistence(timeout: 20)
                      || app.staticTexts["0 -"].waitForExistence(timeout: 5))
        shot(app, "gallery-masks")
        app.swipeUp()
        sleep(1)
        shot(app, "gallery-soil")
        app.terminate()
    }

    /// 连续挖格后杀进程重开：重开后通路贴图按读档状态重算，不留旧边
    func testDigThenRelaunchKeepsTunnelEdges() throws {
        var app = launch(["-ak-reset-save"])
        XCTAssertTrue(app.staticTexts["hud.food"].waitForExistence(timeout: 20))
        for cell in [(2, 4), (2, 5), (2, 6), (5, 1), (6, 1)] {
            for _ in 0..<3 {
                try tapCell(app, cell.0, cell.1)
                usleep(200_000)
            }
        }
        sleep(2)
        XCTAssertEqual(try probe(app).dug, 5)
        shot(app, "dig-before-relaunch")
        app.terminate()
        app = launch([])
        XCTAssertTrue(app.staticTexts["hud.food"].waitForExistence(timeout: 20))
        sleep(2)
        XCTAssertEqual(try probe(app).dug, 5, "dug cells restored from the save")
        shot(app, "dig-after-relaunch")
        app.terminate()
    }

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

    private func tapCell(_ app: XCUIApplication, _ x: Int, _ y: Int) throws {
        let p = try probe(app)
        app.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: p.originX + (Double(x) + 0.5) * p.tile, dy: p.originY + (Double(y) + 0.5) * p.tile))
            .tap()
    }
}
