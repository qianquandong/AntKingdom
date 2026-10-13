import AntKingdomCore
import Foundation

/// Foraging Boost 面板状态（C12，RELEASE_SCOPE 第 3 章）。
/// - 入口只在玩家主动打开的面板里；不自动弹出、不在失败或满仓时催促；
/// - 每次观看使用一次性请求 ID，只在已赚得回调里授予（账本去重），授予后立即写盘；
/// - 写盘失败（R04）：boost 已生效，显示 `reward.save_failed` 与 Try Again，只重试写盘，不需要再看广告；
/// - 展示期间暂停前台步进；提前关闭、无填充、失败都不授予、不扣资源。
@MainActor
final class RewardModel: ObservableObject {
    @Published private(set) var status: RewardLedger.Status = .locked
    /// 整秒（每秒最多发布一次）
    @Published private(set) var boostRemaining = 0.0
    @Published private(set) var cooldownRemaining = 0.0
    @Published private(set) var busy = false
    @Published private(set) var messageKey: String?
    /// 本次面板打开期间是否刚获得 boost 且已写盘（界面据此关闭面板）
    @Published private(set) var justEarned = false
    /// 已授予但写盘失败：面板保持打开，显示提示与 Try Again
    @Published private(set) var savePending = false

    let service: RewardedAdService
    private var prepared = false
    private var grantedThisWatch = false
    var statusProvider: (Bool) -> RewardLedger.Status = { _ in .locked }
    var ledgerProvider: () -> RewardLedger? = { nil }
    var grant: (String) -> RewardGrantResult = { _ in .duplicate }
    /// Try Again：只重试写盘
    var retrySaveHandler: () -> RewardGrantResult = { .granted }
    /// 是否仍有待写盘的奖励（自动保存成功后变为 false）；未设置时不同步
    var pendingProvider: (() -> Bool)?
    var suspend: (Bool) -> Void = { _ in }

    init(service: RewardedAdService) {
        self.service = service
    }

    /// 入口：可领取、生效中、冷却中、当日已满或暂时无广告时显示；锁定或满仓时不显示（不做无意义催促）。
    var showsEntry: Bool {
        switch status {
        case .ready, .active, .cooldown, .dailyLimit, .unavailable: return true
        case .locked, .storageFull: return false
        }
    }

    /// 每帧调用；只在值变化时发布。首次解锁后才准备同意状态与 SDK（不在第一轮教学中联网）。
    func refresh() {
        let next = statusProvider(service.canRequestAds || !prepared)
        let ledger = ledgerProvider()
        let boost = (ledger?.boostRemaining ?? 0).rounded(.up)
        let cooldown = (ledger?.cooldownRemaining ?? 0).rounded(.up)
        if next != status { status = next }
        if savePending, let pendingProvider, !pendingProvider() {
            savePending = false   // 自动保存已完成写盘
            if messageKey == "reward.save_failed" { messageKey = nil }
        }
        if boost != boostRemaining { boostRemaining = boost }
        if cooldown != cooldownRemaining { cooldownRemaining = cooldown }
        if !prepared, next != .locked {
            prepared = true
            Task { await service.prepare() }
        }
    }

    func open() {
        messageKey = savePending ? "reward.save_failed" : nil
        justEarned = false
    }

    func watch() async {
        guard status == .ready, !busy else { return }
        busy = true
        messageKey = nil
        guard await service.load() else {
            busy = false
            messageKey = "reward.unavailable"
            refresh()
            return
        }
        let requestId = UUID().uuidString
        grantedThisWatch = false
        suspend(true)
        let outcome = await service.present { [weak self] in
            guard let self else { return }
            switch self.grant(requestId) {
            case .granted:
                self.grantedThisWatch = true
            case .savePending:
                self.grantedThisWatch = true
                self.savePending = true
            case .duplicate:
                break   // SDK 重复回调：不再授予
            }
        }
        suspend(false)
        busy = false
        switch outcome {
        case .earned, .dismissedEarly:
            break
        case .failed:
            messageKey = "reward.unavailable"
        }
        if savePending { messageKey = "reward.save_failed" }
        justEarned = grantedThisWatch && !savePending
        refresh()
    }

    /// Try Again：只重试写盘（不重新展示广告、不重复授予、不再占用次数）。
    func retrySave() {
        switch retrySaveHandler() {
        case .granted, .duplicate:
            savePending = false
            if messageKey == "reward.save_failed" { messageKey = nil }
            justEarned = true
        case .savePending:
            messageKey = "reward.save_failed"
        }
        refresh()
    }
}
