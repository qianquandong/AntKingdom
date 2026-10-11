import SwiftUI

/// 应用入口。C00 只负责启动并展示核心包已链接；游戏场景在 C04 接入。
@main
struct AntKingdomApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}
