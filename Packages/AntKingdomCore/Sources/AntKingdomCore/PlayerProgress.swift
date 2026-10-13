import Foundation

/// 跨章节的全局进度（RELEASE_SCOPE 第 1 章“跨章状态”）：解锁、完成、已获目标、当前章节。
/// 重玩某章不清除这里的内容；全部本地进度重置才清除。商业化（M5）的全局状态以后也放这里。
/// 解码时缺失的键取默认值，新增字段不会让旧进度文件无法读取。
public struct PlayerProgress: Codable, Equatable, Sendable {
    public static let currentSchema = 1

    public var schemaVersion = PlayerProgress.currentSchema
    public var activeChapterId: String
    /// 按目录顺序
    public var unlockedChapterIds: [String]
    public var completedChapterIds: [String] = []
    /// 章节 ID → 已达成目标（String Catalog ID，排序）；重玩不清除
    public var achievedGoals: [String: [String]] = [:]
    public var savedAt = 0.0
    public var sequence = 0
    /// 任意章节首次建成 Pantry（全局成就；外观面板入口条件，RELEASE_SCOPE 第 2 章）
    public var firstPantryBuilt = false
    /// StoreKit 已验证权益的缓存（离线时显示用；联网后以 StoreKit 当前权益为准，不是唯一证据）
    public var ownedProducts: [String] = []
    /// 当前房间外观（RoomStyle 原始值）
    public var roomStyle = RoomStyle.standard.rawValue
    /// 奖励广告账本（C12，全局；切换/重玩章节不重置）
    public var rewards = RewardLedger()

    public init(activeChapterId: String, unlockedChapterIds: [String]) {
        self.activeChapterId = activeChapterId
        self.unlockedChapterIds = unlockedChapterIds
    }

    public static func fresh(_ catalog: ChapterCatalog) -> PlayerProgress {
        PlayerProgress(activeChapterId: catalog.first.id, unlockedChapterIds: [catalog.first.id])
    }

    enum CodingKeys: String, CodingKey {
        case schemaVersion, activeChapterId, unlockedChapterIds, completedChapterIds, achievedGoals, savedAt, sequence
        case firstPantryBuilt, ownedProducts, roomStyle, rewards
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try c.decode(Int.self, forKey: .schemaVersion)
        activeChapterId = try c.decode(String.self, forKey: .activeChapterId)
        unlockedChapterIds = try c.decode([String].self, forKey: .unlockedChapterIds)
        completedChapterIds = try c.decodeIfPresent([String].self, forKey: .completedChapterIds) ?? []
        achievedGoals = try c.decodeIfPresent([String: [String]].self, forKey: .achievedGoals) ?? [:]
        savedAt = try c.decodeIfPresent(Double.self, forKey: .savedAt) ?? 0
        sequence = try c.decodeIfPresent(Int.self, forKey: .sequence) ?? 0
        firstPantryBuilt = try c.decodeIfPresent(Bool.self, forKey: .firstPantryBuilt) ?? false
        ownedProducts = try c.decodeIfPresent([String].self, forKey: .ownedProducts) ?? []
        roomStyle = try c.decodeIfPresent(String.self, forKey: .roomStyle) ?? RoomStyle.standard.rawValue
        rewards = try c.decodeIfPresent(RewardLedger.self, forKey: .rewards) ?? RewardLedger()
    }

    public func isUnlocked(_ id: String) -> Bool { unlockedChapterIds.contains(id) }
    public func isCompleted(_ id: String) -> Bool { completedChapterIds.contains(id) }

    public func goals(for id: String) -> Set<ChapterGoal> {
        Set((achievedGoals[id] ?? []).compactMap(ChapterGoal.init(rawValue:)))
    }

    /// 合并本局目标（只增不减）；返回新达成的目标。
    @discardableResult
    public mutating func record(_ goals: Set<ChapterGoal>, for id: String) -> Set<ChapterGoal> {
        let before = self.goals(for: id)
        let added = goals.subtracting(before)
        if !added.isEmpty { achievedGoals[id] = before.union(goals).map(\.rawValue).sorted() }
        return added
    }

