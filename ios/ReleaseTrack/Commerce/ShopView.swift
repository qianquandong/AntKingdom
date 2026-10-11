import AntKingdomCore
import SwiftUI

/// 外观面板 Decorate（C11）：Garden Decor Pack 预览、购买、启用/恢复默认、恢复购买。
/// 半屏显示，预览时可直接看到地图上的房间外观。不在失败、满仓或首轮教学中自动弹出。
struct ShopView: View {
    @ObservedObject var shop: ShopModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 14) {
                card
                if let key = shop.messageKey {
                    Text(L10n.text(key))
                        .font(.footnote.weight(.semibold))
                        .multilineTextAlignment(.center)
                        .accessibilityIdentifier("shop.message")
                }
                Spacer(minLength: 0)
                Button {
                    Task { await shop.restore() }
                } label: {
                    Text(L10n.text("shop.restore")).frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.bordered)
                .disabled(shop.busy)
                .accessibilityIdentifier("shop.restore")
            }
            .padding(20)
            .foregroundStyle(Theme.ink)
            .navigationTitle(L10n.text("shop.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.text("action.close")) { dismiss() }
                        .accessibilityIdentifier("shop.close")
                }
            }
        }
        .presentationDetents([.medium])
        .presentationBackgroundInteraction(.enabled(upThrough: .medium))
        .onAppear { shop.open() }
        .onDisappear { shop.close() }
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "leaf.fill").foregroundStyle(Theme.connected)
                Text(L10n.text("shop.garden_pack"))
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .accessibilityIdentifier("shop.garden_pack")
                Spacer()
                if shop.owned {
                    Text(L10n.text("shop.owned"))
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Theme.connected.opacity(0.2), in: Capsule())
                        .accessibilityIdentifier("shop.owned")
                }
            }
            Text(L10n.text("shop.garden_description"))
                .font(.subheadline)
            if shop.owned {
                ownedActions
            } else {
                purchaseActions
            }
        }
        .padding(16)
        .background(Theme.paper, in: RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private var ownedActions: some View {
        if shop.equippedStyle == .garden {
            Button {
                shop.equip(.standard)
            } label: {
                Text(L10n.text("shop.default")).frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("shop.default")
        } else {
            Button {
                shop.equip(.garden)
            } label: {
                Text(L10n.text("shop.equip")).frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.connected)
            .accessibilityIdentifier("shop.equip")
        }
    }

    @ViewBuilder
    private var purchaseActions: some View {
        Button {
            shop.togglePreview()
        } label: {
            Text(L10n.text(shop.previewing ? "shop.preview_end" : "shop.preview"))
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.bordered)
        .accessibilityIdentifier("shop.preview")
        switch shop.product {
        case .ready(let info):
            Button {
                Task { await shop.buy() }
            } label: {
                if shop.busy {
                    ProgressView().frame(maxWidth: .infinity, minHeight: 44)
                        .accessibilityLabel(L10n.text("shop.loading"))
                } else {
                    Text(L10n.text("shop.buy", ["price": info.displayPrice])).frame(maxWidth: .infinity, minHeight: 44)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.connected)
            .disabled(shop.busy)
            .accessibilityIdentifier("shop.buy")
        case .unavailable:
            // 商品未加载：说明 + 重试；没有假价格、没有可点的空购买按钮
            Text(L10n.text("shop.unavailable"))
                .font(.footnote)
                .accessibilityIdentifier("shop.unavailable")
            Button {
                Task { await shop.load() }
            } label: {
                Text(L10n.text("action.retry")).frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("shop.retry")
        case .idle, .loading:
            ProgressView()
                .frame(maxWidth: .infinity, minHeight: 44)
                .accessibilityLabel(L10n.text("shop.loading"))
                .accessibilityIdentifier("shop.loading")
        }
    }
}
