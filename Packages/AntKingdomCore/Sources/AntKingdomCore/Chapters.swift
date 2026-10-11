import Foundation

/// 正式版的一章（RELEASE_SCOPE 第 1 章）：一张 9×9 地下地图 + 标题文案 ID。
/// 所有章节共用同一套规则、人口上限、源规则与仓库；章节之间只有地图不同。
public struct ChapterDefinition: Sendable {
    public let id: String
    /// 英文 String Catalog 的 ID（例如 world.backyard）
    public let titleKey: String
    public let map: MapDefinition

    public init(id: String, titleKey: String, map: MapDefinition) {
        self.id = id
        self.titleKey = titleKey
        self.map = map
    }
}

/// design/chapters.json 的结构。`map` 为空表示地图尚未交付（A04），该章不进入目录。
public struct ChapterManifest: Codable, Equatable, Sendable {
    public struct Entry: Codable, Equatable, Sendable {
        public let id: String
        public let title: String
        /// design/ 下的地图文件名；nil = 尚未交付
        public let map: String?
        public let mapVersion: Int
        /// ready / awaiting_design 等，仅供文档与检查脚本
        public let status: String
    }

    public let version: Int
    public let chapters: [Entry]
}

public enum ChapterError: Error, Equatable, CustomStringConvertible {
    case emptyCatalog
    case duplicateId(String)
    case map(String, String)

    public var description: String {
        switch self {
        case .emptyCatalog: return "no playable chapter"
        case .duplicateId(let id): return "duplicate chapter id \(id)"
        case .map(let id, let reason): return "chapter \(id): \(reason)"
        }
    }
}

/// 按顺序排列的可玩章节。顺序即解锁顺序。
public struct ChapterCatalog: Sendable {
    public let chapters: [ChapterDefinition]

    public init(chapters: [ChapterDefinition]) throws {
        guard !chapters.isEmpty else { throw ChapterError.emptyCatalog }
        var seen = Set<String>()
        for chapter in chapters {
            guard seen.insert(chapter.id).inserted else { throw ChapterError.duplicateId(chapter.id) }
        }
        self.chapters = chapters
    }

    /// 从清单载入：只收入已交付地图的章节；地图文本由调用方按文件名提供（App 从 bundle、测试从夹具）。
    public init(manifest: ChapterManifest, mapText: (String) throws -> String) throws {
        var chapters: [ChapterDefinition] = []
        for entry in manifest.chapters {
            guard let file = entry.map else { continue }
            let map: MapDefinition
            do {
                // 第一章沿用核心地图 ID "backyard"，与核心版存档兼容
                map = try MapDefinition(id: entry.id, version: entry.mapVersion, text: try mapText(file))
            } catch {
                throw ChapterError.map(entry.id, String(describing: error))
            }
            chapters.append(ChapterDefinition(id: entry.id, titleKey: entry.title, map: map))
        }
        try self.init(chapters: chapters)
    }

    /// 只有核心地图的目录（核心验证版与测试使用）
    public static let coreOnly: ChapterCatalog = {
        do { return try ChapterCatalog(chapters: [ChapterDefinition(id: "backyard", titleKey: "world.backyard",
                                                                      map: .backyard)]) }
        catch { fatalError("core catalog invalid: \(error)") }
    }()

    public var first: ChapterDefinition { chapters[0] }

    public func chapter(_ id: String) -> ChapterDefinition? { chapters.first { $0.id == id } }

    public func index(of id: String) -> Int? { chapters.firstIndex { $0.id == id } }

    public func next(after id: String) -> ChapterDefinition? {
        guard let index = index(of: id), index + 1 < chapters.count else { return nil }
        return chapters[index + 1]
    }
}

/// 每章目标（RELEASE_SCOPE 第 1 章）：三个主目标全部达成即完成本章并解锁下一章；
/// 三个探索目标不是解锁门槛。
public enum ChapterGoal: String, CaseIterable, Codable, Sendable {
    case connectCookie = "goal.connect_cookie"
    case buildPantry = "goal.build_pantry"
    case fullColony = "goal.full_colony"
    case connectSugar = "goal.connect_sugar"
    case connectSap = "goal.connect_sap"
    case betterRoute = "goal.better_route"

    public static let main: [ChapterGoal] = [.connectCookie, .buildPantry, .fullColony]
    public static let exploration: [ChapterGoal] = [.connectSugar, .connectSap, .betterRoute]

    public var isMain: Bool { ChapterGoal.main.contains(self) }

    /// 文案 ID（与 rawValue 相同，单独列出便于阅读）
    public var stringKey: String { rawValue }

    /// 布局改善目标的门槛：冻结人口与源后预计产量提高至少 5%
    public static let betterRouteThreshold = 5.0

    /// 当前一局已达成的目标：记录过的标记与当前连通状态取并集（旧存档没有记录也能识别）。
    public static func achieved(in session: GameSession) -> Set<ChapterGoal> {
        var goals = Set<ChapterGoal>()
        let connected = Set(session.flags.connectedSources).union(
            session.colony.sources.filter { $0.definition.kind != .surface && session.colony.isConnected($0) }.map(\.id))
        if connected.contains("cookie") { goals.insert(.connectCookie) }
        if connected.contains("sugar") { goals.insert(.connectSugar) }
        if connected.contains("sap") { goals.insert(.connectSap) }
        if session.flags.pantryBuiltOnce || !session.colony.pantry.isEmpty { goals.insert(.buildPantry) }
        if session.flags.prototypeComplete { goals.insert(.fullColony) }
        if session.flags.bestRouteGain >= betterRouteThreshold { goals.insert(.betterRoute) }
        return goals
    }

    public static func isComplete(_ goals: Set<ChapterGoal>) -> Bool { Set(main).isSubset(of: goals) }
}
