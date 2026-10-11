/// 首局英文引导（PRD 2.1）。只根据当前状态与进度标记决定显示哪条提示，
/// 时间只是观察目标而不是脚本：不同玩家触发顺序可以不同，引导不会替玩家挖格或建仓。
public enum TutorialHint: String, Equatable, Sendable {
    case dig = "tutorial.dig"
    case hatching = "tutorial.hatching"
    case saveFood = "tutorial.save_food"
    case pantry = "tutorial.pantry"
    case move = "tutorial.move"
    case bypass = "tutorial.bypass"
    case complete = "goal.prototype_complete"

    /// 文案 ID（PRD 附录 A）
    public var stringID: String { rawValue }
}

public enum TutorialGuide {
    /// 当前应显示的提示；nil 表示不打扰玩家。
    public static func hint(for snapshot: SessionSnapshot) -> TutorialHint? {
        let flags = snapshot.flags
        if flags.prototypeComplete { return .complete }
        if !flags.firstSourceConnected { return .dig }
        // 繁忙是条件提示：出现繁忙格时优先引导挖旁路（不强制每局都出现拥堵）
        if !snapshot.busyCells.isEmpty { return .bypass }
        if !flags.pantryBuiltOnce {
            if snapshot.ants == Rules.initialAnts { return .hatching }
            if snapshot.hatching && snapshot.food < Rules.pantryCost { return .saveFood }
            return .pantry
        }
        if !flags.pantryMovedOnce { return .move }
        return nil
    }

    /// 建仓提示时，给出一个当前合法的 2×2 左上角（离当前源装货口最近）；没有则 nil。
    public static func suggestedPantrySpot(in session: GameSession) -> GridPoint? {
        let colony = session.colony
        let candidates = colony.walkable.sortedByKey().filter { colony.isValidPantryFootprint(topLeft: $0) }
        guard !candidates.isEmpty else { return nil }
        let target: GridPoint = {
            if let id = colony.activeSourceId, let source = colony.sources.first(where: { $0.id == id }),
               let loading = colony.loadingCells(for: source).sortedByKey().first {
                return loading
            }
            return session.map.entrance
        }()
        return candidates.min { a, b in
            let da = abs(a.x - target.x) + abs(a.y - target.y)
            let db = abs(b.x - target.x) + abs(b.y - target.y)
            return da != db ? da < db : GridPoint.keyLess(a, b)
        }
    }
}
