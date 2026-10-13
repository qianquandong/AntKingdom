import Foundation
import XCTest
@testable import AntKingdomCore

/// C10：章节进度、解锁、切换隔离、重玩、重置与恢复（RELEASE_SCOPE 第 1 章；QA T33、T34、T27）。
final class CampaignTests: XCTestCase {
    final class FakeWall: WallClock {
        var time: Double
        init(_ time: Double) { self.time = time }
        func now() -> Double { time }
    }

    private var store: MemorySaveStore!
    private var wall: FakeWall!
    private var catalog: ChapterCatalog!

    override func setUpWithError() throws {
        store = MemorySaveStore()
        wall = FakeWall(10_000)
        catalog = try twoChapterCatalog()
    }

    private func launch() throws -> (CampaignCoordinator, CampaignLaunchResult) {
        let (campaign, result) = CampaignCoordinator.launch(store: store, appVersion: "t", wallClock: wall, catalog: catalog)
        guard let campaign else {
            XCTFail("launch failed: \(result)")
            throw CampaignError.saveFailed(.unreadable("launch"))
        }
        return (campaign, result)
    }

    /// 把当前章节推进到三个主目标全部达成（固定 600 秒回放）。
    private func complete(_ campaign: CampaignCoordinator) throws {
        try DebugScenario.replay600.apply(to: campaign.session)
    }

    func testFreshLaunchStartsInFirstChapterWithOnlyItUnlocked() throws {
        let (campaign, result) = try launch()
        guard case .ready(nil, false, false) = result else { return XCTFail("\(result)") }
        XCTAssertEqual(campaign.activeChapter.id, "backyard")
        XCTAssertEqual(campaign.progress.unlockedChapterIds, ["backyard"])
        XCTAssertEqual(campaign.progress.completedChapterIds, [])
        XCTAssertNotNil(store.slots[SaveSlotPair.progress.main], "progress is saved immediately")
        XCTAssertNotNil(store.slots[.main], "first chapter keeps the core save file name")
    }

    func testCoreSaveContinuesAsFirstChapter() throws {
        let core = GameSession()
        try DebugScenario.connected.apply(to: core)
        try SaveRepository(store: store, appVersion: "core").save(core, now: wall.time, wallHighWater: wall.time)
        let (campaign, _) = try launch()
        XCTAssertEqual(campaign.session.makeState().dugCells, core.makeState().dugCells)
        XCTAssertEqual(campaign.progress.goals(for: "backyard"), [.connectCookie], "recorded on launch")
    }

    func testCompletingAChapterUnlocksTheNextAndAnnouncesOnce() throws {
        let (campaign, _) = try launch()
        try complete(campaign)
        let events = campaign.evaluate()
        XCTAssertTrue(events.contains(.chapterCompleted(chapterId: "backyard", next: "fixture_two")), "\(events)")
        XCTAssertTrue(events.contains(.goalAchieved(.fullColony)))
        XCTAssertEqual(campaign.progress.unlockedChapterIds, ["backyard", "fixture_two"])
        XCTAssertEqual(campaign.progress.completedChapterIds, ["backyard"])
        XCTAssertTrue(campaign.evaluate().isEmpty, "completion is announced once per run")
        // 立即持久化：冷启动后仍解锁，且不在启动时重复宣布
        let (again, _) = try launch()
        XCTAssertTrue(again.progress.isUnlocked("fixture_two"))
        XCTAssertTrue(again.evaluate().isEmpty)
    }

    func testLockedChapterCannotBeOpened() throws {
        let (campaign, _) = try launch()
        XCTAssertThrowsError(try campaign.switchTo("fixture_two")) { error in
            XCTAssertEqual(error as? CampaignError, .locked("fixture_two"))
        }
        XCTAssertThrowsError(try campaign.switchTo("nope")) { error in
            XCTAssertEqual(error as? CampaignError, .unknownChapter("nope"))
        }
        XCTAssertEqual(campaign.activeChapter.id, "backyard")
    }

