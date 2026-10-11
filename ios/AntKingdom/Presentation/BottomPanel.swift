import AntKingdomCore
import SwiftUI

/// 底部上下文面板：选中源/Queen/Pantry 时显示详情与操作；未选中时显示引导与主要操作。
struct BottomPanel: View {
    @ObservedObject var controller: GameController

    var body: some View {
        Group {
            if let placement = controller.placement {
                PlacementPanel(controller: controller, placement: placement)
            } else {
                selectionPanel
            }
        }
        .foregroundStyle(Theme.ink)
    }

    @ViewBuilder private var selectionPanel: some View {
        Group {
            switch controller.selection {
            case .source(let id)?:
                if let source = controller.snapshot.sources.first(where: { $0.id == id }) {
                    SourcePanel(source: source, snapshot: controller.snapshot) { controller.selection = nil }
                }
            case .queen?:
                QueenPanel(snapshot: controller.snapshot, toggle: controller.toggleHatching) { controller.selection = nil }
            case .pantry?:
                PantryPanel(controller: controller)
            case nil:
                IdlePanel(controller: controller)
            }
        }
        .foregroundStyle(Theme.ink)
    }
}

/// 面板外框：纸张底、圆角、标题与关闭按钮（44pt 点击区）。
struct PanelCard<Content: View>: View {
    let title: String
    let identifier: String
    let close: (() -> Void)?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.system(.headline, design: .rounded))
                    .accessibilityIdentifier("\(identifier).title")
                Spacer()
                if let close {
                    Button(action: close) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22))
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel(L10n.text("action.close"))
                    .accessibilityIdentifier("\(identifier).close")
                }
            }
            content
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.paper.opacity(0.96), in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.18), radius: 6, y: -1)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(identifier)
    }
}

struct SourcePanel: View {
    let source: SessionSnapshot.SourceView
    let snapshot: SessionSnapshot
    let close: () -> Void

    var body: some View {
        PanelCard(title: L10n.text(Format.sourceNameKey(source.id)), identifier: "panel.source", close: close) {
            Label(stateText, systemImage: stateIcon)
                .accessibilityIdentifier("panel.source.state")
            if let remaining = source.remaining {
                Text(L10n.text("stat.remaining", ["food": Format.food(remaining)]))
                    .accessibilityIdentifier("panel.source.remaining")
            }
            if source.isActive, let trip = snapshot.averageTripSeconds {
                HStack {
                    Text(L10n.text("stat.trip", ["seconds": Format.oneDecimal(trip)]))
                    Text(L10n.text("stat.rate", ["rate": Format.oneDecimal(snapshot.expectedFoodPerMinute)]))
                }
                .font(.system(.body, design: .rounded).monospacedDigit())
                Text(L10n.text("stat.trip_help"))
                    .font(.footnote)
                    .foregroundStyle(Theme.ink.opacity(0.7))
                if snapshot.isStorageFull {
                    Text(L10n.text("stat.expected"))
                        .font(.footnote)
                        .foregroundStyle(Theme.ink.opacity(0.7))
                }
            }
        }
    }

    private var stateText: String {
        if source.isEmptyPatch { return L10n.text("state.empty_patch") }
        return L10n.text(source.isConnected ? "state.connected" : "state.no_route")
    }

    private var stateIcon: String {
        if source.isEmptyPatch { return "hourglass" }
        return source.isConnected ? "checkmark.circle" : "xmark.circle"
    }
}

struct QueenPanel: View {
    let snapshot: SessionSnapshot
    let toggle: () -> Void
    let close: () -> Void

    var body: some View {
        PanelCard(title: L10n.text("room.queen"), identifier: "panel.queen", close: close) {
            HStack(spacing: 14) {
                Text(L10n.text("hud.ants", ["ants": String(snapshot.ants), "cap": String(snapshot.populationCap)]))
                Text(L10n.text("hud.eggs", ["eggs": String(snapshot.eggs.count)]))
            }
            .font(.system(.body, design: .rounded).monospacedDigit())
            ForEach(Array(snapshot.eggs.enumerated()), id: \.offset) { _, remaining in
                Label(L10n.text("state.hatching", ["seconds": Format.seconds(remaining)]), systemImage: "oval.portrait")
                    .font(.system(.footnote, design: .rounded).monospacedDigit())
            }
            Button(action: toggle) {
                Text(L10n.text(snapshot.hatching ? "action.pause_hatching" : "action.resume_hatching"))
                    .font(.system(.body, design: .rounded).weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.food)
            .foregroundStyle(Theme.ink)
            .accessibilityIdentifier("panel.queen.toggle")
            if snapshot.hatching && !snapshot.hasPantry {
                Text(L10n.text("tutorial.save_food"))
                    .font(.footnote)
                    .foregroundStyle(Theme.ink.opacity(0.75))
            }
        }
    }
}
