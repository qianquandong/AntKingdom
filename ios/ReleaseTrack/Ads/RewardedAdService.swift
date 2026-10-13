import Foundation

/// 一次奖励广告展示的结果。是否授予只由“已赚得奖励”回调决定（RELEASE_SCOPE 第 3 章），
/// 这里的结果只用于界面提示；关闭广告本身不是发奖条件。
enum AdShowOutcome: Equatable, Sendable {
    /// SDK 报告已赚得奖励（授予已在回调中完成）
    case earned
    /// 提前关闭：无奖励、不扣任何资源
    case dismissedEarly
    /// 无法展示（无填充/网络/SDK 错误）：无奖励，免费流程照常
    case failed
}

/// 奖励广告服务（TECHNICAL_HANDOFF 第 2 章 AdsService）。只在玩家主动点击时请求和展示，
/// 不自动弹出；同意状态（UMP）在请求广告前检查。所有调用在主 actor 上。
@MainActor
protocol RewardedAdService: AnyObject {
    /// UMP：是否可以请求广告（未完成同意流程前为 false）
    var canRequestAds: Bool { get }
    /// UMP：设置页是否需要提供 Privacy Choices
    var privacyOptionsRequired: Bool { get }
    /// 更新同意状态（必要时展示表单）、启动 SDK、预加载一条广告。可重复调用。
    func prepare() async
    /// 确保有一条已加载的广告；失败返回 false
    func load() async -> Bool
    /// 展示广告并等待其关闭。`onEarned` 可能被 SDK 调用多次，调用方用一次性请求 ID 去重。
    func present(onEarned: @escaping @MainActor () -> Void) async -> AdShowOutcome
    func presentPrivacyOptions() async
}
