import AntKingdomCore
import SwiftUI

/// 未选中实体时：当前英文引导 + 建仓入口（还没有 Pantry 时）。完成后仍可继续挖土与移动仓库。
struct IdlePanel: View {
    @ObservedObject var controller: GameController

    var body: some View {
        VStack(spacing: 8) {
            if let hint = TutorialGuide.hint(for: controller.snapshot) {
                HintCard(key: hint.stringID, icon: hint == .complete ? "star.fill" : "hand.tap")
            }
            if !controller.snapshot.hasPantry, controller.snapshot.flags.firstSourceConnected {
                Button(action: controller.beginBuild) {
                    HStack {
                        Text(L10n.text("action.build_pantry"))
                        Spacer()
                        Text(L10n.text("cost.pantry")).monospacedDigit()
                    }
                    .font(.system(.body, design: .rounded).weight(.semibold))
                    .padding(.horizontal, 6)
                    .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.food)
                .foregroundStyle(Theme.ink)
                .accessibilityIdentifier("action.build_pantry")
            }
        }
    }
}

/// 摆放面板：说明当前预览是否合法，非法或余额不足时确认按钮不可用（不扣 Food）。
struct PlacementPanel: View {
    @ObservedObject var controller: GameController
    let placement: PantryPlacement

    var body: some View {
        let validity = controller.placementValidity
        PanelCard(title: L10n.text(placement.kind == .build ? "action.build_pantry" : "action.move"),
                  identifier: "panel.placement", close: nil) {
            if placement.kind == .build {
                Text(L10n.text("cost.pantry"))
                    .font(.system(.body, design: .rounded).monospacedDigit())
                    .accessibilityIdentifier("panel.placement.cost")
            }
            Text(L10n.text(validity.messageKey ?? (placement.kind == .build ? "tutorial.pantry" : "tutorial.move")))
                .font(.footnote)
                .foregroundStyle(validity == .ok ? Theme.ink.opacity(0.75) : Theme.busy)
                .accessibilityIdentifier("panel.placement.message")
            HStack(spacing: 10) {
                Button(action: controller.cancelPlacement) {
                    Text(L10n.text("action.cancel")).frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("action.cancel")
                Button(action: controller.confirmPlacement) {
                    Text(L10n.text("action.confirm")).frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.connected)
                .disabled(validity != .ok)
                .accessibilityIdentifier("action.confirm")
            }
            .font(.system(.body, design: .rounded).weight(.semibold))
        }
    }
}

/// Pantry 详情与移动入口（移动免费，容量不变，旧位置保留通路）。
struct PantryPanel: View {
    @ObservedObject var controller: GameController

    var body: some View {
        PanelCard(title: L10n.text("room.pantry"), identifier: "panel.pantry", close: { controller.selection = nil }) {
            Text(L10n.text("hud.food", ["food": Format.food(controller.snapshot.food),
                                        "capacity": Format.food(controller.snapshot.capacity)]))
                .font(.system(.body, design: .rounded).monospacedDigit())
            Button(action: controller.beginMove) {
                HStack(spacing: 8) {
                    AssetIcon(name: "ui_core_move", fallback: "arrow.up.and.down.and.arrow.left.and.right", size: 16)
                    Text(L10n.text("action.move"))
                }
                .font(.system(.body, design: .rounded).weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.food)
            .foregroundStyle(Theme.ink)
            .accessibilityIdentifier("action.move")
        }
    }
}

/// 单行引导提示卡（不可点击）。
struct HintCard: View {
    let key: String
    var icon = "hand.tap"

    var body: some View {
        Label(L10n.text(key), systemImage: icon)
            .font(.system(.callout, design: .rounded).weight(.semibold))
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.paper.opacity(0.94), in: RoundedRectangle(cornerRadius: 14))
            .accessibilityIdentifier("hint.\(key)")
    }
}
