import AntKingdomCore
import XCTest
@testable import CrumbKingdom

/// C12：奖励面板的授予与暂停逻辑（假广告；QA T40/T41 的逻辑部分）。真实 AdMob 测试广告需网络与设备。
@MainActor
final class RewardModelTests: XCTestCase {
    private final class Harness {
        var ledger = RewardLedger()
        var suspensions: [Bool] = []
        var adAvailableSeen: [Bool] = []
        init() { ledger.foreground = BoostRules.unlockForeground }
    }

    private func makeModel(_ mode: FakeRewardedAdService.Mode, _ h: Harness) -> RewardModel {
        let model = RewardModel(service: FakeRewardedAdService(mode: mode))
        model.statusProvider = { available in
            h.adAvailableSeen.append(available)
            return h.ledger.status(pantryBuilt: true, storageFull: false, day: 0, adAvailable: available)
        }
        model.ledgerProvider = { h.ledger }
        model.grant = { id in h.ledger.grant(requestId: id, day: 0) ? .granted : .duplicate }
        model.suspend = { h.suspensions.append($0) }
        model.refresh()
        return model
    }

    func testEarnedRewardGrantsOnceEvenWithDoubleCallbacks() async {
        let h = Harness()
        let model = makeModel(.twice, h)
        XCTAssertEqual(model.status, .ready)
        XCTAssertTrue(model.showsEntry)
        await model.watch()
        XCTAssertEqual(h.ledger.dayCount, 1, "double earned callback grants once")
        XCTAssertEqual(h.ledger.boostRemaining, BoostRules.duration)
        XCTAssertEqual(model.status, .active)
        XCTAssertTrue(model.justEarned)
        XCTAssertEqual(h.suspensions, [true, false], "foreground stepping pauses only while the ad is shown")
    }

    func testClosingEarlyOrFailingGrantsNothing() async {
        for mode in [FakeRewardedAdService.Mode.close, .fail, .nofill] {
            let h = Harness()
            let model = makeModel(mode, h)
            await model.watch()
            XCTAssertEqual(h.ledger.dayCount, 0, "\(mode)")
            XCTAssertEqual(h.ledger.boostRemaining, 0, "\(mode)")
            XCTAssertEqual(model.status, .ready, "free play continues: \(mode)")
            XCTAssertFalse(model.justEarned, "\(mode)")
            XCTAssertEqual(model.messageKey, mode == .close ? nil : "reward.unavailable", "\(mode)")
        }
    }

    func testNoEntryWhenLockedOrStorageFull() {
        let model = RewardModel(service: FakeRewardedAdService(mode: .earn))
        model.statusProvider = { _ in .locked }
        model.refresh()
        XCTAssertFalse(model.showsEntry)
        model.statusProvider = { _ in .storageFull }
        model.refresh()
        XCTAssertFalse(model.showsEntry, "no pointless ad prompt at full storage")
        model.statusProvider = { _ in .dailyLimit }
        model.refresh()
        XCTAssertTrue(model.showsEntry)
    }

    func testUnavailableServiceNeverShowsAnAd() async {
        let h = Harness()
        let model = RewardModel(service: UnavailableAdService())
        model.statusProvider = { available in h.ledger.status(pantryBuilt: true, storageFull: false, day: 0,
                                                              adAvailable: available) }
        model.ledgerProvider = { h.ledger }
        model.grant = { id in h.ledger.grant(requestId: id, day: 0) ? .granted : .duplicate }
        model.refresh()
        await model.watch()
        XCTAssertEqual(h.ledger.dayCount, 0)
        model.refresh()
        XCTAssertEqual(model.status, .unavailable)
    }

    // MARK: R04：真实 CampaignCoordinator + 可失败的 MemorySaveStore

    @MainActor
    private final class Campaign {
        let store = MemorySaveStore()
        let coordinator: CampaignCoordinator
        let service: FakeRewardedAdService

        init(_ mode: FakeRewardedAdService.Mode) throws {
            let (campaign, _) = CampaignCoordinator.launch(store: store, appVersion: "t", wallClock: SystemWallClock(),
                                                           catalog: .coreOnly)
            coordinator = try XCTUnwrap(campaign)
            try DebugScenario.pantryBuilt.apply(to: coordinator.session)
            _ = coordinator.session.drainEvents()
            coordinator.evaluate()
            coordinator.debugUnlockRewardsForTesting()
            service = FakeRewardedAdService(mode: mode)
        }

