import AntKingdomCore
import SwiftUI

/// 章节完成页要显示的内容（每局宣布一次）。
struct ChapterCompletion: Identifiable, Equatable {
    let chapterId: String
    let next: String?
    var id: String { chapterId }
}

/// 发行轨的面板状态：章节页与完成卡片。和 10Hz 的游戏快照分开发布（同 D-06）。
@MainActor
final class CampaignSheets: ObservableObject {
    @Published var showChapters = false
    @Published var completion: ChapterCompletion?
}

/// 发行轨（C10）应用状态：章节目录 + CampaignCoordinator + 当前章节的 GameController。
/// 切换章节、全部重置会换新的会话，因此换新的 GameController；重玩本章沿用同一会话。
@MainActor
final class CampaignModel: ObservableObject {
    enum Phase {
        case running(GameController)
        /// 当前章节主档与备份都不可用：只提供重开该章（二次确认），不动其他章节
        case chapterSaveUnavailable(String)
        /// 全局进度来自更新版本：不降级、不覆盖
        case progressUnavailable
        /// 内置章节数据损坏（构建错误）：显示存档错误文案与重试
        case catalogUnavailable
    }

    @Published private(set) var phase: Phase = .catalogUnavailable
    let sheets = CampaignSheets()
    private(set) var campaign: CampaignCoordinator?
    let catalog: ChapterCatalog?
    private let store: SaveStore
    private let wallClock: WallClock
    private let appVersion: String
    private let arguments: [String]

    init(arguments: [String] = ProcessInfo.processInfo.arguments) {
        self.arguments = arguments
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        appVersion = "\(version) (\(build))"
        var store: SaveStore = FileSaveStore(directory: AppModel.saveDirectory)
        var fixture = false
        #if DEBUG
        let options = LaunchOptions(arguments: arguments)
        fixture = options.fixtureChapters
        if options.resetSave, let files = try? FileManager.default.contentsOfDirectory(
            at: AppModel.saveDirectory, includingPropertiesForKeys: nil) {
            for file in files where file.pathExtension == "json" { try? FileManager.default.removeItem(at: file) }
        }
        if options.scenario != nil || options.ephemeral {
            // UI 测试与截图：内存存档，互不污染，也不碰真实存档
            store = MemorySaveStore()
        }
        #endif
        self.store = store
        self.wallClock = SystemWallClock()
        self.catalog = try? CampaignModel.loadCatalog(fixture: fixture)
        launch()
    }

    /// 从 bundle 的 chapters.json 与地图文件载入目录；只收入已交付地图的章节。
    static func loadCatalog(bundle: Bundle = .main, fixture: Bool = false) throws -> ChapterCatalog {
        guard let url = bundle.url(forResource: "chapters", withExtension: "json") else {
            throw CocoaError(.fileNoSuchFile)
        }
        let manifest = try JSONDecoder().decode(ChapterManifest.self, from: Data(contentsOf: url))
        let catalog = try ChapterCatalog(manifest: manifest) { file in
            let name = (file as NSString).deletingPathExtension
            let ext = (file as NSString).pathExtension
            guard let mapURL = bundle.url(forResource: name, withExtension: ext) else {
                throw CocoaError(.fileNoSuchFile)
            }
            return try String(contentsOf: mapURL, encoding: .utf8)
        }
        #if DEBUG
        if fixture { return try ChapterCatalog(chapters: catalog.chapters + [try DebugFixtureChapter.make()]) }
        #endif
        return catalog
    }

    /// 读全局进度与当前章节 → 一次离线结算 → 当前章节的控制器。
    func launch() {
        guard let catalog else {
            phase = .catalogUnavailable
            return
        }
        let (campaign, result) = CampaignCoordinator.launch(store: store, appVersion: appVersion,
                                                            wallClock: wallClock, catalog: catalog)
        switch result {
        case .ready(let offline, _, _):
            guard let campaign else { return }
            self.campaign = campaign
            #if DEBUG
            if let scenario = LaunchOptions(arguments: arguments).scenario {
                try? scenario.apply(to: campaign.session)
                _ = campaign.session.drainEvents()
                campaign.lifecycle.save()
            }
            #endif
            let controller = makeController()
            if let offline, offline.isWorthShowing { controller.offlineSummary = offline }
            phase = .running(controller)
        case .chapterSaveUnavailable(let chapterId, _):
            self.campaign = nil
            phase = .chapterSaveUnavailable(chapterId)
        case .progressUnavailable:
            self.campaign = nil
            phase = .progressUnavailable
        }
    }

