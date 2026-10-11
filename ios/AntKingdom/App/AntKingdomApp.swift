import AntKingdomCore
import SwiftUI

#if !RELEASE_TRACK
/// 核心验证版入口（AntKingdom target）。发行轨 target 的入口是 ReleaseTrack/CrumbKingdomApp.swift。
@main
struct AntKingdomApp: App {
    @StateObject private var model = AppModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            #if DEBUG
            if LaunchOptions(arguments: ProcessInfo.processInfo.arguments).gallery {
                TunnelMaskGalleryView()     // A01-02 逐格检视页，只在 Debug
            } else {
                AppRootView(model: model)
            }
            #else
            AppRootView(model: model)
            #endif
        }
        .onChange(of: scenePhase) { _, newPhase in
            model.scenePhaseChanged(newPhase)
        }
    }
}
#endif

#if DEBUG
/// 启动参数（只编译进 Debug；TestFlight/AppStore 二进制中不存在，CI 用 check-release-binary.sh 检查）：
/// - `-ak-scenario <name>`：载入调试场景（内存存档，不碰真实存档）
/// - `-ak-ephemeral`：使用内存存档的新档
/// - `-ak-away <seconds>`：先在“过去”保存，再冷启动，预览离线结算
/// - `-ak-reset-save`：启动前删除本机存档，之后照常持久化（杀进程恢复测试用）
/// - `-ak-reduce-motion`：强制“减少动态”（模拟器测试 QA T31，不改系统设置）
/// - `-ak-gallery`：显示通路遮罩/土层逐格检视页（A01-02 美术核对），不进入游戏
/// - `-ak-zoom <倍数>`：初始镜头缩放（钳制到最小总览 / 最大 1.6 倍），美术截图用；UI 测试的捏合手势在 CI 上缩小不可靠
struct LaunchOptions {
    var scenario: DebugScenario?
    var ephemeral = false
    var simulatedAwaySeconds: Double?
    var resetSave = false
    var reduceMotion = false
    var gallery = false
    var zoom: Double?
    /// 发行轨：在目录后追加测试专用的第二章（只在 Debug；正式第二、三章等 Codex A04）
    var fixtureChapters = false
    /// 发行轨：用确定性的假商店（ok/cancel/pending/fail/unavailable/owned），只在 Debug
    var storeMode: String?

    init(arguments: [String]) {
        func value(after flag: String) -> String? {
            guard let index = arguments.firstIndex(of: flag), index + 1 < arguments.count else { return nil }
            return arguments[index + 1]
        }
        scenario = value(after: "-ak-scenario").flatMap(DebugScenario.init(rawValue:))
        ephemeral = arguments.contains("-ak-ephemeral")
        simulatedAwaySeconds = value(after: "-ak-away").flatMap(Double.init)
        resetSave = arguments.contains("-ak-reset-save")
        reduceMotion = arguments.contains("-ak-reduce-motion")
        gallery = arguments.contains("-ak-gallery")
        zoom = value(after: "-ak-zoom").flatMap(Double.init)
        fixtureChapters = arguments.contains("-ak-fixture-chapters")
        storeMode = value(after: "-ak-store")
    }
}
#endif
