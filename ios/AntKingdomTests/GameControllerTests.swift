import AntKingdomCore
import XCTest
@testable import AntKingdom

/// 平台层集成测试：控制器把点击转成命令、事件转成英文提示，且显示格式符合 PRD 5.1。
@MainActor
final class GameControllerTests: XCTestCase {
    private final class FakeClock: MonotonicClock {
        var now = 100.0
        func uptime() -> Double { now }
    }

    func testTapsAreRateLimitedAndOpenCells() {
        let clock = FakeClock()
        let controller = GameController(session: GameSession(), clock: clock)
        let cell = GridPoint(3, 1)
        controller.tapCell(cell)
        controller.tapCell(cell)            // 同一时刻：超过每秒 8 次上限，被忽略
        XCTAssertEqual(controller.session.digTaps[cell], 1)
        clock.now += 0.2
        controller.tapCell(cell)
        clock.now += 0.2
        controller.tapCell(cell)
        XCTAssertTrue(controller.session.colony.walkable.contains(cell))
    }

    func testHoldDigsFivePerSecondUntilOpen() {
        let clock = FakeClock()
        let controller = GameController(session: GameSession(), clock: clock)
        let cell = GridPoint(5, 1)
        controller.holdBegan(cell)
        XCTAssertEqual(controller.session.digTaps[cell], 1)
        clock.now += 0.45
        controller.frame(delta: 0)
        XCTAssertTrue(controller.session.colony.walkable.contains(cell))
    }

    func testEntityMappingAndSelection() {
        let controller = GameController(session: GameSession())
        XCTAssertEqual(controller.entity(at: GridPoint(0, 6)), .source("cookie"))
        XCTAssertEqual(controller.entity(at: GridPoint(7, 2)), .source("sugar"))
        XCTAssertEqual(controller.entity(at: GridPoint(8, 6)), .source("sap"))
        XCTAssertEqual(controller.entity(at: GridPoint(4, 4)), .queen)
        XCTAssertEqual(controller.entity(at: GridPoint(4, 0)), .source("surface"))
        XCTAssertNil(controller.entity(at: GridPoint(0, 9)))
        controller.tapCell(GridPoint(4, 3))
        XCTAssertEqual(controller.selection, .queen)
        controller.tapCell(GridPoint(4, 3))
        XCTAssertNil(controller.selection)
    }

    func testConnectionShowsEnglishToast() throws {
        let controller = GameController(session: GameSession())
        for p in [GridPoint(2, 4), GridPoint(2, 5), GridPoint(2, 6)] { controller.send(.debugCompleteCell(p)) }
        XCTAssertTrue(controller.toasts.contains { $0.text == "Food connected!" })
    }

    func testDisplayFormats() {
        XCTAssertEqual(Format.food(99.99), "99")
        XCTAssertEqual(Format.food(-0.1), "0")
        XCTAssertEqual(Format.oneDecimal(85.714286), "85.7")
        XCTAssertEqual(Format.seconds(29.01), "30")
        XCTAssertEqual(L10n.text("feedback.route_better", ["percent": Format.oneDecimal(28.571)]),
                       "Faster route! +28.6% Food/min")
    }
}
