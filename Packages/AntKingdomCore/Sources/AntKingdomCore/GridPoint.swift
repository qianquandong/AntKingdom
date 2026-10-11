/// 格坐标：x 向右、y 向下，零起算。y = 0 是地面行。
/// 表现层负责转换到 SpriteKit 坐标；规则层永不翻转 y。
public struct GridPoint: Hashable, Sendable, CustomStringConvertible {
    public let x: Int
    public let y: Int

    public init(_ x: Int, _ y: Int) {
        self.x = x
        self.y = y
    }

    /// 固定邻接顺序：上、左、右、下（PRD 4.3）。
    public var neighbors: [GridPoint] {
        [GridPoint(x, y - 1), GridPoint(x - 1, y), GridPoint(x + 1, y), GridPoint(x, y + 1)]
    }

    /// 决策排序键：先行（y）后列（x）。对应 Python `point_key`。
    public static func keyLess(_ a: GridPoint, _ b: GridPoint) -> Bool {
        a.y != b.y ? a.y < b.y : a.x < b.x
    }

    public var description: String { "(\(x),\(y))" }
}

extension GridPoint: Codable {
    /// 编码为 `[x, y]`，与 design/*.json 夹具一致。
    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        x = try container.decode(Int.self)
        y = try container.decode(Int.self)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(x)
        try container.encode(y)
    }
}

extension Sequence where Element == GridPoint {
    /// 按 (y, x) 稳定排序；不能依赖 Set 的枚举顺序做决策。
    public func sortedByKey() -> [GridPoint] {
        sorted(by: GridPoint.keyLess)
    }
}
