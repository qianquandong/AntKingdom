/// 一局游戏的唯一修改入口：命令校验、三次点击挖掘、0.25 秒量子推进、逻辑事件与 UI 快照。
/// 经济规则全部委托给 `Colony`（Python 基准的逐行移植）；本类型只增加客户端交互状态。
/// 非线程安全：由 App 的单一执行上下文（主 actor）顺序调用。
public final class GameSession {
    public internal(set) var colony: Colony
    public let map: MapDefinition
    public internal(set) var digTaps: [GridPoint: Int] = [:]
    public internal(set) var settings: GameState.Settings
    public internal(set) var flags = GameState.Flags()
    public internal(set) var accumulator = TickAccumulator()
    private var pendingEvents: [GameEvent] = []

    public init(map: MapDefinition = .backyard, settings: GameState.Settings = .init()) {
        self.map = map
        self.colony = Colony(map: map)
        self.settings = settings
    }

    // MARK: 命令

    @discardableResult
    public func apply(_ command: GameCommand) -> CommandResult {
        switch command {
        case .tapSoil(let p):
            return tap(p)
        case .debugCompleteCell(let p):
            guard map.tile(at: p) == .soil, !colony.walkable.contains(p) else { return .rejected(.notSoil) }
            guard colony.isFrontier(p) else { return .rejected(.notFrontier) }
            openCell(p)
            return .cellOpened(p)
        case .buildPantry(let topLeft):
            guard colony.pantry.isEmpty else { return .rejected(.pantryAlreadyBuilt) }
            return placePantry(topLeft, building: true)
        case .movePantry(let topLeft):
            guard !colony.pantry.isEmpty else { return .rejected(.noPantryToMove) }
            return placePantry(topLeft, building: false)
        case .setHatching(let enabled):
            colony.setHatching(enabled)
            return .hatchingChanged(enabled)
        case .setSound(let enabled):
            settings.sound = enabled
            return .settingsChanged
        case .setHaptics(let enabled):
            settings.haptics = enabled
            return .settingsChanged
        case .reset:
            colony = Colony(map: map)
            digTaps = [:]
            flags = GameState.Flags()
            accumulator = TickAccumulator()
            pendingEvents = []
            return .didReset
        }
    }

    private func tap(_ p: GridPoint) -> CommandResult {
        guard map.tile(at: p) == .soil, !colony.walkable.contains(p) else { return .rejected(.notSoil) }
        guard colony.isFrontier(p) else { return .rejected(.notFrontier) }
        let taps = (digTaps[p] ?? 0) + 1
        if taps >= Rules.tapsPerSoil {
            openCell(p)
            return .cellOpened(p)
        }
        digTaps[p] = taps
        return .tapAccepted(p, taps: taps)
    }

    /// 一次完成一格：更新通路，只在此刻重新规划，不逐帧重算。
    private func openCell(_ p: GridPoint) {
        digTaps[p] = nil
        let before = layoutProbe()
        try? colony.dig(p)    // 调用方已校验，不会失败
        emit(.cellOpened(p))
        compareLayout(before)
    }

    private func placePantry(_ topLeft: GridPoint, building: Bool) -> CommandResult {
        guard colony.isValidPantryFootprint(topLeft: topLeft) else { return .rejected(.invalidPantrySpace) }
        if building, colony.food < Rules.pantryCost { return .rejected(.notEnoughFood) }
        let before = layoutProbe()
        do {
            try colony.placePantry(topLeft: topLeft)
        } catch ColonyError.notEnoughFood {
            return .rejected(.notEnoughFood)
        } catch {
            return .rejected(.invalidPantrySpace)
        }
        if building {
            flags.pantryBuiltOnce = true
            emit(.pantryBuilt)
            emitStorageChange(wasFull: before.storageFull)
        } else {
            flags.pantryMovedOnce = true
            emit(.pantryMoved)
        }
        compareLayout(before)
        return building ? .pantryBuilt(topLeft: topLeft) : .pantryMoved(topLeft: topLeft)
    }

    // MARK: 布局反馈

    private struct LayoutProbe {
        let source: String?
        let rate: Double
        let connected: Set<String>
        let storageFull: Bool
    }

    private func connectedSources() -> Set<String> {
        Set(colony.sources.filter { $0.definition.kind != .surface && colony.isConnected($0) }.map(\.id))
    }

