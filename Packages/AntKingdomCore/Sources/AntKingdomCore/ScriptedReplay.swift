/// 600 秒固定操作回放（PRD 6.2），对应 Python `scripted_session`。
/// 只用于回归验证；不模拟真实点击速度、用户选择或付费行为。
public enum ScriptedReplay {
    public static let actions: [Int: [GridPoint]] = [
        30: [GridPoint(2, 4), GridPoint(2, 5), GridPoint(2, 6)],
        150: [GridPoint(1, 4), GridPoint(1, 5)],
        300: [GridPoint(6, 3), GridPoint(6, 2)],
        360: [GridPoint(6, 4), GridPoint(6, 5), GridPoint(6, 6), GridPoint(7, 6)],
    ]
    public static let pantryTopLeft = GridPoint(1, 4)
    public static let pantryFromSecond = 150

    /// 每秒推进后的状态快照，供与 Python 逐步比对。
    public struct Snapshot: Equatable, Sendable {
        public let second: Int
        public let elapsed: Double
        public let food: Double
        public let ants: Int
        public let larvae: [Double]
        public let hauled: Double
        public let spent: Double
        public let refills: Int
        public let refillLeft: Double
        public let nextPatch: Int
        public let remaining: [Double?]
        public let pantryBuilt: Bool
        public let activeSource: String?
    }

    public struct Summary: Equatable, Sendable {
        public let ants: Int
        public let larvae: Int
        public let food: Double
        public let capacity: Double
        public let hauled: Double
        public let spent: Double
        public let refills: Int
        public var conservationError: Double { hauled - spent - food }
    }

    /// 运行回放；`observe` 在每秒推进后被调用。
    @discardableResult
    public static func run(seconds: Int = 600, observe: ((Colony, Int) -> Void)? = nil) throws -> (Colony, Summary) {
        let colony = Colony()
        for second in 0..<seconds {
            for p in actions[second] ?? [] { try colony.dig(p) }
            if second >= pantryFromSecond, colony.pantry.isEmpty, colony.food >= Rules.pantryCost {
                try colony.placePantry(topLeft: pantryTopLeft)
            }
            try colony.advance(1)
            observe?(colony, second)
        }
        let summary = Summary(ants: colony.ants, larvae: colony.larvae.count, food: colony.food,
                              capacity: colony.capacity, hauled: colony.hauled, spent: colony.spent,
                              refills: colony.refills)
        return (colony, summary)
    }

    public static func snapshot(_ colony: Colony, second: Int) -> Snapshot {
        Snapshot(second: second, elapsed: colony.elapsed, food: colony.food, ants: colony.ants,
                 larvae: colony.larvae, hauled: colony.hauled, spent: colony.spent, refills: colony.refills,
                 refillLeft: colony.refillLeft, nextPatch: colony.nextPatch,
                 remaining: colony.sources.map(\.remaining), pantryBuilt: !colony.pantry.isEmpty,
                 activeSource: colony.activeSourceId)
    }
}
