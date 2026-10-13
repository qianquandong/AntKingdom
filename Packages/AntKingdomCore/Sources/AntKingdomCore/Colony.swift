/// 规则层错误。客户端把它们映射为英文提示（PRD 附录 A），不直接显示给玩家。
public enum ColonyError: Error, Equatable, Sendable {
    case notUndugSoil
    case notFrontier
    case invalidPantryFootprint
    case notEnoughFood
    case invalidDuration
    case solverDidNotConverge
}

/// 有限源/永久源的运行时状态。
public struct SourceState: Equatable, Sendable {
    public let definition: SourceDefinition
    /// nil 表示无限
    public var remaining: Double?

    public var id: String { definition.id }
}

/// 离线结算结果：实际搬入与库存净变化分开记录（PRD 5.3）。
public struct OfflineResult: Equatable, Sendable {
    public let netFood: Double
    public let hauledFood: Double
    public let simulatedSeconds: Double
}

/// 一枚正在孵化的卵（D-16）。`slot` 是它在 Queen Chamber 里的固定位置（0、1），从下单到孵化不变。
public struct Egg: Equatable, Sendable {
    public var remaining: Double
    public var slot: Int

    public init(remaining: Double, slot: Int) {
        self.remaining = remaining
        self.slot = slot
    }
}

/// P0 小地图经济状态机，逐行对应 tools/economy_sim.py 的 `Colony`。
/// 食物必须真的挖通；没有广告或付费推算。所有修改在调用者的单一执行上下文中顺序进行。
public final class Colony {
    public let map: MapDefinition
    public internal(set) var walkable: Set<GridPoint>
    public internal(set) var pantry: Set<GridPoint> = []
    public internal(set) var sources: [SourceState]
    public internal(set) var food = 0.0
    public internal(set) var ants = Rules.initialAnts
    /// 正在孵化的卵（创建顺序）。每枚卵从下单到孵化固定占一个槽（D-16）：槽只是表现层的身份与位置，
    /// 不参与经济；孵化时长、人口、成本与 tools/economy_sim.py 完全一致。
    public internal(set) var eggs: [Egg] = []
    /// 每个卵的剩余秒数（与 Python 基准对照的形式）。整体赋值（存档恢复、调试）按顺序确定性分配槽 0、1……
    public internal(set) var larvae: [Double] {
        get { eggs.map(\.remaining) }
        set { eggs = newValue.enumerated().map { Egg(remaining: $1, slot: $0) } }
    }
    public internal(set) var hatching = true
    public internal(set) var elapsed = 0.0
    public internal(set) var refillLeft = Rules.refillSeconds
    /// 下一个补给的源下标：1 = Sugar，0 = Cookie（Cookie → Sugar → Cookie 交替）
    public internal(set) var nextPatch = 1
    public internal(set) var refills = 0
    public internal(set) var hauled = 0.0
    public internal(set) var spent = 0.0

    private var cachedKey: PlanKey?
    private var cachedPlan: TransportPlan?

    private struct PlanKey: Equatable {
        let walkable: Set<GridPoint>
        let sinks: Set<GridPoint>
        let demands: [Demand]
    }

    public init(map: MapDefinition = .backyard) {
        self.map = map
        self.walkable = map.initialWalkable
        self.sources = map.sources.map { SourceState(definition: $0, remaining: $0.initialRemaining) }
    }

    /// 深拷贝（对应测试里的 `copy.deepcopy`）；缓存不复制，会按需重建。
    public func copy() -> Colony {
        let other = Colony(map: map)
        other.walkable = walkable
        other.pantry = pantry
        other.sources = sources
        other.food = food
        other.ants = ants
        other.eggs = eggs
        other.hatching = hatching
        other.elapsed = elapsed
        other.refillLeft = refillLeft
        other.nextPatch = nextPatch
        other.refills = refills
        other.hauled = hauled
        other.spent = spent
        return other
    }

    public var capacity: Double { Rules.baseStorage + (pantry.isEmpty ? 0 : Rules.pantryStorage) }

    /// 新订单占用的槽：编号最小的空槽（确定性）。调用方保证 eggs.count < Rules.larvaSlots。
    func freeEggSlot() -> Int {
        (0..<Rules.larvaSlots).first { slot in !eggs.contains { $0.slot == slot } } ?? eggs.count
    }

