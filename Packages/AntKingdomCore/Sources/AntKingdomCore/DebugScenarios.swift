/// 调试场景：把会话快速带到某个可观察状态，用于 Debug 构建入口、截图证据与 UI 测试。
/// 只经过公开命令或经校验的状态替换，不绕过守恒检查；正式构建不暴露入口（App 侧 #if DEBUG）。
public enum DebugScenario: String, CaseIterable, Sendable {
    /// 新档
    case fresh
    /// 已挖通 Cookie Crumb
    case connected
    /// 接通后 20 只蚂蚁挤在一条通道上（显示繁忙格与旁路提示）
    case busy
    /// 接通、留出 2×2 空间且余额 60 Food，可直接建仓
    case pantryReady = "pantry_ready"
    /// Pantry 建在离源较远的 (1,2)，另有 (1,4) 可移入：用于移动与“真实改善”反馈
    case pantryBuilt = "pantry_built"
    /// 按 PRD 6.2 固定操作推进到 300 秒
    case replay300
    /// 按 PRD 6.2 固定操作推进到 600 秒（人口与容量上限）
    case replay600

    public func apply(to session: GameSession) throws {
        session.apply(.reset)
        switch self {
        case .fresh:
            break
        case .connected:
            connect(session)
        case .busy:
            connect(session)
            try session.debugReplaceState { state in
                state.ants = 20
                state.hatching = false
            }
        case .pantryReady:
            connect(session)
            for p in [GridPoint(1, 4), GridPoint(1, 5)] { session.apply(.debugCompleteCell(p)) }
            try session.debugReplaceState { state in
                state.food = 60
                state.hauled = 60
                state.spent = 0
                state.hatching = false
            }
        case .pantryBuilt:
            connect(session)
            for p in [(1, 4), (1, 5), (2, 3), (1, 3), (2, 2), (1, 2)] {
                session.apply(.debugCompleteCell(GridPoint(p.0, p.1)))
            }
            try session.debugReplaceState { state in
                state.food = 80
                state.hauled = 80
                state.spent = 0
                state.hatching = false
            }
            session.apply(.buildPantry(topLeft: GridPoint(1, 2)))
        case .replay300:
            try replay(session, until: 300)
        case .replay600:
            try replay(session, until: 600)
        }
    }

    private func connect(_ session: GameSession) {
        for p in ScriptedReplay.actions[30] ?? [] { session.apply(.debugCompleteCell(p)) }
    }

    /// 与 ScriptedReplay 相同的动作时刻，但经由会话的 0.25 秒量子推进。
    private func replay(_ session: GameSession, until seconds: Int) throws {
        for second in 0..<seconds {
            for p in ScriptedReplay.actions[second] ?? [] { session.apply(.debugCompleteCell(p)) }
            if second >= ScriptedReplay.pantryFromSecond, session.colony.pantry.isEmpty,
               session.colony.food >= Rules.pantryCost {
                session.apply(.buildPantry(topLeft: ScriptedReplay.pantryTopLeft))
            }
            for _ in 0..<4 { session.tick(frameDelta: Rules.tick) }
        }
        _ = session.drainEvents()
    }
}

extension GameSession {
    /// 调试：在可序列化状态上做修改，再经完整校验后替换会话内部状态。校验失败则不改变任何东西。
    public func debugReplaceState(_ transform: (inout GameState) -> Void) throws {
        var state = makeState()
        transform(&state)
        let replacement = try GameSession(state: state, map: map)
        colony = replacement.colony
        digTaps = replacement.digTaps
        settings = replacement.settings
        flags = replacement.flags
        accumulator = replacement.accumulator
    }
}
