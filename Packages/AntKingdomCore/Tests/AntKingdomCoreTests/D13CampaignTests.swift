import Foundation
import XCTest
@testable import AntKingdomCore

/// D-13：正式版 CampaignCoordinator 与核心版共用生命周期规则（Issue #11 第 5 条）。
final class D13CampaignTests: XCTestCase {
    final class FakeWall: WallClock {
        var time: Double
        init(_ time: Double) { self.time = time }
        func now() -> Double { time }
    }

    private func campaign(_ wall: FakeWall, store: MemorySaveStore = MemorySaveStore()) throws -> CampaignCoordinator {
        let (campaign, result) = CampaignCoordinator.launch(store: store, appVersion: "t", wallClock: wall,
                                                            catalog: .coreOnly, trace: LifecycleTrace())
        let c = try XCTUnwrap(campaign, "\(result)")
        try DebugScenario.connected.apply(to: c.session)
        _ = c.session.drainEvents()
        return c
    }

    private func reference(_ c: CampaignCoordinator, away: Double) throws -> GameState {
        let copy = try GameSession(state: c.session.makeState(), map: c.session.map)
        _ = try copy.settleOffline(seconds: min(away, Rules.offlineCap))
        return copy.makeState()
    }

    func testResumeFramesAreHeldAndTheSaveBeforeActiveDoesNotEatTheInterval() throws {
        let wall = FakeWall(20_000)
        let c = try campaign(wall)
        XCTAssertEqual(c.admitForegroundFrame(), .run)
        let expected = try reference(c, away: 65)
        c.enterBackground()
        wall.time += 65
        XCTAssertEqual(c.admitForegroundFrame(), .hold)
        c.lifecycle.save(reason: "controller")
        XCTAssertEqual(c.becomeActive()?.simulatedSeconds, 65)
        XCTAssertEqual(c.session.makeState(), expected)
        XCTAssertNil(c.becomeActive())
    }

    func testMissingBackgroundIsSettledByTheFrameGapOnTheActiveChapter() throws {
        let wall = FakeWall(30_000)
        let c = try campaign(wall)
        XCTAssertEqual(c.admitForegroundFrame(), .run)
        let expected = try reference(c, away: 65)
        wall.time += 65
        guard case .resumed(let summary?) = c.admitForegroundFrame() else { return XCTFail("gap") }
        XCTAssertEqual(summary.simulatedSeconds, 65)
        XCTAssertEqual(c.session.makeState(), expected)
        XCTAssertNil(c.becomeActive())
    }

    func testChapterSwitchKeepsTheTraceAndDoesNotSettleTheInactiveChapter() throws {
        let store = MemorySaveStore()
        let wall = FakeWall(40_000)
        let (campaign, _) = CampaignCoordinator.launch(store: store, appVersion: "t", wallClock: wall,
                                                       catalog: try twoChapterCatalog(), trace: LifecycleTrace())
        let c = try XCTUnwrap(campaign)
        try DebugScenario.replay600.apply(to: c.session)
        c.evaluate()
        let trace = try XCTUnwrap(c.lifecycle.trace)
        try c.switchTo("fixture_two")
        XCTAssertTrue(c.lifecycle.trace === trace, "diagnostics follow the active chapter")
        XCTAssertEqual(c.admitForegroundFrame(), .run)
        wall.time += 65
        guard case .resumed(let summary?) = c.admitForegroundFrame() else { return XCTFail("gap") }
        XCTAssertEqual(summary.simulatedSeconds, 65, "only the active chapter is settled")
    }

    /// 全屏奖励广告展示约 30 秒、期间没有帧：广告结束后重新计帧，不把展示时长算成离线收益或前台推进。
    func testAdPauseIsNeitherForegroundNorOffline() throws {
        let wall = FakeWall(50_000)
        let c = try campaign(wall)
        XCTAssertEqual(c.admitForegroundFrame(), .run)
        let before = c.session.makeState()
        wall.time += 30                       // 广告展示，SpriteKit 不出帧
        c.lifecycle.restartFrameClock()       // 广告关闭
        XCTAssertEqual(c.admitForegroundFrame(), .run, "no gap settlement for the ad")
        XCTAssertEqual(c.session.makeState(), before)
        wall.time += 0.25
        XCTAssertEqual(c.admitForegroundFrame(), .run)
    }
}
