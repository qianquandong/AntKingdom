#if DEBUG
import Foundation

/// 仅 Debug：确定性的假商店，供 UI 测试与截图覆盖成功/取消/待批准/失败/不可用/已拥有（QA T35–T37 的模拟器部分）。
/// 启动参数 `-ak-store <mode>`。真实 StoreKit 路径由单元测试的 SKTestSession 与本地配置覆盖；
/// Sandbox / TestFlight 需要用户账号（BLOCKED，见 M5 报告）。
@MainActor
final class FakeStoreService: StoreService {
    enum Mode: String {
        case ok, cancel, pending, fail, unavailable, owned
    }

    let mode: Mode
    private var owned: Set<String> = []
    private let product: StoreProductInfo
    private var onChange: (@MainActor () async -> Void)?

    init(mode: Mode, productId: String) {
        self.mode = mode
        product = StoreProductInfo(id: productId, displayName: "Garden Decor Pack", displayPrice: "$2.99")
        if mode == .owned { owned = [productId] }
    }

    func products(_ ids: [String]) async throws -> [StoreProductInfo] {
        try await Task.sleep(nanoseconds: 200_000_000)
        if mode == .unavailable { throw URLError(.notConnectedToInternet) }
        return ids.contains(product.id) ? [product] : []
    }

    func purchase(_ id: String, grant: @escaping @MainActor (String) -> Void) async -> PurchaseOutcome {
        try? await Task.sleep(nanoseconds: 300_000_000)
        switch mode {
        case .ok, .owned:
            owned.insert(id)
            grant(id)
            return .purchased
        case .cancel: return .cancelled
        case .pending: return .pending
        case .fail, .unavailable: return .failed
        }
    }

    func currentEntitlements() async -> Set<String> { owned }

    func sync() async throws {
        if mode == .unavailable { throw URLError(.notConnectedToInternet) }
    }

    func listen(onChange: @escaping @MainActor () async -> Void) {
        self.onChange = onChange
    }
}
#endif
