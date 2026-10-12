import AntKingdomCore
import SwiftUI
import XCTest
@testable import CrumbKingdom

/// D-14：真实接线的集成时序测试——CampaignModel（scenePhase 处理、rewards.suspend 接线）→ CampaignCoordinator →
/// GameController.frame → RewardModel.watch，用可控墙钟与脚本化广告服务逐步驱动。核心规则另见 AntKingdomCore 的
/// D14AdPauseTests。真实 AdMob SDK 的回调时序与真机锁屏需要账号与设备（NOT_RUN，见报告）。
@MainActor
final class AdPauseIntegrationTests: XCTestCase {
    final class Wall: WallClock {
        var time = 60_000.0
        func now() -> Double { time }
    }

    /// 脚本化广告：present 一直挂起，直到测试调用 dismiss；已赚得回调由测试按需触发（可重复）。
    @MainActor
    final class ScriptedAdService: RewardedAdService {
        var loads = true
        private(set) var presentations = 0
        private var earned: (@MainActor () -> Void)?
        private var dismissal: CheckedContinuation<AdShowOutcome, Never>?
        var isPresenting: Bool { dismissal != nil }

        var canRequestAds: Bool { true }
        var privacyOptionsRequired: Bool { false }
        func prepare() async {}
        func load() async -> Bool { loads }
        func present(onEarned: @escaping @MainActor () -> Void) async -> AdShowOutcome {
            presentations += 1
            earned = onEarned
            return await withCheckedContinuation { dismissal = $0 }
        }
        func presentPrivacyOptions() async {}

        func earn() { earned?() }
        func dismiss(_ outcome: AdShowOutcome) {
            dismissal?.resume(returning: outcome)
            dismissal = nil
        }
    }

    private struct Rig {
        let model: CampaignModel
        let controller: GameController
        let campaign: CampaignCoordinator
        let ads: ScriptedAdService
        let wall: Wall
        let store: MemorySaveStore
    }

    private func makeRig(store: MemorySaveStore = MemorySaveStore(), wall: Wall = Wall(),
                         arguments: [String] = ["-ak-scenario", "pantry_built", "-ak-reward-ready"]) throws -> Rig {
        let ads = ScriptedAdService()
        let model = CampaignModel(arguments: arguments, store: store, wallClock: wall, adService: ads,
                                  storeService: FakeStoreService(mode: .unavailable, productId: ""),
                                  observesSystemLifecycle: false)
        guard case .running(let controller) = model.phase else {
            XCTFail("campaign did not start: \(model.phase)")
            throw CancellationError()
        }
        let campaign = try XCTUnwrap(model.campaign)
        return Rig(model: model, controller: controller, campaign: campaign, ads: ads, wall: wall, store: store)
    }

    /// SpriteKit 帧：每 0.25 秒一帧，墙钟同步前进
    private func frames(_ rig: Rig, seconds: Double) {
        for _ in 0..<Int((seconds / 0.25).rounded()) {
            rig.wall.time += 0.25
            rig.controller.frame(delta: 0.25)
        }
    }

    /// 玩家点 Watch：等到广告真正展示（suspend(true) 已调用、present 挂起）
    private func startWatching(_ rig: Rig) async -> Task<Void, Never> {
        let task = Task { await rig.model.rewards.watch() }
        var spins = 0
        while !rig.ads.isPresenting && spins < 1_000 {
            await Task.yield()
            spins += 1
        }
        XCTAssertTrue(rig.ads.isPresenting, "the ad is on screen")
        return task
    }

    /// 生命周期日志里本次暂停的开始/结束行数（Debug 构建才有日志）
    private func pauseLines(_ rig: Rig) -> (begin: Int, end: Int, ignored: Int) {
        let lines = rig.campaign.lifecycle.trace?.lines ?? []
        return (lines.filter { $0.contains(" pause begin ") }.count,
                lines.filter { $0.contains(" pause end after=") }.count,
                lines.filter { $0.contains(" ignored ") && $0.contains(" pause ") }.count)
    }

    private func reference(_ state: GameState, away: Double, map: MapDefinition) throws -> GameState {
        let copy = try GameSession(state: state, map: map)
        _ = try copy.settleOffline(seconds: min(away, Rules.offlineCap))
        return copy.makeState()
    }

    /// 解锁奖励并进入可领取状态（首帧记录首次建仓）
    private func ready(_ rig: Rig) {
        frames(rig, seconds: 1)
        rig.model.rewards.refresh()
        XCTAssertEqual(rig.model.rewards.status, .ready)
    }

    // MARK: Codex 两条复现的 App 接线版

