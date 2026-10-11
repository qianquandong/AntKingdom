import AntKingdomCore
import SwiftUI

/// 根视图：正常游戏，或存档不可用时的英文错误与重置入口。
struct AppRootView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        switch model.phase {
        case .running(let controller):
            RunningGameView(controller: controller)
        case .saveUnavailable:
            SaveErrorView(retry: model.launch, startOver: model.startOverAfterSaveError)
        }
    }
}

/// 游戏主界面 + 离线结果。离线结果由 controller 发布（冷启动、回前台），必须在观察 controller 的视图上挂 sheet：
/// 挂在只观察 AppModel 的父视图上时，OK 关不掉、回前台也不会弹出。
private struct RunningGameView: View {
    @ObservedObject var controller: GameController

    var body: some View {
        RootView(controller: controller)
            .sheet(item: Binding(get: { controller.offlineSummary.map(IdentifiedSummary.init) },
                                 set: { if $0 == nil { controller.offlineSummary = nil } })) { item in
                OfflineSummaryView(summary: item.summary) { controller.offlineSummary = nil }
            }
    }
}

private struct IdentifiedSummary: Identifiable {
    let summary: OfflineSummary
    var id: Double { summary.awaySeconds }
}

/// 离线结果：只显示实际搬入的 Food（PRD 5.3），并说明 25% / 一小时规则。
struct OfflineSummaryView: View {
    let summary: OfflineSummary
    let dismiss: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text(L10n.text("offline.title"))
                .font(.system(.title2, design: .rounded).weight(.bold))
                .accessibilityIdentifier("offline.title")
            Text(L10n.text("offline.summary", ["food": Format.food(summary.hauledFood)]))
                .font(.system(.title3, design: .rounded))
                .multilineTextAlignment(.center)
                .accessibilityIdentifier("offline.summary")
            Text(L10n.text("offline.note"))
                .font(.footnote)
                .foregroundStyle(Theme.ink.opacity(0.7))
            Button(action: dismiss) {
                Text(L10n.text("action.ok"))
                    .font(.system(.body, design: .rounded).weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.food)
            .foregroundStyle(Theme.ink)
            .accessibilityIdentifier("offline.ok")
        }
        .padding(24)
        .foregroundStyle(Theme.ink)
        .presentationDetents([.height(300)])
        .interactiveDismissDisabled(false)
    }
}

/// 主档与备份都不可用：英文错误 + 重试 + Start Over（二次确认），不静默清档。
struct SaveErrorView: View {
    let retry: () -> Void
    let startOver: () -> Void
    @State private var confirm = false

    var body: some View {
        ZStack {
            Theme.paper.ignoresSafeArea()
            VStack(spacing: 18) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(Theme.busy)
                Text(L10n.text("error.save"))
                    .font(.system(.title3, design: .rounded).weight(.semibold))
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier("error.save")
                Button(action: retry) {
                    Text(L10n.text("action.retry")).frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.connected)
                .accessibilityIdentifier("action.retry")
                Button(role: .destructive) {
                    confirm = true
                } label: {
                    Text(L10n.text("action.reset")).frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("action.reset")
            }
            .padding(32)
            .foregroundStyle(Theme.ink)
        }
        .confirmationDialog(L10n.text("dialog.reset"), isPresented: $confirm, titleVisibility: .visible) {
            Button(L10n.text("action.reset"), role: .destructive, action: startOver)
            Button(L10n.text("action.cancel"), role: .cancel) {}
        }
    }
}
