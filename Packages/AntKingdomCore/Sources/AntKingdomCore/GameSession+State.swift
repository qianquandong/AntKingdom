extension GameSession {
    /// 导出可序列化状态（存档 payload）。
    public func makeState() -> GameState {
        let dug = colony.walkable.subtracting(map.initialWalkable).sortedByKey()
        var patches: [String: Double] = [:]
        for source in colony.sources where source.definition.kind == .patch {
            patches[source.id] = source.remaining ?? 0
        }
        return GameState(
            mapId: map.id, mapVersion: map.version,
            dugCells: dug,
            digTaps: digTaps.keys.sortedByKey().map { GameState.DigTap(cell: $0, taps: digTaps[$0]!) },
            food: colony.food, ants: colony.ants, larvae: colony.larvae, eggSlots: colony.eggs.map(\.slot),
            hatching: colony.hatching,
            pantryTopLeft: colony.pantry.min(by: GridPoint.keyLess),
            patchRemaining: patches,
            refillLeft: colony.refillLeft,
            nextPatchId: colony.sources[colony.nextPatch].id,
            refills: colony.refills, elapsed: colony.elapsed, hauled: colony.hauled, spent: colony.spent,
            pendingTick: accumulator.pending, settings: settings, flags: flags)
    }

    /// 从存档恢复；任何非法占地、负资源、超人口、非有限数都拒绝（PRD 5.3 启动校验）。
    public convenience init(state: GameState, map: MapDefinition = .backyard) throws {
        try GameSession.validate(state, map: map)
        self.init(map: map, settings: state.settings)
        let colony = Colony(map: map)
        colony.walkable = map.initialWalkable.union(state.dugCells)
        if let topLeft = state.pantryTopLeft { colony.pantry = Colony.pantryCells(topLeft: topLeft) }
        for index in colony.sources.indices where colony.sources[index].definition.kind == .patch {
            colony.sources[index].remaining = state.patchRemaining[colony.sources[index].id]
        }
        colony.food = state.food
        colony.ants = state.ants
        colony.larvae = state.larvae
        colony.restoreEggSlots(state.eggSlots)
        colony.hatching = state.hatching
        colony.elapsed = state.elapsed
        colony.refillLeft = state.refillLeft
        colony.nextPatch = colony.sources.firstIndex { $0.id == state.nextPatchId }!
        colony.refills = state.refills
        colony.hauled = state.hauled
        colony.spent = state.spent
        self.colony = colony
        self.digTaps = Dictionary(uniqueKeysWithValues: state.digTaps.map { ($0.cell, $0.taps) })
        self.flags = state.flags
        self.accumulator = TickAccumulator(pending: state.pendingTick)
    }

    public static func validate(_ state: GameState, map: MapDefinition = .backyard) throws {
        func fail(_ reason: String) -> StateValidationError { .invalid(reason) }
        guard state.mapId == map.id, state.mapVersion == map.version else { throw StateValidationError.mapMismatch }
        let numbers = [state.food, state.elapsed, state.hauled, state.spent, state.refillLeft, state.pendingTick]
            + state.larvae + Array(state.patchRemaining.values)
        guard numbers.allSatisfy(\.isFinite) else { throw fail("non-finite number") }
        let dug = Set(state.dugCells)
        guard dug.count == state.dugCells.count, dug.allSatisfy({ map.tile(at: $0) == .soil }) else {
            throw fail("dug cell is not soil")
        }
        let walkable = map.initialWalkable.union(dug)
        guard MapDefinition.flood(walkable, from: map.entrance) == walkable else { throw fail("disconnected tunnel") }
        for tap in state.digTaps {
            guard (1..<Rules.tapsPerSoil).contains(tap.taps), map.tile(at: tap.cell) == .soil,
                  !dug.contains(tap.cell), tap.cell.neighbors.contains(where: walkable.contains) else {
                throw fail("bad dig progress")
            }
        }
        guard Set(state.digTaps.map(\.cell)).count == state.digTaps.count else { throw fail("duplicate dig progress") }
        let capacity = Rules.baseStorage + (state.pantryTopLeft == nil ? 0 : Rules.pantryStorage)
        guard state.food >= 0, state.food <= capacity + 1e-9 else { throw fail("food out of range") }
        guard state.ants >= 0, state.larvae.count <= Rules.larvaSlots,
              state.ants + state.larvae.count <= Rules.populationCap else { throw fail("population out of range") }
        guard state.larvae.allSatisfy({ $0 > 0 && $0 <= Rules.hatchSeconds }) else { throw fail("bad egg timer") }
        if let topLeft = state.pantryTopLeft {
            let cells = Colony.pantryCells(topLeft: topLeft)
            guard cells.isSubset(of: walkable), cells.isDisjoint(with: map.queenCells), !cells.contains(map.entrance) else {
                throw fail("illegal Pantry footprint")
            }
        }
        for source in map.sources where source.kind == .patch {
            guard let remaining = state.patchRemaining[source.id], remaining >= 0,
                  remaining <= max(source.initialRemaining ?? 0, source.refillAmount ?? 0) + 1e-9 else {
                throw fail("bad patch remaining")
            }
        }
        guard state.patchRemaining.count == map.sources.filter({ $0.kind == .patch }).count else {
            throw fail("unknown patch")
        }
        guard map.sources.contains(where: { $0.id == state.nextPatchId && $0.kind == .patch }) else {
            throw fail("bad next patch")
        }
        guard state.refillLeft > 0, state.refillLeft <= Rules.refillSeconds + 1e-9 else { throw fail("bad refill timer") }
        guard state.refills >= 0, state.elapsed >= 0, state.hauled >= 0, state.spent >= 0 else {
            throw fail("negative counter")
        }
        let sourceIds = Set(map.sources.filter { $0.kind != .surface }.map(\.id))
        guard Set(state.flags.connectedSources).isSubset(of: sourceIds),
              state.flags.connectedSources == state.flags.connectedSources.sorted(),
              Set(state.flags.connectedSources).count == state.flags.connectedSources.count,
              state.flags.bestRouteGain.isFinite, state.flags.bestRouteGain >= 0 else {
            throw fail("bad goal flags")
        }
        // 资源守恒：搬入 − 支出 = 库存（容差随规模放大）
        guard abs(state.hauled - state.spent - state.food) <= 1e-6 * max(1, state.hauled) else {
            throw fail("food not conserved")
        }
    }
}
