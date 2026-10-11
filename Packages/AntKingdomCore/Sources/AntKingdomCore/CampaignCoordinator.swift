import Foundation

/// 章节层面给表现层的事件。
public enum CampaignEvent: Equatable, Sendable {
    /// 本局新达成一个目标（主目标或探索目标）
    case goalAchieved(ChapterGoal)
    /// 本章三个主目标全部达成（每局只宣布一次）；`next` 为目录中的下一章（已随完成解锁），最后一章为 nil
    case chapterCompleted(chapterId: String, next: String?)
}

public enum CampaignLaunchResult {
    case ready(offline: OfflineSummary?, recoveredFromBackup: Bool, recoveredProgress: Bool)
    /// 当前章节的主档与备份都不可用：只提供“重开本章”，不动其他章节与全局进度
    case chapterSaveUnavailable(chapterId: String, SaveError)
    /// 全局进度来自更新版本的 App：不降级、不覆盖
    case progressUnavailable(SaveError)
}

public enum CampaignError: Error, Equatable {
    case unknownChapter(String)
    case locked(String)
    case saveFailed(SaveError)
}

/// 正式版章节协调（C10）：全局进度 + 当前章节的生命周期。
/// - 每章独立存档；只推进当前章节，离线只结算离开时的当前章节一次；
/// - 切换章节先保存，再以“现在”为起点载入目标章节（非活动章节不后台产粮）；
/// - 重玩只重置本章，保留解锁、已获目标与设置；
/// - 全局进度损坏且无备份时，从各章存档推导，不静默清空解锁。
/// 非线程安全：由 App 主 actor 顺序调用。
public final class CampaignCoordinator {
    public let catalog: ChapterCatalog
    public private(set) var progress: PlayerProgress
    public private(set) var lifecycle: LifecycleCoordinator
    public private(set) var activeChapter: ChapterDefinition
    private let store: SaveStore
    private let appVersion: String
    private let wallClock: WallClock
    private let progressRepository: ProgressRepository
    public private(set) var lastSaveError: SaveError?

    public var session: GameSession { lifecycle.session }

    private init(catalog: ChapterCatalog, progress: PlayerProgress, lifecycle: LifecycleCoordinator,
                 chapter: ChapterDefinition, store: SaveStore, appVersion: String, wallClock: WallClock) {
        self.catalog = catalog
        self.progress = progress
        self.lifecycle = lifecycle
        self.activeChapter = chapter
        self.store = store
        self.appVersion = appVersion
        self.wallClock = wallClock
        self.progressRepository = ProgressRepository(store: store)
    }

    private static func repository(_ chapter: ChapterDefinition, store: SaveStore, appVersion: String) -> SaveRepository {
        SaveRepository(store: store, appVersion: appVersion, slots: .chapter(chapter.id), map: chapter.map)
    }

    /// 冷启动：读全局进度（或迁移/推导）→ 载入当前章节并结算一次离线 → 记录目标 → 保存进度。
    public static func launch(store: SaveStore, appVersion: String, wallClock: WallClock,
                              catalog: ChapterCatalog,
                              trace: LifecycleTrace? = nil) -> (CampaignCoordinator?, CampaignLaunchResult) {
        let progressRepository = ProgressRepository(store: store)
        var progress: PlayerProgress
        var recoveredBackup = false
        var recoveredProgress = false
        switch progressRepository.load() {
        case .fresh:
            // 首次进入正式版：若有核心版存档（同一文件名），第一章直接继续
            progress = .fresh(catalog)
        case .loaded(let loaded, let fromBackup):
            progress = loaded
            recoveredBackup = fromBackup
        case .unavailable(let error):
            if case .newerSchema = error { return (nil, .progressUnavailable(error)) }
            progress = derive(catalog: catalog, store: store, appVersion: appVersion)
            recoveredProgress = true
        }
        progress.normalize(catalog)
        let chapter = catalog.chapter(progress.activeChapterId) ?? catalog.first
        let (lifecycle, result) = LifecycleCoordinator.launch(
            repository: repository(chapter, store: store, appVersion: appVersion), wallClock: wallClock, map: chapter.map,
            trace: trace)
        switch result {
        case .ready(_, let offline, let fromBackup):
            guard let lifecycle else { return (nil, .chapterSaveUnavailable(chapterId: chapter.id, .unreadable("state"))) }
            let campaign = CampaignCoordinator(catalog: catalog, progress: progress, lifecycle: lifecycle, chapter: chapter,
                                               store: store, appVersion: appVersion, wallClock: wallClock)
            // 启动时补记已经达成但未记录的目标（例如核心版存档已经完成）；不在启动时弹完成页
            _ = campaign.evaluate(announce: false)
            campaign.saveProgress()
            return (campaign, .ready(offline: offline, recoveredFromBackup: fromBackup || recoveredBackup,
                                     recoveredProgress: recoveredProgress))
        case .saveUnavailable(let error):
            return (nil, .chapterSaveUnavailable(chapterId: chapter.id, error))
        }
    }