    /// 广告关闭回调之前 SpriteKit 先出帧（含 30 秒无帧后的第一帧）：控制器不推进、不弹 Welcome Back；
    /// 关闭后第一帧只作基准，之后正常推进。
    func testFramesBeforeTheAdIsDismissedNeitherAdvanceNorSettle() async throws {
        let rig = try makeRig()
        ready(rig)
        let watching = await startWatching(rig)
        XCTAssertTrue(rig.campaign.isAdPaused, "suspend(true) reaches the lifecycle")
        XCTAssertTrue(rig.controller.isSuspended)
        let atAdStart = rig.campaign.session.makeState()
        let foreground = rig.campaign.progress.rewards.foreground
        rig.wall.time += 30                               // 广告遮住 SpriteKit，30 秒无帧
        rig.controller.frame(delta: 1)                    // 关闭回调之前的第一帧
        frames(rig, seconds: 5)
        XCTAssertEqual(rig.campaign.session.makeState(), atAdStart, "no income while the ad is on screen")
        XCTAssertNil(rig.controller.offlineSummary, "no Welcome Back for an ad")
        rig.ads.earn()
        rig.ads.dismiss(.earned)
        await watching.value
        XCTAssertFalse(rig.campaign.isAdPaused)
        XCTAssertFalse(rig.controller.isSuspended)
        rig.campaign.syncRewards()
        XCTAssertEqual(rig.campaign.progress.rewards.foreground, foreground, "the ad is not effective foreground time")
        XCTAssertEqual(rig.campaign.session.boostRemaining, BoostRules.duration, "boost starts after the ad, unused")
        rig.controller.frame(delta: 0)                    // onResume 之后场景的第一帧
        frames(rig, seconds: 1)
        XCTAssertEqual(rig.campaign.session.makeState().elapsed, atAdStart.elapsed + 1, "only post-ad play advances")
        XCTAssertNil(rig.controller.offlineSummary)
    }

    /// 广告中锁屏/按 Home（scenePhase inactive → background，重复通知）→ 后台 65 秒 → 恢复首帧早于 .active →
    /// 回来时广告仍开着 → 重复的已赚得回调 → 关闭。只结算后台 65 秒（参考模拟逐字段相同），奖励只授予一次。
    func testLockDuringTheAdSettlesOnlyTheBackgroundAndGrantsOnce() async throws {
        let rig = try makeRig()
        ready(rig)
        let watching = await startWatching(rig)
        let atAdStart = rig.campaign.session.makeState()
        frames(rig, seconds: 30)                          // 广告 30 秒（这次 SpriteKit 有帧）
        XCTAssertEqual(rig.campaign.session.makeState(), atAdStart)
        rig.model.scenePhaseChanged(.inactive)
        rig.model.scenePhaseChanged(.background)
        rig.model.scenePhaseChanged(.background)          // UIKit 通知与 scenePhase 都到达
        rig.wall.time += 65
        rig.controller.frame(delta: 1)                    // 恢复首帧早于 .active
        rig.model.scenePhaseChanged(.inactive)
        rig.model.scenePhaseChanged(.active)
        rig.model.scenePhaseChanged(.active)
        XCTAssertEqual(rig.controller.offlineSummary?.simulatedSeconds, 65, "the ad's 30 s are not offline")
        let expected = try reference(atAdStart, away: 65, map: rig.campaign.session.map)
        XCTAssertEqual(rig.campaign.session.makeState(), expected)
        XCTAssertTrue(rig.campaign.isAdPaused, "the ad is still open after returning")
        frames(rig, seconds: 10)
        XCTAssertEqual(rig.campaign.session.makeState(), expected, "still paused until the ad closes")
        rig.ads.earn()
        rig.ads.earn()                                    // SDK 重复回调
        rig.ads.dismiss(.earned)
        await watching.value
        XCTAssertEqual(rig.campaign.progress.rewards.dayCount, 1, "granted once")
        XCTAssertEqual(rig.ads.presentations, 1)
        XCTAssertFalse(rig.campaign.isAdPaused)
        rig.model.rewards.suspend(false)                  // 迟到的重复关闭：幂等
        XCTAssertFalse(rig.controller.isSuspended)
        XCTAssertEqual(pauseLines(rig).end, 1)
        XCTAssertEqual(pauseLines(rig).ignored, 1, "the late duplicate is logged and ignored")
        rig.controller.frame(delta: 0)
        frames(rig, seconds: 1)
        XCTAssertEqual(rig.campaign.session.makeState().elapsed, expected.elapsed + 1)
        // 广告结束后 D-13 的帧停顿检测照常：没有后台记录的 65 秒停顿仍结算一次
        let beforeGap = rig.campaign.session.makeState()
        rig.controller.offlineSummary = nil               // 玩家已关闭上一次的 Welcome Back
        rig.wall.time += 65
        rig.controller.frame(delta: 1)
        XCTAssertEqual(rig.controller.offlineSummary?.simulatedSeconds, 65)
        XCTAssertEqual(rig.campaign.session.makeState(), try reference(beforeGap, away: 65, map: rig.campaign.session.map))
    }

