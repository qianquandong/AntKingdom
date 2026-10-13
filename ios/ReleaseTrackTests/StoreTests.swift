import AntKingdomCore
import StoreKit
import StoreKitTest
import XCTest
@testable import CrumbKingdom

/// C11 / R03：StoreKit 2 本地配置（SKTestSession）下的真实交易路径：交付（写盘）成功后才完成交易；
/// 交付失败的交易留在 Transaction.unfinished，重试后只完成一次；Ask to Buy 批准与退款经 Transaction.updates 到达。
/// 商品 ID 与价格来自 Products.storekit（占位 Bundle ID 前缀、US$2.99 只是本地测试值，真实定价待用户决定）。
@MainActor
final class StoreKitServiceTests: XCTestCase {
    private let productId = "com.example.CrumbKingdom.garden_decor"
    private var session: SKTestSession!

    override func setUp() async throws {
        session = try SKTestSession(configurationFileNamed: "Products")
        session.resetToDefaultState()
        session.disableDialogs = true
        session.clearTransactions()
    }

    override func tearDown() async throws {
        session.clearTransactions()
    }

    /// StoreKit 的未完成交易（本商品）
    private func unfinishedIds() async -> [UInt64] {
        var ids: [UInt64] = []
        for await result in Transaction.unfinished {
            if case .verified(let transaction) = result, transaction.productID == productId { ids.append(transaction.id) }
        }
        return ids
    }

