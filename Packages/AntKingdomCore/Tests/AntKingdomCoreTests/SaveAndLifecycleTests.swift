import Foundation
import XCTest
@testable import AntKingdomCore

/// C06：版本化保存、备份、损坏恢复、迁移守卫，以及后台/前台/冷启动离线结算（QA T22–T28）。
final class SaveAndLifecycleTests: XCTestCase {
    final class FakeWall: WallClock {
        var time: Double
        init(_ time: Double) { self.time = time }
        func now() -> Double { time }
    }

    private func playedSession() -> GameSession {
        let session = GameSession()
        for p in [GridPoint(2, 4), GridPoint(2, 5), GridPoint(2, 6)] { session.apply(.debugCompleteCell(p)) }
        session.apply(.tapSoil(GridPoint(1, 4)))
        for _ in 0..<(4 * 75) { session.tick(frameDelta: 0.25) }
        session.tick(frameDelta: 0.1)
        return session
    }

    func testRoundTripPreservesEveryField() throws {
        let store = MemorySaveStore()
        let repository = SaveRepository(store: store, appVersion: "0.1.0 (1)")
        let session = playedSession()
        let saved = try repository.save(session, now: 1_000, wallHighWater: 900)
        XCTAssertEqual(saved.wallHighWater, 1_000)
        guard case .loaded(let envelope, false) = SaveRepository(store: store, appVersion: "x").load() else {
            return XCTFail("expected load")
        }
        XCTAssertEqual(envelope, saved)
        XCTAssertEqual(try GameSession(state: envelope.state).makeState(), session.makeState())
    }

    func testFreshWhenNothingSaved() {
        XCTAssertEqual(SaveRepository(store: MemorySaveStore(), appVersion: "x").load(), .fresh)
    }

    func testCorruptMainFallsBackToLastValidBackup() throws {
        let store = MemorySaveStore()
        let repository = SaveRepository(store: store, appVersion: "x")
        let session = playedSession()
        let first = try repository.save(session, now: 1_000, wallHighWater: 1_000)
        session.tick(frameDelta: 1)
        try repository.save(session, now: 1_010, wallHighWater: 1_010)
        store.slots[.main] = Data("{\"schemaVersion\":1, truncated".utf8)
        guard case .loaded(let envelope, true) = SaveRepository(store: store, appVersion: "x").load() else {
            return XCTFail("expected backup")
        }
        XCTAssertEqual(envelope, first)
    }

    func testBothCorruptIsReportedNotSilentlyWiped() {
        let store = MemorySaveStore()
        store.slots[.main] = Data("garbage".utf8)
        store.slots[.backup] = Data("{}".utf8)
        guard case .unavailable = SaveRepository(store: store, appVersion: "x").load() else {
            return XCTFail("expected unavailable")
        }
        XCTAssertNotNil(store.slots[.main], "nothing is deleted without the player's choice")
    }

    func testInvalidStateInsideAValidFileIsRejected() throws {
        let store = MemorySaveStore()
        let repository = SaveRepository(store: store, appVersion: "x")
        var envelope = try repository.save(GameSession(), now: 1, wallHighWater: 1)
        envelope.state.ants = 99
        store.slots[.main] = try SaveRepository.encode(envelope)
        store.slots[.backup] = nil
        guard case .unavailable = repository.load() else { return XCTFail("over-population must be rejected") }
    }

    func testNewerSchemaIsNotDowngradedOrOverwritten() throws {
        let store = MemorySaveStore()
        var envelope = try SaveRepository(store: store, appVersion: "x").save(GameSession(), now: 1, wallHighWater: 1)
        envelope.schemaVersion = 99
        store.slots[.main] = try SaveRepository.encode(envelope)
        XCTAssertEqual(SaveRepository(store: store, appVersion: "x").load(), .unavailable(.newerSchema(99)))
        let (coordinator, result) = LifecycleCoordinator.launch(repository: SaveRepository(store: store, appVersion: "x"),
                                                               wallClock: FakeWall(5))
        XCTAssertNil(coordinator)
        guard case .saveUnavailable(.newerSchema(99)) = result else { return XCTFail("\(result)") }
        let raw = try JSONSerialization.jsonObject(with: store.slots[.main]!) as? [String: Any]
        XCTAssertEqual(raw?["schemaVersion"] as? Int, 99, "the newer save is left untouched")
    }

    func testFailedWriteKeepsPreviousSave() throws {
        let store = MemorySaveStore()
        let repository = SaveRepository(store: store, appVersion: "x")
        let session = playedSession()
        try repository.save(session, now: 1, wallHighWater: 1)
        let before = store.slots[.main]
        store.failWrites = true
        session.tick(frameDelta: 5)
        XCTAssertThrowsError(try repository.save(session, now: 2, wallHighWater: 2))
        XCTAssertEqual(store.slots[.main], before)
    }

    func testFileStoreWritesAtomicallyAndRecoversFromTruncation() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("ak-save-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = FileSaveStore(directory: directory)
        let repository = SaveRepository(store: store, appVersion: "x")
        let session = playedSession()
        try repository.save(session, now: 10, wallHighWater: 10)
        try repository.save(session, now: 20, wallHighWater: 20)
        let mainURL = directory.appendingPathComponent(SaveSlot.main.rawValue)
        let full = try Data(contentsOf: mainURL)
        try full.prefix(full.count / 2).write(to: mainURL)       // 模拟损坏的主档
        guard case .loaded(let envelope, true) = SaveRepository(store: store, appVersion: "x").load() else {
            return XCTFail("expected recovery")
        }
        XCTAssertEqual(envelope.savedAt, 10)
    }

