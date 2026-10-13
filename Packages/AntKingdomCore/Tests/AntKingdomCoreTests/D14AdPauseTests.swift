import Foundation
import XCTest
@testable import AntKingdomCore

/// D-14（Codex 复核 docs/reviews/2026-10-11-followup-review.md）：全屏奖励广告的有意暂停是生命周期的第三种状态，
/// 既不是前台推进，也不是离线。前两条来自 Codex 复现用例 docs/reviews/repro/D13AdInterruptionReviewTests.swift，
/// 只在 CampaignModel 调用 `rewards.suspend(true)` 的位置改接正式 API `beginAdPause()`，其余步骤与断言不变。
/// 全部用可控墙钟；App 内接线（CampaignModel → GameController → RewardModel）另见 CrumbKingdomTests 的 AdPauseIntegrationTests。
final class D14AdPauseTests: XCTestCase {
    final class Wall: WallClock {
        var value = 50_000.0
        func now() -> Double { value }
    }

    private func make(_ wall: Wall, store: MemorySaveStore = MemorySaveStore(),
                      catalog: ChapterCatalog = .coreOnly) throws -> CampaignCoordinator {
        let (campaign, result) = CampaignCoordinator.launch(store: store, appVersion: "review", wallClock: wall,
                                                            catalog: catalog, trace: LifecycleTrace())
        let c = try XCTUnwrap(campaign, "\(result)")
        try DebugScenario.connected.apply(to: c.session)
        _ = c.session.drainEvents()
        return c
    }

    /// 参考模拟：同一状态副本按离线 25% 效率结算 min(away, 1h)
    private func reference(_ state: GameState, away: Double) throws -> GameState {
        let copy = try GameSession(state: state, map: .backyard)
        _ = try copy.settleOffline(seconds: min(away, Rules.offlineCap))
        return copy.makeState()
    }

    /// 与 GameController.frame 相同的顺序：先问生命周期，只有 `.run` 才推进会话并记账。
    /// 步长 0.25 秒（二进制精确），离开时长相减没有舍入误差。
    @discardableResult
    private func step(_ c: CampaignCoordinator, _ wall: Wall, _ dt: Double = 0.25) -> ForegroundFrame {
        wall.value += dt
        let admission = c.admitForegroundFrame()
        if admission == .run {
            c.session.tick(frameDelta: dt)
            _ = c.session.drainEvents()
            c.syncRewards()
        }
        return admission
    }

    // MARK: Codex 复现（改接暂停 API）

    /// 广告展示 30 秒（期间 SpriteKit 有帧 / 没帧两种）→ 按 Home → 后台 65 秒 → 回来：只结算 65 秒，
    /// 状态与“广告开始时的状态 + 65 秒离线参考模拟”逐字段相同。原实现结算 95 秒。
    func testHomeDuringAdDoesNotCountTheAdAsOffline() throws {
        for framesDuringAd in [false, true] {
            let wall = Wall()
            let campaign = try make(wall)
            XCTAssertEqual(campaign.admitForegroundFrame(), .run)
            let atAdStart = campaign.session.makeState()
            campaign.beginAdPause()                      // CampaignModel：rewards.suspend(true)
            for _ in 0..<120 {                           // 广告展示 30 秒
                if framesDuringAd {
                    XCTAssertEqual(step(campaign, wall), .hold)
                } else {
                    wall.value += 0.25
                }
            }
            campaign.enterBackground()                   // 广告期间按 Home
            wall.value += 65
            let summary = try XCTUnwrap(campaign.becomeActive())
            XCTAssertEqual(summary.simulatedSeconds, 65,
                           "The 30 seconds spent watching the ad in foreground must be excluded (frames: \(framesDuringAd))")
            XCTAssertEqual(summary.awaySeconds, 65)
            XCTAssertEqual(campaign.session.makeState(), try reference(atAdStart, away: 65), "frames: \(framesDuringAd)")
        }
    }

    /// 广告仍在展示时 SpriteKit 先出一帧（关闭回调之前）：不结算、不推进；关闭后第一帧只作基准。
    /// 原实现在这一帧按帧停顿结算 30 秒（Food 0→约 12.5）。
    func testFrameBeforeAdDismissalDoesNotSettleTheAdGap() throws {
        let wall = Wall()
        let campaign = try make(wall)
        XCTAssertEqual(campaign.admitForegroundFrame(), .run)
        campaign.session.boostRemaining = 120            // boost 生效中：广告期间也不能消耗
        let before = campaign.session.makeState()
        campaign.syncRewards()
        let foreground = campaign.progress.rewards.foreground
        campaign.beginAdPause()
        wall.value += 30
        let admission = campaign.admitForegroundFrame()
        if case .resumed = admission {
            XCTFail("Ad gap was settled before the suspended-frame guard")
        }
        XCTAssertEqual(admission, .hold)
        XCTAssertEqual(campaign.session.makeState(), before,
                       "A frame emitted while the ad is still presented must not generate income")
        campaign.endAdPause()                            // CampaignModel：rewards.suspend(false)
        XCTAssertEqual(step(campaign, wall, 0), .run, "the first frame after the ad is only a baseline")
        XCTAssertEqual(campaign.session.makeState(), before)
        XCTAssertEqual(campaign.session.boostRemaining, 120, "boost does not run during the ad")
        XCTAssertEqual(campaign.progress.rewards.foreground, foreground, "the ad is not effective foreground time")
        XCTAssertEqual(step(campaign, wall), .run)
        XCTAssertEqual(campaign.session.makeState().elapsed, before.elapsed + 0.25, "play continues normally after the ad")
    }