    /// StoreKit 测试会话的状态传播是异步的：在时限内等待条件成立（期望本身不变）
    private func eventually(_ seconds: Double = 10, _ condition: () async -> Bool) async -> Bool {
        let deadline = Date().addingTimeInterval(seconds)
        while Date() < deadline {
            if await condition() { return true }
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        return await condition()
    }

    func testProductLoadsWithLocalizedPrice() async throws {
        let products = try await StoreKitService().products([productId])
        XCTAssertEqual(products.count, 1)
        XCTAssertEqual(products.first?.displayName, "Garden Decor Pack")
        XCTAssertTrue(products.first?.displayPrice.contains("2.99") ?? false, products.first?.displayPrice ?? "")
    }

    func testVerifiedPurchaseDeliversThenFinishes() async throws {
        let service = StoreKitService()
        _ = try await service.products([productId])
        var delivered: [StoreTransaction] = []
        var unfinishedAtDelivery: [UInt64] = []
        let outcome = await service.purchase(productId) { transaction in
            delivered.append(transaction)
            unfinishedAtDelivery = await self.unfinishedIds()
            return true
        }
        XCTAssertEqual(outcome, .purchased)
        XCTAssertEqual(delivered.map(\.productId), [productId])
        XCTAssertEqual(delivered.first?.revoked, false)
        XCTAssertEqual(unfinishedAtDelivery, delivered.map(\.id), "not finished before the entitlement was saved")
        let finished = await eventually { await self.unfinishedIds().isEmpty }
        XCTAssertTrue(finished, "finished after a successful save")
        let owned = await service.currentEntitlements()
        XCTAssertEqual(owned, [productId])
    }

    /// R03：写盘失败 → 不完成交易、不报告成功；重试交付成功后只完成一次。
    func testSaveFailureLeavesTransactionUnfinishedUntilRetry() async throws {
        let service = StoreKitService()
        _ = try await service.products([productId])
        let outcome = await service.purchase(productId) { _ in false }
        XCTAssertEqual(outcome, .savePending)
        let pending = await unfinishedIds()
        XCTAssertEqual(pending.count, 1, "the paid transaction stays unfinished for redelivery")

        var failedAgain: [UInt64] = []
        let stillFailing = await service.deliverUnfinished { failedAgain.append($0.id); return false }
        XCTAssertFalse(stillFailing)
        XCTAssertEqual(failedAgain, pending)
        let stillPending = await unfinishedIds()
        XCTAssertEqual(stillPending, pending)

        var retried: [UInt64] = []
        let delivered = await service.deliverUnfinished { retried.append($0.id); return true }
        XCTAssertTrue(delivered)
        XCTAssertEqual(retried, pending)
        let finished = await eventually { await self.unfinishedIds().isEmpty }
        XCTAssertTrue(finished)
        var redelivered: [UInt64] = []
        await service.deliverUnfinished { redelivered.append($0.id); return true }
        XCTAssertEqual(redelivered, [], "a finished transaction is not delivered again")
    }

    /// Ask to Buy：购买返回 pending 不授予；批准后经 Transaction.updates 交付，写盘失败时仍未完成，重试后完成。
    func testAskToBuyApprovalArrivesThroughUpdates() async throws {
        session.askToBuyEnabled = true
        let service = StoreKitService()
        _ = try await service.products([productId])
        let outcome = await service.purchase(productId) { _ in
            XCTFail("nothing may be delivered while awaiting approval")
            return true
        }
        XCTAssertEqual(outcome, .pending)
        let ownedWhilePending = await service.currentEntitlements()
        XCTAssertEqual(ownedWhilePending, [])

        let approved = expectation(description: "approved transaction delivered")
        var updates: [StoreTransaction] = []
        service.listen { transaction in
            updates.append(transaction)
            if updates.count == 1 { approved.fulfill() }
            return false   // 写盘失败
        }
        let transaction = try XCTUnwrap(session.allTransactions().first { $0.productIdentifier == productId })
        try session.approveAskToBuyTransaction(identifier: transaction.identifier)
        await fulfillment(of: [approved], timeout: 15)
        XCTAssertEqual(updates.first?.productId, productId)
        XCTAssertEqual(updates.first?.revoked, false)
        let unfinished = await unfinishedIds()
        XCTAssertEqual(unfinished.count, 1, "save failed: approval stays unfinished")

        let delivered = await service.deliverUnfinished { _ in true }
        XCTAssertTrue(delivered)
        let finished = await eventually { await self.unfinishedIds().isEmpty }
        XCTAssertTrue(finished)
    }

    /// 退款/撤销经 Transaction.updates 以“已撤销”到达；当前权益随之移除。
    func testRefundArrivesAsRevokedUpdateAndRemovesTheEntitlement() async throws {
        let service = StoreKitService()
        _ = try await service.products([productId])
        _ = await service.purchase(productId) { _ in true }
        let owned = await service.currentEntitlements()
        XCTAssertEqual(owned, [productId])

        let revoked = expectation(description: "revocation delivered")
        service.listen { transaction in
            if transaction.revoked, transaction.productId == self.productId { revoked.fulfill() }
            return true
        }
        let transaction = try XCTUnwrap(session.allTransactions().first { $0.productIdentifier == productId })
        try session.refundTransaction(identifier: transaction.identifier)
        await fulfillment(of: [revoked], timeout: 15)
        let removed = await eventually { await service.currentEntitlements().isEmpty }
        XCTAssertTrue(removed, "refunded/revoked purchase is no longer an entitlement")
    }

    func testUnknownProductIsNotPurchasable() async {
        let outcome = await StoreKitService().purchase("com.example.CrumbKingdom.missing") { _ in
            XCTFail("nothing may be delivered")
            return true
        }
        XCTAssertEqual(outcome, .failed)
    }
}

/// ShopModel + 真实 CampaignCoordinator + 可失败的 MemorySaveStore（R03）：
/// 权益写盘成功后才完成交易；写盘失败不完成、不显示成功、可重试且只完成一次；购买与交易更新两条路径；
/// 取消/待批准/失败不授予；预览不写进度；撤销回退默认外观；重置游戏不删除权益。
@MainActor
final class ShopModelTests: XCTestCase {
    private let bundleId = "com.example.CrumbKingdom"
    private var garden: String { "\(bundleId).garden_decor" }

    private final class Harness {
        let store: MemorySaveStore
        let campaign: CampaignCoordinator
        var styleChanges = 0

        /// 传入已有的存储相当于重启后读同一份磁盘
        init(store: MemorySaveStore = MemorySaveStore()) throws {
            self.store = store
            let (campaign, _) = CampaignCoordinator.launch(store: store, appVersion: "t", wallClock: SystemWallClock(),
                                                           catalog: .coreOnly)
            self.campaign = try XCTUnwrap(campaign)
        }

        /// 磁盘上的全局进度（相当于重启后读到的）
        func onDisk() throws -> PlayerProgress? {
            guard case .loaded(let progress, _) = ProgressRepository(store: store).load() else { return nil }
            return progress
        }
    }

