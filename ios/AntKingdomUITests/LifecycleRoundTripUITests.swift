import XCTest

/// D-13（Issue #11）回归：反复真实切后台 65 秒再回来。每轮重启到同一个可结算状态（-ak-scenario connected，
/// 内存存档、未满仓），记录实际离开时长、结算秒数与搬入量（Debug 生命周期日志）、Welcome Back 文案与 OK 行为。
/// 轮数由 TEST_RUNNER_AK_ROUNDS 指定（CI 的 D-13 回归 job：标准机型与小屏各 10 轮）；未指定时跳过。
/// 任何一轮失败都保留该轮日志并继续跑完其余轮次，最后整体判定，不删除失败轮。
final class LifecycleRoundTripUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = true
        app = XCUIApplication()
    }

    private struct Settlement {
        let kind: String
        let settled: Double
        let hauled: Double
    }

    private func traceLines() -> [String] {
        let element = app.staticTexts["debug.lifecycle"]
        guard element.waitForExistence(timeout: 5) else { return [] }
        return element.label.components(separatedBy: " | ")
    }

    private func value(_ key: String, in line: String) -> Double? {
        line.split(separator: " ").first { $0.hasPrefix(key + "=") }.flatMap { Double($0.dropFirst(key.count + 1)) }
    }

    /// 本进程里所有“回到前台/帧停顿”的结算（冷启动是新档，不会有 launch 结算）
    private func settlements(_ lines: [String]) -> [Settlement] {
        lines.compactMap { line in
            guard let kind = [" settle active ", " settle gap "].first(where: { line.contains($0) }),
                  let settled = value("settled", in: line), settled > 0 else { return nil }
            return Settlement(kind: kind.trimmingCharacters(in: .whitespaces), settled: settled,
                              hauled: value("hauled", in: line) ?? 0)
        }
    }

    func testRepeatedSixtyFiveSecondBackgroundRoundTrips() throws {
        let rounds = Int(ProcessInfo.processInfo.environment["AK_ROUNDS"] ?? "") ?? 0
        try XCTSkipIf(rounds <= 0, "set TEST_RUNNER_AK_ROUNDS to run the D-13 round trips")
        let device = ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"] ?? "unknown"
        var failures = 0
        for round in 1...rounds {
            var problems: [String] = []
            if app.state != .notRunning { app.terminate() }
            app.launchArguments = ["-ak-scenario", "connected"]
            app.launch()
            if !app.staticTexts["hud.food"].waitForExistence(timeout: 20) { problems.append("no HUD") }
            sleep(2)
            let left = Date()
            XCUIDevice.shared.press(.home)
            sleep(65)
            app.activate()
            let away = Date().timeIntervalSince(left)
            let title = app.staticTexts["offline.title"]
            let shown = title.waitForExistence(timeout: 10)
            if !shown { problems.append("Welcome Back not shown") }
            let summaryText = shown ? app.staticTexts["offline.summary"].label : ""
            let lines = traceLines()
            let paid = settlements(lines)
            if paid.count != 1 { problems.append("expected exactly one settlement, got \(paid.count)") }
            let settlement = paid.first
            if let s = settlement {
                if s.settled < 60 { problems.append("settled \(s.settled) s < 60") }
                if abs(s.settled - away) > 3 { problems.append("settled \(s.settled) s vs away \(away) s") }
                let expectedText = "Your ants brought in \(Int(s.hauled.rounded(.down))) Food."
                if shown, summaryText != expectedText { problems.append("summary '\(summaryText)' != '\(expectedText)'") }
                if s.hauled <= 0 { problems.append("nothing hauled (state must not be full or empty)") }
            }
            var closed = false
            if shown {
                app.buttons["offline.ok"].tap()
                let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: title)
                closed = XCTWaiter().wait(for: [gone], timeout: 5) == .completed
                if !closed { problems.append("OK did not close the summary") }
            }
            let held = lines.first { $0.contains("held ") && $0.contains("frame(s) before active") }
                .flatMap { line in line.components(separatedBy: "held ").last?.split(separator: " ").first }
                .map(String.init) ?? "0"
            let record = String(format: "D13-ROUND device=%@ round=%ld away=%.2f settled=%@ hauled=%@ path=%@ held=%@ shown=%ld ok=%ld result=%@",
                                device, round, away,
                                settlement.map { String(format: "%.2f", $0.settled) } ?? "-",
                                settlement.map { String(format: "%.2f", $0.hauled) } ?? "-",
                                settlement?.kind ?? "-", held, shown ? 1 : 0, closed ? 1 : 0,
                                problems.isEmpty ? "PASS" : "FAIL(" + problems.joined(separator: "; ") + ")")
            print(record)
            let attachment = XCTAttachment(string: record + "\n" + lines.joined(separator: "\n"))
            attachment.name = "D13-round-\(round)"
            attachment.lifetime = .keepAlways
            add(attachment)
            if !problems.isEmpty {
                failures += 1
                let shot = XCTAttachment(screenshot: app.screenshot())
                shot.name = "D13-round-\(round)-failure"
                shot.lifetime = .keepAlways
                add(shot)
                XCTFail("round \(round): " + problems.joined(separator: "; "))
            }
        }
        XCTAssertEqual(failures, 0, "\(failures)/\(rounds) rounds failed on \(device)")
    }
}