    /// 全局进度不可读时，从各章有效存档推导：第一章解锁；主目标达成的章节记为完成并解锁下一章。
    static func derive(catalog: ChapterCatalog, store: SaveStore, appVersion: String) -> PlayerProgress {
        var progress = PlayerProgress.fresh(catalog)
        for chapter in catalog.chapters {
            guard case .loaded(let envelope, _) = repository(chapter, store: store, appVersion: appVersion).load(),
                  let session = try? GameSession(state: envelope.state, map: chapter.map) else { continue }
            let goals = ChapterGoal.achieved(in: session)
            progress.record(goals, for: chapter.id)
            if ChapterGoal.isComplete(goals) { progress.complete(chapter.id, catalog: catalog) }
        }
        progress.normalize(catalog)
        return progress
    }

    /// 当前章节的存档不可用时，只重开当前章节（UI 二次确认）；其他章节与全局进度不动。
    public static func startChapterOver(_ chapterId: String, store: SaveStore, appVersion: String, catalog: ChapterCatalog) {
        guard let chapter = catalog.chapter(chapterId) else { return }
        try? repository(chapter, store: store, appVersion: appVersion).eraseAll()
    }

    // MARK: 目标与完成

    /// 每批会话事件之后调用：合并本局目标到全局进度；主目标全部达成时记录完成并解锁下一章，立即保存。
    /// `announce = false`（启动、切换、进后台）只记录不宣布；完成页留到下一次宣布时显示，每局一次。
    @discardableResult
    public func evaluate(announce: Bool = true) -> [CampaignEvent] {
        let id = activeChapter.id
        let goals = ChapterGoal.achieved(in: session)
        let added = progress.record(goals, for: id)
        var events: [CampaignEvent] = []
        if announce {
            events += ChapterGoal.allCases.filter(added.contains).map(CampaignEvent.goalAchieved)
        }
        var changed = !added.isEmpty
        if goals.contains(.buildPantry), !progress.firstPantryBuilt {
            progress.firstPantryBuilt = true
            changed = true
        }
        if ChapterGoal.isComplete(goals) {
            let next = catalog.next(after: id)?.id
            if !progress.isCompleted(id) || (next.map { !progress.isUnlocked($0) } ?? false) {
                progress.complete(id, catalog: catalog)
                changed = true
            }
            if announce, !session.flags.chapterComplete {
                session.flags.chapterComplete = true
                events.append(.chapterCompleted(chapterId: id, next: next))
                lifecycle.save()
            }
        }
        if changed { saveProgress() }
        return events
    }

    // MARK: 切换、重玩、重置

