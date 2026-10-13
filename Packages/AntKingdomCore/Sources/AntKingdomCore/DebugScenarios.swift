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
    /// A01-02 截图：按可挖前沿顺序挖开 16 格，让通路网同时出现四邻遮罩 1–15（直道、转角、三岔、四向、尽头）。
    /// 遮罩 0（四邻都不通）在游戏中不会出现——每个挖开的格都与已有通路相连
    case tunnelGallery = "tunnel_gallery"
    /// A01 美术录屏：Cookie 接通、只剩 15 Food（约 9 秒搬完），Sugar 已空，轮到 Cookie；两块都空后 6 秒补给 →
    /// 约 20 秒内看到 Cookie 有货 → 耗尽 → 补给（Sugar 保持耗尽图）。原先 4 Food 在录像首个可见帧之前就搬完了
    case sourceCycleCookie = "source_cycle_cookie"
    /// 同上，接通 Sugar（挖开 (5,1)(6,1)(7,1)）、只剩 8 Food（约 6 秒搬完），轮到 Sugar：Sugar 有货 → 耗尽 → 补给
    case sourceCycleSugar = "source_cycle_sugar"
    /// A01-02 美术截图：Queen 房间 1 颗 / 2 颗卵（孵化暂停，卵保持可见）
    case eggsOne = "eggs_one"
    case eggsTwo = "eggs_two"
    /// D-16 E02：两枚卵（槽 0 剩 15 秒、槽 1 剩 25 秒），孵化订单开启、Food 足够。左卵先孵化后新订单占空出的左槽，
    /// 右卵留在原槽继续倒计时（15 秒留给 UI 测试启动后先读到两枚卵）
    case eggsRefill = "eggs_refill"
    /// A02-T03：Cookie 到 Queen 唯一的一条蜿蜒通路，带货的一程依次朝南、东、东、北、东、东、北、北、西，
    /// 用来检查货物在四个方向都在嘴前、随身体转向（孵化订单关闭，人口固定 5）
    case antFourWay = "ant_four_way"

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
        case .tunnelGallery:
            for p in DebugScenario.tunnelGalleryCells { session.apply(.debugCompleteCell(p)) }
            try session.debugReplaceState { $0.hatching = false }
        case .sourceCycleCookie:
            connect(session)
            try session.debugReplaceState { state in
                state.patchRemaining["cookie"] = 15   // 约 9 秒耗尽：录像里能看到有货（4 Food 在首个可见帧前就搬完）
                state.patchRemaining["sugar"] = 0
                state.refillLeft = 6
                state.nextPatchId = "cookie"
                state.hatching = false
            }
        case .sourceCycleSugar:
            for p in [GridPoint(5, 1), GridPoint(6, 1), GridPoint(7, 1)] { session.apply(.debugCompleteCell(p)) }
            try session.debugReplaceState { state in
                state.patchRemaining["cookie"] = 0
                state.patchRemaining["sugar"] = 8
                state.refillLeft = 6
                state.nextPatchId = "sugar"
                state.hatching = false
            }
        case .antFourWay:
            // 从 Queen 东南角一路挖到 Cookie 东侧：每一格都与上一格相邻，没有捷径（(3,7) 不挖，南向的凹段绕不过去）
            for p in DebugScenario.antFourWayCells { session.apply(.debugCompleteCell(p)) }
            try session.debugReplaceState { $0.hatching = false }
        case .eggsRefill:
            connect(session)
            try session.debugReplaceState { state in
                state.larvae = [15, 25]
                state.eggSlots = [0, 1]
                state.hauled += 40 - state.food
                state.food = 40
                state.hatching = true
            }
        case .eggsOne, .eggsTwo:
            connect(session)
            let eggs: [Double] = self == .eggsOne ? [20] : [20, 25]
            try session.debugReplaceState { state in
                state.larvae = eggs
                state.hatching = false
            }
        }
    }

    /// ant_four_way 的挖开顺序（从 Queen 出发，每一步都是可挖前沿）
    public static let antFourWayCells = [
        GridPoint(5, 5), GridPoint(6, 5), GridPoint(6, 6), GridPoint(6, 7), GridPoint(5, 7),
        GridPoint(4, 7), GridPoint(4, 8), GridPoint(3, 8), GridPoint(2, 8), GridPoint(2, 7),
    ]

    /// 挖开顺序（每一步都是可挖前沿）
    public static let tunnelGalleryCells = [(3, 5), (2, 3), (5, 1), (5, 5), (2, 5), (3, 6), (6, 1), (6, 3), (3, 2), (3, 1),
                                            (1, 5), (6, 2), (2, 6), (4, 6), (1, 4), (6, 4)].map { GridPoint($0.0, $0.1) }

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
