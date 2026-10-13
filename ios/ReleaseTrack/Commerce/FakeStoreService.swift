#if DEBUG
import Foundation

/// 仅 Debug：确定性的假商店，供 UI 测试与截图覆盖成功/取消/待批准/失败/不可用/已拥有（QA T35–T37 的模拟器部分）。
/// 启动参数 `-ak-store <mode>`。真实 StoreKit 路径由单元测试的 SKTestSession 与本地配置覆盖；
/// Sandbox / TestFlight 需要用户账号（BLOCKED，见 M5 报告）。
/// 与 StoreKit 一样：交付返回 false 的交易不完成，留在未完成队列里；`log` 按顺序记录交付与完成，供测试核对次序。
@MainActor
final class FakeStoreService: StoreService {
    enum Mode: String {
        case ok, cancel, pending, fail, unavailable, owned
    }

    let mode: Mode
    /// App Store 一侧的权益（与本机是否写盘无关）
    private(set) var owned: Set<String> = []
    private(set) var unfinished: [StoreTransaction] = []
    /// 每笔交易被完成的次数
    private(set) var finishCount: [UInt64: Int] = [:]
    /// 次序记录：`deliver:<id>`（交付返回后，附 ok/failed）、`finish:<id>`
    private(set) var log: [String] = []
    private let product: StoreProductInfo
    private var onUpdate: DeliverTransaction?
    private var nextId: UInt64 = 1
    /// 交付前的延迟（UI 测试模拟真实购买耗时；单元测试设为 0）
    var delay: UInt64 = 300_000_000
    /// 测试用：完成交易的那一刻调用（核对此时权益已经在磁盘上）
    var onFinish: ((StoreTransaction) -> Void)?

    init(mode: Mode, productId: String) {
        self.mode = mode
        product = StoreProductInfo(id: productId, displayName: "Garden Decor Pack", displayPrice: "$2.99")
        if mode == .owned { owned = [productId] }
    }

    func products(_ ids: [String]) async throws -> [StoreProductInfo] {
        if delay > 0 { try await Task.sleep(nanoseconds: 200_000_000) }
        if mode == .unavailable { throw URLError(.notConnectedToInternet) }
        return ids.contains(product.id) ? [product] : []
    }

    func purchase(_ id: String, deliver: @escaping DeliverTransaction) async -> PurchaseOutcome {
        if delay > 0 { try? await Task.sleep(nanoseconds: delay) }
        switch mode {
        case .ok, .owned:
            let transaction = makeTransaction(id)
            owned.insert(id)
            guard await run(deliver, transaction) else {
                unfinished.append(transaction)
                return .savePending
            }
            return .purchased
        case .cancel: return .cancelled
        case .pending: return .pending
        case .fail, .unavailable: return .failed
        }
    }

    func currentEntitlements() async -> Set<String> { owned }

    @discardableResult
    func deliverUnfinished(_ deliver: @escaping DeliverTransaction) async -> Bool {
        let pending = unfinished
        unfinished = []
        for transaction in pending {
            if !(await run(deliver, transaction)) { unfinished.append(transaction) }
        }
        return unfinished.isEmpty
    }

    func sync() async throws {
        if mode == .unavailable { throw URLError(.notConnectedToInternet) }
    }

    func listen(_ deliver: @escaping DeliverTransaction) {
        onUpdate = deliver
    }

    /// 测试用：模拟一次交易更新（Ask to Buy 批准、其他设备购买、退款/撤销）。
    func simulateUpdate(productId: String, revoked: Bool = false) async {
        let transaction = makeTransaction(productId, revoked: revoked)
        if revoked { owned.remove(productId) } else { owned.insert(productId) }
        guard let onUpdate else {
            unfinished.append(transaction)
            return
        }
        if !(await run(onUpdate, transaction)) { unfinished.append(transaction) }
    }

    private func makeTransaction(_ productId: String, revoked: Bool = false) -> StoreTransaction {
        defer { nextId += 1 }
        return StoreTransaction(id: nextId, productId: productId, revoked: revoked)
    }

    /// 交付；成功才完成。
    private func run(_ deliver: DeliverTransaction, _ transaction: StoreTransaction) async -> Bool {
        let saved = await deliver(transaction)
        log.append("deliver:\(transaction.id):\(saved ? "ok" : "failed")")
        if saved {
            onFinish?(transaction)
            finishCount[transaction.id, default: 0] += 1
            log.append("finish:\(transaction.id)")
        }
        return saved
    }
}
#endif