    // MARK: 广告与后台交错

    /// 回到前台时广告仍开着：只结算真正的后台区间；之后的帧继续 hold 到广告关闭，关闭后正常推进。
    func testReturningWhileTheAdIsStillOpenSettlesOnlyTheBackgroundAndKeepsHolding() throws {
        let wall = Wall()
        let c = try make(wall)
        step(c, wall)
        step(c, wall)
        let atAdStart = c.session.makeState()
        c.beginAdPause()
        wall.value += 10
        c.enterBackground()
        wall.value += 65
        XCTAssertEqual(step(c, wall, 0), .hold, "resume frame before .active")
        XCTAssertEqual(c.becomeActive()?.simulatedSeconds, 65)
        let settled = c.session.makeState()
        XCTAssertEqual(settled, try reference(atAdStart, away: 65))
        XCTAssertTrue(c.isAdPaused, "the ad is still on screen")
        for _ in 0..<80 { XCTAssertEqual(step(c, wall), .hold, "ad still open") }   // 再看 20 秒
        XCTAssertEqual(c.session.makeState(), settled)
        c.endAdPause()
        XCTAssertEqual(step(c, wall, 0), .run)
        XCTAssertEqual(step(c, wall), .run)
        XCTAssertEqual(c.session.makeState().elapsed, settled.elapsed + 0.25, "neither the ad nor the hold is replayed")
    }

    /// 广告在后台被关闭（例如展示失败或系统回收）：只解除暂停，后台区间仍由 `.active` 结算一次；回来后不再 hold。
    func testAdClosedWhileInBackground() throws {
        let wall = Wall()
        let c = try make(wall)
        step(c, wall)
        let atAdStart = c.session.makeState()
        c.beginAdPause()
        wall.value += 12
        c.enterBackground()
        wall.value += 5
        c.endAdPause()
        wall.value += 60
        XCTAssertEqual(step(c, wall, 0), .hold, "background interval not settled yet")
        XCTAssertEqual(c.becomeActive()?.simulatedSeconds, 65)
        XCTAssertEqual(c.session.makeState(), try reference(atAdStart, away: 65))
        XCTAssertEqual(step(c, wall, 0), .run)
    }

    /// 已在后台才收到开始（不应发生，但回调顺序不由我们控制）：照常结算后台，暂停到结束为止。
    func testPauseBegunWhileInBackground() throws {
        let wall = Wall()
        let c = try make(wall)
        step(c, wall)
        let before = c.session.makeState()
        c.enterBackground()
        c.beginAdPause()
        wall.value += 65
        XCTAssertEqual(c.becomeActive()?.simulatedSeconds, 65)
        XCTAssertEqual(c.session.makeState(), try reference(before, away: 65))
        XCTAssertEqual(step(c, wall), .hold)
        c.endAdPause()
        XCTAssertEqual(step(c, wall, 0), .run)
    }

    // MARK: 幂等

    /// 重复开始、重复关闭、没有开始的关闭、scenePhase + UIKit 双通知：只结算一次、只暂停一次；
    /// 暂停结束后 D-13 帧停顿检测照常工作（没有被永久关掉）。
    func testPauseCallbacksAreIdempotentAndGapDetectionSurvives() throws {
        let wall = Wall()
        let c = try make(wall)
        step(c, wall)
        c.endAdPause()                                   // 没有对应开始：忽略
        XCTAssertFalse(c.isAdPaused)
        XCTAssertEqual(step(c, wall), .run)
        let atAdStart = c.session.makeState()
        let adStart = wall.value
        c.beginAdPause()
        wall.value += 5
        c.beginAdPause()                                 // 重复开始：以第一次为准
        XCTAssertEqual(c.lifecycle.pausedSince, adStart)
        wall.value += 25
        c.enterBackground()
        c.enterBackground()                              // scenePhase 与 UIKit 通知各一次
        wall.value += 65
        XCTAssertEqual(c.becomeActive()?.simulatedSeconds, 65)
        XCTAssertNil(c.becomeActive(), "settled exactly once")
        c.endAdPause()
        c.endAdPause()                                   // 完成后 SDK 再报告一次关闭
        XCTAssertFalse(c.isAdPaused)
        XCTAssertEqual(c.session.makeState(), try reference(atAdStart, away: 65))
        XCTAssertEqual(step(c, wall, 0), .run)
        XCTAssertEqual(step(c, wall), .run)
        let beforeGap = c.session.makeState()
        wall.value += 65                                 // 没有后台记录的停顿：仍按离线结算一次
        guard case .resumed(let summary?) = c.admitForegroundFrame() else { return XCTFail("gap detection must still work") }
        XCTAssertEqual(summary.simulatedSeconds, 65)
        XCTAssertEqual(c.session.makeState(), try reference(beforeGap, away: 65))
    }

