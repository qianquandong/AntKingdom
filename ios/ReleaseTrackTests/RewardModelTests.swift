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
        model.grant = { id in h.ledger.grant(requestId: id, day: 0) }
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
        model.grant = { id in h.ledger.grant(requestId: id, day: 0) }
        model.refresh()
        await model.watch()
        XCTAssertEqual(h.ledger.dayCount, 0)
        model.refresh()
        XCTAssertEqual(model.status, .unavailable)
    }
}
