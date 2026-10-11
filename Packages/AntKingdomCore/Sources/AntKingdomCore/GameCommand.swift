/// 玩家与调试入口能发出的全部命令。命令在单一执行上下文中排队、校验后原子生效；
/// 失败不部分扣费、不改状态。渲染与系统回调只能通过命令修改状态。
public enum GameCommand: Equatable, Sendable {
    /// 一次有效挖掘点击（频率限制在输入层，见 TapRateLimiter）
    case tapSoil(GridPoint)
    case buildPantry(topLeft: GridPoint)
    case movePantry(topLeft: GridPoint)
    case setHatching(Bool)
    case setSound(Bool)
    case setHaptics(Bool)
    /// 重置本地进度（UI 负责二次确认）
    case reset
    /// 调试/回放：直接完成一格（跳过三次点击）。正式 UI 不暴露。
    case debugCompleteCell(GridPoint)
}

public enum RejectReason: Equatable, Sendable {
    case notSoil
    case notFrontier
    case invalidPantrySpace
    case notEnoughFood
    case pantryAlreadyBuilt
    case noPantryToMove
}

public enum CommandResult: Equatable, Sendable {
    case tapAccepted(GridPoint, taps: Int)
    case cellOpened(GridPoint)
    case pantryBuilt(topLeft: GridPoint)
    case pantryMoved(topLeft: GridPoint)
    case hatchingChanged(Bool)
    case settingsChanged
    case didReset
    case rejected(RejectReason)

    public var isRejected: Bool {
        if case .rejected = self { return true }
        return false
    }
}

/// 逻辑事件：给表现层播放反馈、给本地调试日志记录。到达粒子不发钱，事件也不改余额。
public enum GameEvent: Equatable, Sendable {
    case cellOpened(GridPoint)
    /// 某个源从未连通变为连通（feedback.connected）
    case sourceConnected(String)
    /// 全员服务的源发生变化
    case activeSourceChanged(from: String?, to: String?, reason: SourceChangeReason)
    /// 冻结人口与源后，布局改变使预计产量提高（feedback.route_better）
    case routeImproved(sourceId: String, percent: Double)
    /// 固定补给到货（event.food_arrived）
    case foodArrived(String)
    case antsHatched(Int)
    case storageFullChanged(Bool)
    case pantryBuilt
    case pantryMoved
    /// 人口与容量上限都已达到（goal.prototype_complete）
    case prototypeComplete
}

public enum SourceChangeReason: String, Equatable, Sendable {
    case connected, depleted, refilled, layout, population
}

/// 输入层频率限制：手动点击逻辑上限每秒 8 次；长按每秒 5 次（PRD 2.2）。
/// 纯逻辑、可注入时间，便于测试；时间单位为秒（前台单调时钟）。
public struct TapRateLimiter: Sendable {
    public private(set) var lastAccepted: Double?

    public init() {}

    public static let manualInterval = 1.0 / Rules.maxManualTapsPerSecond
    public static let holdInterval = 1.0 / Rules.holdTapsPerSecond

    /// 手动点击：距上一次有效点击不足 1/8 秒则忽略（不计数、不报错）。
    public mutating func acceptManualTap(at time: Double) -> Bool {
        if let last = lastAccepted, time - last < TapRateLimiter.manualInterval - 1e-9 { return false }
        lastAccepted = time
        return true
    }

    /// 长按从 `start` 持续到 `now` 应累计的有效点击数（按下立即一次，之后每 0.2 秒一次）。
    public static func holdTaps(from start: Double, to now: Double) -> Int {
        guard now >= start else { return 0 }
        return Int(((now - start) / holdInterval + 1e-9).rounded(.down)) + 1
    }
}
