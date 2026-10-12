import Foundation
import UIKit

/// 不可用的广告服务：没有广告 SDK 时（或 Debug 的 UI 测试默认）使用，入口显示“暂无广告”，免费流程照常。
@MainActor
final class UnavailableAdService: RewardedAdService {
    var canRequestAds: Bool { false }
    var privacyOptionsRequired: Bool { false }
    func prepare() async {}
    func load() async -> Bool { false }
    func present(onEarned: @escaping @MainActor () -> Void) async -> AdShowOutcome { .failed }
    func presentPrivacyOptions() async {}
}

#if DEBUG
/// 仅 Debug：确定性的假广告（启动参数 `-ak-ads <mode>`），覆盖 QA T40/T41 的模拟器部分：
/// earn 成功、twice 双回调、close 提前关闭、fail 展示失败、nofill 无填充。真实 AdMob 测试广告需要网络与设备验证。
/// long（D-14）：像真实 SDK 一样从顶层控制器全屏展示（遮住 SpriteKit）40 秒后赚得并关闭，用于“广告中按 Home”的 UI 测试。
@MainActor
final class FakeRewardedAdService: RewardedAdService {
    enum Mode: String {
        case earn, twice, close, fail, nofill, long
    }
    static let longDuration: UInt64 = 40_000_000_000

    let mode: Mode
    private(set) var presentations = 0

    init(mode: Mode) {
        self.mode = mode
    }

    var canRequestAds: Bool { true }
    var privacyOptionsRequired: Bool { true }

    func prepare() async {}

    func load() async -> Bool {
        try? await Task.sleep(nanoseconds: 200_000_000)
        return mode != .nofill
    }

    func present(onEarned: @escaping @MainActor () -> Void) async -> AdShowOutcome {
        presentations += 1
        if mode == .long { return await presentFullScreen(onEarned: onEarned) }
        try? await Task.sleep(nanoseconds: 500_000_000)   // 模拟全屏广告展示时间（前台步进暂停）
        switch mode {
        case .earn:
            onEarned()
            return .earned
        case .twice:
            onEarned()
            onEarned()   // SDK 重复回调：账本按请求 ID 只授予一次
            return .earned
        case .close:
            return .dismissedEarly
        case .fail, .nofill:
            return .failed
        case .long:
            return .failed   // 上面已处理
        }
    }

    /// 无文字的黑色全屏控制器（不是玩家可见文案；只在 Debug 假广告里出现）
    private func presentFullScreen(onEarned: @escaping @MainActor () -> Void) async -> AdShowOutcome {
        guard let root = Self.topViewController() else { return .failed }
        let cover = UIViewController()
        cover.view.backgroundColor = .black
        cover.view.isAccessibilityElement = true
        cover.view.accessibilityIdentifier = "fake.ad"
        cover.modalPresentationStyle = .fullScreen
        root.present(cover, animated: false)
        try? await Task.sleep(nanoseconds: Self.longDuration)
        onEarned()
        await withCheckedContinuation { (done: CheckedContinuation<Void, Never>) in
            cover.dismiss(animated: false) { done.resume() }
        }
        return .earned
    }

    private static func topViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        var top = scene?.keyWindow?.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        return top
    }

    func presentPrivacyOptions() async {}
}
#endif
