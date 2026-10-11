import XCTest

/// C05 UI 测试：Pantry 建造/移动的真实格网操作；非法操作不能确认、不扣 Food。
/// CI 会为本类录制模拟器视频作为“操作录像”证据。
final class PantryFlowUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    private func launch(_ scenario: String) {
        app.launchArguments = ["-ak-scenario", scenario]
        app.launch()
        XCTAssertTrue(app.staticTexts["hud.food"].waitForExistence(timeout: 15))
    }

    private func tapCell(_ x: Int, _ y: Int) throws {
        let probe = app.staticTexts["debug.probe"]
        XCTAssertTrue(probe.waitForExistence(timeout: 5))
        var values: [String: String] = [:]
        for part in probe.label.split(separator: " ") {
            let pair = part.split(separator: "=", maxSplits: 1)
            if pair.count == 2 { values[String(pair[0])] = String(pair[1]) }
        }
        let origin = try XCTUnwrap(values["origin"]).split(separator: ",").compactMap { Double($0) }
        let tile = try XCTUnwrap(Double(values["tile"] ?? ""))
        app.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: origin[0] + (Double(x) + 0.5) * tile, dy: origin[1] + (Double(y) + 0.5) * tile))
            .tap()
    }

    /// 读取 HUD 的 "Food: N/M"。模拟一直在跑、地面兜底持续进账，所以只能做相对断言。
    private func hud() throws -> (food: Int, capacity: Int) {
        let label = app.staticTexts["hud.food"].label
        XCTAssertTrue(label.hasPrefix("Food: "), label)
        let parts = label.dropFirst("Food: ".count).split(separator: "/").map { Int($0.filter(\.isNumber)) }
        let food = try XCTUnwrap(parts.count == 2 ? parts[0] : nil, label)
        let capacity = try XCTUnwrap(parts.count == 2 ? parts[1] : nil, label)
        return (food, capacity)
    }

    private func screenshot(_ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    func testBuildPantryChargesOnceAndRaisesCapacity() throws {
        launch("pantry_ready")
        let start = try hud()
        XCTAssertEqual(start.capacity, 100)
        XCTAssertGreaterThanOrEqual(start.food, 60)
        app.buttons["action.build_pantry"].tap()
        XCTAssertTrue(app.staticTexts["panel.placement.cost"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["panel.placement.cost"].label, "50 Food")
        screenshot("C05-build-preview")
        // 先点一个非法位置：确认不可用、余额不变
        try tapCell(4, 3)
        XCTAssertEqual(app.staticTexts["panel.placement.message"].label, "Choose a clear 2 x 2 space.")
        XCTAssertFalse(app.buttons["action.confirm"].isEnabled)
        XCTAssertGreaterThanOrEqual(try hud().food, start.food, "illegal spot must not charge")
        screenshot("C05-build-illegal")
        try tapCell(1, 4)
        XCTAssertTrue(app.buttons["action.confirm"].isEnabled)
        let beforeConfirm = try hud()
        app.buttons["action.confirm"].tap()
        XCTAssertTrue(app.staticTexts["hud.food"].waitForLabelSuffix("/1100"))
        let built = try hud()
        // 只扣一次 50：不会低于确认前余额 −50；确认前最多满仓 100，扣后加上读取间隔的进账也不超过 60
        XCTAssertGreaterThanOrEqual(built.food, beforeConfirm.food - 50)
        XCTAssertLessThanOrEqual(built.food, 60)
        screenshot("C05-pantry-built")
    }

    func testCancelledAndIllegalMovesChangeNothing() throws {
        launch("pantry_built")
        let start = try hud()
        XCTAssertEqual(start.capacity, 1100)
        XCTAssertGreaterThanOrEqual(start.food, 30)
        try tapCell(1, 2)
        XCTAssertTrue(app.buttons["action.move"].waitForExistence(timeout: 5))
        app.buttons["action.move"].tap()
        try tapCell(4, 3)   // Queen Chamber：非法
        XCTAssertFalse(app.buttons["action.confirm"].isEnabled)
        app.buttons["action.cancel"].tap()
        XCTAssertFalse(app.buttons["action.confirm"].exists)
        let after = try hud()
        XCTAssertEqual(after.capacity, 1100)
        XCTAssertGreaterThanOrEqual(after.food, start.food, "cancel must not charge")
    }

    func testMovingCloserShowsRealImprovement() throws {
        launch("pantry_built")
        try tapCell(1, 2)
        XCTAssertTrue(app.buttons["action.move"].waitForExistence(timeout: 5))
        app.buttons["action.move"].tap()
        try tapCell(1, 4)
        XCTAssertTrue(app.buttons["action.confirm"].isEnabled)
        screenshot("C05-move-preview")
        let beforeMove = try hud()
        app.buttons["action.confirm"].tap()
        XCTAssertTrue(app.staticTexts["toast.feedback.route_better"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["toast.feedback.route_better"].label.hasPrefix("Faster route! +"))
        let moved = try hud()
        XCTAssertEqual(moved.capacity, 1100)
        XCTAssertGreaterThanOrEqual(moved.food, beforeMove.food, "moving is free")
        screenshot("C05-route-better")
    }
}

private extension XCUIElement {
    func waitForLabelSuffix(_ suffix: String, timeout: TimeInterval = 5) -> Bool {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label ENDSWITH %@", suffix), object: self)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }
}