    /// 切换章节：先保存当前章节与进度，再载入目标章节（不结算离线）。设置跟随玩家，不随章节变化。
    public func switchTo(_ id: String) throws {
        guard let chapter = catalog.chapter(id) else { throw CampaignError.unknownChapter(id) }
        guard progress.isUnlocked(id) else { throw CampaignError.locked(id) }
        if id == activeChapter.id { return }
        evaluate(announce: false)
        lifecycle.save()
        let settings = session.settings
        let (next, result) = LifecycleCoordinator.launch(
            repository: CampaignCoordinator.repository(chapter, store: store, appVersion: appVersion),
            wallClock: wallClock, map: chapter.map, settleOffline: false, trace: lifecycle.trace)
        guard let next else {
            if case .saveUnavailable(let error) = result { throw CampaignError.saveFailed(error) }
            throw CampaignError.saveFailed(.unreadable("chapter"))
        }
        next.session.apply(.setSound(settings.sound))
        next.session.apply(.setHaptics(settings.haptics))
        _ = next.session.drainEvents()
        lifecycle = next
        activeChapter = chapter
        progress.activeChapterId = id
        evaluate(announce: false)
        lifecycle.save()
        saveProgress()
    }

    /// 重玩本章（UI 二次确认）：只重置本章地图与经济；解锁、已获目标、设置保留。
    public func replayActiveChapter() {
        lifecycle.resetColony()
        saveProgress()
    }

    // MARK: 外观与权益（C11）

    /// StoreKit 当前已验证权益 → 缓存（失去权益的外观回退默认），并立即写盘。
    /// 返回是否已写盘：只有写盘成功后，调用方才可以完成（finish）对应交易。写盘失败时内存中的权益已更新，
    /// 交易保持未完成，可再次调用本方法或 `saveProgress()` 重试（同一权益集合重复写入结果相同）。
    @discardableResult
    public func updateEntitlements(_ owned: Set<String>, bundleId: String) -> Bool {
        progress.setEntitlements(owned, bundleId: bundleId)
        return saveProgress()
    }

    /// 启用已拥有的外观；未拥有返回 false，不改变任何东西。
    @discardableResult
    public func selectRoomStyle(_ style: RoomStyle, bundleId: String) -> Bool {
        guard progress.select(style, bundleId: bundleId) else { return false }
        saveProgress()
        return true
    }

    /// 重置全部本地进度（UI 二次确认）：所有章节存档与全局进度清空，回到第一章；设置保留。
    /// 购买的永久外观权益与当前外观选择保留（权益来自 StoreKit，可恢复），见 RELEASE_SCOPE 第 2 章。
    public func resetAllProgress() {
        let settings = session.settings
        let owned = progress.ownedProducts
        let style = progress.roomStyle
        for chapter in catalog.chapters {
            try? CampaignCoordinator.repository(chapter, store: store, appVersion: appVersion).eraseAll()
        }
        try? progressRepository.eraseAll()
        progress = .fresh(catalog)
        progress.ownedProducts = owned
        progress.roomStyle = style
        let chapter = catalog.first
        let (fresh, _) = LifecycleCoordinator.launch(
            repository: CampaignCoordinator.repository(chapter, store: store, appVersion: appVersion),
            wallClock: wallClock, map: chapter.map, settleOffline: false, trace: lifecycle.trace)
        if let fresh {
            fresh.session.apply(.setSound(settings.sound))
            fresh.session.apply(.setHaptics(settings.haptics))
            _ = fresh.session.drainEvents()
            lifecycle = fresh
            lifecycle.save()
        }
        activeChapter = chapter
        saveProgress()
    }

    // MARK: 生命周期

    public func enterBackground() {
        evaluate(announce: false)
        lifecycle.enterBackground()
        saveProgress()
    }

    /// 回到前台：只结算当前章节一次。目标由下一帧的 evaluate() 记录并宣布。
    public func becomeActive() -> OfflineSummary? {
        lifecycle.becomeActive()
    }

    /// 每帧推进之前的准入（D-13）：与核心版同一规则——离开区间未结算时不推进不保存，
    /// 帧停顿而没有后台记录时由当前章节结算一次离线。
    public func admitForegroundFrame() -> ForegroundFrame {
        let admission = lifecycle.admitForegroundFrame()
        if case .resumed = admission { saveProgress() }
        return admission
    }

    @discardableResult
    public func saveProgress() -> Bool {
        do {
            try progressRepository.save(&progress, now: wallClock.now())
            lastSaveError = nil
            return true
        } catch let error as SaveError {
            lastSaveError = error
            return false
        } catch {
            lastSaveError = .writeFailed(String(describing: error))
            return false
        }
    }
}
