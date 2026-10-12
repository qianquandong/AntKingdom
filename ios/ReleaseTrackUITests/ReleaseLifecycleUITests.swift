import XCTest

/// D-13：发行轨 CrumbKingdom 走 CampaignModel → CampaignCoordinator 的同一套生命周期规则。
/// 真实切后台 65 秒再回来：弹出 Welcome Back，文案等于这次结算的搬入量，只结算一次，OK 可关闭。
final class ReleaseLifecycleUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    func testSixtyFiveSecondBackgroundIsSettledOnceByTheCampaign() {
        app.launchArguments = ["-ak-scenario", "connected"]
        app.launch()
        XCTAssertTrue(app.staticTexts["hud.food"].waitForExistence(timeout: 20))
        sleep(2)
        let left = Date()
        XCUIDevice.shared.press(.home)
        sleep(65)
        app.activate()
        let away = Date().timeIntervalSince(left)
        let title = app.staticTexts["offline.title"]
        XCTAssertTrue(title.waitForExistence(timeout: 10), "returning after 65 s must show the summary")
        let lines = app.staticTexts["debug.lifecycle"].label.components(separatedBy: " | ")
        let paid = lines.filter { ($0.contains(" settle active ") || $0.contains(" settle gap ")) && !$0.contains("settled=0") }
        XCTAssertEqual(paid.count, 1, lines.joined(separator: " / "))
        if let line = paid.first {
            func value(_ key: String) -> Double? {
                line.split(separator: " ").first { $0.hasPrefix(key + "=") }.flatMap { Double($0.dropFirst(key.count + 1)) }
            }
            XCTAssertEqual(value("settled") ?? 0, away, accuracy: 3, line)
            XCTAssertEqual(app.staticTexts["offline.summary"].label,
                           "Your ants brought in \(Int((value("hauled") ?? -1).rounded(.down))) Food.")
        }
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "D13-release-offline-summary"
        shot.lifetime = .keepAlways
        add(shot)
        app.buttons["offline.ok"].tap()
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: title)
        XCTAssertEqual(XCTWaiter().wait(for: [gone], timeout: 5), .completed, "OK must close the summary")
    }
}