    private func makeShop(_ mode: FakeStoreService.Mode, _ harness: Harness) -> (ShopModel, FakeStoreService) {
        let service = FakeStoreService(mode: mode, productId: garden)
        service.delay = 0
        let bundleId = bundleId
        let shop = ShopModel(
            service: service, bundleId: bundleId,
            progress: { harness.campaign.progress },
            updateEntitlements: { owned in harness.campaign.updateEntitlements(owned, bundleId: bundleId) },
            selectStyle: { style in harness.campaign.selectRoomStyle(style, bundleId: bundleId) })
        shop.onStyleChange = { harness.styleChanges += 1 }
        return (shop, service)
    }

    func testPurchaseSavesTheEntitlementBeforeFinishing() async throws {
        let harness = try Harness()
        let (shop, service) = makeShop(.ok, harness)
        var onDiskAtFinish: [String]?
        service.onFinish = { _ in onDiskAtFinish = (try? harness.onDisk())?.ownedProducts }
        await shop.load()
        guard case .ready(let info) = shop.product else { return XCTFail("product") }
        XCTAssertEqual(info.displayPrice, "$2.99")
        await shop.buy()
        XCTAssertEqual(service.log, ["deliver:1:ok", "finish:1"])
        XCTAssertEqual(onDiskAtFinish, [garden], "entitlement was on disk when the transaction finished")
        XCTAssertEqual(service.finishCount, [1: 1])
        XCTAssertTrue(shop.owned)
        XCTAssertFalse(shop.savePending)
        XCTAssertNil(shop.messageKey)
        XCTAssertEqual(try harness.onDisk()?.selectedRoomStyle, .garden)
    }

    /// R03 验收：注入写盘失败 → 不 finish、不显示成功；存储恢复后 Try Again → 同一交易幂等交付、只完成一次。
    func testSaveFailureKeepsTheTransactionUnfinishedAndRetryCompletesOnce() async throws {
        let harness = try Harness()
        let (shop, service) = makeShop(.ok, harness)
        await shop.load()
        harness.store.failWrites = true
        await shop.buy()
        XCTAssertEqual(service.log, ["deliver:1:failed"])
        XCTAssertEqual(service.finishCount, [:], "no finish without a saved entitlement")
        XCTAssertEqual(service.unfinished.map(\.id), [1])
        XCTAssertTrue(shop.savePending)
        XCTAssertEqual(shop.messageKey, "shop.save_failed")
        XCTAssertEqual(harness.campaign.progress.selectedRoomStyle, .standard, "not equipped as if delivered")
        XCTAssertEqual(try harness.onDisk()?.ownedProducts ?? [], [])

        await shop.retrySave()   // 存储仍失败
        XCTAssertEqual(service.finishCount, [:])
        XCTAssertTrue(shop.savePending)
        XCTAssertEqual(shop.messageKey, "shop.save_failed")

        harness.store.failWrites = false
        await shop.retrySave()
        XCTAssertEqual(service.log, ["deliver:1:failed", "deliver:1:failed", "deliver:1:ok", "finish:1"])
        XCTAssertEqual(service.finishCount, [1: 1])
        XCTAssertTrue(service.unfinished.isEmpty)
        XCTAssertFalse(shop.savePending)
        XCTAssertNil(shop.messageKey)
        XCTAssertEqual(try harness.onDisk()?.ownedProducts, [garden])
        XCTAssertEqual(harness.campaign.progress.selectedRoomStyle, .garden, "equipped once the purchase is saved")

        await shop.retrySave()
        await shop.syncOnLaunch()
        XCTAssertEqual(service.finishCount, [1: 1], "finished exactly once")
    }

    /// 写盘失败后进程退出：下次启动交付未完成的交易（不需要再次购买），写盘成功后完成。
    func testUnfinishedPurchaseIsDeliveredOnNextLaunch() async throws {
        let harness = try Harness()
        let (shop, service) = makeShop(.ok, harness)
        await shop.load()
        harness.store.failWrites = true
        await shop.buy()
        XCTAssertEqual(service.unfinished.count, 1)

        harness.store.failWrites = false
        let relaunched = try Harness(store: harness.store)   // 重启：同一份磁盘，权益不在上面
        XCTAssertFalse(relaunched.campaign.progress.owns(.garden, bundleId: bundleId))
        let restarted = ShopModel(
            service: service, bundleId: bundleId,
            progress: { relaunched.campaign.progress },
            updateEntitlements: { [bundleId] owned in relaunched.campaign.updateEntitlements(owned, bundleId: bundleId) },
            selectStyle: { [bundleId] style in relaunched.campaign.selectRoomStyle(style, bundleId: bundleId) })
        await restarted.syncOnLaunch()
        XCTAssertEqual(service.finishCount, [1: 1])
        XCTAssertTrue(restarted.owned)
        XCTAssertFalse(restarted.savePending)
        XCTAssertEqual(try relaunched.onDisk()?.ownedProducts, [garden])
    }