    func testChaptersKeepSeparateStateAndInactiveChaptersDoNotEarn() throws {
        let (campaign, _) = try launch()
        try complete(campaign)
        campaign.evaluate()
        let backyard = campaign.session.makeState()

        try campaign.switchTo("fixture_two")
        XCTAssertEqual(campaign.activeChapter.id, "fixture_two")
        XCTAssertEqual(campaign.session.colony.ants, Rules.initialAnts, "new chapter starts fresh")
        XCTAssertEqual(campaign.session.map.id, "fixture_two")
        campaign.session.apply(.debugCompleteCell(GridPoint(3, 1)))
        let fixture = campaign.session.makeState()

        // 两小时后切回第一章：非活动期间不产粮、不孵化
        wall.time += 7_200
        try campaign.switchTo("backyard")
        XCTAssertEqual(campaign.session.makeState().food, backyard.food)
        XCTAssertEqual(campaign.session.makeState().elapsed, backyard.elapsed)
        XCTAssertEqual(campaign.session.makeState().dugCells, backyard.dugCells)

        // 再切过去：第二章保持离开时的状态
        wall.time += 7_200
        try campaign.switchTo("fixture_two")
        XCTAssertEqual(campaign.session.makeState().dugCells, fixture.dugCells)
        XCTAssertEqual(campaign.session.makeState().elapsed, fixture.elapsed)
        XCTAssertEqual(campaign.progress.activeChapterId, "fixture_two")
    }

    func testOfflineSettlesOnlyTheActiveChapterOnce() throws {
        let (campaign, _) = try launch()
        try DebugScenario.connected.apply(to: campaign.session)
        campaign.lifecycle.save()
        try complete(campaign)
        campaign.evaluate()
        try campaign.switchTo("fixture_two")
        campaign.session.apply(.debugCompleteCell(GridPoint(3, 1)))
        try campaign.switchTo("backyard")
        let backyardBefore = campaign.session.makeState()
        campaign.enterBackground()

        // 冷启动 30 分钟后：只结算当前章节（Backyard）一次
        wall.time += 1_800
        let (relaunched, result) = try launch()
        guard case .ready(let offline, _, _) = result else { return XCTFail("\(result)") }
        XCTAssertEqual(offline?.simulatedSeconds, 1_800)
        XCTAssertEqual(relaunched.activeChapter.id, "backyard")
        XCTAssertEqual(relaunched.session.makeState().elapsed, backyardBefore.elapsed + 1_800, accuracy: 1e-6)

        // 第二章没有因为这 30 分钟而推进
        let fixtureRepo = SaveRepository(store: store, appVersion: "t", slots: .chapter("fixture_two"),
                                         map: catalog.chapter("fixture_two")!.map)
        guard case .loaded(let envelope, _) = fixtureRepo.load() else { return XCTFail("fixture save") }
        let elapsedBefore = envelope.state.elapsed
        try relaunched.switchTo("fixture_two")
        XCTAssertEqual(relaunched.session.makeState().elapsed, elapsedBefore)
    }

    func testReplayResetsOnlyTheChapterAndKeepsUnlocksAndGoals() throws {
        let (campaign, _) = try launch()
        campaign.session.apply(.setSound(false))
        try complete(campaign)
        campaign.evaluate()
        let goals = campaign.progress.goals(for: "backyard")

        campaign.replayActiveChapter()
        XCTAssertEqual(campaign.session.colony.ants, Rules.initialAnts)
        XCTAssertEqual(campaign.session.colony.food, 0)
        XCTAssertEqual(campaign.session.makeState().dugCells, [])
        XCTAssertFalse(campaign.session.settings.sound, "settings stay")
        XCTAssertTrue(campaign.progress.isUnlocked("fixture_two"))
        XCTAssertTrue(campaign.progress.isCompleted("backyard"))
        XCTAssertEqual(campaign.progress.goals(for: "backyard"), goals)

        // 重玩后再次完成，完成页再宣布一次（新的一局）
        try complete(campaign)
        XCTAssertTrue(campaign.evaluate().contains(.chapterCompleted(chapterId: "backyard", next: "fixture_two")))
    }

    func testResetAllProgressClearsChaptersAndUnlocksButKeepsSettings() throws {
        let (campaign, _) = try launch()
        campaign.session.apply(.setHaptics(false))
        try complete(campaign)
        campaign.evaluate()
        try campaign.switchTo("fixture_two")
        campaign.session.apply(.debugCompleteCell(GridPoint(3, 1)))
        campaign.lifecycle.save()

        campaign.resetAllProgress()
        XCTAssertEqual(campaign.activeChapter.id, "backyard")
        XCTAssertEqual(campaign.progress.unlockedChapterIds, ["backyard"])
        XCTAssertEqual(campaign.progress.completedChapterIds, [])
        XCTAssertFalse(campaign.session.settings.haptics)
        XCTAssertNil(store.slots[SaveSlotPair.chapter("fixture_two").main])
        let (again, _) = try launch()
        XCTAssertEqual(again.progress.unlockedChapterIds, ["backyard"])
        XCTAssertFalse(again.session.settings.haptics)
    }