    /// 按存档里的槽恢复（D-16）。槽缺失（旧存档）、数量不符、越界或重复时，按创建顺序确定性分配 0、1……一次；
    /// 不因槽数据拒绝读档（槽只影响表现）。
    func restoreEggSlots(_ slots: [Int]?) {
        guard let slots, slots.count == eggs.count, Set(slots).count == slots.count,
              slots.allSatisfy({ (0..<Rules.larvaSlots).contains($0) }) else { return }
        for index in eggs.indices { eggs[index].slot = slots[index] }
    }

    public var sinks: Set<GridPoint> { map.queenCells.union(pantry) }

    public var isStorageFull: Bool { capacity - food <= Rules.epsilon }

    public func isFrontier(_ p: GridPoint) -> Bool {
        map.tile(at: p) == .soil && !walkable.contains(p) && p.neighbors.contains(where: walkable.contains)
    }

    // MARK: 地图动作

    /// 完成一格挖掘。基准工具按“完成一格”操作；客户端先累计三次有效点击（见 DigProgress）。
    public func dig(_ p: GridPoint) throws {
        guard map.tile(at: p) == .soil, !walkable.contains(p) else { throw ColonyError.notUndugSoil }
        guard p.neighbors.contains(where: walkable.contains) else { throw ColonyError.notFrontier }
        walkable.insert(p)
    }

    public static func pantryCells(topLeft: GridPoint) -> Set<GridPoint> {
        [GridPoint(topLeft.x, topLeft.y), GridPoint(topLeft.x, topLeft.y + 1),
         GridPoint(topLeft.x + 1, topLeft.y), GridPoint(topLeft.x + 1, topLeft.y + 1)]
    }

    /// 占地是否合法（不检查余额）：四格都已挖通，不压 Queen、入口；补给/石头本就不可通行。
    public func isValidPantryFootprint(topLeft: GridPoint) -> Bool {
        let cells = Colony.pantryCells(topLeft: topLeft)
        return cells.isSubset(of: walkable) && cells.isDisjoint(with: map.queenCells) && !cells.contains(map.entrance)
    }

    /// 首次建造扣 50 Food；之后的调用是免费移动（允许与旧位置重叠）。失败不改任何状态。
    public func placePantry(topLeft: GridPoint) throws {
        guard isValidPantryFootprint(topLeft: topLeft) else { throw ColonyError.invalidPantryFootprint }
        if pantry.isEmpty {
            guard food >= Rules.pantryCost else { throw ColonyError.notEnoughFood }
            food -= Rules.pantryCost
            spent += Rules.pantryCost
        }
        pantry = Colony.pantryCells(topLeft: topLeft)
    }

    public func setHatching(_ enabled: Bool) {
        hatching = enabled
    }

    // MARK: 运输

    /// 某个源当前的装货点（未扣除余量判断）。
    public func loadingCells(for source: SourceState) -> Set<GridPoint> {
        if source.definition.kind == .surface { return [map.entrance] }
        var starts = Set<GridPoint>()
        for p in source.definition.cells {
            for q in p.neighbors where walkable.contains(q) { starts.insert(q) }
        }
        return starts
    }

    /// 源是否与卸货点连通（不考虑余量）。
    public func isConnected(_ source: SourceState) -> Bool {
        Pathfinder.shortestPath(walkable: walkable, starts: loadingCells(for: source), sinks: sinks) != nil
    }

    /// 首版源选择：已连接且有存量的补给 > 树液根 > 地面兜底；同级按无拥堵周期、ID。
    public func activeDemands() -> [Demand] {
        var active: [(priority: Int, freeTrip: Double, id: String, starts: Set<GridPoint>, extra: Double)] = []
        for source in sources {
            if let remaining = source.remaining, remaining <= Rules.epsilon { continue }
            let starts = loadingCells(for: source)
            if let route = Pathfinder.shortestPath(walkable: walkable, starts: starts, sinks: sinks) {
                let freeTrip = 2 * Double(max(1, route.count - 1)) / Rules.speed + Rules.handling
                    + source.definition.extraSeconds
                active.append((source.definition.priority, freeTrip, source.id, starts, source.definition.extraSeconds))
            }
        }
        active.sort { a, b in
            if a.priority != b.priority { return a.priority < b.priority }
            if a.freeTrip != b.freeTrip { return a.freeTrip < b.freeTrip }
            return a.id < b.id
        }
        guard let first = active.first else { return [] }
        return [Demand(id: first.id, starts: first.starts, ants: ants, extraSeconds: first.extra)]
    }

