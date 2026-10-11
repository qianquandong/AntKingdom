import Foundation
import StoreKit

/// StoreKit 2 实现（C11）。只认已验证（.verified）且未撤销的交易；先授予并持久化，再 finish。
/// 本地测试：scheme 的 StoreKit 配置 ReleaseTrack/Commerce/Products.storekit；单元测试用 SKTestSession。
@MainActor
final class StoreKitService: StoreService {
    private var loaded: [String: Product] = [:]
    /// App 生命周期内常驻（由 CampaignModel 持有），不需要在 deinit 里取消
    private var updatesTask: Task<Void, Never>?

    func products(_ ids: [String]) async throws -> [StoreProductInfo] {
        let products = try await Product.products(for: ids)
        for product in products { loaded[product.id] = product }
        return products.map { StoreProductInfo(id: $0.id, displayName: $0.displayName, displayPrice: $0.displayPrice) }
    }

    func purchase(_ id: String, grant: @escaping @MainActor (String) -> Void) async -> PurchaseOutcome {
        var product = loaded[id]
        if product == nil { product = try? await Product.products(for: [id]).first }
        guard let product else { return .failed }
        do {
            switch try await product.purchase() {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    if transaction.revocationDate == nil { grant(transaction.productID) }
                    await transaction.finish()
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

    func sync() async throws {
        try await AppStore.sync()
    }

    func listen(onChange: @escaping @MainActor () async -> Void) {
        updatesTask?.cancel()
        updatesTask = Task { @MainActor in
            for await result in Transaction.updates {
                // 未验证的更新不授予任何东西；已验证的先由 onChange 重新计算权益并保存，再完成交易
                if case .verified(let transaction) = result {
                    await onChange()
                    await transaction.finish()
                }
            }
        }
    }
}
