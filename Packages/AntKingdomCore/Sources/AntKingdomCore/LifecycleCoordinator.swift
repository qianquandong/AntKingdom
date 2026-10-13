import Foundation

/// 离线回来时给玩家看的结果：只用实际搬入值（offline.summary），同时保留净变化供调试。
public struct OfflineSummary: Equatable, Sendable {
    public let hauledFood: Double
    public let netFood: Double
    /// 实际结算的秒数（已封顶到一小时）
    public let simulatedSeconds: Double
    /// 墙钟离开时长（未封顶，可能为 0）
    public let awaySeconds: Double

    public init(hauledFood: Double, netFood: Double, simulatedSeconds: Double, awaySeconds: Double) {
        self.hauledFood = hauledFood
        self.netFood = netFood
        self.simulatedSeconds = simulatedSeconds
        self.awaySeconds = awaySeconds
    }

    /// 低于一分钟的离开不弹总结，避免切换应用时打扰
    public var isWorthShowing: Bool { simulatedSeconds >= 60 }
}

/// 启动结果
public enum LaunchResult {
    case ready(GameSession, offline: OfflineSummary?, recoveredFromBackup: Bool)
    /// 主档和备份都不可用：显示 error.save 与重置入口，不静默清档
    case saveUnavailable(SaveError)
}

/// 前台帧的准入结果（D-13）。每帧推进之前先问生命周期：离开区间未结算时不推进、不保存。
public enum ForegroundFrame: Equatable, Sendable {
    /// 正常推进本帧
    case run
    /// 后台区间尚未结算（例如恢复首帧早于 `.active` 到达），或处于有意暂停（全屏广告，D-14）：本帧不推进、不保存
    case hold
    /// 两帧之间停顿超过阈值却没有记录后台（`.background` 迟到或缺失）：已把停顿区间按离线结算；
    /// 本帧丢弃帧间隔，不再推进
    case resumed(OfflineSummary?)
}

/// 前后台生命周期与离线结算（PRD 5.3，TECHNICAL_HANDOFF 第 5 章）。
/// - 前台用单调时钟（由场景帧间隔驱动）；墙钟只用于后台差值与持久化。
/// - 离线时长 = clamp(回来时墙钟 − 离开基准, 0, 3600)。离开基准 = max(离开时的高水位, 实际离开时刻)，
///   在离开时冻结：之后的保存（恢复首帧的自动保存、点击后的立即保存）只能把存档时间记为离开基准，
///   不能推进它，否则尚未结算的后台区间会被吃掉（D-13）。
/// - 高水位是见过的最大墙钟，因此系统时间回拨不产生负时间，回拨后再拨回也不会重复领取。
/// - 实际离开时刻取本次前台最后一帧的墙钟：`.background` 回调迟到时，迟到的那段不算成在线。
/// - 同一离开区间恰好结算一次：重复的后台/前台通知直接忽略；帧停顿检测与后台记录互斥。
/// - 有意暂停（全屏奖励广告，D-14）是第三种状态：既不是前台推进，也不是离线。暂停期间帧一律不推进、
///   不结算；此时切后台，离开时刻取后台回调时刻（广告前的最后一帧会把广告时长算成离线）。
/// - 唯一负责人：开始离线（`enterBackground` 或帧停顿）、结算（`becomeActive` 或帧停顿）、恢复在线、保存都在本类。
public final class LifecycleCoordinator {
    /// 两帧墙钟间隔超过此值、且没有记录后台时，视为 App 没在运行（被挂起而 `.background` 未送达或迟到），
    /// 整段按离线结算。普通卡顿仍由前台帧封顶（TickAccumulator.maxFrameDelta）处理。
    public static let frameGapThreshold = 5.0

