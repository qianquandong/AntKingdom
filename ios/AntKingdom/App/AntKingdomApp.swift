import AntKingdomCore
import SwiftUI

@main
struct AntKingdomApp: App {
    @StateObject private var controller = AppBootstrap.makeController()

    var body: some Scene {
        WindowGroup {
            RootView(controller: controller)
        }
    }
}

/// 依赖组装。C06 在这里接入存档仓库与生命周期；调试场景只在 Debug 构建可用。
enum AppBootstrap {
    @MainActor
    static func makeController(arguments: [String] = ProcessInfo.processInfo.arguments) -> GameController {
        let session = GameSession()
        #if DEBUG
        if let scenario = LaunchOptions(arguments: arguments).scenario {
            try? scenario.apply(to: session)
        }
        #endif
        return GameController(session: session)
    }
}

/// 启动参数（仅 Debug 解释）：`-ak-scenario <name>` 载入调试场景，用于 UI 测试与截图证据。
struct LaunchOptions {
    var scenario: DebugScenario?

    init(arguments: [String]) {
        if let index = arguments.firstIndex(of: "-ak-scenario"), index + 1 < arguments.count {
            scenario = DebugScenario(rawValue: arguments[index + 1])
        }
    }
}
