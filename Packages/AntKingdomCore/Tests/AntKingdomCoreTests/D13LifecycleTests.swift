import Foundation
import XCTest
@testable import AntKingdomCore

/// D-13（Issue #11）：后台区间的离线收益不能被“回到前台之前”的保存吃掉，也不能因为生命周期事件延迟、
/// 重复或缺失而漏算/重复结算。全部用可控墙钟，不依赖真实等待或重跑。
final class D13LifecycleTests: XCTestCase {
    final class FakeWall: WallClock {
        var time: Double
        init(_ time: Double) { self.time = time }
        func now() -> Double { time }
    }

    private func coordinator(_ wall: FakeWall, store: MemorySaveStore = MemorySaveStore(),
                             scenario: DebugScenario = .connected) throws -> LifecycleCoordinator {
        let (coordinator, _) = LifecycleCoordinator.launch(repository: SaveRepository(store: store, appVersion: "x"),
                                                           wallClock: wall, trace: LifecycleTrace())
        let c = try XCTUnwrap(coordinator)
        try scenario.apply(to: c.session)
        _ = c.session.drainEvents()
        return c
    }

    /// 同一初始状态、同 25% 效率的参考模拟：直接对状态副本做离线结算（封顶 1 小时）。
    private func reference(_ c: LifecycleCoordinator, away: Double) throws -> GameState {
        let copy = try GameSession(state: c.session.makeState(), map: c.session.map)
        _ = try copy.settleOffline(seconds: min(away, Rules.offlineCap))
        return copy.makeState()
    }

    /// 模拟前台跑了若干帧（只走帧准入，不推进模拟，便于与参考状态逐字段比较）。
    /// 步长取 0.25 秒（二进制可精确表示），离开时长相减没有舍入误差。
    private func frames(_ c: LifecycleCoordinator, _ wall: FakeWall, count: Int = 3) {
        for _ in 0..<count {
            wall.time += 0.25
            XCTAssertEqual(c.admitForegroundFrame(), .run)
        }
    }

    // MARK: 原实现稳定失败的最小复现（只用原有 API；修复前在 swift:6.2 中 2/2 失败，见 M2 报告）

    /// CI 38172213454 attempt 2 的时序：进入后台并保存 → 65 秒后回来，SpriteKit 先跑了恢复首帧
    /// （帧间隔封顶 1 秒，Food +约 2）并因距上次保存超过 30 秒触发自动保存 → 之后才处理 `.active`。
    /// 原实现的保存把墙钟高水位推进到“现在”，离线起点被吃掉，`.active` 结算 0 秒、不弹总结。
    func testSaveBetweenBackgroundAndActiveDoesNotEatTheOfflineInterval() throws {
        let wall = FakeWall(1_000)
        let c = try coordinator(wall)
        let expected = try reference(c, away: 65)
        c.enterBackground()
        wall.time += 65
        c.save()                                 // 恢复首帧的自动保存（或任何在 `.active` 之前的保存）
        let summary = try XCTUnwrap(c.becomeActive(), "the 65 s away must be settled")
        XCTAssertEqual(summary.simulatedSeconds, 65)
        XCTAssertTrue(summary.isWorthShowing, "Welcome Back is shown")
        XCTAssertEqual(c.session.makeState(), expected)
        XCTAssertNil(c.becomeActive(), "settled exactly once")
    }

    /// 同一类问题的冷启动形态：后台期间发生保存后进程被杀，冷启动也只能从离开时刻起算。
    func testKillAfterABackgroundSaveStillSettlesFromDeparture() throws {
        let store = MemorySaveStore()
        let wall = FakeWall(5_000)
        let c = try coordinator(wall, store: store)
        c.save()
        let expected = try reference(c, away: 600)
        c.enterBackground()
        wall.time += 30
        c.save()
        wall.time += 570                         // 被杀；离开共 600 秒后冷启动
        let (_, result) = LifecycleCoordinator.launch(repository: SaveRepository(store: store, appVersion: "x"),
                                                      wallClock: wall)
        guard case .ready(let session, let summary?, _) = result else { return XCTFail("\(result)") }
        XCTAssertEqual(summary.simulatedSeconds, 600)
        XCTAssertEqual(session.makeState(), expected)
    }

    // MARK: 帧准入：恢复首帧早于 `.active`、`.background` 迟到或缺失