    public let session: GameSession
    private let repository: SaveRepository
    private let wallClock: WallClock
    private let monotonic: MonotonicClock
    public private(set) var wallHighWater: Double
    public private(set) var isInBackground = false
    public private(set) var lastSaveError: SaveError?
    /// 当前未结算离开区间的起点（离开时冻结；结算后清空）
    public private(set) var awayReference: Double?
    /// 本次在前台最后一帧的墙钟（启动后、回到前台后第一帧之前为 nil）
    public private(set) var lastFrameWall: Double?
    /// 有意暂停（全屏奖励广告）开始时的墙钟；未暂停为 nil（D-14）
    public private(set) var pausedSince: Double?
    public var isPaused: Bool { pausedSince != nil }
    /// 仅调试：结构化生命周期日志（Release 不创建）
    public var trace: LifecycleTrace?
    private var heldFrames = 0
    private var pausedFrames = 0

    init(session: GameSession, repository: SaveRepository, wallClock: WallClock, wallHighWater: Double,
         monotonic: MonotonicClock = SystemMonotonicClock(), trace: LifecycleTrace? = nil) {
        self.session = session
        self.repository = repository
        self.wallClock = wallClock
        self.monotonic = monotonic
        self.wallHighWater = wallHighWater
        self.trace = trace
    }

    /// 冷启动：读档 → 校验 → 结算离线（一次）→ 立即保存新的高水位。
    /// `settleOffline = false` 用于正式版切换章节：非活动章节不后台产粮，从“现在”起算（RELEASE_SCOPE 第 1 章）。
    public static func launch(repository: SaveRepository, wallClock: WallClock,
                              map: MapDefinition = .backyard,
                              settleOffline: Bool = true,
                              trace: LifecycleTrace? = nil) -> (LifecycleCoordinator?, LaunchResult) {
        let now = wallClock.now()
        switch repository.load() {
        case .fresh:
            let coordinator = LifecycleCoordinator(session: GameSession(map: map), repository: repository,
                                                   wallClock: wallClock, wallHighWater: now, trace: trace)
            coordinator.log("launch", "fresh")
            coordinator.save(reason: "launch")
            return (coordinator, .ready(coordinator.session, offline: nil, recoveredFromBackup: false))
        case .loaded(let envelope, let recovered):
            guard let session = try? GameSession(state: envelope.state, map: map) else {
                return (nil, .saveUnavailable(.unreadable("state")))
            }
            let reference = settleOffline ? max(envelope.savedAt, envelope.wallHighWater)
                : max(envelope.savedAt, envelope.wallHighWater, now.isFinite ? now : 0)
            let coordinator = LifecycleCoordinator(session: session, repository: repository,
                                                   wallClock: wallClock, wallHighWater: reference, trace: trace)
            coordinator.log("launch", "loaded savedAt=\(traceNumber(envelope.savedAt)) settle=\(settleOffline)")
            let summary = settleOffline ? coordinator.settle(from: reference, to: now, kind: "launch") : nil
            coordinator.save(reason: "launch")
            return (coordinator, .ready(session, offline: summary, recoveredFromBackup: recovered))
        case .unavailable(let error):
            return (nil, .saveUnavailable(error))
        }
    }

    /// 进入后台：冻结离开基准并立即保存（多次通知只处理第一次）。
    /// 离开时刻取最后一个前台帧（回调迟到时更早）；还没有帧记录时取回调时刻。
    /// 有意暂停中（广告展示时按 Home/锁屏）取回调时刻：广告遮住 SpriteKit 时最后一帧可能早在广告开始之前，
    /// 用它会把广告展示时长算成离线（D-14）。回调迟到的那一小段不算离线，宁少不多。
    public func enterBackground() {
        let now = wallClock.now()
        guard !isInBackground else {
            log("background", "duplicate ignored")
            return
        }
        let departure = isPaused ? now : (lastFrameWall.map { min($0, now) } ?? now)
        let reference = departure.isFinite ? max(wallHighWater, departure) : wallHighWater
        isInBackground = true
        awayReference = reference
        wallHighWater = max(wallHighWater, reference)   // 离开时刻也是见过的墙钟：回拨后再拨回不能重复领取
        heldFrames = 0
        log("background", "departure=\(traceNumber(departure)) callback=\(traceNumber(now))\(isPaused ? " paused" : "")")
        save(reason: "background")
    }