    /// 交易更新路径（Ask to Buy 批准、其他设备购买）：写盘失败不完成；恢复后启动/重试只完成一次。
    func testApprovedUpdateFollowsTheSameSaveThenFinishOrder() async throws {
        let harness = try Harness()
        let (shop, service) = makeShop(.pending, harness)
        await shop.load()
        await shop.buy()
        XCTAssertEqual(shop.messageKey, "shop.pending")
        XCTAssertFalse(shop.owned)
        shop.listenForUpdates()

        harness.store.failWrites = true
        await service.simulateUpdate(productId: garden)
        XCTAssertEqual(service.finishCount, [:])
        XCTAssertTrue(shop.savePending)
        XCTAssertEqual(shop.messageKey, "shop.save_failed")

        harness.store.failWrites = false
        await shop.retrySave()
        XCTAssertEqual(service.finishCount.values.reduce(0, +), 1)
        XCTAssertFalse(shop.savePending)
        XCTAssertEqual(try harness.onDisk()?.ownedProducts, [garden])
    }

    /// 退款/撤销经交易更新到达：权益移除、回退默认外观并写盘后才完成；地图与经济不动。
    func testRefundUpdateRevertsTheStyleAndSavesBeforeFinishing() async throws {
        let harness = try Harness()
        let (shop, service) = makeShop(.owned, harness)
        await shop.syncOnLaunch()
        shop.equip(.garden)
        XCTAssertEqual(harness.campaign.progress.selectedRoomStyle, .garden)
        let colony = harness.campaign.session.makeState()
        shop.listenForUpdates()
        var styleAtFinish: RoomStyle?
        service.onFinish = { _ in styleAtFinish = (try? harness.onDisk())?.selectedRoomStyle }
        await service.simulateUpdate(productId: garden, revoked: true)
        XCTAssertFalse(shop.owned)
        XCTAssertEqual(harness.campaign.progress.selectedRoomStyle, .standard)
        XCTAssertEqual(styleAtFinish, .standard)
        XCTAssertEqual(try harness.onDisk()?.ownedProducts, [])
        XCTAssertEqual(harness.campaign.session.makeState(), colony)
    }

    /// 启动时存储不可写、权益也没有变化：不提示保存失败，可以正常购买（CI 38168148276 的 UI 测试发现的缺陷）。
    func testLaunchWithFailingStorageAndNoChangeShowsNoError() async throws {
        let harness = try Harness()
        let (shop, service) = makeShop(.ok, harness)
        harness.store.failWrites = true
        await shop.syncOnLaunch()
        XCTAssertFalse(shop.savePending)
        XCTAssertNil(shop.messageKey)
        await shop.load()
        guard case .ready = shop.product else { return XCTFail("buy stays available") }
        await shop.buy()
        XCTAssertTrue(shop.savePending, "the purchase itself is what failed to save")
        XCTAssertEqual(service.finishCount, [:])
    }

    /// 退款写盘失败：内存已回退、不打扰玩家，交易不完成；存储恢复后下次交付重写磁盘再完成。
    func testRevocationSaveFailureRetriesQuietly() async throws {
        let harness = try Harness()
        let (shop, service) = makeShop(.owned, harness)
        await shop.syncOnLaunch()
        shop.equip(.garden)
        shop.listenForUpdates()
        harness.store.failWrites = true
        await service.simulateUpdate(productId: garden, revoked: true)
        XCTAssertFalse(shop.owned)
        XCTAssertEqual(harness.campaign.progress.selectedRoomStyle, .standard)
        XCTAssertFalse(shop.savePending)
        XCTAssertNil(shop.messageKey)
        XCTAssertEqual(service.unfinished.count, 1, "not finished until the removal is on disk")
        XCTAssertEqual(try harness.onDisk()?.ownedProducts, [garden])

        harness.store.failWrites = false
        await shop.syncOnLaunch()
        XCTAssertTrue(service.unfinished.isEmpty)
        XCTAssertEqual(try harness.onDisk()?.ownedProducts, [])
        XCTAssertEqual(try harness.onDisk()?.selectedRoomStyle, .standard)
    }