    // MARK: 写盘、强杀、封顶、回拨

    /// 广告中按 Home 后进程被杀：后台存档时间是回调时刻，冷启动只结算真正离开的 65 秒（不是 95 秒）。
    func testKillDuringTheAdsBackgroundColdStartsFromTheCallback() throws {
        let store = MemorySaveStore()
        let wall = Wall()
        let c = try make(wall, store: store)
        step(c, wall)
        XCTAssertTrue(c.saveAll())
        let atAdStart = c.session.makeState()
        c.beginAdPause()
        wall.value += 30
        c.enterBackground()
        wall.value += 65                                 // 被杀；65 秒后冷启动
        let (relaunched, result) = CampaignCoordinator.launch(store: store, appVersion: "review", wallClock: wall,
                                                              catalog: .coreOnly)
        guard case .ready(let offline?, _, _) = result, let relaunched else { return XCTFail("\(result)") }
        XCTAssertEqual(offline.simulatedSeconds, 65)
        XCTAssertEqual(relaunched.session.makeState(), try reference(atAdStart, away: 65))
        XCTAssertFalse(relaunched.isAdPaused, "a new process starts unpaused")
    }

    /// 广告期间写盘失败：回来仍只结算一次 65 秒；恢复写盘后冷启动不重复支付。
    func testWriteFailureDuringTheAdStillSettlesOnceAndIsNotRepaid() throws {
        let store = MemorySaveStore()
        let wall = Wall()
        let c = try make(wall, store: store)
        step(c, wall)
        let atAdStart = c.session.makeState()
        c.beginAdPause()
        store.failWrites = true
        wall.value += 30
        c.enterBackground()
        XCTAssertNotNil(c.lifecycle.lastSaveError)
        wall.value += 65
        XCTAssertEqual(c.becomeActive()?.simulatedSeconds, 65)
        let expected = try reference(atAdStart, away: 65)
        XCTAssertEqual(c.session.makeState(), expected)
        c.endAdPause()
        store.failWrites = false
        XCTAssertTrue(c.saveAll())
        let (_, result) = CampaignCoordinator.launch(store: store, appVersion: "review", wallClock: wall, catalog: .coreOnly)
        guard case .ready(nil, _, _) = result else { return XCTFail("already settled: \(result)") }
    }

    /// 离线 1 小时封顶与 25% 效率不变：广告 30 秒 + 后台 2 小时 → 结算 3600 秒。
    func testOfflineCapIsKept() throws {
        let wall = Wall()
        let c = try make(wall)
        step(c, wall)
        let atAdStart = c.session.makeState()
        c.beginAdPause()
        wall.value += 30
        c.enterBackground()
        wall.value += 7_200
        let summary = try XCTUnwrap(c.becomeActive())
        XCTAssertEqual(summary.simulatedSeconds, Rules.offlineCap)
        XCTAssertEqual(summary.awaySeconds, 7_200)
        XCTAssertEqual(c.session.makeState(), try reference(atAdStart, away: 7_200))
        c.endAdPause()
    }

    /// 广告期间系统时间回拨：离开基准不低于高水位，不出现负收益；回拨后再拨回不重复领取。
    func testClockRollbackDuringTheAd() throws {
        let wall = Wall()
        let c = try make(wall)
        step(c, wall)
        let before = c.session.makeState()
        c.beginAdPause()
        wall.value -= 600
        c.enterBackground()
        wall.value += 65
        XCTAssertNil(c.becomeActive(), "no negative or phantom income after a rollback")
        XCTAssertEqual(c.session.makeState(), before)
        c.endAdPause()
    }

    // MARK: 章节

    /// 广告期间切换章节或全部重置（界面上不会发生，防御）：暂停随当前章节的新生命周期保留，关闭后照常。
    func testPauseFollowsTheActiveChapter() throws {
        let wall = Wall()
        let (campaign, _) = CampaignCoordinator.launch(store: MemorySaveStore(), appVersion: "review", wallClock: wall,
                                                       catalog: try twoChapterCatalog(), trace: LifecycleTrace())
        let c = try XCTUnwrap(campaign)
        try DebugScenario.replay600.apply(to: c.session)
        c.evaluate()
        c.beginAdPause()
        try c.switchTo("fixture_two")
        XCTAssertTrue(c.isAdPaused)
        XCTAssertEqual(step(c, wall), .hold)
        c.resetAllProgress()
        XCTAssertTrue(c.isAdPaused)
        XCTAssertEqual(step(c, wall), .hold)
        c.endAdPause()
        XCTAssertEqual(step(c, wall, 0), .run)
    }
}
