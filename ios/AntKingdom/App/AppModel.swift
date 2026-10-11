import AntKingdomCore
import SwiftUI

/// 应用级状态：读档/离线结算/前后台与自动保存（C06）。所有修改在主 actor 上顺序进行。
@MainActor
final class AppModel: ObservableObject {
    enum Phase {
        case running(GameController)
        /// 主档与备份都不可用：显示 error.save，提供重试与 Start Over（不静默清档）
        case saveUnavailable(SaveError)
    }

    @Published private(set) var phase: Phase
    private var coordinator: LifecycleCoordinator?
    private let store: SaveStore
    private let wallClock: WallClock
    private let appVersion: String
    private var arguments: [String]

    init(arguments: [String] = ProcessInfo.processInfo.arguments) {
        self.arguments = arguments
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        appVersion = "\(version) (\(build))"
        var wall: WallClock = SystemWallClock()
        var store: SaveStore = FileSaveStore(directory: AppModel.saveDirectory)
        #if DEBUG
        let options = LaunchOptions(arguments: arguments)
        if options.resetSave {
            for slot in SaveSlot.allCases { try? store.remove(slot) }
        }
        if options.scenario != nil || options.ephemeral {
            // UI 测试与截图：内存存档，互不污染，也不碰真实存档
            store = MemorySaveStore()
        }
        if let away = options.simulatedAwaySeconds {
            let offsetClock = OffsetWallClock(base: SystemWallClock(), offset: 0)
            AppModel.prepareAwayPreview(store: store, away: away, scenario: options.scenario, clock: offsetClock)
            wall = offsetClock
        }
        #endif
        self.store = store
        self.wallClock = wall
        self.phase = .saveUnavailable(.unreadable("not launched"))
        launch()
    }

    static var saveDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent("AntKingdom", isDirectory: true)
    }

    /// 读档 → 校验 → 一次离线结算 → 立即保存。
    func launch() {
        let (coordinator, result) = LifecycleCoordinator.launch(repository: SaveRepository(store: store, appVersion: appVersion),
                                                                wallClock: wallClock)
        switch result {
        case .ready(let session, let offline, _):
            self.coordinator = coordinator
            #if DEBUG
            if let scenario = LaunchOptions(arguments: arguments).scenario,
               LaunchOptions(arguments: arguments).simulatedAwaySeconds == nil {
                try? scenario.apply(to: session)
                _ = session.drainEvents()
                coordinator?.save()
            }
            #endif
            let controller = GameController(session: session)
            wire(controller)
            if let offline, offline.isWorthShowing { controller.offlineSummary = offline }
            phase = .running(controller)
        case .saveUnavailable(let error):
            self.coordinator = nil
            phase = .saveUnavailable(error)
        }
    }

    /// 存档不可用时玩家确认 Start Over：清除本地存档后开新档。
    func startOverAfterSaveError() {
        for slot in SaveSlot.allCases { try? store.remove(slot) }
        launch()
    }

    private func wire(_ controller: GameController) {
        controller.persist = { [weak self] in self?.coordinator?.save() ?? false }
        controller.resetHandler = { [weak self] in self?.coordinator?.resetColony() }
    }

    func scenePhaseChanged(_ newPhase: ScenePhase) {
        guard let coordinator, case .running(let controller) = phase else { return }
        switch newPhase {
        case .background:
            coordinator.enterBackground()
        case .active:
            if let summary = coordinator.becomeActive(), summary.isWorthShowing {
                controller.offlineSummary = summary
            }
            controller.onResume?()
        default:
            break
        }
    }
}

#if DEBUG
/// 调试：把墙钟整体后移，用于在模拟器里预览离线结算（不改系统时间）。
final class OffsetWallClock: WallClock {
    let base: WallClock
    var offset: Double
    init(base: WallClock, offset: Double) {
        self.base = base
        self.offset = offset
    }
    func now() -> Double { base.now() + offset }
}

extension AppModel {
    /// 先在“过去”保存一份场景存档，再以当前时间启动，从而真实走一遍冷启动离线结算。
    static func prepareAwayPreview(store: SaveStore, away: Double, scenario: DebugScenario?, clock: OffsetWallClock) {
        clock.offset = -away
        let (coordinator, _) = LifecycleCoordinator.launch(repository: SaveRepository(store: store, appVersion: "debug"),
                                                           wallClock: clock)
        if let coordinator, let scenario {
            try? scenario.apply(to: coordinator.session)
            _ = coordinator.session.drainEvents()
            coordinator.save()
        }
        clock.offset = 0
    }
}
#endif
