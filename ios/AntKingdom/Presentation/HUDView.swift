import AntKingdomCore
import SwiftUI
import UIKit

enum Theme {
    static let paper = Color(red: 0.965, green: 0.925, blue: 0.847)
    static let ink = Color(red: 0.188, green: 0.161, blue: 0.145)
    static let food = Color(red: 0.91, green: 0.714, blue: 0.329)
    static let connected = Color(red: 0.408, green: 0.549, blue: 0.439)
    static let busy = Color(red: 0.835, green: 0.478, blue: 0.231)
}

/// 顶部 HUD：Food / Ants / Eggs、当前运输状态、设置入口。文字为原生 SwiftUI，不烘焙进图。
struct HUDView: View {
    @ObservedObject var controller: GameController

    private var snapshot: SessionSnapshot { controller.snapshot }

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 10) {
                // 一行放不下（发行轨多了入口按钮、375pt 小屏）时分两行，不把读数截成无法辨认的前缀（D-09）
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 10) {
                        foodStat
                        antsStat
                        eggsStat
                    }
                    VStack(alignment: .leading, spacing: 0) {
                        foodStat
                        HStack(spacing: 10) {
                            antsStat
                            eggsStat
                        }
                    }
                }
                Spacer(minLength: 0)
                if let openChapters = controller.openChapters {
                    Button(action: openChapters) {
                        Image(systemName: "map.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel(L10n.text("chapter.select"))
                    .accessibilityIdentifier("hud.chapters")
                }
                Button {
                    controller.showSettings = true
                } label: {
                    AssetIcon(name: "ui_core_settings", fallback: "gearshape.fill", size: 20)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel(L10n.text("settings.title"))
                .accessibilityIdentifier("hud.settings")
            }
            RouteStatusBar(snapshot: snapshot)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .foregroundStyle(Theme.ink)
        .background(Theme.paper.opacity(0.94), in: RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
    }

    private var foodStat: some View {
        stat(L10n.text("hud.food", ["food": Format.food(snapshot.food), "capacity": Format.food(snapshot.capacity)]),
             id: "hud.food")
    }

    private var antsStat: some View {
        stat(L10n.text("hud.ants", ["ants": String(snapshot.ants), "cap": String(snapshot.populationCap)]), id: "hud.ants")
    }

    private var eggsStat: some View {
        stat(L10n.text("hud.eggs", ["eggs": String(snapshot.eggs.count)]), id: "hud.eggs")
    }

    private func stat(_ text: String, id: String) -> some View {
        Text(text)
            .font(.system(.subheadline, design: .rounded).weight(.semibold).monospacedDigit())
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .accessibilityIdentifier(id)
    }
}

/// A03 图标：Codex 交付的 ui_core_* 存在时用位图，否则用 SF Symbol 占位（文字始终原生）。
struct AssetIcon: View {
    let name: String
    let fallback: String
    var size: CGFloat = 18

    var body: some View {
        Group {
            if let image = UIImage(named: name) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: size + 4, height: size + 4)
            } else {
                Image(systemName: fallback)
                    .font(.system(size: size, weight: .semibold))
            }
        }
        .accessibilityHidden(true)   // 装饰图标；按钮的可读名称来自英文文案
    }
}

/// 运输状态：当前源、预计 Food/min、Trip；满仓与繁忙单独标出（文字 + 图标，不只靠颜色）。
struct RouteStatusBar: View {
    let snapshot: SessionSnapshot

    var body: some View {
        // 一行放不下时：来源与状态在上，Food/min 与 Trip 在下（D-09；A00 交接要求 Trip 保留、小屏两行）
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                sourceLabel
                figures
                Spacer(minLength: 0)
                stateLabel
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    sourceLabel
                    Spacer(minLength: 0)
                    stateLabel
                }
                HStack(spacing: 8) {
                    figures
                    Spacer(minLength: 0)
                }
            }
        }
        .font(.system(.footnote, design: .rounded).weight(.medium).monospacedDigit())
        .lineLimit(1)
        .minimumScaleFactor(0.75)
    }

    @ViewBuilder
    private var sourceLabel: some View {
        if let source = snapshot.activeSourceId, snapshot.averageTripSeconds != nil {
            Label(L10n.text(Format.sourceNameKey(source)), systemImage: "link")
                .accessibilityIdentifier("hud.source")
        } else {
            Label(L10n.text("state.no_route"), systemImage: "link.badge.plus")
                .accessibilityIdentifier("hud.source")
        }
    }

    @ViewBuilder
    private var figures: some View {
        if snapshot.activeSourceId != nil, let trip = snapshot.averageTripSeconds {
            Text(L10n.text("stat.rate", ["rate": Format.oneDecimal(snapshot.expectedFoodPerMinute)]))
                .accessibilityIdentifier("hud.rate")
            Text(L10n.text("stat.trip", ["seconds": Format.oneDecimal(trip)]))
                .accessibilityIdentifier("hud.trip")
        }
    }

    @ViewBuilder
    private var stateLabel: some View {
        if snapshot.isStorageFull {
            Label(L10n.text("state.storage_full"), systemImage: "archivebox.fill")
                .foregroundStyle(Theme.busy)
                .accessibilityIdentifier("hud.storage_full")
        } else if !snapshot.busyCells.isEmpty {
            Label(L10n.text("state.busy"), systemImage: "line.3.horizontal")
                .foregroundStyle(Theme.busy)
                .accessibilityIdentifier("hud.busy")
        }
    }
}

/// 短暂提示条，叠在 HUD 下方，不遮挡底部操作。
struct ToastStack: View {
    let toasts: [Toast]
    /// 减少动态：提示只淡入淡出，不从上方滑入
    var reduceMotion = false

    var body: some View {
        VStack(spacing: 6) {
            ForEach(toasts) { toast in
                Text(toast.text)
                    .font(.system(.callout, design: .rounded).weight(.semibold))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(background(toast.style), in: Capsule())
                    .foregroundStyle(toast.style == .info ? Theme.ink : .white)
                    .accessibilityIdentifier("toast.\(toast.identifier)")
                    .transition(reduceMotion ? AnyTransition.opacity : AnyTransition.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeOut(duration: 0.2), value: toasts)
        .allowsHitTesting(false)
    }

    private func background(_ style: Toast.Style) -> Color {
        switch style {
        case .info: return Theme.paper
        case .success: return Theme.connected
        case .warning: return Theme.busy
        }
    }
}