    /// 当前全员服务的源；没有任何连通源时为 nil。
    public var activeSourceId: String? { activeDemands().first?.id }

    /// 对应 Python `Colony.plan`：缓存键包含通路、卸货点、源需求与人口。
    public func plan() throws -> TransportPlan {
        let demands = activeDemands()
        let key = PlanKey(walkable: walkable, sinks: sinks, demands: demands)
        if key != cachedKey || cachedPlan == nil {
            let plan = TransportPlanner.plan(walkable: walkable, sinks: sinks, demands: demands)
            guard plan.converged else { throw ColonyError.solverDidNotConverge }
            cachedPlan = plan
            cachedKey = key
        }
        return cachedPlan!
    }

    // MARK: 经济步进

    /// 仅按实际入库量扣有限源；满仓时源和库存均不变。返回实际入库。
    @discardableResult
    public func harvest(seconds: Double, efficiency: Double) throws -> Double {
        let available = max(0.0, capacity - food)
        if available <= Rules.epsilon { return 0.0 }
        let plan = try plan()
        var desired: [Double] = []
        var total = 0.0
        for source in sources {
            var amount = plan.rate(for: source.id) * seconds * efficiency
            if let remaining = source.remaining { amount = min(amount, remaining) }
            desired.append(amount)
            total += amount
        }
        let scale = total > 0 ? min(1.0, available / total) : 0.0
        var credited = 0.0
        for index in sources.indices {
            let amount = desired[index] * scale
            if let remaining = sources[index].remaining {
                sources[index].remaining = max(0.0, remaining - amount)
            }
            credited += amount
        }
        food = min(capacity, food + credited)
        hauled += credited
        return credited
    }

    /// 0.25 秒基准步长，在孵化完成与刷新到期处切短。步内顺序见 PRD 5.3。
    public func advance(_ seconds: Double, efficiency: Double = 1.0) throws {
        guard seconds.isFinite, seconds >= 0, efficiency >= 0, efficiency <= 1 else {
            throw ColonyError.invalidDuration
        }
        let end = elapsed + seconds
        while elapsed < end - Rules.epsilon {
            var dt = min(Rules.tick, end - elapsed)
            if let soonest = eggs.map(\.remaining).min() { dt = min(dt, soonest) }
            let patchesEmpty = sources[0].remaining! <= Rules.epsilon && sources[1].remaining! <= Rules.epsilon
            if patchesEmpty { dt = min(dt, refillLeft) }
            try harvest(seconds: dt, efficiency: efficiency)
            for index in eggs.indices { eggs[index].remaining -= dt }
            ants += eggs.filter { $0.remaining <= Rules.epsilon }.count
            eggs.removeAll { $0.remaining <= Rules.epsilon }   // 只移除孵化的那枚，其余留在原槽
            if hatching {
                while eggs.count < Rules.larvaSlots, ants + eggs.count < Rules.populationCap,
                      food >= Rules.hatchCost {
                    food -= Rules.hatchCost
                    spent += Rules.hatchCost
                    eggs.append(Egg(remaining: Rules.hatchSeconds, slot: freeEggSlot()))
                }
            }
            if patchesEmpty {
                refillLeft -= dt
                if refillLeft <= Rules.epsilon {
                    sources[nextPatch].remaining = sources[nextPatch].definition.refillAmount
                    nextPatch = 1 - nextPatch
                    refills += 1
                    refillLeft = Rules.refillSeconds
                }
            }
            elapsed += dt
        }
    }

    /// 离线：同一状态机，只把运输流量乘 0.25；计时按封顶后的实际秒数推进。
    @discardableResult
    public func offline(_ seconds: Double) throws -> OfflineResult {
        guard seconds.isFinite, seconds >= 0 else { throw ColonyError.invalidDuration }
        let before = food
        let hauledBefore = hauled
        let simulated = min(seconds, Rules.offlineCap)
        try advance(simulated, efficiency: Rules.offlineEfficiency)
        return OfflineResult(netFood: food - before, hauledFood: hauled - hauledBefore, simulatedSeconds: simulated)
    }
}
