import AntKingdomCore
import Foundation

/// 外观商品面板的状态（C11，RELEASE_SCOPE 第 2 章）。
/// - 价格只来自 StoreKit；商品未加载时显示不可用/重试，不显示假价格或可点的空购买按钮；
/// - 只有已验证成功的交易授予权益；先保存权益再完成交易；
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
    /// 最近一次结果的文案 ID（shop.pending / shop.failed / shop.restored …）
    @Published private(set) var messageKey: String?
    @Published private(set) var previewing = false
    /// 外观或权益变化（CampaignModel 据此刷新控制器的外观）
    var onStyleChange: (() -> Void)?

    let bundleId: String
    let productId: String
    private let service: StoreService
    private let progress: () -> PlayerProgress?
    private let updateEntitlements: (Set<String>) -> Void
    private let selectStyle: (RoomStyle) -> Bool

    init(service: StoreService, bundleId: String,
         progress: @escaping () -> PlayerProgress?,
         updateEntitlements: @escaping (Set<String>) -> Void,
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

    /// 启动时与交易更新时：用 StoreKit 当前权益更新缓存（撤销/退款会回退默认外观）。
    func start() {
        service.listen { [weak self] in await self?.refreshEntitlements() }
        Task { await refreshEntitlements() }
    }

    func refreshEntitlements() async {
        let owned = await service.currentEntitlements()
        updateEntitlements(owned)
        onStyleChange?()
    }

    func open() {
        messageKey = nil
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
        let outcome = await service.purchase(productId) { [weak self] id in
            guard let self else { return }
            // 先持久化已验证权益（缓存），交易随后由服务完成
            var current = Set(self.progress()?.ownedProducts ?? [])
            current.insert(id)
            self.updateEntitlements(current)
        }
        busy = false
        switch outcome {
        case .purchased:
            previewing = false
            _ = selectStyle(.garden)
            onStyleChange?()
        case .cancelled:
            break
        case .pending:
            messageKey = "shop.pending"
        case .failed, .unverified:
            messageKey = "shop.failed"
        }
    }

    func restore() async {
        guard !busy else { return }
        busy = true
        messageKey = nil
        do {
            try await service.sync()
            await refreshEntitlements()
            messageKey = owned ? "shop.restored" : "shop.restore_empty"
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

    /// 关闭面板：结束预览，回到已启用的外观。
    func close() {
        if previewing {
            previewing = false
            onStyleChange?()
        }
        messageKey = nil
    }
}
