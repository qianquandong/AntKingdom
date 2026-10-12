import AntKingdomCore
import SwiftUI

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

#if DEBUG
/// 启动参数（只编译进 Debug；TestFlight/AppStore 二进制中不存在，CI 用 check-release-binary.sh 检查）：
/// - `-ak-scenario <name>`：载入调试场景（内存存档，不碰真实存档）
/// - `-ak-ephemeral`：使用内存存档的新档
/// - `-ak-away <seconds>`：先在“过去”保存，再冷启动，预览离线结算
/// - `-ak-reset-save`：启动前删除本机存档，之后照常持久化（杀进程恢复测试用）
/// - `-ak-reduce-motion`：强制“减少动态”（模拟器测试 QA T31，不改系统设置）
/// - `-ak-gallery`：显示通路遮罩/土层逐格检视页（A01-02 美术核对），不进入游戏
struct LaunchOptions {
    var scenario: DebugScenario?
    var ephemeral = false
    var simulatedAwaySeconds: Double?
    var resetSave = false
    var reduceMotion = false
    var gallery = false

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
    }
}
#endif
