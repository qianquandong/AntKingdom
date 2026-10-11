/// 一个源的运输需求：所有装货点与分配给它的成年蚂蚁。
public struct Demand: Equatable, Sendable {
    public let id: String
    public let starts: Set<GridPoint>
    public let ants: Int
    public let extraSeconds: Double

    public init(id: String, starts: Set<GridPoint>, ants: Int, extraSeconds: Double = 0) {
        self.id = id
        self.starts = starts
        self.ants = ants
        self.extraSeconds = extraSeconds
    }
}

/// 一条候选路线及其分配人数。
public struct Route: Equatable, Sendable {
    public let sourceId: String
    /// 含装货点与卸货点
    public let cells: [GridPoint]
    public internal(set) var ants: Int
    public let extraSeconds: Double

    /// 单程格数 L = max(1, 路径格数 − 1)
    public var distance: Int { max(1, cells.count - 1) }

    /// 中间格：装卸两端不计入拥堵（服务耗时已单独计入 handling）。
    public var transit: ArraySlice<GridPoint> {
        cells.count > 2 ? cells[1..<(cells.count - 1)] : []
    }
}

/// 求解结果。`sourceRates` 保持 Python dict 的插入顺序，求和顺序因此一致。
public struct TransportPlan: Equatable, Sendable {
    public let routes: [Route]
    public let loads: [GridPoint: Int]
    /// 与 routes 一一对应的完整往返周期（秒）
    public let tripSeconds: [Double]
    public let sourceRates: [SourceRate]
    public let moves: Int
    public let converged: Bool
    public let improvements: [Double]

    public struct SourceRate: Equatable, Sendable {
        public let sourceId: String
        public let foodPerSecond: Double
    }

    /// 总 Food/s（按插入顺序求和）
    public var rate: Double { sourceRates.reduce(0.0) { $0 + $1.foodPerSecond } }

    public func rate(for sourceId: String) -> Double {
        sourceRates.first { $0.sourceId == sourceId }?.foodPerSecond ?? 0
    }

    public var maxLoad: Int { loads.values.max() ?? 0 }

    /// 负载超过预算的“繁忙”格（load > C）
    public var busyCells: Set<GridPoint> {
        Set(loads.filter { Double($0.value) > Rules.laneCapacity }.keys)
    }

    /// 已分配蚂蚁的加权平均周期；没有活跃路线时为 nil（显示 state.no_route）。
    public var averageTripSeconds: Double? {
        var ants = 0
        var weighted = 0.0
        for (route, trip) in zip(routes, tripSeconds) where route.ants > 0 {
            ants += route.ants
            weighted += Double(route.ants) * trip
        }
        return ants > 0 ? weighted / Double(ants) : nil
    }

    public static let empty = TransportPlan(routes: [], loads: [:], tripSeconds: [], sourceRates: [],
                                            moves: 0, converged: true, improvements: [0])
}

public enum TransportPlanner {
    /// 对应 Python `evaluate`：共享负载 → 每条路线的周期 → 每个源的 Food/s。
    public static func evaluate(_ routes: [Route], speed: Double = Rules.speed, carry: Double = Rules.carry)
        -> (loads: [GridPoint: Int], trips: [Double], rates: [TransportPlan.SourceRate]) {
        precondition(speed > 0 && carry > 0, "speed and carry must be positive")
        var loads: [GridPoint: Int] = [:]
        for route in routes {
            for p in route.transit { loads[p, default: 0] += route.ants }
        }
        var trips: [Double] = []
        var order: [String] = []
        var rateBySource: [String: Double] = [:]
        trips.reserveCapacity(routes.count)
        for route in routes {
            var extra = 0.0
            for p in route.transit {
                extra += max(0.0, Double(loads[p] ?? 0) / Rules.laneCapacity - 1.0)
            }
            let trip = 2.0 * (Double(route.distance) + extra) / speed + Rules.handling + route.extraSeconds
            trips.append(trip)
            if rateBySource[route.sourceId] == nil {
                order.append(route.sourceId)
                rateBySource[route.sourceId] = 0.0
            }
            rateBySource[route.sourceId]! += Double(route.ants) * carry / trip
        }
        let rates = order.map { TransportPlan.SourceRate(sourceId: $0, foodPerSecond: rateBySource[$0]!) }
        return (loads, trips, rates)
    }

    static func score(_ routes: [Route], speed: Double, carry: Double) -> Double {
        evaluate(routes, speed: speed, carry: carry).rates.reduce(0.0) { $0 + $1.foodPerSecond }
    }

    /// 对应 Python `plan_transport`：从主路径出发，每次只挪一只，接受严格增加全体 Food/s
    /// 最多的一次调整（> 1e-10，同增益保留先遍历到的）；最多 256 次。
    public static func plan(walkable: Set<GridPoint>, sinks: Set<GridPoint>, demands: [Demand],
                            speed: Double = Rules.speed, carry: Double = Rules.carry) -> TransportPlan {
        var routes: [Route] = []
        for demand in demands.sorted(by: { $0.id < $1.id }) {
            precondition(demand.ants >= 0, "negative haulers")
            let paths = Pathfinder.candidatePaths(walkable: walkable, starts: demand.starts, sinks: sinks)
            for (index, path) in paths.enumerated() {
                routes.append(Route(sourceId: demand.id, cells: path, ants: index == 0 ? demand.ants : 0,
                                    extraSeconds: demand.extraSeconds))
            }
        }
        var current = score(routes, speed: speed, carry: carry)
        var improvements = [current]
        var moves = 0
        var converged = false
        while moves < Rules.maxMoves {
            var bestScore = current
            var best: (Int, Int)?
            for i in routes.indices where routes[i].ants > 0 {
                for j in routes.indices where i != j && routes[i].sourceId == routes[j].sourceId {
                    routes[i].ants -= 1
                    routes[j].ants += 1
                    let candidate = score(routes, speed: speed, carry: carry)
                    routes[i].ants += 1
                    routes[j].ants -= 1
                    if candidate > bestScore + Rules.epsilon {
                        bestScore = candidate
                        best = (i, j)
                    }
                }
            }
            guard let (i, j) = best else {
                converged = true
                break
            }
            routes[i].ants -= 1
            routes[j].ants += 1
            current = bestScore
            improvements.append(current)
            moves += 1
        }
        let result = evaluate(routes, speed: speed, carry: carry)
        return TransportPlan(routes: routes, loads: result.loads, tripSeconds: result.trips,
                             sourceRates: result.rates, moves: moves, converged: converged,
                             improvements: improvements)
    }
}
