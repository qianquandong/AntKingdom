import Foundation

/// design/transport_cases.json 的结构。双方（Python/Swift）共用同一份输入。
public struct TransportCase: Codable, Sendable {
    public struct Variant: Codable, Sendable {
        public let walkable: [GridPoint]
        public let sinks: [GridPoint]
    }

    public struct DemandSpec: Codable, Sendable {
        public let id: String
        public let starts: [GridPoint]
        public let ants: Int
    }

    public let id: String
    public let description: String
    public let before: Variant
    public let after: Variant
    public let demands: [DemandSpec]
    public let expected: [String: Double]

    public static func load(from url: URL) throws -> [TransportCase] {
        try JSONDecoder().decode([TransportCase].self, from: Data(contentsOf: url))
    }

    public func plan(_ variant: Variant) -> TransportPlan {
        TransportPlanner.plan(walkable: Set(variant.walkable), sinks: Set(variant.sinks),
                              demands: demands.map { Demand(id: $0.id, starts: Set($0.starts), ants: $0.ants) })
    }

    /// 与 Python `fixture_results()` 同口径的结果（未取整）。
    public func result() -> FixtureResult {
        let before = plan(before), after = plan(after)
        return FixtureResult(
            caseId: id,
            beforeFoodPerMin: before.rate * 60,
            afterFoodPerMin: after.rate * 60,
            gainPercent: (after.rate / before.rate - 1) * 100,
            beforeMaxLoad: before.maxLoad,
            afterMaxLoad: after.maxLoad,
            afterAllocations: after.routes.map(\.ants),
            converged: before.converged && after.converged)
    }
}

public struct FixtureResult: Equatable, Sendable {
    public let caseId: String
    public let beforeFoodPerMin: Double
    public let afterFoodPerMin: Double
    public let gainPercent: Double
    public let beforeMaxLoad: Int
    public let afterMaxLoad: Int
    public let afterAllocations: [Int]
    public let converged: Bool

    /// 按 expected 字典里的键取值（键名与 Python 相同）。
    public func value(forExpectedKey key: String) -> Double? {
        switch key {
        case "before_food_per_min": return beforeFoodPerMin
        case "after_food_per_min": return afterFoodPerMin
        case "gain_percent": return gainPercent
        case "before_max_load": return Double(beforeMaxLoad)
        case "after_max_load": return Double(afterMaxLoad)
        default: return nil
        }
    }
}
