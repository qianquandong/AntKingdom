import Foundation

/// 界面需要的商品信息。价格一律来自 StoreKit 的本地化显示价格，不写死（RELEASE_SCOPE 第 2 章）。
struct StoreProductInfo: Equatable, Sendable {
    let id: String
    let displayName: String
    let displayPrice: String
}

/// 一笔已验证的交易（StoreKit `Transaction` 或测试替身）。未验证的交易不会以这个形式出现。
struct StoreTransaction: Equatable, Sendable {
    let id: UInt64
    let productId: String
    /// 已退款/撤销：交付时移除这项权益
    let revoked: Bool
}

/// 一次购买的结果。只有 `.purchased` 表示已验证、权益已写盘、交易已完成。
enum PurchaseOutcome: Equatable, Sendable {
    case purchased
    /// 已验证（App Store 已收款），但本机写盘失败：交易保持未完成，界面提示重试；
    /// 重试或下次启动重新交付，不需要再次购买
    case savePending
    case cancelled
    /// 待批准（Ask to Buy 等）：不授予，批准后经交易更新到达
    case pending
    /// 网络/商店错误或商品不可用：不扣任何游戏资源
    case failed
    /// 交易未通过验证：不授予
    case unverified
}

/// 交付一笔已验证交易：更新权益缓存并写盘。返回 true 表示已写盘，服务此后才完成（finish）交易；
/// 返回 false 时交易保持未完成。同一交易可能被交付多次（重试、启动时重新交付），实现必须幂等。
typealias DeliverTransaction = @MainActor (StoreTransaction) async -> Bool

/// 商店服务（TECHNICAL_HANDOFF 第 2 章 StoreService）。所有回调在主 actor 上执行。
/// 约定（R03）：先交付并写盘，写盘成功后才完成交易；写盘失败的交易留在未完成队列里等待重试。
@MainActor
protocol StoreService: AnyObject {
    func products(_ ids: [String]) async throws -> [StoreProductInfo]
    func purchase(_ id: String, deliver: @escaping DeliverTransaction) async -> PurchaseOutcome
    /// 当前已验证、未撤销的权益（商品 ID）
    func currentEntitlements() async -> Set<String>
    /// 重新交付所有未完成的已验证交易（上次写盘失败，或完成前进程退出）；交付成功的才完成。
    /// 返回是否全部交付成功（没有未完成交易也返回 true）。
    @discardableResult
    func deliverUnfinished(_ deliver: @escaping DeliverTransaction) async -> Bool
    /// 恢复购买：与 App Store 同步（可能要求登录）
    func sync() async throws
    /// 监听后续交易（其他设备购买、Ask to Buy 批准、退款/撤销）；交付成功后才完成交易
    func listen(_ deliver: @escaping DeliverTransaction)
}
