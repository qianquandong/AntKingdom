import UIKit

/// 触觉反馈。设置关闭时不触发；关闭反馈不影响任何核心状态（QA T31）。
@MainActor
final class Haptics {
    private let light = UIImpactFeedbackGenerator(style: .light)
    private let medium = UIImpactFeedbackGenerator(style: .medium)
    private let notification = UINotificationFeedbackGenerator()
    private let selectionGenerator = UISelectionFeedbackGenerator()

    init() {}

    func dig(enabled: Bool) {
        guard enabled else { return }
        light.impactOccurred(intensity: 0.6)
    }

    func cellOpened(enabled: Bool) {
        guard enabled else { return }
        medium.impactOccurred()
    }

    func selection(enabled: Bool) {
        guard enabled else { return }
        selectionGenerator.selectionChanged()
    }

    func success(enabled: Bool) {
        guard enabled else { return }
        notification.notificationOccurred(.success)
    }

    func rejected(enabled: Bool) {
        guard enabled else { return }
        notification.notificationOccurred(.warning)
    }
}
