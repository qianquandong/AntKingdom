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

    /// D-13：生命周期说 hold 时（后台区间未结算），帧既不推进也不自动保存；resumed 时弹出总结且丢弃本帧间隔。
    func testFramesRespectLifecycleAdmission() {
        let clock = FakeClock()
        let controller = GameController(session: GameSession(), clock: clock)
        var saves = 0
        controller.persist = { saves += 1; return true }
        var admission = ForegroundFrame.hold
        controller.admitFrame = { admission }
        let before = controller.session.makeState()
        clock.now += 120                     // 距上次保存早已超过 30 秒
        controller.frame(delta: 1)
        XCTAssertEqual(controller.session.makeState(), before, "held frame does not advance")
        XCTAssertEqual(saves, 0, "held frame does not autosave")

        let summary = OfflineSummary(hauledFood: 27, netFood: 27, simulatedSeconds: 65, awaySeconds: 65)
        admission = .resumed(summary)
        var resumed = 0
        controller.onResume = { resumed += 1 }
        controller.frame(delta: 1)
        XCTAssertEqual(controller.session.makeState(), before, "gap frame drops its delta")
        XCTAssertEqual(controller.offlineSummary, summary)
        XCTAssertEqual(resumed, 1)

        admission = .run
        controller.frame(delta: 1)
        XCTAssertGreaterThan(controller.session.colony.elapsed, before.elapsed, "normal frames advance again")
        XCTAssertEqual(saves, 1, "and autosave resumes")
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
