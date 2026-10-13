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

    /// D-14：全屏广告展示中按 Home（Debug 假广告 `-ak-ads long` 像真实 SDK 一样从顶层控制器全屏展示 40 秒，遮住 SpriteKit），
    /// 约 20 秒后回来时广告仍开着。只结算后台时长、不含按 Home 之前的广告展示时间；广告关闭后没有帧停顿结算；奖励只授予一次。
    /// 真实 AdMob 广告与真机锁屏需要账号与设备（NOT_RUN）。
    func testHomeDuringAFullScreenAdSettlesOnlyTheBackground() {
        app.launchArguments = ["-ak-scenario", "pantry_built", "-ak-ads", "long", "-ak-reward-ready"]
        app.launch()
        XCTAssertTrue(app.staticTexts["hud.food"].waitForExistence(timeout: 20))
        let entry = app.buttons["hud.reward"]
        XCTAssertTrue(entry.waitForExistence(timeout: 8))
        entry.tap()
        XCTAssertTrue(app.buttons["reward.watch"].waitForExistence(timeout: 5))
        app.buttons["reward.watch"].tap()
        let ad = app.otherElements["fake.ad"]
        XCTAssertTrue(ad.waitForExistence(timeout: 5), "the full-screen ad is shown")
        sleep(8)                                          // 看广告 8 秒（不是离线）
        let left = Date()
        XCUIDevice.shared.press(.home)
        sleep(20)
        app.activate()
        let away = Date().timeIntervalSince(left)
        XCTAssertTrue(ad.waitForExistence(timeout: 5), "the ad is still open after returning")
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "D14-ad-still-open-after-home"
        shot.lifetime = .keepAlways
        add(shot)
        let closed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: ad)
        XCTAssertEqual(XCTWaiter().wait(for: [closed], timeout: 30), .completed, "the ad finishes")
        XCTAssertTrue(app.staticTexts["hud.food"].waitForExistence(timeout: 10))
        sleep(2)
        let lines = app.staticTexts["debug.lifecycle"].label.components(separatedBy: " | ")
        let all = lines.joined(separator: " / ")
        let paid = lines.filter { ($0.contains(" settle active ") || $0.contains(" settle gap ")) && !$0.contains("settled=0") }
        XCTAssertEqual(paid.count, 1, all)
        if let line = paid.first {
            XCTAssertTrue(line.contains(" settle active "), "settled by .active, not by a frame gap: \(line)")
            let settled = line.split(separator: " ").first { $0.hasPrefix("settled=") }.flatMap { Double($0.dropFirst(8)) }
            XCTAssertEqual(settled ?? 0, away, accuracy: 3, "only the background, not the 8 s of ad: \(line)")
        }
        XCTAssertTrue(lines.contains { $0.contains(" background departure=") && $0.contains(" paused ") }, all)
        let settleIndex = lines.firstIndex { $0.contains(" settle active ") } ?? -1
        let endIndex = lines.firstIndex { $0.contains(" pause end after=") } ?? -1
        XCTAssertGreaterThan(endIndex, settleIndex, "the ad was still open when the background was settled: \(all)")
        XCTAssertEqual(lines.filter { $0.contains(" pause end after=") }.count, 1, all)
        XCTAssertTrue(app.buttons["hud.reward"].label.hasPrefix("Boost: "), app.buttons["hud.reward"].label)
        let after = XCTAttachment(screenshot: app.screenshot())
        after.name = "D14-after-ad"
        after.lifetime = .keepAlways
        add(after)
    }
}
