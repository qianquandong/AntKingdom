import AntKingdomCore
import SwiftUI

/// 发行轨入口（CrumbKingdom target，编译条件 RELEASE_TRACK）：章节、正式版内容；M5 再加商品与奖励广告。
/// 核心验证版入口仍是 AntKingdom target 的 AntKingdomApp。
@main
struct CrumbKingdomApp: App {
    @StateObject private var model = CampaignModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            CampaignRootView(model: model)
        }
        .onChange(of: scenePhase) { _, newPhase in
            model.scenePhaseChanged(newPhase)
        }
    }
}
