import Foundation

/// 界面需要的商品信息。价格一律来自 StoreKit 的本地化显示价格，不写死（RELEASE_SCOPE 第 2 章）。
struct StoreProductInfo: Equatable, Sendable {
    let id: String
    let displayName: String
    let displayPrice: String
}

/// 一次购买的结果。只有 `.purchased` 表示已验证成功并已授予权益。
enum PurchaseOutcome: Equatable, Sendable {
    case purchased
    case cancelled
    /// 待批准（Ask to Buy 等）：不授予，批准后经交易更新到达
    case pending
    /// 网络/商店错误或商品不可用：不扣任何游戏资源
    case failed
    /// 交易未通过验证：不授予
    case unverified
}

/// 商店服务（TECHNICAL_HANDOFF 第 2 章 StoreService）。所有回调在主 actor 上执行。
/// `grant` 在交易完成（finish）之前调用：先持久化权益，再完成交易。
@MainActor
protocol StoreService: AnyObject {
    func products(_ ids: [String]) async throws -> [StoreProductInfo]
    func purchase(_ id: String, grant: @escaping @MainActor (String) -> Void) async -> PurchaseOutcome
    /// 当前已验证、未撤销的权益（商品 ID）
    func currentEntitlements() async -> Set<String>
    /// 恢复购买：与 App Store 同步（可能要求登录）
    func sync() async throws
    /// 监听后续交易（其他设备购买、Ask to Buy 批准、退款/撤销）；回调完成（权益已保存）后才完成交易
    func listen(onChange: @escaping @MainActor () async -> Void)
}
