import Foundation
import XCTest
@testable import AntKingdomCore

/// C12：奖励广告 Foraging Boost 的倍率、账本、章节交互与 Python 差分（QA T40–T43 的逻辑部分）。
final class RewardTests: XCTestCase {
    final class FakeWall: WallClock {
        var time: Double
        init(_ time: Double) { self.time = time }
        func now() -> Double { time }
    }

    private func connected() throws -> GameSession {
        let session = GameSession()
        try DebugScenario.connected.apply(to: session)
        _ = session.drainEvents()
        return session
    }

    private func unlocked() -> RewardLedger {
        var ledger = RewardLedger()
        ledger.foreground = BoostRules.unlockForeground
        return ledger
    }

    // MARK: 倍率

    func testMultiplierOneIsTheCoreBaseline() throws {
        let a = Colony(), b = Colony()
        try connectCookie(a)
        try connectCookie(b)
        try a.advance(120)
        try b.advance(120, efficiency: 1, multiplier: 1)
        XCTAssertEqual(a.food, b.food)
        XCTAssertEqual(a.hauled, b.hauled)
        XCTAssertThrowsError(try a.advance(1, multiplier: 0.5))
        XCTAssertThrowsError(try a.advance(1, multiplier: .nan))
    }

    func testBoostEndingInsideAQuantumIsSplitExactly() throws {
        let exact = Colony()
        try connectCookie(exact)
        exact.setHatching(false)
        try exact.advance(0.1, multiplier: BoostRules.multiplier)
        try exact.advance(0.15)
        let session = try connected()
        session.apply(.setHatching(false))
        session.boostRemaining = 0.1
        session.tick(frameDelta: Rules.tick)
        XCTAssertEqual(session.colony.hauled, exact.hauled, accuracy: 1e-12)
        XCTAssertEqual(session.boostRemaining, 0)
        XCTAssertEqual(session.drainForegroundSeconds(), Rules.tick)
        XCTAssertEqual(session.drainForegroundSeconds(), 0)
    }

    func testOfflineNeitherUsesNorConsumesTheBoost() throws {
        let plain = try connected(), boosted = try connected()
        boosted.boostRemaining = 120
        let a = try plain.settleOffline(seconds: 1_800)
        let b = try boosted.settleOffline(seconds: 1_800)
        XCTAssertEqual(a, b)
        XCTAssertEqual(boosted.boostRemaining, 120)
        XCTAssertEqual(boosted.drainForegroundSeconds(), 0, "offline is not active play")
    }

    // MARK: 账本（与 tests/test_rewards.py 同一组规则）

    func testLockedUntilFirstPantryAndTenMinutes() {
        var ledger = RewardLedger()
        XCTAssertEqual(ledger.status(pantryBuilt: false, storageFull: false, day: 0), .locked)
        ledger.foreground = BoostRules.unlockForeground - 1
        XCTAssertEqual(ledger.status(pantryBuilt: true, storageFull: false, day: 0), .locked)
        ledger.foreground = BoostRules.unlockForeground
        XCTAssertEqual(ledger.status(pantryBuilt: true, storageFull: false, day: 0), .ready)
        XCTAssertEqual(ledger.status(pantryBuilt: true, storageFull: true, day: 0), .storageFull)
        XCTAssertEqual(ledger.status(pantryBuilt: true, storageFull: false, day: 0, adAvailable: false), .unavailable)
    }

    func testDuplicateCallbacksGrantOnce() {
        var ledger = unlocked()
        XCTAssertTrue(ledger.grant(requestId: "same", day: 0))
        ledger.boostRemaining -= 100
        XCTAssertFalse(ledger.grant(requestId: "same", day: 0))
        XCTAssertEqual(ledger.boostRemaining, BoostRules.duration - 100)
        XCTAssertEqual(ledger.dayCount, 1)
    }

    func testNoStackingAndCooldownCountsForegroundOnly() {
        var ledger = unlocked()
        ledger.grant(requestId: "a", day: 0)
        XCTAssertEqual(ledger.status(pantryBuilt: true, storageFull: false, day: 0), .active)
        ledger.boostRemaining = 0
        ledger.foreground += BoostRules.duration
        XCTAssertEqual(ledger.status(pantryBuilt: true, storageFull: false, day: 0), .cooldown)
        XCTAssertEqual(ledger.cooldownRemaining, BoostRules.cooldown - BoostRules.duration)
        ledger.foreground += BoostRules.cooldown - BoostRules.duration
        XCTAssertEqual(ledger.status(pantryBuilt: true, storageFull: false, day: 0), .ready)
    }

