import AntKingdomCore
import Combine
import SwiftUI
import UIKit

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
    /// 声音与触觉（按设置过滤）
    let feedback = FeedbackPlayer()
    /// Debug 启动参数 -ak-reduce-motion 强制“减少动态”，便于模拟器测试
    var forceReduceMotion = false
    /// 减少动态：系统设置或调试强制；场景与提示据此去掉位移/抖动类动画
    var reduceMotion: Bool { forceReduceMotion || UIAccessibility.isReduceMotionEnabled }

    /// SwiftUI 使用的快照（节流发布）
    @Published private(set) var snapshot: SessionSnapshot
    @Published var selection: Selection?
    @Published private(set) var toasts: [Toast] = []
    /// 面板显示状态（设置、离线总结）单独发布：sheet 挂在只观察它的视图上，不随 10Hz 快照重绘。
    /// 否则 iOS 18 上设置页的分段控件会在点击过程中被重设回旧值（D-06，CI 小屏 iOS 18.5 录像）。
    let presentation = PresentationState()
    var showSettings: Bool {
        get { presentation.showSettings }
        set { presentation.showSettings = newValue }
    }
    /// Pantry 建造/移动摆放模式（摆放时不挖土）
    @Published var placement: PantryPlacement?
    /// 回到前台/冷启动时的离线结果（PRD 5.3）
    var offlineSummary: OfflineSummary? {
        get { presentation.offlineSummary }
        set { presentation.offlineSummary = newValue }
    }

    /// 持久化钩子（AppModel 注入）：返回是否保存成功
    var persist: (() -> Bool)?
    /// Start Over：由生命周期协调器清档并重存；未注入时退回只重置会话
    var resetHandler: (() -> Void)?
    /// 回到前台：场景丢弃暂停期间的帧间隔，后台时长只由离线结算处理
    var onResume: (() -> Void)?
    /// 每帧推进之前的生命周期准入（D-13，AppModel / CampaignModel 注入）：离开区间未结算时不推进、不保存
    var admitFrame: (() -> ForegroundFrame)?
    #if DEBUG
    /// 仅调试：生命周期环形日志（UI 测试从隐藏元素 debug.lifecycle 读取）
    var lifecycleTrace: LifecycleTrace?
    @Published var debugLifecycle = ""
    private var traceSeen = -1
    #endif
    /// 正式版（发行轨）钩子：每批会话事件处理之后调用（章节目标与完成页）。核心版为 nil。
    var afterEvents: (() -> Void)?
    /// 正式版：HUD 显示章节入口并调用它。核心版为 nil，不显示入口。
    var openChapters: (() -> Void)?
    /// 正式版：首次建仓后 HUD 显示外观入口（RELEASE_SCOPE 第 2 章）。核心版为 nil。
    var openShop: (() -> Void)?
    /// 正式版：设置里的 Restore Purchases。核心版为 nil，不显示。
    var restorePurchases: (() -> Void)?
    /// 房间外观（只影响 Queen Chamber 与 Pantry 的绘制；经济不读取）。核心版恒为默认。
    var roomStyle: RoomStyle = .standard
    /// 正式版：HUD 显示奖励广告入口（可领取/生效/冷却/当日已满时）。核心版为 nil。
    var openReward: (() -> Void)?
    /// 正式版：设置里的 Privacy Choices（UMP 要求时显示）。核心版为 nil。
    var privacyChoices: (() -> Void)?
    /// 全屏广告展示期间暂停前台步进（RELEASE_SCOPE 第 3 章）；场景仍刷新，不累积补算时间。
    var isSuspended = false
    /// 核心版用提示条宣布“原型完成”；正式版改由章节完成页宣布（RELEASE_SCOPE 第 6 节）。
    var announcesPrototypeComplete = true
    /// 设置页重置按钮与二次确认的文案 ID：核心版重置本局；正式版重置全部本地进度。
    var resetTitleKey = "action.reset"
    var resetDialogKey = "dialog.reset"
    private var dirty = false
    private var lastSave = -Double.infinity
    private var saveFailureShown = false
    private static let autosaveInterval = 30.0
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
        let first = session.snapshot()
        self.snapshot = first
        self.latest = first
    }

    // MARK: 每帧

    func frame(delta: Double) {
        switch admitFrame?() ?? .run {
        case .hold:
            return                    // 后台区间尚未结算（恢复首帧早于 .active）：不推进、不保存（D-13）
        case .resumed(let summary):
            // 帧停顿超过阈值且没有后台记录：生命周期已按离线结算；丢弃本帧间隔
            if let summary, summary.isWorthShowing { offlineSummary = summary }
            onResume?()
            refresh()
            return
        case .run:
            break
        }
        // 全屏广告展示期间不推进（RELEASE_SCOPE 第 3 章）；准入照常调用，生命周期的前台帧时钟保持更新
        guard !isSuspended else { return }
        session.tick(frameDelta: delta)
        advanceHold()
        handle(session.drainEvents())
        afterEvents?()
        latest = session.snapshot()
        let now = clock.uptime()
        if now - lastSave >= GameController.autosaveInterval || (dirty && now - lastSave >= 1) {
            saveNow()
        }
        if now - lastPublish >= 0.1 || discreteChange(latest, snapshot) {
            publish(now: now)
        }
    }

    #if DEBUG
    /// 生命周期日志有新行时刷新隐藏元素（不按帧拼字符串）
    func refreshDebugLifecycle() {
        guard let trace = lifecycleTrace, trace.sequence != traceSeen else { return }
        traceSeen = trace.sequence
        debugLifecycle = trace.tail(24)
    }
    #endif

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
    func refresh() {
        handle(session.drainEvents())
        afterEvents?()
        latest = session.snapshot()
        publish(now: clock.uptime())
    }

    // MARK: 命令

    @discardableResult
    func send(_ command: GameCommand) -> CommandResult {
        let result = session.apply(command)
        refresh()
        switch result {
        case .rejected:
            break
        case .tapAccepted:
            dirty = true          // 未完成格的点击数也要保存，但节流到每秒最多一次
        default:
            saveNow()             // 开格、建仓、移仓、孵化开关、设置：关键操作后立即原子保存
        }
        return result
    }

    /// 立即保存；失败时提示一次英文错误（不阻断游戏）。
    func saveNow() {
        guard let persist else { return }
        lastSave = clock.uptime()
        dirty = false
        if persist() {
            saveFailureShown = false
        } else if !saveFailureShown {
            saveFailureShown = true
            show("error.save", style: .warning, duration: 4)
        }
    }

    /// 地图单击：可挖前沿→挖一下；实体→选中；其他→取消选中。
    func tapCell(_ cell: GridPoint) {
        if placement != nil {
            movePlacement(to: cell)
            return
        }
        if latest.frontier.contains(cell) {
            selection = nil
            guard tapLimiter.acceptManualTap(at: clock.uptime()) else { return }
            dig(cell)
            return
        }
        if let entity = entity(at: cell) {
            selection = (selection == entity) ? nil : entity
            feedback.play(.select, settings: latest.settings)
            return
        }
        if session.map.tile(at: cell) == .soil, !latest.walkable.contains(cell) {
            onRejectedTap?(cell)
            feedback.play(.rejected, settings: latest.settings)
        }
        selection = nil
    }

    private func dig(_ cell: GridPoint) {
        let result = send(.tapSoil(cell))
        switch result {
        case .tapAccepted: feedback.play(.dig, settings: latest.settings)
        case .cellOpened: feedback.play(.tunnelOpen, settings: latest.settings)
        case .rejected:
            onRejectedTap?(cell)
            feedback.play(.rejected, settings: latest.settings)
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
        guard placement == nil, latest.frontier.contains(cell) else { return }
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
                feedback.play(.tunnelOpen, settings: latest.settings)
                hold = nil
                refresh()
                saveNow()
                return
            }
            dirty = true
            if result.isRejected {
                hold = nil
                return
            }
            feedback.play(.dig, settings: latest.settings)
        }
        hold = current
    }

    func toggleHatching() {
        send(.setHatching(!latest.hatching))
    }

    /// 设置里的 Start Over（UI 已二次确认）。设置项保留。
    func resetColony() {
        performReset { [self] in
            if let resetHandler { resetHandler() } else { send(.reset) }
        }
    }

    /// 在会话外部完成重置（例如正式版“重玩本章”）后，清掉交互状态并立即刷新场景与面板。
    func performReset(_ action: () -> Void) {
        selection = nil
        placement = nil
        hold = nil
        action()
        refresh()
        onReset?()
    }

    // MARK: 事件 → 反馈

    private func handle(_ events: [GameEvent]) {
        for event in events {
            switch event {
            case .sourceConnected:
                show("feedback.connected", style: .success)
                feedback.play(.connected, settings: latest.settings)
                onRoutePulse?()
            case .routeImproved(_, let percent):
                show("feedback.route_better", ["percent": Format.oneDecimal(percent)], style: .success)
                onRoutePulse?()
            case .foodArrived:
                show("event.food_arrived", style: .info)
                feedback.play(.refill, settings: latest.settings)
            case .pantryBuilt:
                feedback.play(.build, settings: latest.settings)
            case .pantryMoved:
                feedback.play(.move, settings: latest.settings)
            case .antsHatched:
                feedback.play(.hatch, settings: latest.settings)
            case .storageFullChanged(true):
                show("state.storage_full", style: .warning)
            case .prototypeComplete:
                if announcesPrototypeComplete { show("goal.prototype_complete", style: .success, duration: 6) }
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
