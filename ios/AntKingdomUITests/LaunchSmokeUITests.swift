import XCTest

/// UI 冒烟：冷启动后看到英文标题；截图作为 xcresult 附件保留。
final class LaunchSmokeUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testColdLaunchShowsEnglishTitle() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.staticTexts["title"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.staticTexts["title"].label, "Crumb Kingdom")
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "C00-launch"
        shot.lifetime = .keepAlways
        add(shot)
    }
}
