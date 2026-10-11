/// 离线回来时给玩家看的结果：只用实际搬入值（offline.summary），同时保留净变化供调试。
public struct OfflineSummary: Equatable, Sendable {
    public let hauledFood: Double
    public let netFood: Double
    /// 实际结算的秒数（已封顶到一小时）
    public let simulatedSeconds: Double
    /// 墙钟离开时长（未封顶，可能为 0）
    public let awaySeconds: Double

    /// 低于一分钟的离开不弹总结，避免切换应用时打扰
    public var isWorthShowing: Bool { simulatedSeconds >= 60 }
}

/// 启动结果
public enum LaunchResult {
    case ready(GameSession, offline: OfflineSummary?, recoveredFromBackup: Bool)
    /// 主档和备份都不可用：显示 error.save 与重置入口，不静默清档
    case saveUnavailable(SaveError)
}

/// 前后台生命周期与离线结算（PRD 5.3，TECHNICAL_HANDOFF 第 5 章）。
/// - 前台用单调时钟（由场景帧间隔驱动）；墙钟只用于后台差值与持久化。
/// - 离线时长 = clamp(当前墙钟 − 高水位, 0, 3600)；高水位是见过的最大墙钟，
///   因此系统时间回拨不产生负时间，回拨后再拨回也不会重复领取。
/// - 同一次后台区间只结算一次：重复的“回到前台”通知直接忽略。
public final class LifecycleCoordinator {
    public let session: GameSession
    private let repository: SaveRepository
    private let wallClock: WallClock
    public private(set) var wallHighWater: Double
    public private(set) var isInBackground = false
    public private(set) var lastSaveError: SaveError?

    init(session: GameSession, repository: SaveRepository, wallClock: WallClock, wallHighWater: Double) {
        self.session = session
        self.repository = repository
        self.wallClock = wallClock
        self.wallHighWater = wallHighWater
    }

    /// 冷启动：读档 → 校验 → 结算离线（一次）→ 立即保存新的高水位。
    public static func launch(repository: SaveRepository, wallClock: WallClock,
                              map: MapDefinition = .backyard) -> (LifecycleCoordinator?, LaunchResult) {
        let now = wallClock.now()
        switch repository.load() {
        case .fresh:
            let coordinator = LifecycleCoordinator(session: GameSession(map: map), repository: repository,
                                                   wallClock: wallClock, wallHighWater: now)
            coordinator.save()
            return (coordinator, .ready(coordinator.session, offline: nil, recoveredFromBackup: false))
        case .loaded(let envelope, let recovered):
            guard let session = try? GameSession(state: envelope.state, map: map) else {
                return (nil, .saveUnavailable(.unreadable("state")))
            }
            let reference = max(envelope.savedAt, envelope.wallHighWater)
            let coordinator = LifecycleCoordinator(session: session, repository: repository,
                                                   wallClock: wallClock, wallHighWater: reference)
            let summary = coordinator.settle(now: now)
            coordinator.save()
            return (coordinator, .ready(session, offline: summary, recoveredFromBackup: recovered))
        case .unavailable(let error):
            return (nil, .saveUnavailable(error))
        }
    }

    /// 进入后台：记录并立即保存（多次通知只处理第一次）。
    public func enterBackground() {
        guard !isInBackground else { return }
        isInBackground = true
        wallHighWater = max(wallHighWater, wallClock.now())
        save()
    }

    /// 回到前台：只为这一次后台区间结算一次离线。
    public func becomeActive() -> OfflineSummary? {
        guard isInBackground else { return nil }
        isInBackground = false
        let summary = settle(now: wallClock.now())
        save()
        return summary
    }

    /// 关键操作后与定时自动保存。失败不抛给玩家，记录后由 UI 提示 error.save。
    @discardableResult
    public func save() -> Bool {
        let now = wallClock.now()
        wallHighWater = max(wallHighWater, now.isFinite ? now : wallHighWater)
        do {
            try repository.save(session, now: now, wallHighWater: wallHighWater)
            lastSaveError = nil
            return true
        } catch let error as SaveError {
            lastSaveError = error
            return false
        } catch {
            lastSaveError = .writeFailed(String(describing: error))
            return false
        }
    }

    /// 玩家确认 Start Over：清空本地档并从新档开始（设置保留）。
    public func resetColony() {
        session.apply(.reset)
        try? repository.eraseAll()
        save()
    }

    private func settle(now: Double) -> OfflineSummary? {
        let away = now.isFinite ? now - wallHighWater : 0
        let seconds = OfflineClock.cappedSeconds(savedAt: wallHighWater, now: now)
        if now.isFinite { wallHighWater = max(wallHighWater, now) }
        guard seconds > 0, let result = try? session.settleOffline(seconds: seconds) else { return nil }
        return OfflineSummary(hauledFood: result.hauledFood, netFood: result.netFood,
                              simulatedSeconds: result.simulatedSeconds, awaySeconds: max(0, away))
    }
}
