import Foundation

/// 存档外层：schema 版本与 App 版本分开；保存时间与“墙钟高水位”用于离线结算。
public struct SaveEnvelope: Codable, Equatable, Sendable {
    public var schemaVersion: Int
    public var appVersion: String
    /// 写入时的墙钟（Unix 秒）
    public var savedAt: Double
    /// 见过的最大墙钟。离线时长从这里算起，系统时间回拨再拨回不能重复领离线（PRD 5.3、QA T24）
    public var wallHighWater: Double
    /// 单调递增的写入序号，便于排查与比对
    public var sequence: Int
    public var state: GameState

    public init(schemaVersion: Int, appVersion: String, savedAt: Double, wallHighWater: Double, sequence: Int,
                state: GameState) {
        self.schemaVersion = schemaVersion
        self.appVersion = appVersion
        self.savedAt = savedAt
        self.wallHighWater = wallHighWater
        self.sequence = sequence
        self.state = state
    }
}

public enum SaveError: Error, Equatable, Sendable {
    /// 存档来自更新版本的 App，不能降级读取，也不能覆盖
    case newerSchema(Int)
    case unreadable(String)
    case writeFailed(String)
}

/// 存储位置抽象：主档与备份两个槽。写入必须原子（写临时文件后替换）。
public protocol SaveStore: AnyObject {
    func read(_ slot: SaveSlot) throws -> Data?
    func write(_ data: Data, to slot: SaveSlot) throws
    func remove(_ slot: SaveSlot) throws
}

public enum SaveSlot: String, CaseIterable, Sendable {
    case main = "colony.json"
    case backup = "colony.backup.json"
}

/// 文件存储：`Data.write(options: .atomic)` 先写同目录临时文件再原子替换，崩溃时旧文件仍完整。
public final class FileSaveStore: SaveStore {
    public let directory: URL

    public init(directory: URL) {
        self.directory = directory
    }

    private func url(_ slot: SaveSlot) -> URL { directory.appendingPathComponent(slot.rawValue) }

    public func read(_ slot: SaveSlot) throws -> Data? {
        let url = url(slot)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try Data(contentsOf: url)
    }

    public func write(_ data: Data, to slot: SaveSlot) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try data.write(to: url(slot), options: .atomic)
    }

    public func remove(_ slot: SaveSlot) throws {
        let url = url(slot)
        if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
    }
}

/// 内存存储：测试与预览用，可注入写入失败。
public final class MemorySaveStore: SaveStore {
    public var slots: [SaveSlot: Data] = [:]
    public var failWrites = false

    public init() {}

    public func read(_ slot: SaveSlot) throws -> Data? { slots[slot] }

    public func write(_ data: Data, to slot: SaveSlot) throws {
        if failWrites { throw SaveError.writeFailed("injected") }
        slots[slot] = data
    }

    public func remove(_ slot: SaveSlot) throws { slots[slot] = nil }
}

/// 读取结果
public enum LoadOutcome: Equatable {
    /// 没有任何存档：新档
    case fresh
    /// 读到有效存档；`recoveredFromBackup` 表示主档损坏、已用最近有效备份
    case loaded(SaveEnvelope, recoveredFromBackup: Bool)
    /// 主档与备份都不可用：显示英文错误与重置入口，不静默清档
    case unavailable(SaveError)
}

/// 版本化保存、备份、校验与迁移（PRD 5.3、TECHNICAL_HANDOFF 第 5 章）。
public final class SaveRepository {
    public static let currentSchema = CoreInfo.saveSchemaVersion
    private let store: SaveStore
    private let appVersion: String
    public private(set) var sequence = 0

    public init(store: SaveStore, appVersion: String) {
        self.store = store
        self.appVersion = appVersion
    }

    /// 保存：先把当前有效主档复制为备份，再原子写入新主档。失败时抛出，主档保持上一份有效内容。
    @discardableResult
    public func save(_ session: GameSession, now: Double, wallHighWater: Double) throws -> SaveEnvelope {
        sequence += 1
        let envelope = SaveEnvelope(schemaVersion: SaveRepository.currentSchema, appVersion: appVersion,
                                    savedAt: now, wallHighWater: max(wallHighWater, now), sequence: sequence,
                                    state: session.makeState())
        let data = try SaveRepository.encode(envelope)
        if let current = try? store.read(.main), (try? SaveRepository.decodeValid(current)) != nil {
            try? store.write(current, to: .backup)
        }
        do {
            try store.write(data, to: .main)
        } catch {
            throw SaveError.writeFailed(String(describing: error))
        }
        return envelope
    }

    public func load() -> LoadOutcome {
        let main = try? store.read(.main)
        let backup = try? store.read(.backup)
        if main == nil, backup == nil { return .fresh }
        var lastError = SaveError.unreadable("missing")
        if let main {
            do {
                let envelope = try SaveRepository.decodeValid(main)
                sequence = envelope.sequence
                return .loaded(envelope, recoveredFromBackup: false)
            } catch let error as SaveError {
                if case .newerSchema = error { return .unavailable(error) }
                lastError = error
            } catch {
                lastError = .unreadable(String(describing: error))
            }
        }
        if let backup, let envelope = try? SaveRepository.decodeValid(backup) {
            sequence = envelope.sequence
            return .loaded(envelope, recoveredFromBackup: true)
        }
        return .unavailable(lastError)
    }

    /// 玩家确认重置后清除本地存档（UI 负责二次确认）。
    public func eraseAll() throws {
        for slot in SaveSlot.allCases { try store.remove(slot) }
        sequence = 0
    }

    public static func encode(_ envelope: SaveEnvelope) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(envelope)
    }

    /// 解码 + 迁移 + 完整状态校验；任何一步失败都视为不可用。
    public static func decodeValid(_ data: Data) throws -> SaveEnvelope {
        struct Header: Decodable { let schemaVersion: Int }
        guard let header = try? JSONDecoder().decode(Header.self, from: data) else {
            throw SaveError.unreadable("no header")
        }
        if header.schemaVersion > currentSchema { throw SaveError.newerSchema(header.schemaVersion) }
        let migrated = try migrate(data, from: header.schemaVersion)
        let envelope: SaveEnvelope
        do {
            envelope = try JSONDecoder().decode(SaveEnvelope.self, from: migrated)
        } catch {
            throw SaveError.unreadable("decode: \(error)")
        }
        guard envelope.savedAt.isFinite, envelope.wallHighWater.isFinite else { throw SaveError.unreadable("time") }
        do {
            _ = try GameSession(state: envelope.state)
        } catch {
            throw SaveError.unreadable("state: \(error)")
        }
        return envelope
    }

    /// 逐版本迁移。v1 是首个版本；以后每加一版在这里追加一步，并保留旧版本样例存档的回归测试。
    static func migrate(_ data: Data, from version: Int) throws -> Data {
        switch version {
        case currentSchema: return data
        default: throw SaveError.unreadable("unsupported schema \(version)")
        }
    }
}
