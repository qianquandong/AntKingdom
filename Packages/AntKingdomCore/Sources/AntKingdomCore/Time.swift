import Foundation

/// 墙钟：只用于后台差值和持久化（可被用户修改，必须钳制）。
public protocol WallClock {
    /// Unix 秒
    func now() -> Double
}

/// 前台单调时钟：设备重启会归零，但运行期间不受用户改系统时间影响。
public protocol MonotonicClock {
    func uptime() -> Double
}

public struct SystemWallClock: WallClock {
    public init() {}
    public func now() -> Double { Date().timeIntervalSince1970 }
}

public struct SystemMonotonicClock: MonotonicClock {
    public init() {}
    public func uptime() -> Double { ProcessInfo.processInfo.systemUptime }
}

/// 离线时长计算（PRD 5.3）：dt = clamp(当前 − 保存时间, 0, 3600)。
/// 负时差（系统时间回拨）按零处理；超过一小时的部分全部忽略；非有限值视为零。
public enum OfflineClock {
    public static func cappedSeconds(savedAt: Double, now: Double) -> Double {
        guard savedAt.isFinite, now.isFinite else { return 0 }
        return min(max(now - savedAt, 0), Rules.offlineCap)
    }
}

/// 前台帧时间累积器：按 0.25 秒逻辑量子推进，帧率（30/60/120Hz）不影响结果。
/// 单帧超过 `maxFrameDelta` 的部分视为卡顿丢弃——长时间离开由离线结算处理，避免重复计时。
public struct TickAccumulator: Equatable, Codable, Sendable {
    public static let maxFrameDelta = 1.0
    /// 尚未消耗的前台秒数（< 一个量子）；存档保存，避免丢失或重复时间。
    public private(set) var pending: Double = 0

    public init(pending: Double = 0) {
        self.pending = min(max(pending.isFinite ? pending : 0, 0), Rules.tick)
    }

    /// 加入一帧，返回本帧应推进的量子数。
    public mutating func add(_ frameDelta: Double) -> Int {
        guard frameDelta.isFinite, frameDelta > 0 else { return 0 }
        pending += min(frameDelta, TickAccumulator.maxFrameDelta)
        var quanta = 0
        while pending >= Rules.tick - 1e-12 {
            pending = max(0, pending - Rules.tick)
            quanta += 1
        }
        return quanta
    }
}