    /// 回到前台：为这一次离开区间结算一次离线。重复通知、没有后台记录的 inactive→active 都返回 nil。
    public func becomeActive() -> OfflineSummary? {
        let now = wallClock.now()
        guard isInBackground, let reference = awayReference else {
            log("active", "no open interval")
            return nil
        }
        if heldFrames > 0 { log("active", "held \(heldFrames) frame(s) before active") }
        let summary = settle(from: reference, to: now, kind: "active")
        isInBackground = false
        awayReference = nil
        lastFrameWall = nil
        heldFrames = 0
        if isPaused { log("active", "still paused: frames held until the pause ends") }
        save(reason: "active")
        return summary
    }

    /// 每个前台帧推进之前调用（D-13）：
    /// - 离开区间未结算（后台已记录、`becomeActive` 尚未处理）→ `.hold`，本帧不推进、不保存；
    /// - 有意暂停中（广告仍在展示，包括回到前台而广告未关）→ `.hold`，不推进、不保存、不做帧停顿结算；
    /// - 距上一帧的墙钟间隔超过 `frameGapThreshold` 且没有后台记录 → 把这段按离线结算一次 → `.resumed`；
    /// - 否则 `.run`。
    public func admitForegroundFrame() -> ForegroundFrame {
        if isInBackground {
            heldFrames += 1
            if heldFrames == 1 { log("frame", "held: interval not settled yet") }
            return .hold
        }
        if isPaused {
            pausedFrames += 1
            if pausedFrames == 1 { log("frame", "held: intentional pause") }
            return .hold
        }
        let now = wallClock.now()
        guard now.isFinite else { return .run }
        guard let last = lastFrameWall else {
            lastFrameWall = now
            return .run
        }
        lastFrameWall = max(last, now)
        guard now - last > LifecycleCoordinator.frameGapThreshold else { return .run }
        log("frame", "gap \(traceNumber(now - last))s without background")
        let summary = settle(from: max(wallHighWater, last), to: now, kind: "gap")
        save(reason: "gap")
        return .resumed(summary)
    }

    /// 有意暂停开始（全屏奖励广告展示，RELEASE_SCOPE 第 3 章“展示期间暂停”，D-14）。暂停期间：
    /// - 前台帧一律 `.hold`：不推进、不保存、不做帧停顿结算；广告期间 SpriteKit 有帧或没帧，结果一致；
    /// - 切后台时离开时刻取回调时刻，广告展示时长既不算前台、也不算离线；
    /// - 回到前台只结算真正的后台区间；广告仍未关闭则保持暂停，直到 `endIntentionalPause()`。
    /// 与结束成对使用；重复开始只记第一次。
    public func beginIntentionalPause() {
        guard pausedSince == nil else {
            log("pause", "duplicate begin ignored")
            return
        }
        let now = wallClock.now()
        pausedSince = now.isFinite ? now : wallHighWater
        pausedFrames = 0
        log("pause", "begin")
    }

    /// 有意暂停结束（广告完成、提前关闭或展示失败都调用一次）。重复或没有对应开始的调用直接忽略。
    /// 结束后重新计帧：下一帧只作为基准，暂停期间的时间不补算（帧停顿检测从这一帧起照常工作）。
    /// 在后台结束（广告在后台被关闭）时只解除暂停，后台区间仍由 `becomeActive` 结算一次。
    public func endIntentionalPause() {
        guard let since = pausedSince else {
            log("pause", "end without begin ignored")
            return
        }
        let now = wallClock.now()
        pausedSince = nil
        lastFrameWall = nil
        log("pause", "end after=\(traceNumber(now.isFinite ? max(0, now - since) : 0)) held=\(pausedFrames)")
        pausedFrames = 0
    }

