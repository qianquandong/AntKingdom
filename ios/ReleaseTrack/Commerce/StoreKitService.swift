import Foundation
import StoreKit

/// StoreKit 2 实现（C11）。只认已验证（.verified）的交易；先交付并写盘，写盘成功后才 finish（R03）。
/// 写盘失败的交易不 finish：它留在 `Transaction.unfinished` 里，重试或下次启动时重新交付。
/// 本地测试：scheme 的 StoreKit 配置 ReleaseTrack/Commerce/Products.storekit；单元测试用 SKTestSession。
@MainActor
final class StoreKitService: StoreService {
    private var loaded: [String: Product] = [:]
    /// App 生命周期内常驻（由 CampaignModel 持有），不需要在 deinit 里取消
    private var updatesTask: Task<Void, Never>?
    /// 本进程内已完成的交易：启动时 updates 与 unfinished 可能交付同一笔，只完成一次
    private var finished: Set<UInt64> = []

    func products(_ ids: [String]) async throws -> [StoreProductInfo] {
        let products = try await Product.products(for: ids)
        for product in products { loaded[product.id] = product }
        return products.map { StoreProductInfo(id: $0.id, displayName: $0.displayName, displayPrice: $0.displayPrice) }
    }

    func purchase(_ id: String, deliver: @escaping DeliverTransaction) async -> PurchaseOutcome {
        var product = loaded[id]
        if product == nil { product = try? await Product.products(for: [id]).first }
        guard let product else { return .failed }
        do {
            switch try await product.purchase() {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    guard await deliver(StoreTransaction(transaction)) else { return .savePending }
                    await complete(transaction)
                    return .purchased
                case .unverified:
                    return .unverified
                }
            case .userCancelled:
                return .cancelled
            case .pending:
                return .pending
            @unknown default:
                return .failed
            }
        } catch {
            return .failed
        }
    }

    func currentEntitlements() async -> Set<String> {
        var owned = Set<String>()
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result, transaction.revocationDate == nil {
                owned.insert(transaction.productID)
            }
        }
        return owned
    }

    @discardableResult
    func deliverUnfinished(_ deliver: @escaping DeliverTransaction) async -> Bool {
        var all = true
        for await result in Transaction.unfinished {
            // 未验证的交易不授予，也不替它完成
            guard case .verified(let transaction) = result else { continue }
            if await deliver(StoreTransaction(transaction)) {
                await complete(transaction)
            } else {
                all = false
            }
        }
        return all
    }

    func sync() async throws {
        try await AppStore.sync()
    }

    func listen(_ deliver: @escaping DeliverTransaction) {
        updatesTask?.cancel()
        updatesTask = Task { @MainActor [weak self] in
            for await result in Transaction.updates {
                // 未验证的更新不授予任何东西；已验证的先交付写盘，成功后才完成
                guard case .verified(let transaction) = result else { continue }
                if await deliver(StoreTransaction(transaction)) {
                    await self?.complete(transaction)
                }
            }
        }
    }

    private func complete(_ transaction: Transaction) async {
        guard finished.insert(transaction.id).inserted else { return }
        await transaction.finish()
    }
}

extension StoreTransaction {
    init(_ transaction: Transaction) {
        self.init(id: transaction.id, productId: transaction.productID, revoked: transaction.revocationDate != nil)
    }
}