    // MARK: 完成 / 取消 / 失败 / 无填充

    func testEveryOutcomeEndsThePauseExactlyOnce() async throws {
        for outcome in [AdShowOutcome.earned, .dismissedEarly, .failed] {
            let rig = try makeRig()
            ready(rig)
            let watching = await startWatching(rig)
            let atAdStart = rig.campaign.session.makeState()
            frames(rig, seconds: 20)
            if outcome == .earned { rig.ads.earn() }
            rig.ads.dismiss(outcome)
            await watching.value
            XCTAssertFalse(rig.campaign.isAdPaused, "\(outcome)")
            XCTAssertFalse(rig.controller.isSuspended, "\(outcome)")
            let lines = pauseLines(rig)
            XCTAssertEqual(lines.begin, 1, "\(outcome)")
            XCTAssertEqual(lines.end, 1, "\(outcome): paired exactly once")
            XCTAssertEqual(lines.ignored, 0, "\(outcome)")
            XCTAssertEqual(rig.campaign.progress.rewards.dayCount, outcome == .earned ? 1 : 0, "\(outcome)")
            XCTAssertEqual(rig.campaign.session.makeState(), atAdStart, "\(outcome): the ad time is not played")
            rig.controller.frame(delta: 0)
            frames(rig, seconds: 1)
            XCTAssertEqual(rig.campaign.session.makeState().elapsed, atAdStart.elapsed + 1, "\(outcome)")
        }
        let rig = try makeRig()
        ready(rig)
        rig.ads.loads = false                             // 无填充：不展示、不暂停
        await rig.model.rewards.watch()
        XCTAssertEqual(rig.ads.presentations, 0)
        XCTAssertFalse(rig.campaign.isAdPaused)
        XCTAssertEqual(rig.model.rewards.messageKey, "reward.unavailable")
    }

    // MARK: 写盘失败与强杀

    /// 广告中按 Home 时写盘失败：回来仍只结算一次；之后在后台被杀（写盘恢复后）冷启动不重复支付。
    /// 另一条：广告中按 Home、后台存档成功后被杀，冷启动只结算真正离开的时长（不含广告 30 秒）。
    func testSaveFailureAndKillDuringTheAd() async throws {
        let store = MemorySaveStore()
        let wall = Wall()
        let rig = try makeRig(store: store, wall: wall)
        ready(rig)
        var watching = await startWatching(rig)
        let atAdStart = rig.campaign.session.makeState()
        store.failWrites = true
        wall.time += 30
        rig.model.scenePhaseChanged(.background)
        wall.time += 65
        rig.model.scenePhaseChanged(.active)
        XCTAssertEqual(rig.controller.offlineSummary?.simulatedSeconds, 65)
        let expected = try reference(atAdStart, away: 65, map: rig.campaign.session.map)
        XCTAssertEqual(rig.campaign.session.makeState(), expected)
        store.failWrites = false
        rig.ads.dismiss(.dismissedEarly)
        await watching.value
        XCTAssertTrue(rig.campaign.saveAll())
        rig.controller.offlineSummary = nil

        // 第二次观看：广告中按 Home、后台存档成功，然后进程被杀，65 秒后冷启动
        rig.controller.frame(delta: 0)
        frames(rig, seconds: 1)
        rig.campaign.debugUnlockRewardsForTesting()
        rig.model.rewards.refresh()
        XCTAssertEqual(rig.model.rewards.status, .ready)
        watching = await startWatching(rig)
        let atSecondAd = rig.campaign.session.makeState()
        wall.time += 30
        rig.model.scenePhaseChanged(.background)
        wall.time += 65
        _ = watching   // 进程被杀：广告与任务一起消失
        let relaunched = try makeRig(store: store, wall: wall, arguments: [])
        XCTAssertEqual(relaunched.controller.offlineSummary?.simulatedSeconds, 65, "cold start counts from the Home press")
        XCTAssertEqual(relaunched.campaign.session.makeState(),
                       try reference(atSecondAd, away: 65, map: relaunched.campaign.session.map))
        XCTAssertFalse(relaunched.campaign.isAdPaused)
        rig.ads.dismiss(.dismissedEarly)                  // 收尾：结束挂起的任务
    }
}