    /// 标记完成并解锁下一章；返回新解锁的章节 ID。
    @discardableResult
    public mutating func complete(_ id: String, catalog: ChapterCatalog) -> String? {
        if !completedChapterIds.contains(id) { completedChapterIds.append(id) }
        guard let next = catalog.next(after: id), !unlockedChapterIds.contains(next.id) else { return nil }
        unlockedChapterIds.append(next.id)
        unlockedChapterIds = catalog.chapters.map(\.id).filter(unlockedChapterIds.contains)
            + unlockedChapterIds.filter { catalog.index(of: $0) == nil }
        return next.id
    }

    /// 适配当前目录：第一章总是解锁；完成的章节解锁下一章（目录新增章节后自动补上）；当前章节必须可玩。
    /// 不认识的章节 ID（更新版本的内容）原样保留，不删除玩家记录。
    public mutating func normalize(_ catalog: ChapterCatalog) {
        if !unlockedChapterIds.contains(catalog.first.id) { unlockedChapterIds.insert(catalog.first.id, at: 0) }
        for id in completedChapterIds { _ = complete(id, catalog: catalog) }
        if catalog.chapter(activeChapterId) == nil || !isUnlocked(activeChapterId) {
            activeChapterId = catalog.first.id
        }
    }

    /// 结构校验：任何非法内容都视为不可读，改用备份或从各章存档推导。
    public func validate() throws {
        guard schemaVersion >= 1, !activeChapterId.isEmpty, unlockedChapterIds.contains(activeChapterId),
              Set(unlockedChapterIds).count == unlockedChapterIds.count,
              Set(completedChapterIds).count == completedChapterIds.count,
              savedAt.isFinite, sequence >= 0 else {
            throw SaveError.unreadable("progress invalid")
        }
        for goals in achievedGoals.values where goals.contains(where: { ChapterGoal(rawValue: $0) == nil }) {
            throw SaveError.unreadable("unknown goal")
        }
        guard RoomStyle(rawValue: roomStyle) != nil, Set(ownedProducts).count == ownedProducts.count else {
            throw SaveError.unreadable("bad cosmetics")
        }
        try rewards.validate()
    }
}

/// 全局进度的读写：主档 + 备份，原子写入；与章节存档分开，单个文件损坏不影响其他。
public final class ProgressRepository {
    private let store: SaveStore
    public let slots: SaveSlotPair

    public init(store: SaveStore, slots: SaveSlotPair = .progress) {
        self.store = store
        self.slots = slots
    }

    public enum Outcome: Equatable {
        case fresh
        case loaded(PlayerProgress, recoveredFromBackup: Bool)
        case unavailable(SaveError)
    }

    public func load() -> Outcome {
        let main = try? store.read(slots.main)
        let backup = try? store.read(slots.backup)
        if main == nil, backup == nil { return .fresh }
        var lastError = SaveError.unreadable("missing")
        if let main {
            do { return .loaded(try ProgressRepository.decodeValid(main), recoveredFromBackup: false) }
            catch let error as SaveError {
                if case .newerSchema = error { return .unavailable(error) }
                lastError = error
            } catch { lastError = .unreadable(String(describing: error)) }
        }
        if let backup, let progress = try? ProgressRepository.decodeValid(backup) {
            return .loaded(progress, recoveredFromBackup: true)
        }
        return .unavailable(lastError)
    }

    @discardableResult
    public func save(_ progress: inout PlayerProgress, now: Double) throws -> Data {
        progress.sequence += 1
        progress.savedAt = now.isFinite ? now : progress.savedAt
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(progress)
        if let current = try? store.read(slots.main), (try? ProgressRepository.decodeValid(current)) != nil {
            try? store.write(current, to: slots.backup)
        }
        do { try store.write(data, to: slots.main) }
        catch { throw SaveError.writeFailed(String(describing: error)) }
        return data
    }

    public func eraseAll() throws {
        for slot in slots.all { try store.remove(slot) }
    }

    public static func decodeValid(_ data: Data) throws -> PlayerProgress {
        struct Header: Decodable { let schemaVersion: Int }
        guard let header = try? JSONDecoder().decode(Header.self, from: data) else {
            throw SaveError.unreadable("no header")
        }
        if header.schemaVersion > PlayerProgress.currentSchema { throw SaveError.newerSchema(header.schemaVersion) }
        let progress: PlayerProgress
        do { progress = try JSONDecoder().decode(PlayerProgress.self, from: data) }
        catch { throw SaveError.unreadable("decode: \(error)") }
        try progress.validate()
        return progress
    }
}