    func testResumeFramesBeforeActiveAreHeldAndNothingIsSaved() throws {
        let store = MemorySaveStore()
        let wall = FakeWall(2_000)
        let c = try coordinator(wall, store: store)
        frames(c, wall)
        let expected = try reference(c, away: 65)
        c.enterBackground()
        guard case .loaded(let atBackground, _) = SaveRepository(store: store, appVersion: "x").load() else {
            return XCTFail("background save")
        }
        wall.time += 65
        for _ in 0..<3 { XCTAssertEqual(c.admitForegroundFrame(), .hold, "resume frames wait for active") }
        guard case .loaded(let afterHold, _) = SaveRepository(store: store, appVersion: "x").load() else {
            return XCTFail("still saved")
        }
        XCTAssertEqual(afterHold.sequence, atBackground.sequence, "held frames do not save")
        let summary = try XCTUnwrap(c.becomeActive())
        XCTAssertEqual(summary.simulatedSeconds, 65, accuracy: 1e-9)
        XCTAssertEqual(c.session.makeState(), expected)
        XCTAssertTrue(c.trace?.lines.contains { $0.contains("held 3 frame(s) before active") } ?? false)
        XCTAssertEqual(c.admitForegroundFrame(), .run)
        wall.time += 0.25
        XCTAssertEqual(c.admitForegroundFrame(), .run, "back to normal frames")
    }

    /// `.background` 回调迟到（App 已被挂起，回调在回来时才处理）：离开时刻取最后一帧，迟到的那段不算在线。
    func testLateBackgroundCallbackCountsFromTheLastFrame() throws {
        let wall = FakeWall(3_000)
        let c = try coordinator(wall)
        frames(c, wall)
        let expected = try reference(c, away: 65)
        wall.time += 65
        c.enterBackground()                      // 迟到 65 秒
        let summary = try XCTUnwrap(c.becomeActive())
        XCTAssertEqual(summary.simulatedSeconds, 65, accuracy: 1e-9)
        XCTAssertEqual(c.session.makeState(), expected)
    }

    /// `.background` 根本没有送达：第一帧发现停顿超过阈值，整段按离线结算一次。
    func testMissingBackgroundIsSettledOnceByTheFrameGap() throws {
        let wall = FakeWall(4_000)
        let c = try coordinator(wall)
        frames(c, wall)
        let expected = try reference(c, away: 65)
        wall.time += 65
        guard case .resumed(let summary?) = c.admitForegroundFrame() else { return XCTFail("gap must settle") }
        XCTAssertEqual(summary.simulatedSeconds, 65, accuracy: 1e-9)
        XCTAssertTrue(summary.isWorthShowing)
        XCTAssertEqual(c.session.makeState(), expected)
        wall.time += 0.25
        XCTAssertEqual(c.admitForegroundFrame(), .run)
        XCTAssertNil(c.becomeActive(), "no background interval: nothing more to settle")
        XCTAssertEqual(c.session.makeState(), expected)
    }

    /// 回来后先由帧停顿结算，随后迟到的 background/active 才到：不重复结算。
    func testLateEventsAfterAGapSettlementDoNotPayTwice() throws {
        let wall = FakeWall(4_500)
        let c = try coordinator(wall)
        frames(c, wall)
        let expected = try reference(c, away: 65)
        wall.time += 65
        guard case .resumed = c.admitForegroundFrame() else { return XCTFail("gap") }
        c.enterBackground()                      // 迟到的后台回调（与回来的帧同一时刻）
        let late = c.becomeActive()
        XCTAssertEqual(late?.simulatedSeconds ?? 0, 0, accuracy: 1e-9)
        XCTAssertEqual(c.session.makeState(), expected)
    }

    func testDuplicateBackgroundAndActiveSettleExactlyOnce() throws {
        let wall = FakeWall(5_500)
        let c = try coordinator(wall)
        frames(c, wall)
        let expected = try reference(c, away: 65)
        c.enterBackground()
        c.enterBackground()
        wall.time += 65
        c.enterBackground()
        XCTAssertEqual(c.becomeActive()?.simulatedSeconds, 65)
        XCTAssertNil(c.becomeActive())
        XCTAssertNil(c.becomeActive())
        XCTAssertEqual(c.session.makeState(), expected)
    }

    /// 短暂 inactive→active（系统面板）或普通卡顿：不记录后台、帧间隔不超过阈值，不算离线。
    func testShortInactiveAndHitchesAreNotOffline() throws {
        let wall = FakeWall(6_000)
        let c = try coordinator(wall)
        frames(c, wall)
        let before = c.session.makeState()
        wall.time += 2                           // 下拉控制中心约 2 秒，帧暂停
        XCTAssertEqual(c.admitForegroundFrame(), .run)
        XCTAssertNil(c.becomeActive(), "inactive→active without background settles nothing")
        wall.time += LifecycleCoordinator.frameGapThreshold - 0.01
        XCTAssertEqual(c.admitForegroundFrame(), .run)
        XCTAssertEqual(c.session.makeState(), before)
    }

    // MARK: 写盘失败、强杀、冷启动