    func testCorruptProgressIsRebuiltFromChapterSaves() throws {
        let (campaign, _) = try launch()
        try complete(campaign)
        campaign.evaluate()
        campaign.lifecycle.save()
        store.slots[SaveSlotPair.progress.main] = Data("garbage".utf8)
        store.slots[SaveSlotPair.progress.backup] = Data("{}".utf8)

        let (again, result) = try launch()
        guard case .ready(_, _, true) = result else { return XCTFail("expected rebuilt progress: \(result)") }
        XCTAssertTrue(again.progress.isCompleted("backyard"))
        XCTAssertTrue(again.progress.isUnlocked("fixture_two"), "unlocks are not silently lost")
    }

    func testCorruptProgressMainUsesBackup() throws {
        let (campaign, _) = try launch()
        try complete(campaign)
        campaign.evaluate()
        campaign.saveProgress()
        store.slots[SaveSlotPair.progress.main] = Data("{\"schemaVersion\":1".utf8)
        let (again, result) = try launch()
        guard case .ready(_, true, false) = result else { return XCTFail("\(result)") }
        XCTAssertTrue(again.progress.isUnlocked("fixture_two"))
    }

    func testNewerProgressSchemaIsNotOverwritten() throws {
        _ = try launch()
        var progress = PlayerProgress.fresh(catalog)
        progress.schemaVersion = 99
        let data = try JSONEncoder().encode(progress)
        store.slots[SaveSlotPair.progress.main] = data
        let (campaign, result) = CampaignCoordinator.launch(store: store, appVersion: "t", wallClock: wall, catalog: catalog)
        XCTAssertNil(campaign)
        guard case .progressUnavailable(.newerSchema(99)) = result else { return XCTFail("\(result)") }
        XCTAssertEqual(store.slots[SaveSlotPair.progress.main], data)
    }

    func testBrokenChapterSaveOnlyAffectsThatChapter() throws {
        let (campaign, _) = try launch()
        try complete(campaign)
        campaign.evaluate()
        try campaign.switchTo("fixture_two")
        campaign.enterBackground()
        let pair = SaveSlotPair.chapter("fixture_two")
        store.slots[pair.main] = Data("x".utf8)
        store.slots[pair.backup] = Data("y".utf8)

        let (broken, result) = CampaignCoordinator.launch(store: store, appVersion: "t", wallClock: wall, catalog: catalog)
        XCTAssertNil(broken)
        guard case .chapterSaveUnavailable("fixture_two", _) = result else { return XCTFail("\(result)") }
        XCTAssertNotNil(store.slots[.main], "first chapter untouched")

        CampaignCoordinator.startChapterOver("fixture_two", store: store, appVersion: "t", catalog: catalog)
        let (recovered, _) = try launch()
        XCTAssertEqual(recovered.activeChapter.id, "fixture_two")
        XCTAssertEqual(recovered.session.colony.ants, Rules.initialAnts)
        XCTAssertTrue(recovered.progress.isCompleted("backyard"))
    }

    func testNewChaptersInALaterBuildUnlockForPlayersWhoFinished() throws {
        catalog = ChapterCatalog.coreOnly
        let (campaign, _) = try launch()
        try complete(campaign)
        let events = campaign.evaluate()
        XCTAssertTrue(events.contains(.chapterCompleted(chapterId: "backyard", next: nil)))
        XCTAssertEqual(campaign.progress.unlockedChapterIds, ["backyard"])

        catalog = try twoChapterCatalog()
        let (updated, _) = try launch()
        XCTAssertTrue(updated.progress.isUnlocked("fixture_two"))
    }

    func testProgressDecodesWithMissingOptionalKeys() throws {
        let json = #"{"schemaVersion":1,"activeChapterId":"backyard","unlockedChapterIds":["backyard"]}"#
        let progress = try ProgressRepository.decodeValid(Data(json.utf8))
        XCTAssertEqual(progress.completedChapterIds, [])
        XCTAssertEqual(progress.achievedGoals, [:])
        let invalid = #"{"schemaVersion":1,"activeChapterId":"x","unlockedChapterIds":["backyard"]}"#
        XCTAssertThrowsError(try ProgressRepository.decodeValid(Data(invalid.utf8)))
    }
}
