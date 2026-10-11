import AntKingdomCore
import AVFoundation
import UIKit

/// audio_core 的 7 类音效（ART_DIRECTION A03）。文件名见 AssetNames.sound。
enum SoundCue: String, CaseIterable {
    case dig
    case tunnelOpen = "tunnel_open"
    case build
    case move
    case hatch
    case refill
    case ui
}

enum HapticCue: Equatable {
    case light, medium, selection, success, warning
}

/// 一次玩家可感知的反馈：声音 + 触觉。视觉效果由场景按“减少动态”自行决定。
enum FeedbackCue: CaseIterable {
    case dig, tunnelOpen, connected, build, move, hatch, refill, select, rejected

    var sound: SoundCue? {
        switch self {
        case .dig: return .dig
        case .tunnelOpen: return .tunnelOpen
        case .build: return .build
        case .move: return .move
        case .hatch: return .hatch
        case .refill: return .refill
        case .select: return .ui
        case .connected, .rejected: return nil
        }
    }

    var haptic: HapticCue? {
        switch self {
        case .dig: return .light
        case .tunnelOpen: return .medium
        case .connected, .build: return .success
        case .move, .select: return .selection
        case .rejected: return .warning
        case .hatch, .refill: return nil
        }
    }
}

/// 反馈出口：按设置过滤后播放。关闭音效/触觉只影响这里，不影响任何核心状态（QA T31）。
@MainActor
final class FeedbackPlayer {
    private let haptics = Haptics()
    private let sounds = SoundPlayer()
    /// 测试与调试：实际发出的声音/触觉（被设置关闭的不会出现）
    var onEmit: ((SoundCue?, HapticCue?) -> Void)?

    func play(_ cue: FeedbackCue, settings: GameState.Settings) {
        let sound = settings.sound ? cue.sound : nil
        let haptic = settings.haptics ? cue.haptic : nil
        if let sound { sounds.play(sound) }
        if let haptic { haptics.play(haptic) }
        if sound != nil || haptic != nil { onEmit?(sound, haptic) }
    }
}

/// 音效播放。ambient 类别：遵守静音开关、与其他 App 的音频混合、不打断音乐。
/// 文件缺失（Codex 交付前）时静默跳过。
@MainActor
final class SoundPlayer {
    private var players: [SoundCue: AVAudioPlayer] = [:]
    private var missing: Set<SoundCue> = []
    private var sessionConfigured = false

    static func url(for cue: SoundCue, in bundle: Bundle = .main) -> URL? {
        for ext in ["caf", "wav", "m4a"] {
            if let url = bundle.url(forResource: AssetNames.sound(cue), withExtension: ext) { return url }
        }
        return nil
    }

    func play(_ cue: SoundCue) {
        guard !missing.contains(cue) else { return }
        if players[cue] == nil {
            guard let url = SoundPlayer.url(for: cue), let player = try? AVAudioPlayer(contentsOf: url) else {
                missing.insert(cue)
                return
            }
            configureSession()
            player.prepareToPlay()
            players[cue] = player
        }
        guard let player = players[cue] else { return }
        player.currentTime = 0
        player.play()
    }

    private func configureSession() {
        guard !sessionConfigured else { return }
        sessionConfigured = true
        try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: [.mixWithOthers])
    }
}