    /// 关键操作后与定时自动保存。失败不抛给玩家，记录后由 UI 提示 error.save。
    /// 离开区间未结算时，存档时间记为离开基准：保存不能吃掉尚未结算的离线时间（冷启动也从离开时刻起算）。
    @discardableResult
    public func save(reason: String = "app") -> Bool {
        let persistedAt: Double
        if isInBackground, let reference = awayReference {
            persistedAt = reference
        } else {
            let now = wallClock.now()
            wallHighWater = max(wallHighWater, now.isFinite ? now : wallHighWater)
            persistedAt = now.isFinite ? now : wallHighWater
        }
        do {
            try repository.save(session, now: persistedAt, wallHighWater: wallHighWater)
            lastSaveError = nil
            log("save", "\(reason) ok at=\(traceNumber(persistedAt))")
            return true
        } catch let error as SaveError {
            lastSaveError = error
            log("save", "\(reason) FAILED")
            return false
        } catch {
            lastSaveError = .writeFailed(String(describing: error))
            log("save", "\(reason) FAILED")
            return false
        }
    }

    /// 玩家确认 Start Over：清空本地档并从新档开始（设置保留）。
    public func resetColony() {
        session.apply(.reset)
        try? repository.eraseAll()
        save(reason: "reset")
    }

    /// 记录表现层的生命周期观测（scenePhase、系统通知、总结弹出/关闭）。只写调试日志，不改变状态。
    public func note(_ kind: String, _ detail: String) {
        log(kind, detail)
    }

    private func settle(from reference: Double, to now: Double, kind: String) -> OfflineSummary? {
        let away = now.isFinite ? max(0, now - reference) : 0
        let seconds = OfflineClock.cappedSeconds(savedAt: reference, now: now)
        if now.isFinite { wallHighWater = max(wallHighWater, now) }
        let foodBefore = session.colony.food
        guard seconds > 0, let result = try? session.settleOffline(seconds: seconds) else {
            log("settle", "\(kind) away=\(traceNumber(away)) settled=0")
            return nil
        }
        log("settle", "\(kind) away=\(traceNumber(away)) settled=\(traceNumber(result.simulatedSeconds)) "
            + "hauled=\(traceNumber(result.hauledFood)) food=\(traceNumber(foodBefore))->\(traceNumber(session.colony.food))")
        return OfflineSummary(hauledFood: result.hauledFood, netFood: result.netFood,
                              simulatedSeconds: result.simulatedSeconds, awaySeconds: away)
    }

    private func log(_ kind: String, _ detail: String) {
        guard let trace else { return }
        trace.record(kind: kind, detail: detail, wall: wallClock.now(), mono: monotonic.uptime(),
                     inBackground: isInBackground, highWater: wallHighWater, awayReference: awayReference,
                     lastFrame: lastFrameWall)
    }
}

/// 仅调试：生命周期环形日志（D-13 诊断）。不含设备标识、账号或购买数据；只在 Debug 构建创建。
/// 只在事件发生时写一行（不按帧写），最多保留 `capacity` 行。
public final class LifecycleTrace {
    public let capacity: Int
    public private(set) var lines: [String] = []
    /// 每记录一行加一（表现层据此判断是否需要刷新）
    public private(set) var sequence = 0
    private let processId: Int32

    public init(capacity: Int = 200, processId: Int32 = ProcessInfo.processInfo.processIdentifier) {
        self.capacity = capacity
        self.processId = processId
    }

    public func record(kind: String, detail: String, wall: Double, mono: Double, inBackground: Bool,
                       highWater: Double, awayReference: Double?, lastFrame: Double?) {
        sequence += 1
        let line = "#\(sequence) p\(processId) \(kind) \(detail) wall=\(traceNumber(wall)) mono=\(traceNumber(mono)) "
            + "bg=\(inBackground ? 1 : 0) hw=\(traceNumber(highWater)) ref=\(awayReference.map(traceNumber) ?? "-") "
            + "last=\(lastFrame.map(traceNumber) ?? "-")"
        lines.append(line)
        if lines.count > capacity { lines.removeFirst(lines.count - capacity) }
    }

    /// 最近 n 行，用 “ | ” 连接（UI 测试从隐藏的调试元素读取）
    public func tail(_ n: Int) -> String {
        lines.suffix(n).joined(separator: " | ")
    }
}

func traceNumber(_ value: Double) -> String {
    String(format: "%.2f", locale: Locale(identifier: "en_US_POSIX"), value)
}