    func testDailyLimitAndClockRollback() {
        var ledger = unlocked()
        for i in 0..<BoostRules.dailyLimit {
            XCTAssertEqual(ledger.status(pantryBuilt: true, storageFull: false, day: 5), .ready)
            ledger.grant(requestId: "r\(i)", day: 5)
            ledger.boostRemaining = 0
            ledger.foreground += BoostRules.cooldown
        }
        XCTAssertEqual(ledger.status(pantryBuilt: true, storageFull: false, day: 5), .dailyLimit)
        XCTAssertEqual(ledger.status(pantryBuilt: true, storageFull: false, day: 4), .dailyLimit, "rollback does not reset")
        XCTAssertEqual(ledger.status(pantryBuilt: true, storageFull: false, day: 6), .ready)
        ledger.grant(requestId: "next", day: 6)
        XCTAssertEqual(ledger.dayIndex, 6)
        XCTAssertEqual(ledger.dayCount, 1)
    }

    func testRequestMemoryIsBounded() {
        var ledger = unlocked()
        for i in 0..<(BoostRules.rememberedRequests + 10) {
            ledger.processedRequests.append("old-\(i)")
        }
        ledger.grant(requestId: "fresh", day: 1)
        XCTAssertEqual(ledger.processedRequests.count, BoostRules.rememberedRequests)
        XCTAssertEqual(ledger.processedRequests.last, "fresh")
    }

    func testUTCDayIndex() {
        XCTAssertEqual(RewardLedger.utcDay(0), 0)
        XCTAssertEqual(RewardLedger.utcDay(86_399), 0)
        XCTAssertEqual(RewardLedger.utcDay(86_400), 1)
        XCTAssertEqual(RewardLedger.utcDay(.nan), 0)
    }

    // MARK: 章节与存档

    private func campaign(_ store: MemorySaveStore, _ wall: FakeWall) throws -> CampaignCoordinator {
        let (campaign, result) = CampaignCoordinator.launch(store: store, appVersion: "t", wallClock: wall,
                                                            catalog: try twoChapterCatalog())
        return try XCTUnwrap(campaign, "\(result)")
    }

    /// 建仓并累计 600 秒有效前台（通过真实的会话推进），得到可领取状态。
    private func readyCampaign(_ store: MemorySaveStore, _ wall: FakeWall) throws -> CampaignCoordinator {
        let c = try campaign(store, wall)
        try DebugScenario.pantryBuilt.apply(to: c.session)
        c.session.apply(.setHatching(false))
        try c.session.debugReplaceState { $0.food = 100; $0.hauled = 100; $0.spent = 0 }
        c.evaluate()
        c.progress.rewards.foreground = BoostRules.unlockForeground
        return c
    }

    func testGrantIsSavedImmediatelyAndCannotBeRepeatedAfterACrash() throws {
        let store = MemorySaveStore(), wall = FakeWall(86_400 * 3)
        let c = try readyCampaign(store, wall)
        XCTAssertEqual(c.rewardStatus(adAvailable: true), .ready)
        XCTAssertTrue(c.grantReward(requestId: "ad-1"))
        XCTAssertEqual(c.session.boostRemaining, BoostRules.duration)
        XCTAssertFalse(c.grantReward(requestId: "ad-1"), "double earned callback")
        // 没有其他保存：崩溃后重开，奖励状态来自授予时的立即保存
        let reopened = try campaign(store, wall)
        XCTAssertEqual(reopened.progress.rewards.boostRemaining, BoostRules.duration)
        XCTAssertEqual(reopened.session.boostRemaining, BoostRules.duration)
        XCTAssertFalse(reopened.grantReward(requestId: "ad-1"))
        XCTAssertEqual(reopened.rewardStatus(adAvailable: true), .active)
    }

