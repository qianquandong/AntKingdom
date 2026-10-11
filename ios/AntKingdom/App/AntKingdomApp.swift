import AntKingdomCore
import SwiftUI

@main
struct AntKingdomApp: App {
    @StateObject private var model = AppModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            AppRootView(model: model)
        }
        .onChange(of: scenePhase) { _, newPhase in
            model.scenePhaseChanged(newPhase)
        }
    }
}

/// 启动参数（仅 Debug 解释）：
/// - `-ak-scenario <name>`：载入调试场景（内存存档，不碰真实存档）
/// - `-ak-ephemeral`：使用内存存档的新档
/// - `-ak-away <seconds>`：先在“过去”保存，再冷启动，预览离线结算
/// - `-ak-reset-save`：启动前删除本机存档，之后照常持久化（杀进程恢复测试用）
/// - `-ak-reduce-motion`：强制“减少动态”（模拟器测试 QA T31，不改系统设置）
struct LaunchOptions {
    var scenario: DebugScenario?
    var ephemeral = false
    var simulatedAwaySeconds: Double?
    var resetSave = false
    var reduceMotion = false

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
    }
}