    func testWriteFailureDuringBackgroundStillSettlesOnceAndColdStartDoesNotRepay() throws {
        let store = MemorySaveStore()
        let wall = FakeWall(7_000)
        let c = try coordinator(wall, store: store)
        c.save()
        frames(c, wall)
        let expected = try reference(c, away: 65)
        store.failWrites = true
        c.enterBackground()
        XCTAssertNotNil(c.lastSaveError)
        wall.time += 65
        XCTAssertEqual(c.becomeActive()?.simulatedSeconds, 65)
        XCTAssertEqual(c.session.makeState(), expected)
        store.failWrites = false
        XCTAssertTrue(c.save())
        // 强杀后立即冷启动：已结算的区间不再支付
        let (_, result) = LifecycleCoordinator.launch(repository: SaveRepository(store: store, appVersion: "x"),
                                                      wallClock: wall)
        guard case .ready(let session, nil, _) = result else { return XCTFail("\(result)") }
        XCTAssertEqual(session.makeState(), expected)
    }

    /// 本地存档的边界（如实记录）：写盘一直失败期间被强杀，冷启动只能从最后一次成功写盘起算。
    func testKillWhileWritesKeepFailingFallsBackToTheLastSuccessfulSave() throws {
        let store = MemorySaveStore()
        let wall = FakeWall(8_000)
        let c = try coordinator(wall, store: store)
        XCTAssertTrue(c.save())
        let lastGood = c.session.makeState()
        wall.time += 10
        store.failWrites = true
        c.enterBackground()
        wall.time += 65
        store.failWrites = false
        let (_, result) = LifecycleCoordinator.launch(repository: SaveRepository(store: store, appVersion: "x"),
                                                      wallClock: wall)
        guard case .ready(let session, let summary?, _) = result else { return XCTFail("\(result)") }
        XCTAssertEqual(summary.simulatedSeconds, 75, accuracy: 1e-9, "from the last successful save")
        let copy = try GameSession(state: lastGood, map: .backyard)
        _ = try copy.settleOffline(seconds: 75)
        XCTAssertEqual(session.makeState(), copy.makeState())
    }

    // MARK: 时长矩阵 × 状态（对照参考模拟逐字段比较）

    func testDurationsAndStatesMatchTheReferenceSimulation() throws {
        let setups: [(String, DebugScenario, (GameSession) throws -> Void)] = [
            ("partial storage", .connected, { _ in }),
            ("almost full", .connected, { s in try s.debugReplaceState { $0.hauled += 95 - $0.food; $0.food = 95 } }),
            ("full", .connected, { s in try s.debugReplaceState { $0.hauled += 100 - $0.food; $0.food = 100 } }),
            ("hatching off", .connected, { s in s.apply(.setHatching(false)) }),
            ("pantry built", .pantryBuilt, { _ in }),
        ]
        for (name, scenario, setup) in setups {
            for away in [30.0, 65, 3_600, 7_200] {
                let wall = FakeWall(10_000)
                let c = try coordinator(wall, scenario: scenario)
                try setup(c.session)
                _ = c.session.drainEvents()
                frames(c, wall)
                let expected = try reference(c, away: away)
                c.enterBackground()
                wall.time += away
                c.save()                         // 回来前的保存不能影响结果
                let summary = c.becomeActive()
                XCTAssertEqual(summary?.simulatedSeconds ?? 0, min(away, Rules.offlineCap), accuracy: 1e-9, "\(name) \(away)")
                XCTAssertEqual(summary?.awaySeconds ?? 0, away, accuracy: 1e-9, "\(name) \(away)")
                XCTAssertEqual(summary?.isWorthShowing ?? false, away >= 60, "\(name) \(away)")
                XCTAssertEqual(c.session.makeState(), expected, "\(name) \(away)")
                XCTAssertNil(c.becomeActive(), "\(name) \(away) once")
                XCTAssertEqual(c.session.makeState(), expected, "\(name) \(away) unchanged")
            }
        }
    }

    /// 回拨再恢复（含帧路径）：不出现负收益、不重复领取；真实时间过去后照常结算。
    func testClockRollbackAndRecoveryWithFrames() throws {
        let wall = FakeWall(100_000)
        let c = try coordinator(wall)
        frames(c, wall)
        let start = c.session.makeState()
        c.enterBackground()
        wall.time -= 7_200
        XCTAssertNil(c.becomeActive())
        frames(c, wall)
        XCTAssertEqual(c.session.makeState(), start, "no negative or extra income")
        c.enterBackground()
        wall.time = 100_000.25
        XCTAssertEqual(c.becomeActive()?.simulatedSeconds ?? 0, 0, accuracy: 0.1, "rolling forward again does not repay")
        frames(c, wall)
        let expected = try reference(c, away: 65)
        c.enterBackground()
        wall.time += 65
        XCTAssertEqual(c.becomeActive()?.simulatedSeconds ?? 0, 65, accuracy: 1e-9)
        XCTAssertEqual(c.session.makeState(), expected)
    }
}