    private func makeController() -> GameController {
        guard let campaign else { fatalError("controller without campaign") }
        let controller = GameController(session: campaign.session)
        controller.announcesPrototypeComplete = false
        controller.resetTitleKey = "settings.reset_all"
        controller.resetDialogKey = "dialog.reset_all"
        controller.persist = { [weak self] in self?.campaign?.lifecycle.save() ?? false }
        controller.resetHandler = { [weak self] in self?.resetAllProgress() }
        controller.openChapters = { [weak self] in self?.sheets.showChapters = true }
        controller.afterEvents = { [weak self, weak controller] in
            guard let self, let controller, let campaign = self.campaign else { return }
            self.handle(campaign.evaluate(), controller: controller)
        }
        #if DEBUG
        controller.forceReduceMotion = LaunchOptions(arguments: arguments).reduceMotion
        #endif
        return controller
    }

    private func handle(_ events: [CampaignEvent], controller: GameController) {
        for event in events {
            switch event {
            case .goalAchieved(let goal):
                controller.show("goal.done", ["goal": L10n.text(goal.stringKey)], style: .success, duration: 3)
            case .chapterCompleted(let chapterId, let next):
                sheets.completion = ChapterCompletion(chapterId: chapterId, next: next)
            }
        }
    }

    var activeChapterId: String? { campaign?.activeChapter.id }

    func status(of chapter: ChapterDefinition) -> (unlocked: Bool, completed: Bool, goals: Int) {
        guard let progress = campaign?.progress else { return (false, false, 0) }
        return (progress.isUnlocked(chapter.id), progress.isCompleted(chapter.id), progress.goals(for: chapter.id).count)
    }

    func achievedGoals(_ chapterId: String) -> Set<ChapterGoal> {
        campaign?.progress.goals(for: chapterId) ?? []
    }

    // MARK: 玩家操作

    /// 打开已解锁章节：先保存当前章节，再以“现在”为起点载入目标章节。
    func open(_ chapterId: String) {
        guard let campaign else { return }
        sheets.completion = nil
        if chapterId == campaign.activeChapter.id {
            sheets.showChapters = false
            return
        }
        do {
            try campaign.switchTo(chapterId)
        } catch {
            return   // 锁定/未知章节：界面上本就不可点
        }
        sheets.showChapters = false
        phase = .running(makeController())
    }

    /// 重玩本章（界面已二次确认）：保留解锁、已获目标、设置与购买。
    func replayActiveChapter() {
        guard let campaign, case .running(let controller) = phase else { return }
        sheets.completion = nil
        sheets.showChapters = false
        controller.performReset { campaign.replayActiveChapter() }
    }

    /// 设置里的 Reset All Progress（界面已二次确认）：回到第一章，设置保留。
    func resetAllProgress() {
        guard let campaign else { return }
        sheets.completion = nil
        sheets.showChapters = false
        campaign.resetAllProgress()
        phase = .running(makeController())
    }

    func dismissCompletion() {
        sheets.completion = nil
    }

    /// 当前章节存档不可用时，玩家确认后只重开该章。
    func startChapterOver(_ chapterId: String) {
        guard let catalog else { return }
        CampaignCoordinator.startChapterOver(chapterId, store: store, appVersion: appVersion, catalog: catalog)
        launch()
    }

    func scenePhaseChanged(_ newPhase: ScenePhase) {
        guard let campaign, case .running(let controller) = phase else { return }
        switch newPhase {
        case .background:
            campaign.enterBackground()
        case .active:
            if let summary = campaign.becomeActive(), summary.isWorthShowing {
                controller.offlineSummary = summary
            }
            controller.onResume?()
        default:
            break
        }
    }
}
