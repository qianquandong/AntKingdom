#if canImport(GoogleMobileAds) && canImport(UserMessagingPlatform)
import GoogleMobileAds
import UIKit
import UserMessagingPlatform

/// 单一 AdMob + UMP 集成（RELEASE_SCOPE 第 3、4 章；GoogleMobileAds 13.11.0、UMP 3.1.0，版本锁定见 ios/project.yml）。
/// - 每次准备时更新同意状态，必要时展示 UMP 表单；canRequestAds 为 false 时不初始化 SDK、不请求广告，
///   入口显示“暂无广告”，免费玩法照常；
/// - SDK 只初始化一次（`MobileAds.shared.start()` 为异步，等待完成后才加载广告）；并发的准备共用同一次；
/// - 不请求 ATT、不读取 IDFA；
/// - 只在 SDK 的已赚得奖励回调里授予，关闭/失败不授予。
/// 开发与测试使用 Google 公布的测试 App ID 与测试广告单元（Info.plist 的 GADApplicationIdentifier、
/// AKRewardedAdUnitID）；正式 ID 由用户的 AdMob 账号提供（M5 BLOCKED）。
@MainActor
final class AdMobRewardedService: NSObject, RewardedAdService, FullScreenContentDelegate {
    private let unitID: String
    private var ad: RewardedAd?
    private let sdkStart = AsyncOnce()
    private var preparing: Task<Void, Never>?
    private var dismissal: CheckedContinuation<Void, Never>?
    private var presentFailed = false
    /// 本次展示是否收到过已赚得回调（只用于界面提示；授予在 onEarned 里按请求 ID 去重）
    private var earnedThisPresentation = false

    init(unitID: String) {
        self.unitID = unitID
    }

    var canRequestAds: Bool { ConsentInformation.shared.canRequestAds }

    var privacyOptionsRequired: Bool {
        ConsentInformation.shared.privacyOptionsRequirementStatus == .required
    }

    func prepare() async {
        // 重复/并发调用等待同一次准备；完成后再次调用会重新检查同意状态
        if let preparing { return await preparing.value }
        let task = Task { @MainActor in await self.runPrepare() }
        preparing = task
        await task.value
        preparing = nil
    }

    private func runPrepare() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            ConsentInformation.shared.requestConsentInfoUpdate(with: RequestParameters()) { _ in
                continuation.resume()
            }
        }
        if let root = Self.topViewController() {
            try? await ConsentForm.loadAndPresentIfRequired(from: root)
        }
        _ = await load()
    }

    /// 初始化 SDK（只一次）并等待完成。
    private func startSDK() async {
        await sdkStart.run {
            _ = await MobileAds.shared.start()
        }
    }

    func load() async -> Bool {
        guard canRequestAds else { return false }
        await startSDK()
        if ad != nil { return true }
        do {
            let loaded = try await RewardedAd.load(with: unitID, request: Request())
            loaded.fullScreenContentDelegate = self
            ad = loaded
            return true
        } catch {
            ad = nil
            return false
        }
    }

    func present(onEarned: @escaping @MainActor () -> Void) async -> AdShowOutcome {
        guard let current = ad, let root = Self.topViewController() else { return .failed }
        ad = nil
        presentFailed = false
        earnedThisPresentation = false
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            dismissal = continuation
            current.present(from: root) {
                Task { @MainActor in
                    self.earnedThisPresentation = true
                    onEarned()
                }
            }
        }
        // 回调与关闭都经主 actor 排队：给已赚得回调一次执行机会再判定结果
        await Task.yield()
        Task { _ = await self.load() }   // 预加载下一条
        if presentFailed { return .failed }
        return earnedThisPresentation ? .earned : .dismissedEarly
    }

    func presentPrivacyOptions() async {
        guard let root = Self.topViewController() else { return }
        try? await ConsentForm.presentPrivacyOptionsForm(from: root)
    }

    // MARK: FullScreenContentDelegate

    nonisolated func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        Task { @MainActor in self.finish() }
    }

    nonisolated func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        Task { @MainActor in
            self.presentFailed = true
            self.finish()
        }
    }

    private func finish() {
        dismissal?.resume()
        dismissal = nil
    }

    static func topViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        var top = scene?.keyWindow?.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        return top
    }
}
#endif
