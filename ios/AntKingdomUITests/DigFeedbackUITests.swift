import XCTest

/// A02-02（Issue #19）A02B-03 / A02B-05：三种 Soil 各 0→1→2→3 命中的固定镜头截图；正常与 Reduce Motion 下连续 50 次操作后
/// 土屑节点全部清零（调试探针 fx=），已挖格数与操作一致。画面好坏由 Codex 看截图 / 录像复核；模拟器不代替真机。
final class DigFeedbackUITests: XCTestCase {
    private var device: String { ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"] ?? "device" }

    private func shot(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "A02B-\(name)-\(device)"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func probe(_ app: XCUIApplication) throws -> [String: String] {
        let element = app.staticTexts["debug.probe"]
        XCTAssertTrue(element.waitForExistence(timeout: 5))
        var values: [String: String] = [:]
        for part in element.label.split(separator: " ") {
            let pair = part.split(separator: "=", maxSplits: 1)
            if pair.count == 2 { values[String(pair[0])] = String(pair[1]) }
        }
        return values
    }

    private func tap(_ app: XCUIApplication, _ x: Int, _ y: Int) throws {
        let p = try probe(app)
        let origin = try XCTUnwrap(p["origin"]).split(separator: ",").compactMap { Double($0) }
        let tile = try XCTUnwrap(Double(p["tile"] ?? ""))
        app.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: origin[0] + (Double(x) + 0.5) * tile, dy: origin[1] + (Double(y) + 0.5) * tile))
            .tap()
    }

    private func dug(_ app: XCUIApplication) throws -> Int { try XCTUnwrap(Int(probe(app)["dug"] ?? "")) }

    /// 等土屑全部清掉（约 0.35 秒动画；慢 runner 给到 5 秒）
    private func waitNoCrumbs(_ app: XCUIApplication) throws -> Bool {
        let deadline = Date().addingTimeInterval(5)
        while Date() < deadline {
            if try probe(app)["fx"] == "0" { return true }
            usleep(250_000)
        }
        return false
    }

    /// Soil 变体 = x % 3 + 1：(3,1) → 1、(4,5) → 2、(5,1) → 3（都在新档的可挖前沿上）
    func testThreeHitsOnEachSoilVariant() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-ak-scenario", "fresh"]   // 默认缩放：整张图十行都在 HUD 下方可点
        app.launch()
        XCTAssertTrue(app.staticTexts["hud.food"].waitForExistence(timeout: 20))
        for (variant, cell) in [(1, (3, 1)), (2, (4, 5)), (3, (5, 1))] {
            let before = try dug(app)
            shot(app, "soil\(variant)-hit0")
            for hit in 1...3 {
                try tap(app, cell.0, cell.1)
                usleep(150_000)
                if hit == 2 { shot(app, "soil\(variant)-hit2-crumbs") }
                XCTAssertTrue(try waitNoCrumbs(app), "crumbs cleared after hit \(hit)")
                shot(app, "soil\(variant)-hit\(hit)")
            }
            XCTAssertEqual(try dug(app), before + 1, "three hits open exactly one cell")
        }
        app.terminate()
    }

    func testFiftyOperationsLeaveNoCrumbs() throws {
        try fiftyOperations(reduceMotion: false)
    }

    func testFiftyOperationsLeaveNoCrumbsWithReduceMotion() throws {
        try fiftyOperations(reduceMotion: true)
    }

    /// 与 tunnel_gallery 相同的挖开顺序（每一步都在可挖前沿上）：16 格 × 3 次 = 48 次，再在第 17 格点 2 次，共 50 次有效命中
    private func fiftyOperations(reduceMotion: Bool) throws {
        let cells = [(3, 5), (2, 3), (5, 1), (5, 5), (2, 5), (3, 6), (6, 1), (6, 3), (3, 2), (3, 1),
                     (1, 5), (6, 2), (2, 6), (4, 6), (1, 4), (6, 4)]
        let app = XCUIApplication()
        app.launchArguments = ["-ak-scenario", "fresh"] + (reduceMotion ? ["-ak-reduce-motion"] : [])
        app.launch()
        XCTAssertTrue(app.staticTexts["hud.food"].waitForExistence(timeout: 20))
        for cell in cells {
            for _ in 0..<3 {
                try tap(app, cell.0, cell.1)
                usleep(200_000)
            }
        }
        for _ in 0..<2 {
            try tap(app, 7, 1)                               // (7,1) 与 (6,1) 相邻，两次命中不开通
            usleep(200_000)
        }
        XCTAssertTrue(try waitNoCrumbs(app), "no crumb nodes left after 50 operations")
        XCTAssertEqual(try dug(app), cells.count, "every cell opened once, nothing extra")
        shot(app, reduceMotion ? "fifty-reduce-motion" : "fifty")
        app.terminate()
    }
}