    func testCommittedV1SampleStillLoads() throws {
        let data = try Data(contentsOf: repoFile("Packages/AntKingdomCore/Tests/AntKingdomCoreTests/Fixtures/save_v1_sample.json"))
        let envelope = try SaveRepository.decodeValid(data)
        XCTAssertEqual(envelope.schemaVersion, 1)
        XCTAssertGreaterThan(envelope.state.dugCells.count, 0)
    }

    // MARK: 生命周期

    private func launchedCoordinator(_ wall: FakeWall, store: MemorySaveStore = MemorySaveStore()) -> LifecycleCoordinator {
        let (coordinator, _) = LifecycleCoordinator.launch(repository: SaveRepository(store: store, appVersion: "x"),
                                                           wallClock: wall)
        return coordinator!
    }

    func testBackgroundThirtySecondsMatchesQuarterRateStateMachine() throws {
        let wall = FakeWall(1_000)
        let coordinator = launchedCoordinator(wall)
        for p in [GridPoint(2, 4), GridPoint(2, 5), GridPoint(2, 6)] { coordinator.session.apply(.debugCompleteCell(p)) }
        let expected = coordinator.session.colony.copy()
        coordinator.enterBackground()
        wall.time += 30
        let summary = try XCTUnwrap(coordinator.becomeActive())
        try expected.offline(30)
        XCTAssertEqual(summary.simulatedSeconds, 30)
        XCTAssertEqual(coordinator.session.colony.food, expected.food)
        XCTAssertEqual(summary.hauledFood, expected.hauled, accuracy: 1e-9)
        XCTAssertFalse(summary.isWorthShowing)
    }

    func testOneAndTwoHoursAreCappedAndSettledOnlyOnce() throws {
        for away in [3_600.0, 7_200.0] {
            let wall = FakeWall(50_000)
            let coordinator = launchedCoordinator(wall)
            coordinator.enterBackground()
            coordinator.enterBackground()            // 重复通知
            wall.time += away
            let summary = try XCTUnwrap(coordinator.becomeActive())
            XCTAssertEqual(summary.simulatedSeconds, 3_600)
            XCTAssertEqual(summary.awaySeconds, away)
            XCTAssertNil(coordinator.becomeActive(), "second activation must not pay again")
            XCTAssertEqual(coordinator.session.colony.elapsed, 3_600, accuracy: 1e-9)
        }
    }

    func testClockRollbackGivesNothingAndRollForwardDoesNotRepay() throws {
        let wall = FakeWall(100_000)
        let coordinator = launchedCoordinator(wall)
        coordinator.enterBackground()
        wall.time -= 7_200                           // 用户把系统时间调回两小时
        XCTAssertNil(coordinator.becomeActive())
        coordinator.enterBackground()
        wall.time = 100_000                          // 再调回真实时间
        XCTAssertNil(coordinator.becomeActive(), "high-water mark prevents a second payout")
        XCTAssertEqual(coordinator.session.colony.elapsed, 0)
        wall.time = 100_060
        coordinator.enterBackground()
        wall.time = 100_120
        XCTAssertEqual(coordinator.becomeActive()?.simulatedSeconds, 60)
    }

    func testColdLaunchAfterKillSettlesOnceFromLastSave() throws {
        let store = MemorySaveStore()
        let wall = FakeWall(10_000)
        let coordinator = launchedCoordinator(wall, store: store)
        for p in [GridPoint(2, 4), GridPoint(2, 5), GridPoint(2, 6)] { coordinator.session.apply(.debugCompleteCell(p)) }
        coordinator.save()
        let foodAtKill = coordinator.session.colony.food
        // 进程被杀：没有后台通知。600 秒后冷启动
        wall.time += 600
        let (_, first) = LifecycleCoordinator.launch(repository: SaveRepository(store: store, appVersion: "x"), wallClock: wall)
        guard case .ready(let session, let summary?, false) = first else { return XCTFail("\(first)") }
        XCTAssertEqual(summary.simulatedSeconds, 600)
        XCTAssertGreaterThan(session.colony.hauled, 0)
        XCTAssertGreaterThanOrEqual(session.colony.food + session.colony.spent, foodAtKill)
        // 立刻再次冷启动：不能重复结算
        let (_, second) = LifecycleCoordinator.launch(repository: SaveRepository(store: store, appVersion: "x"), wallClock: wall)
        guard case .ready(let again, nil, false) = second else { return XCTFail("\(second)") }
        XCTAssertEqual(again.makeState(), session.makeState())
    }

    func testResetErasesProgressButKeepsSettings() throws {
        let store = MemorySaveStore()
        let wall = FakeWall(1)
        let coordinator = launchedCoordinator(wall, store: store)
        coordinator.session.apply(.setHaptics(false))
        coordinator.session.apply(.debugCompleteCell(GridPoint(3, 1)))
        coordinator.save()
        coordinator.resetColony()
        guard case .loaded(let envelope, _) = SaveRepository(store: store, appVersion: "x").load() else {
            return XCTFail("expected save after reset")
        }
        XCTAssertTrue(envelope.state.dugCells.isEmpty)
        XCTAssertFalse(envelope.state.settings.haptics)
    }

    func testSaveFailureIsSurfacedNotFatal() {
        let store = MemorySaveStore()
        let coordinator = launchedCoordinator(FakeWall(1), store: store)
        store.failWrites = true
        XCTAssertFalse(coordinator.save())
        XCTAssertNotNil(coordinator.lastSaveError)
        store.failWrites = false
        XCTAssertTrue(coordinator.save())
        XCTAssertNil(coordinator.lastSaveError)
    }
}
