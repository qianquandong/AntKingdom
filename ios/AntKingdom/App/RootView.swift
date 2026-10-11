import AntKingdomCore
import SwiftUI

/// C00 启动页：证明 App、String Catalog 与核心包均可构建运行。
/// 玩家可见文字只来自 String Catalog（PRD 附录 A）。
struct RootView: View {
    var body: some View {
        ZStack {
            Color(red: 0.96, green: 0.93, blue: 0.85).ignoresSafeArea()
            VStack(spacing: 12) {
                Text(L10n.text("game.title"))
                    .font(.system(.largeTitle, design: .rounded).weight(.bold))
                    .accessibilityIdentifier("title")
                Text(L10n.text("world.backyard"))
                    .font(.system(.title3, design: .rounded))
                    .accessibilityIdentifier("world")
            }
            .foregroundStyle(Color(red: 0.19, green: 0.16, blue: 0.15))
        }
    }
}
