import UIKit

/// 触觉反馈。是否触发由 FeedbackPlayer 按设置决定；关闭反馈不影响任何核心状态（QA T31）。
@MainActor
final class Haptics {
    private let light = UIImpactFeedbackGenerator(style: .light)
    private let medium = UIImpactFeedbackGenerator(style: .medium)
    private let notification = UINotificationFeedbackGenerator()
    private let selectionGenerator = UISelectionFeedbackGenerator()

    init() {}

    func play(_ cue: HapticCue) {
        switch cue {
        case .light: light.impactOccurred(intensity: 0.6)
        case .medium: medium.impactOccurred()
        case .selection: selectionGenerator.selectionChanged()
        case .success: notification.notificationOccurred(.success)
        case .warning: notification.notificationOccurred(.warning)
        }
    }
}