    private func layoutProbe() -> LayoutProbe {
        LayoutProbe(source: colony.activeSourceId, rate: (try? colony.plan().rate) ?? 0,
                    connected: connectedSources(), storageFull: colony.isStorageFull)
    }

    /// 只在冻结人口与源之后预计产量确实增加时报告改善；新源接通只算探索。
    private func compareLayout(_ before: LayoutProbe) {
        let connected = connectedSources()
        for id in connected.subtracting(before.connected).sorted() {
            emit(.sourceConnected(id))
            flags.firstSourceConnected = true
        }
        let source = colony.activeSourceId
        if source != before.source {
            let reason: SourceChangeReason = connected.contains(source ?? "") && !before.connected.contains(source ?? "")
                ? .connected : .layout
            emit(.activeSourceChanged(from: before.source, to: source, reason: reason))
            return
        }
        guard let id = source, before.rate > 0, let after = try? colony.plan().rate else { return }
        let percent = (after / before.rate - 1) * 100
        // 显示保留一位小数；低于 0.05% 会显示成 +0.0%，不报告。
        if percent >= 0.05 { emit(.routeImproved(sourceId: id, percent: percent)) }
    }

    // MARK: 时间推进

    /// 前台每帧调用；内部按 0.25 秒量子推进，帧率不影响经济结果。
    public func tick(frameDelta: Double) {
        let quanta = accumulator.add(frameDelta)
        for _ in 0..<quanta { stepQuantum(Rules.tick, efficiency: 1) }
    }

    /// 推进一个逻辑量子并发出事件。
    func stepQuantum(_ seconds: Double, efficiency: Double) {
        let source = colony.activeSourceId
        let refills = colony.refills
        let refillingIndex = colony.nextPatch
        let ants = colony.ants
        let wasFull = colony.isStorageFull
        let sourceWasEmpty = colony.sources.first { $0.id == source }.map { ($0.remaining ?? 1) <= Rules.epsilon } ?? false
        do {
            try colony.advance(seconds, efficiency: efficiency)
        } catch {
            assertionFailure("advance failed: \(error)")
            return
        }
        if colony.refills > refills { emit(.foodArrived(colony.sources[refillingIndex].id)) }
        if colony.ants > ants { emit(.antsHatched(colony.ants - ants)) }
        emitStorageChange(wasFull: wasFull)
        let now = colony.activeSourceId
        if now != source {
            let depleted = colony.sources.first { $0.id == source }.map { ($0.remaining ?? 1) <= Rules.epsilon } ?? false
            let reason: SourceChangeReason = colony.refills > refills ? .refilled
                : (depleted && !sourceWasEmpty ? .depleted : .layout)
            emit(.activeSourceChanged(from: source, to: now, reason: reason))
        }
        checkPrototypeComplete()
    }

    private func emitStorageChange(wasFull: Bool) {
        let full = colony.isStorageFull
        if full != wasFull { emit(.storageFullChanged(full)) }
    }

    /// 验证版终点：24 只成年、无卵、已建 Pantry、库存达到 1100 上限。只提示一次。
    private func checkPrototypeComplete() {
        guard !flags.prototypeComplete, colony.ants >= Rules.populationCap, colony.larvae.isEmpty,
              !colony.pantry.isEmpty, colony.isStorageFull else { return }
        flags.prototypeComplete = true
        emit(.prototypeComplete)
    }

    /// 离线结算：同一状态机，运输 ×0.25，时长已由调用方钳制到 [0, 3600]。
    @discardableResult
    public func settleOffline(seconds: Double) throws -> OfflineResult {
        let wasFull = colony.isStorageFull
        let ants = colony.ants
        let result = try colony.offline(seconds)
        if colony.ants > ants { emit(.antsHatched(colony.ants - ants)) }
        emitStorageChange(wasFull: wasFull)
        checkPrototypeComplete()
        return result
    }

    // MARK: 事件

    private func emit(_ event: GameEvent) {
        pendingEvents.append(event)
    }

    /// 表现层每帧取走事件；事件只用于反馈，不改变状态。
    public func drainEvents() -> [GameEvent] {
        defer { pendingEvents.removeAll() }
        return pendingEvents
    }
}
