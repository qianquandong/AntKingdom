import AntKingdomCore
import StoreKitTest
import XCTest
@testable import CrumbKingdom

/// C11：StoreKit 2 本地配置（SKTestSession）下的真实购买路径，以及 ShopModel 各分支（QA T35–T38 的模拟器部分）。
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

    func testProductLoadsWithLocalizedPrice() async throws {
        let products = try await StoreKitService().products([productId])
        XCTAssertEqual(products.count, 1)
        XCTAssertEqual(products.first?.displayName, "Garden Decor Pack")
        XCTAssertTrue(products.first?.displayPrice.contains("2.99") ?? false, products.first?.displayPrice ?? "")
    }

    func testVerifiedPurchaseGrantsBeforeFinishAndShowsInEntitlements() async throws {
        let service = StoreKitService()
        _ = try await service.products([productId])
        var granted: [String] = []
        let outcome = await service.purchase(productId) { granted.append($0) }
        XCTAssertEqual(outcome, .purchased)
        XCTAssertEqual(granted, [productId])
        let owned = await service.currentEntitlements()
        XCTAssertEqual(owned, [productId])
    }

    func testAskToBuyIsPendingAndGrantsNothing() async throws {
        session.askToBuyEnabled = true
        let service = StoreKitService()
        _ = try await service.products([productId])
        var granted: [String] = []
        let outcome = await service.purchase(productId) { granted.append($0) }
        XCTAssertEqual(outcome, .pending)
        XCTAssertEqual(granted, [])
        let owned = await service.currentEntitlements()
        XCTAssertEqual(owned, [])
    }

    func testRefundRemovesTheEntitlement() async throws {
        let service = StoreKitService()
        _ = try await service.products([productId])
        _ = await service.purchase(productId) { _ in }
        let owned = await service.currentEntitlements()
        XCTAssertEqual(owned, [productId])
        let transaction = try XCTUnwrap(session.allTransactions().first { $0.productIdentifier == productId })
        try session.refundTransaction(identifier: transaction.identifier)
        let after = await service.currentEntitlements()
        XCTAssertEqual(after, [], "refunded/revoked purchase is no longer an entitlement")
    }

    func testUnknownProductIsNotPurchasable() async {
        let outcome = await StoreKitService().purchase("com.example.CrumbKingdom.missing") { _ in
            XCTFail("nothing may be granted")
        }
        XCTAssertEqual(outcome, .failed)
    }
}

/// ShopModel：权益只在已验证成功后授予；失败/取消/待批准不改状态；预览不写进度；撤销回退默认外观。
@MainActor
final class ShopModelTests: XCTestCase {
    private let bundleId = "com.example.CrumbKingdom"

    private final class Harness {
        var progress = PlayerProgress.fresh(.coreOnly)
        var styleChanges = 0
    }

    private func makeShop(_ mode: FakeStoreService.Mode, _ harness: Harness) -> ShopModel {
        let shop = ShopModel(
            service: FakeStoreService(mode: mode, productId: "\(bundleId).garden_decor"), bundleId: bundleId,
            progress: { harness.progress },
            updateEntitlements: { [bundleId] owned in harness.progress.setEntitlements(owned, bundleId: bundleId) },
            selectStyle: { [bundleId] style in harness.progress.select(style, bundleId: bundleId) })
        shop.onStyleChange = { harness.styleChanges += 1 }
        return shop
    }

    func testSuccessfulPurchaseOwnsAndEquipsGarden() async {
        let harness = Harness()
        let shop = makeShop(.ok, harness)
        await shop.load()
        guard case .ready(let info) = shop.product else { return XCTFail("product") }
        XCTAssertEqual(info.displayPrice, "$2.99")
        await shop.buy()
        XCTAssertTrue(shop.owned)
        XCTAssertEqual(harness.progress.selectedRoomStyle, .garden)
        XCTAssertNil(shop.messageKey)
    }

    func testCancelPendingAndFailureGrantNothing() async {
        let cases: [(FakeStoreService.Mode, String?)] = [(.cancel, nil), (.pending, "shop.pending"), (.fail, "shop.failed")]
        for (mode, message) in cases {
            let harness = Harness()
            let shop = makeShop(mode, harness)
            await shop.load()
            await shop.buy()
            XCTAssertFalse(shop.owned, "\(mode)")
            XCTAssertEqual(harness.progress.ownedProducts, [], "\(mode)")
            XCTAssertEqual(harness.progress.selectedRoomStyle, .standard, "\(mode)")
            XCTAssertEqual(shop.messageKey, message, "\(mode)")
        }
    }

    func testUnavailableShowsNoPriceAndRestoreReportsIt() async {
        let harness = Harness()
        let shop = makeShop(.unavailable, harness)
        await shop.load()
        XCTAssertEqual(shop.product, .unavailable)
        await shop.buy()
        XCTAssertFalse(shop.owned)
        await shop.restore()
        XCTAssertEqual(shop.messageKey, "shop.unavailable")
    }

    func testRestoreFindsOwnedOrReportsEmpty() async {
        let owned = Harness()
        let shop = makeShop(.owned, owned)
        await shop.restore()
        XCTAssertTrue(shop.owned)
        XCTAssertEqual(shop.messageKey, "shop.restored")

        let empty = Harness()
        let other = makeShop(.ok, empty)
        await other.restore()
        XCTAssertFalse(other.owned)
        XCTAssertEqual(other.messageKey, "shop.restore_empty")
    }

    func testPreviewDoesNotWriteProgress() async {
        let harness = Harness()
        let shop = makeShop(.ok, harness)
        shop.togglePreview()
        XCTAssertEqual(shop.displayedStyle, .garden)
        XCTAssertEqual(harness.progress.selectedRoomStyle, .standard)
        shop.close()
        XCTAssertEqual(shop.displayedStyle, .standard)
        XCTAssertGreaterThanOrEqual(harness.styleChanges, 2)
    }

    func testRevocationOnRefreshFallsBackToDefault() async {
        let harness = Harness()
        harness.progress.setEntitlements(["\(bundleId).garden_decor"], bundleId: bundleId)
        harness.progress.select(.garden, bundleId: bundleId)
        // 假商店里没有权益：相当于退款/撤销后的当前权益
        let shop = makeShop(.ok, harness)
        await shop.refreshEntitlements()
        XCTAssertFalse(shop.owned)
        XCTAssertEqual(harness.progress.selectedRoomStyle, .standard)
    }
}