        func model() -> RewardModel {
            let model = RewardModel(service: service)
            let coordinator = coordinator
            model.statusProvider = { available in coordinator.rewardStatus(adAvailable: available) }
            model.ledgerProvider = { coordinator.progress.rewards }
            model.grant = { id in coordinator.grantReward(requestId: id) }
            model.retrySaveHandler = { coordinator.retryRewardSave() }
            model.pendingProvider = { coordinator.hasUnsavedReward }
            model.refresh()
            return model
        }

        /// 磁盘上的奖励账本（相当于重启后读到的）
        func ledgerOnDisk() -> RewardLedger? {
            guard case .loaded(let progress, _) = ProgressRepository(store: store).load() else { return nil }
            return progress.rewards
        }
    }

    func testSaveFailureShowsRetryAndRetryNeedsNoSecondAd() async throws {
        let c = try Campaign(.earn)
        let model = c.model()
        XCTAssertEqual(model.status, .ready)
        c.store.failWrites = true
        await model.watch()
        XCTAssertTrue(model.savePending)
        XCTAssertEqual(model.messageKey, "reward.save_failed")
        XCTAssertFalse(model.justEarned, "the panel stays open with the error")
        XCTAssertEqual(model.status, .active, "the earned boost is on")
        XCTAssertEqual(c.coordinator.progress.rewards.dayCount, 1)
        XCTAssertEqual(c.ledgerOnDisk()?.dayCount, 0, "not reported as saved")

        model.retrySave()   // 存储仍失败
        XCTAssertTrue(model.savePending)
        XCTAssertEqual(c.coordinator.progress.rewards.dayCount, 1)

        c.store.failWrites = false
        model.retrySave()
        XCTAssertFalse(model.savePending)
        XCTAssertNil(model.messageKey)
        XCTAssertTrue(model.justEarned)
        XCTAssertEqual(c.service.presentations, 1, "no second ad")
        let ledger = try XCTUnwrap(c.ledgerOnDisk())
        XCTAssertEqual(ledger.dayCount, 1)
        XCTAssertEqual(ledger.processedRequests.count, 1)
        XCTAssertNotNil(ledger.lastGrantForeground)
        XCTAssertGreaterThan(ledger.boostRemaining, 0)
    }

    func testDoubleCallbackWhileSaveFailsDoesNotStack() async throws {
        let c = try Campaign(.twice)
        let model = c.model()
        c.store.failWrites = true
        await model.watch()
        XCTAssertTrue(model.savePending)
        XCTAssertEqual(c.coordinator.progress.rewards.dayCount, 1, "second callback only retried the save")
        XCTAssertEqual(c.coordinator.progress.rewards.processedRequests.count, 1)
        XCTAssertEqual(c.coordinator.session.boostRemaining, BoostRules.duration)
    }

    func testAutosaveClearsThePendingPrompt() async throws {
        let c = try Campaign(.earn)
        let model = c.model()
        c.store.failWrites = true
        await model.watch()
        XCTAssertTrue(model.savePending)
        c.store.failWrites = false
        XCTAssertTrue(c.coordinator.saveAll())
        model.refresh()
        XCTAssertFalse(model.savePending)
        XCTAssertNil(model.messageKey)
        XCTAssertEqual(c.ledgerOnDisk()?.dayCount, 1)
    }

    func testFailedOrClosedAdsGrantNothingWithRealProgress() async throws {
        for mode in [FakeRewardedAdService.Mode.close, .fail, .nofill] {
            let c = try Campaign(mode)
            let model = c.model()
            await model.watch()
            XCTAssertEqual(c.coordinator.progress.rewards.dayCount, 0, "\(mode)")
            XCTAssertEqual(c.coordinator.session.boostRemaining, 0, "\(mode)")
            XCTAssertFalse(model.savePending, "\(mode)")
            XCTAssertEqual(model.status, .ready, "free play continues: \(mode)")
        }
    }

    // MARK: R01：SDK 初始化只一次

    func testSDKStartRunsOnceForRepeatedAndConcurrentCalls() async {
        final class Counter { var value = 0 }
        let once = AsyncOnce()
        let counter = Counter()
        let first = Task { @MainActor in
            await once.run {
                counter.value += 1
                try? await Task.sleep(nanoseconds: 50_000_000)
            }
        }
        let second = Task { @MainActor in await once.run { counter.value += 1 } }
        await first.value
        await second.value
        await once.run { counter.value += 1 }
        XCTAssertEqual(counter.value, 1)
        XCTAssertEqual(once.runs, 1)
    }
}
