import AntKingdomCore
import Combine
import SwiftUI

/// 当前选中的地图实体（底部面板显示详情）。
enum Selection: Equatable {
    case source(String)
    case queen
    case pantry
}

/// 短暂提示。文本只来自英文 String Catalog。
struct Toast: Identifiable, Equatable {
    enum Style { case info, success, warning }
    let id = UUID()
    let text: String
    let style: Style
    let identifier: String
}

/// App 与规则层之间唯一的桥：所有状态修改都在主 actor 上排队成 GameCommand。
/// 场景每帧调用 `frame(delta:)`；SwiftUI 以约 10Hz 读取发布的快照，避免每帧重绘 HUD。
@MainActor
final class GameController: ObservableObject {
    let session: GameSession
    private let clock: MonotonicClock
    let haptics: Haptics

    /// SwiftUI 使用的快照（节流发布）
    @Published private(set) var snapshot: SessionSnapshot
    @Published var selection: Selection?
    @Published private(set) var toasts: [Toast] = []
    @Published var showSettings = false
    /// 仅调试/UI 测试：地图变换与已挖格数
    @Published var debugProbe = ""

    /// 场景每帧读取的最新快照（不触发 SwiftUI 刷新）
    private(set) var latest: SessionSnapshot
    /// 场景订阅：路线高亮等一次性视觉反馈
    var onRoutePulse: (() -> Void)?
    var onRejectedTap: ((GridPoint) -> Void)?
    var onReset: (() -> Void)?

    private var tapLimiter = TapRateLimiter()
    private var hold: (cell: GridPoint, start: Double, applied: Int)?
    private var lastPublish = -Double.infinity

    init(session: GameSession, clock: MonotonicClock = SystemMonotonicClock()) {
        self.session = session
        self.clock = clock
        self.haptics = Haptics()
        let first = session.snapshot()
        self.snapshot = first
        self.latest = first
    }

    // MARK: 每帧

    func frame(delta: Double) {
        session.tick(frameDelta: delta)
        advanceHold()
        handle(session.drainEvents())
        latest = session.snapshot()
        let now = clock.uptime()
        if now - lastPublish >= 0.1 || discreteChange(latest, snapshot) {
            publish(now: now)
        }
    }

    private func publish(now: Double) {
        snapshot = latest
        lastPublish = now
    }

    private func discreteChange(_ a: SessionSnapshot, _ b: SessionSnapshot) -> Bool {
        a.ants != b.ants || a.eggs.count != b.eggs.count || a.pantryCells != b.pantryCells
            || a.activeSourceId != b.activeSourceId || a.isStorageFull != b.isStorageFull
            || a.hatching != b.hatching || a.walkable.count != b.walkable.count || a.settings != b.settings
    }

    /// 立即刷新（命令执行后），让面板与场景同帧反映结果。
    private func refresh() {
        handle(session.drainEvents())
        latest = session.snapshot()
        publish(now: clock.uptime())
    }

    // MARK: 命令

    @discardableResult
    func send(_ command: GameCommand) -> CommandResult {
        let result = session.apply(command)
        refresh()
        return result
    }

    /// 地图单击：可挖前沿→挖一下；实体→选中；其他→取消选中。
    func tapCell(_ cell: GridPoint) {
        if latest.frontier.contains(cell) {
            selection = nil
            guard tapLimiter.acceptManualTap(at: clock.uptime()) else { return }
            dig(cell)
            return
        }
        if let entity = entity(at: cell) {
            selection = (selection == entity) ? nil : entity
            haptics.selection(enabled: latest.settings.haptics)
            return
        }
        if session.map.tile(at: cell) == .soil, !latest.walkable.contains(cell) {
            onRejectedTap?(cell)
            haptics.rejected(enabled: latest.settings.haptics)
        }
        selection = nil
    }

    private func dig(_ cell: GridPoint) {
        let result = send(.tapSoil(cell))
        switch result {
        case .tapAccepted: haptics.dig(enabled: latest.settings.haptics)
        case .cellOpened: haptics.cellOpened(enabled: latest.settings.haptics)
        case .rejected:
            onRejectedTap?(cell)
            haptics.rejected(enabled: latest.settings.haptics)
        default: break
        }
    }

    func entity(at cell: GridPoint) -> Selection? {
        if latest.pantryCells.contains(cell) { return .pantry }
        if session.map.queenCells.contains(cell) { return .queen }
        if let source = latest.sources.first(where: { $0.kind != .surface && $0.cells.contains(cell) }) {
            return .source(source.id)
        }
        if cell == session.map.entrance { return .source("surface") }
        return nil
    }

    /// 长按挖掘：按下即一次，之后每秒 5 次（PRD 2.2），直到松手或该格打通。
    func holdBegan(_ cell: GridPoint) {
        guard latest.frontier.contains(cell) else { return }
        selection = nil
        hold = (cell, clock.uptime(), 0)
        advanceHold()
    }

    func holdEnded() {
        hold = nil
    }

    private func advanceHold() {
        guard var current = hold else { return }
        let due = TapRateLimiter.holdTaps(from: current.start, to: clock.uptime())
        while current.applied < due {
            current.applied += 1
            let result = session.apply(.tapSoil(current.cell))
            if case .cellOpened = result {
                haptics.cellOpened(enabled: latest.settings.haptics)
                hold = nil
                refresh()
                return
            }
            if result.isRejected {
                hold = nil
                return
            }
            haptics.dig(enabled: latest.settings.haptics)
        }
        hold = current
    }

    func toggleHatching() {
        send(.setHatching(!latest.hatching))
    }

    /// 设置里的 Start Over（UI 已二次确认）。设置项保留。
    func resetColony() {
        selection = nil
        hold = nil
        send(.reset)
        onReset?()
    }

    // MARK: 事件 → 反馈

    private func handle(_ events: [GameEvent]) {
        for event in events {
            switch event {
            case .sourceConnected:
                show("feedback.connected", style: .success)
                haptics.success(enabled: latest.settings.haptics)
                onRoutePulse?()
            case .routeImproved(_, let percent):
                show("feedback.route_better", ["percent": Format.oneDecimal(percent)], style: .success)
                onRoutePulse?()
            case .foodArrived:
                show("event.food_arrived", style: .info)
            case .storageFullChanged(true):
                show("state.storage_full", style: .warning)
            case .prototypeComplete:
                show("goal.prototype_complete", style: .success, duration: 6)
            default:
                break
            }
        }
    }

    func show(_ key: String, _ arguments: [String: String] = [:], style: Toast.Style, duration: Double = 2.6) {
        let toast = Toast(text: L10n.text(key, arguments), style: style, identifier: key)
        toasts.append(toast)
        if toasts.count > 3 { toasts.removeFirst(toasts.count - 3) }
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            self?.toasts.removeAll { $0.id == toast.id }
        }
    }
}