    func testCancelPendingAndFailureGrantNothing() async throws {
        let cases: [(FakeStoreService.Mode, String?)] = [(.cancel, nil), (.pending, "shop.pending"), (.fail, "shop.failed")]
        for (mode, message) in cases {
            let harness = try Harness()
            let (shop, service) = makeShop(mode, harness)
            await shop.load()
            await shop.buy()
            XCTAssertFalse(shop.owned, "\(mode)")
            XCTAssertEqual(harness.campaign.progress.ownedProducts, [], "\(mode)")
            XCTAssertEqual(harness.campaign.progress.selectedRoomStyle, .standard, "\(mode)")
            XCTAssertEqual(shop.messageKey, message, "\(mode)")
            XCTAssertEqual(service.log, [], "\(mode): nothing delivered or finished")
        }
    }

    func testUnavailableShowsNoPriceAndRestoreReportsIt() async throws {
        let harness = try Harness()
        let (shop, _) = makeShop(.unavailable, harness)
        await shop.load()
        XCTAssertEqual(shop.product, .unavailable)
        await shop.buy()
        XCTAssertFalse(shop.owned)
        await shop.restore()
        XCTAssertEqual(shop.messageKey, "shop.unavailable")
    }

    func testRestoreFindsOwnedOrReportsEmpty() async throws {
        let owned = try Harness()
        let (shop, _) = makeShop(.owned, owned)
        await shop.restore()
        XCTAssertTrue(shop.owned)
        XCTAssertEqual(shop.messageKey, "shop.restored")
        XCTAssertEqual(try owned.onDisk()?.ownedProducts, [garden])

        let empty = try Harness()
        let (other, _) = makeShop(.ok, empty)
        await other.restore()
        XCTAssertFalse(other.owned)
        XCTAssertEqual(other.messageKey, "shop.restore_empty")
    }

    func testRestoreWithFailingStorageReportsTheSaveError() async throws {
        let harness = try Harness()
        let (shop, _) = makeShop(.owned, harness)
        harness.store.failWrites = true
        await shop.restore()
        XCTAssertEqual(shop.messageKey, "shop.save_failed", "not reported as restored")
        XCTAssertTrue(shop.savePending)
        harness.store.failWrites = false
        await shop.retrySave()
        XCTAssertFalse(shop.savePending)
        XCTAssertEqual(try harness.onDisk()?.ownedProducts, [garden])
    }

    func testPreviewDoesNotWriteProgress() async throws {
        let harness = try Harness()
        let (shop, _) = makeShop(.ok, harness)
        shop.togglePreview()
        XCTAssertEqual(shop.displayedStyle, .garden)
        XCTAssertEqual(harness.campaign.progress.selectedRoomStyle, .standard)
        shop.close()
        XCTAssertEqual(shop.displayedStyle, .standard)
        XCTAssertGreaterThanOrEqual(harness.styleChanges, 2)
    }

    func testRevocationOnRefreshFallsBackToDefault() async throws {
        let harness = try Harness()
        harness.campaign.updateEntitlements([garden], bundleId: bundleId)
        harness.campaign.selectRoomStyle(.garden, bundleId: bundleId)
        // 假商店里没有权益：相当于退款/撤销后的当前权益
        let (shop, _) = makeShop(.ok, harness)
        await shop.refreshEntitlements()
        XCTAssertFalse(shop.owned)
        XCTAssertEqual(harness.campaign.progress.selectedRoomStyle, .standard)
    }

    func testResetAllProgressKeepsTheSavedPurchase() async throws {
        let harness = try Harness()
        let (shop, _) = makeShop(.ok, harness)
        await shop.load()
        await shop.buy()
        harness.campaign.resetAllProgress()
        XCTAssertTrue(shop.owned)
        XCTAssertEqual(try harness.onDisk()?.ownedProducts, [garden])
    }
}
