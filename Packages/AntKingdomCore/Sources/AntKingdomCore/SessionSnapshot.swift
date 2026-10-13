/// 表现层每帧读取的只读快照。渲染和 UI 不能通过快照修改状态。
public struct SessionSnapshot: Equatable, Sendable {
    public struct RouteView: Equatable, Sendable {
        public let sourceId: String
        public let cells: [GridPoint]
        public let ants: Int
        public let tripSeconds: Double
    }

    public struct SourceView: Equatable, Sendable {
        public let id: String
        public let kind: SourceDefinition.Kind
        public let cells: Set<GridPoint>
        /// nil = 无限
        public let remaining: Double?
        public let isConnected: Bool
        public let isActive: Bool
        /// 补给为空（显示空盘/等待补给）
        public var isEmptyPatch: Bool { kind == .patch && (remaining ?? 0) <= Rules.epsilon }
    }

    public let food: Double
    public let capacity: Double
    public let ants: Int
    public let populationCap: Int
    /// 每个卵的剩余秒数
    public let eggs: [Double]
    /// 与 eggs 一一对应的固定槽（D-16）：表现层按槽放卵，孵化只移除那一枚
    public let eggSlots: [Int]
    public let hatching: Bool
    public let isStorageFull: Bool
    public let activeSourceId: String?
    /// 当前网络不受库存限制时的预计能力（Food/min）
    public let expectedFoodPerMinute: Double
    /// 已分配蚂蚁的加权平均完整往返周期；无活跃路线为 nil
    public let averageTripSeconds: Double?
    /// 只含已分配蚂蚁的路线
    public let routes: [RouteView]
    public let loads: [GridPoint: Int]
    public let busyCells: Set<GridPoint>
    public let sources: [SourceView]
    public let walkable: Set<GridPoint>
    public let pantryCells: Set<GridPoint>
    public let digTaps: [GridPoint: Int]
    public let frontier: Set<GridPoint>
    /// 两处补给都空时的刷新倒计时
    public let refillCountdown: Double?
    public let elapsed: Double
    public let settings: GameState.Settings
    public let flags: GameState.Flags

    public var hasPantry: Bool { !pantryCells.isEmpty }
    public var canAffordPantry: Bool { food >= Rules.pantryCost }
}

extension GameSession {
    public func snapshot() -> SessionSnapshot {
        let plan = (try? colony.plan()) ?? .empty
        let active = colony.activeSourceId
        let routes = zip(plan.routes, plan.tripSeconds).compactMap { route, trip -> SessionSnapshot.RouteView? in
            route.ants > 0 ? .init(sourceId: route.sourceId, cells: route.cells, ants: route.ants, tripSeconds: trip) : nil
        }
        let sources = colony.sources.map { source in
            SessionSnapshot.SourceView(id: source.id, kind: source.definition.kind, cells: source.definition.cells,
                                       remaining: source.remaining, isConnected: colony.isConnected(source),
                                       isActive: source.id == active)
        }
        let patchesEmpty = colony.sources.filter { $0.definition.kind == .patch }
            .allSatisfy { ($0.remaining ?? 0) <= Rules.epsilon }
        return SessionSnapshot(
            food: colony.food, capacity: colony.capacity, ants: colony.ants, populationCap: Rules.populationCap,
            eggs: colony.larvae, eggSlots: colony.eggs.map(\.slot), hatching: colony.hatching, isStorageFull: colony.isStorageFull,
            activeSourceId: active, expectedFoodPerMinute: plan.rate * 60,
            averageTripSeconds: plan.averageTripSeconds, routes: routes, loads: plan.loads,
            busyCells: plan.busyCells, sources: sources, walkable: colony.walkable, pantryCells: colony.pantry,
            digTaps: digTaps, frontier: map.soilCells.filter { colony.isFrontier($0) },
            refillCountdown: patchesEmpty ? colony.refillLeft : nil, elapsed: colony.elapsed,
            settings: settings, flags: flags)
    }
}
