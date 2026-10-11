/// 可序列化的唯一逻辑事实（存档内容的 payload）。路线与缓存不保存，从这些字段重建。
/// 字段对应 PRD 5.3 的保存清单；版本号与保存时间在 SaveEnvelope 中。
public struct GameState: Codable, Equatable, Sendable {
    public struct DigTap: Codable, Equatable, Sendable {
        public let cell: GridPoint
        public let taps: Int
    }

    public struct Settings: Codable, Equatable, Sendable {
        public var sound = true
        public var haptics = true
        public init(sound: Bool = true, haptics: Bool = true) {
            self.sound = sound
            self.haptics = haptics
        }
    }

    /// 首局引导与反馈去重用的进度标记（不影响经济）。
    /// 解码时缺失的键取默认值：新增标记不会让旧存档无法读取。
    public struct Flags: Codable, Equatable, Sendable {
        public var firstSourceConnected = false
        public var pantryBuiltOnce = false
        public var pantryMovedOnce = false
        public var prototypeComplete = false
        public init() {}

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            firstSourceConnected = try c.decodeIfPresent(Bool.self, forKey: .firstSourceConnected) ?? false
            pantryBuiltOnce = try c.decodeIfPresent(Bool.self, forKey: .pantryBuiltOnce) ?? false
            pantryMovedOnce = try c.decodeIfPresent(Bool.self, forKey: .pantryMovedOnce) ?? false
            prototypeComplete = try c.decodeIfPresent(Bool.self, forKey: .prototypeComplete) ?? false
        }
    }

    public var mapId: String
    public var mapVersion: Int
    /// 玩家挖开的格（按 (y,x) 排序）；初始通路不在其中
    public var dugCells: [GridPoint]
    /// 未完成格的有效点击数（1…2）
    public var digTaps: [DigTap]
    public var food: Double
    public var ants: Int
    /// 每个卵的剩余秒数
    public var larvae: [Double]
    public var hatching: Bool
    public var pantryTopLeft: GridPoint?
    /// 有限补给的余量，键为源 ID（cookie / sugar）
    public var patchRemaining: [String: Double]
    public var refillLeft: Double
    /// 下一次补给的源 ID
    public var nextPatchId: String
    public var refills: Int
    /// 累计逻辑时间（秒）
    public var elapsed: Double
    public var hauled: Double
    public var spent: Double
    /// 前台累积器中尚未推进的秒数（< 0.25）
    public var pendingTick: Double
    public var settings: Settings
    public var flags: Flags
}

public enum StateValidationError: Error, Equatable, Sendable, CustomStringConvertible {
    case mapMismatch
    case invalid(String)

    public var description: String {
        switch self {
        case .mapMismatch: return "map mismatch"
        case .invalid(let reason): return "invalid state: \(reason)"
        }
    }
}