    func testBoostIsGlobalAcrossChapterSwitchReplayAndResetAll() throws {
        let store = MemorySaveStore(), wall = FakeWall(10)
        let c = try campaign(store, wall)
        // 先完成第一章解锁第二章（固定回放是前台时间，会正常消耗 boost，所以放在授予之前）
        try DebugScenario.replay600.apply(to: c.session)
        c.evaluate()
        c.progress.rewards.foreground = BoostRules.unlockForeground
        XCTAssertTrue(c.grantReward(requestId: "ad-1"))
        for _ in 0..<40 { c.session.tick(frameDelta: Rules.tick) }   // 10 秒前台
        c.syncRewards()
        XCTAssertEqual(c.progress.rewards.boostRemaining, BoostRules.duration - 10, accuracy: 1e-9)

        try c.switchTo("fixture_two")
        XCTAssertEqual(c.session.boostRemaining, BoostRules.duration - 10, accuracy: 1e-9, "follows the player")

        c.replayActiveChapter()
        XCTAssertEqual(c.session.boostRemaining, BoostRules.duration - 10, accuracy: 1e-9, "replay does not refresh")
        XCTAssertEqual(c.progress.rewards.dayCount, 1)

        c.resetAllProgress()
        XCTAssertEqual(c.progress.rewards.dayCount, 1, "reset all does not refill daily boosts")
        XCTAssertEqual(c.session.boostRemaining, BoostRules.duration - 10, accuracy: 1e-9)
        XCTAssertFalse(c.grantReward(requestId: "ad-1"), "same request after reset")
    }

    func testStorageFullHidesTheOffer() throws {
        let store = MemorySaveStore(), wall = FakeWall(10)
        let c = try campaign(store, wall)
        try DebugScenario.replay600.apply(to: c.session)
        c.evaluate()
        c.progress.rewards.foreground = BoostRules.unlockForeground
        XCTAssertTrue(c.session.colony.isStorageFull)
        XCTAssertEqual(c.rewardStatus(adAvailable: true), .storageFull, "no pointless ad prompt at full storage")
    }

    func testInvalidLedgerInProgressIsRejected() throws {
        var progress = PlayerProgress.fresh(.coreOnly)
        progress.rewards.boostRemaining = 999
        let data = try JSONEncoder().encode(progress)
        XCTAssertThrowsError(try ProgressRepository.decodeValid(data))
    }

    // MARK: 与 Python 基准差分（RELEASE_SCOPE 第 5 章三条回放 × 两种节奏）

    func testBoostReplaysMatchPython() throws {
        let data = try Data(contentsOf: repoFile("design/reference/core_reference.json"))
        let reference = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let rows = try XCTUnwrap(reference["boost_replays"] as? [[String: Any]])
        XCTAssertEqual(rows.count, 6)
        func number(_ value: Any?) -> Double { (value as? NSNumber)?.doubleValue ?? .nan }
        for row in rows {
            let pace = row["pace"] as! String
            let policy = BoostReplay.Policy(rawValue: row["policy"] as! String)!
            let result = pace == "reference"
                ? BoostReplay.run(actions: BoostReplay.referenceActions, pantryFrom: 150, seconds: 1800, policy: policy)
                : BoostReplay.run(actions: BoostReplay.slowActions, pantryFrom: 420, seconds: 2400, policy: policy)
            let id = "\(pace)/\(policy.rawValue)"
            XCTAssertEqual(result.firstPantry, row["first_pantry"] as? Int, id)
            XCTAssertEqual(result.firstReady, row["first_ready"] as? Int, id)
            XCTAssertEqual(result.grants, row["grants"] as? [Int], id)
            XCTAssertEqual(result.completeAt, row["complete_at"] as? Int, id)
            XCTAssertEqual(result.ants, row["ants"] as? Int, id)
            XCTAssertEqual(result.larvae, row["larvae"] as? Int, id)
            XCTAssertEqual(result.refills, row["refills"] as? Int, id)
            XCTAssertTrue(isClose(result.food, number(row["food"])), id)
            XCTAssertTrue(isClose(result.hauled, number(row["hauled"])), id)
            XCTAssertTrue(isClose(result.spent, number(row["spent"])), id)
            XCTAssertTrue(isClose(result.boostRemaining, number(row["boost_left"])), id)
            XCTAssertTrue(isClose(result.foreground, number(row["foreground"])), id)
            let remaining = row["remaining"] as! [Any]
            for (mine, theirs) in zip(result.remaining, remaining) {
                if theirs is NSNull { XCTAssertNil(mine, id) } else { XCTAssertTrue(isClose(mine ?? .nan, number(theirs)), id) }
            }
        }
    }
}
