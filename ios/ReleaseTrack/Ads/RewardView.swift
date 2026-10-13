import AntKingdomCore
import SwiftUI

/// Foraging Boost 面板：说明交换内容 → Watch Ad / Not Now；生效、冷却、当日已满、暂无广告分别说明。
/// 拒绝或没有广告时正常游玩，无任何资源惩罚。
struct RewardView: View {
    @ObservedObject var rewards: RewardModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles").foregroundStyle(Theme.food)
                Text(L10n.text("reward.title"))
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .accessibilityIdentifier("reward.title")
            }
            Text(L10n.text("reward.description"))
                .font(.subheadline)
                .multilineTextAlignment(.center)
            stateView
            if let key = rewards.messageKey {
                Text(L10n.text(key))
                    .font(.footnote.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier("reward.message")
            }
            if rewards.savePending {
                // 已赚得奖励写盘失败（R04）：只重试写盘，不需要再看广告
                Button {
                    rewards.retrySave()
                } label: {
                    Text(L10n.text("action.retry")).frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.connected)
                .accessibilityIdentifier("reward.retry_save")
            }
            Button {
                dismiss()
            } label: {
                Text(L10n.text("reward.not_now")).frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("reward.not_now")
        }
        .padding(22)
        .foregroundStyle(Theme.ink)
        .presentationDetents([.height(rewards.savePending ? 440 : 340)])
        .onAppear { rewards.open() }
        .onChange(of: rewards.justEarned) { _, earned in
            if earned { dismiss() }
        }
    }

    @ViewBuilder
    private var stateView: some View {
        switch rewards.status {
        case .ready:
            Button {
                Task { await rewards.watch() }
            } label: {
                Group {
                    if rewards.busy {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text(L10n.text("reward.loading"))
                        }
                    } else {
                        Text(L10n.text("reward.watch"))
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.connected)
            .disabled(rewards.busy)
            .accessibilityIdentifier("reward.watch")
        case .active:
            status(L10n.text("reward.active", ["time": Format.clock(rewards.boostRemaining)]), id: "reward.active")
        case .cooldown:
            status(L10n.text("reward.cooldown", ["time": Format.clock(rewards.cooldownRemaining)]), id: "reward.cooldown")
        case .dailyLimit:
            status(L10n.text("reward.daily_limit"), id: "reward.daily_limit")
        case .unavailable, .storageFull, .locked:
            status(L10n.text("reward.unavailable"), id: "reward.unavailable")
        }
    }

    private func status(_ text: String, id: String) -> some View {
        Text(text)
            .font(.system(.body, design: .rounded).weight(.semibold).monospacedDigit())
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, minHeight: 44)
            .accessibilityIdentifier(id)
    }
}
