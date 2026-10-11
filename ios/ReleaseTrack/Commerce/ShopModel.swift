import AntKingdomCore
import Foundation

/// 外观商品面板的状态（C11，RELEASE_SCOPE 第 2 章）。
/// - 价格只来自 StoreKit；商品未加载时显示不可用/重试，不显示假价格或可点的空购买按钮；
/// - 只有已验证的交易授予权益；权益写盘成功后服务才完成交易（R03）。写盘失败显示 `shop.save_failed`
///   与 Try Again，交易保持未完成，重试或下次启动重新交付，不要求再次购买；
/// - 预览只改变画面，不写进度；关闭面板或停止预览回到当前外观；
/// - 失败、取消、待批准都不扣任何游戏资源，免费游戏照常可玩。
@MainActor
final class ShopModel: ObservableObject {
    enum ProductState: Equatable {
        case idle, loading, unavailable
        case ready(StoreProductInfo)
    }

    @Published private(set) var product: ProductState = .idle
    @Published private(set) var busy = false
    /// 最近一次结果的文案 ID（shop.pending / shop.failed / shop.restored / shop.save_failed …）
    @Published private(set) var messageKey: String?
    @Published private(set) var previewing = false
    /// 权益已更新但写盘失败：显示提示与 Try Again；对应交易未完成
    @Published private(set) var savePending = false
    /// 外观或权益变化（CampaignModel 据此刷新控制器的外观）
    var onStyleChange: (() -> Void)?

    let bundleId: String
    let productId: String
    private let service: StoreService
    private let progress: () -> PlayerProgress?
    /// 更新权益缓存并写盘；返回是否已写盘
    private let updateEntitlements: (Set<String>) -> Bool
    private let selectStyle: (RoomStyle) -> Bool
    /// 刚买下但写盘失败：写盘成功后再启用新外观
    private var equipAfterSave = false
    /// 最近一次权益写盘失败：内存中的权益可能与磁盘不同，下次交付必须重写
    private var entitlementsUnsaved = false

    init(service: StoreService, bundleId: String,
         progress: @escaping () -> PlayerProgress?,
         updateEntitlements: @escaping (Set<String>) -> Bool,
         selectStyle: @escaping (RoomStyle) -> Bool) {
        self.service = service
        self.bundleId = bundleId
        self.productId = RoomStyle.garden.productId(bundleId: bundleId) ?? ""
        self.progress = progress
        self.updateEntitlements = updateEntitlements
        self.selectStyle = selectStyle
    }

    var owned: Bool { progress()?.owns(.garden, bundleId: bundleId) ?? false }
    var equippedStyle: RoomStyle { progress()?.selectedRoomStyle ?? .standard }
    /// 画面上显示的外观：预览优先，其次已启用的外观
    var displayedStyle: RoomStyle { previewing ? .garden : equippedStyle }

    /// 启动：监听交易更新；交付上次未完成的交易；再用 StoreKit 当前权益校正缓存（撤销/退款会回退默认外观）。
    func start() {
        listenForUpdates()
        Task { await syncOnLaunch() }
    }

    func listenForUpdates() {
        service.listen { [weak self] transaction in await self?.deliver(transaction) ?? false }
    }

    func syncOnLaunch() async {
        await service.deliverUnfinished { [weak self] transaction in await self?.deliver(transaction) ?? false }
        await refreshEntitlements()
    }

    /// 交付一笔已验证交易：以 StoreKit 当前权益为准，并按这笔交易补上/移除（currentEntitlements 可能尚未反映它），
    /// 然后写盘。返回 true 表示已写盘，服务此后才完成交易。重复交付同一交易结果相同。
    func deliver(_ transaction: StoreTransaction) async -> Bool {
        var current = await service.currentEntitlements()
        if transaction.revoked {
            current.remove(transaction.productId)
        } else {
            current.insert(transaction.productId)
        }
        return save(current)
    }

    @discardableResult
    func refreshEntitlements() async -> Bool {
        save(await service.currentEntitlements())
    }

    func open() {
        if !savePending { messageKey = nil }
        if case .ready = product { return }
        Task { await load() }
    }

    func load() async {
        product = .loading
        do {
            if let info = try await service.products([productId]).first(where: { $0.id == productId }) {
                product = .ready(info)
            } else {
                product = .unavailable
            }
        } catch {
            product = .unavailable
        }
    }

    func buy() async {
        guard case .ready = product, !busy, !owned else { return }
        busy = true
        messageKey = nil
        let outcome = await service.purchase(productId) { [weak self] transaction in
            await self?.deliver(transaction) ?? false
        }
        busy = false
        switch outcome {
        case .purchased:
            previewing = false
            _ = selectStyle(.garden)
            onStyleChange?()
        case .savePending:
            // 提示已由 save() 设置；写盘成功后再启用，不显示“已完成”
            previewing = false
            equipAfterSave = true
            onStyleChange?()
        case .cancelled:
            break
        case .pending:
            messageKey = "shop.pending"
        case .failed, .unverified:
            messageKey = "shop.failed"
        }
    }

    /// Try Again：重新交付未完成的交易（成功后才完成）；没有未完成交易时把当前权益再写一次。
    func retrySave() async {
        guard !busy else { return }
        busy = true
        let delivered = await service.deliverUnfinished { [weak self] transaction in
            await self?.deliver(transaction) ?? false
        }
        if delivered, savePending {
            await refreshEntitlements()
        }
        busy = false
        if !savePending, equipAfterSave {
            equipAfterSave = false
            if owned { _ = selectStyle(.garden) }
            onStyleChange?()
        }
    }

    func restore() async {
        guard !busy else { return }
        busy = true
        messageKey = nil
        do {
            try await service.sync()
            await service.deliverUnfinished { [weak self] transaction in await self?.deliver(transaction) ?? false }
            if await refreshEntitlements() {
                messageKey = owned ? "shop.restored" : "shop.restore_empty"
            }
        } catch {
            messageKey = "shop.unavailable"
        }
        busy = false
    }

    func equip(_ style: RoomStyle) {
        previewing = false
        _ = selectStyle(style)
        onStyleChange?()
    }

    func togglePreview() {
        previewing.toggle()
        onStyleChange?()
    }

    /// 关闭面板：结束预览，回到已启用的外观。写盘失败的提示保留到成功为止。
    func close() {
        if previewing {
            previewing = false
            onStyleChange?()
        }
        if !savePending { messageKey = nil }
    }

    /// 写权益缓存；记录写盘结果与提示。
    /// - 与已写盘的缓存相同：没有要写的，直接算已交付（启动时存储不可写也不打扰玩家）；
    /// - 新获得的权益写盘失败：显示 shop.save_failed 与 Try Again；
    /// - 只是移除（退款/撤销）写盘失败：内存已回退，交易保持未完成，下次交付或自动保存时重写，不打扰玩家。
    private func save(_ owned: Set<String>) -> Bool {
        let cached = Set(progress()?.ownedProducts ?? [])
        if owned == cached, !entitlementsUnsaved, progress() != nil { return true }
        let grants = !owned.subtracting(cached).isEmpty
        let saved = updateEntitlements(owned)
        entitlementsUnsaved = !saved
        if saved {
            savePending = false
            if messageKey == "shop.save_failed" { messageKey = nil }
        } else if grants || savePending {
            savePending = true
            messageKey = "shop.save_failed"
        }
        onStyleChange?()
        return saved
    }
}
