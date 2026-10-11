import AntKingdomCore
import SwiftUI

/// 未选中任何实体时的底部区域：当前引导提示（C05 扩展为完整首局引导与建仓入口）。
struct IdlePanel: View {
    @ObservedObject var controller: GameController

    var body: some View {
        if !controller.snapshot.flags.firstSourceConnected {
            HintCard(key: "tutorial.dig")
        }
    }
}

/// Pantry 详情（C05 加入移动入口）。
struct PantryPanel: View {
    @ObservedObject var controller: GameController

    var body: some View {
        PanelCard(title: L10n.text("room.pantry"), identifier: "panel.pantry", close: { controller.selection = nil }) {
            Text(L10n.text("hud.food", ["food": Format.food(controller.snapshot.food),
                                        "capacity": Format.food(controller.snapshot.capacity)]))
                .font(.system(.body, design: .rounded).monospacedDigit())
        }
    }
}

/// 单行引导提示卡（不可点击，不拦截地图以外的操作）。
struct HintCard: View {
    let key: String

    var body: some View {
        Label(L10n.text(key), systemImage: "hand.tap")
            .font(.system(.callout, design: .rounded).weight(.semibold))
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.paper.opacity(0.94), in: RoundedRectangle(cornerRadius: 14))
            .accessibilityIdentifier("hint.\(key)")
    }
}
