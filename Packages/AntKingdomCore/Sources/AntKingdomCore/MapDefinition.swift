/// 地图符号（PRD 第 3 章）。
public enum Tile: Character, Sendable, CaseIterable {
    case surface = "~"
    case entrance = "E"
    case tunnel = "."
    case soil = "#"
    case queen = "Q"
    case cookie = "C"
    case sugar = "S"
    case sap = "R"
    case stone = "X"
}

/// 一个食物源的静态定义。顺序即 Python `Colony.sources` 的顺序，影响结算顺序。
public struct SourceDefinition: Equatable, Sendable {
    public enum Kind: String, Sendable { case patch, permanent, surface }

    public let id: String
    public let kind: Kind
    /// 占地格（补给/树液根）；地面源为入口。
    public let cells: Set<GridPoint>
    /// nil 表示无限
    public let initialRemaining: Double?
    /// 数字越小优先级越高：补给 0 > 树液根 1 > 地面 2
    public let priority: Int
    public let extraSeconds: Double
    /// 补给刷新时补充的量；永久源为 nil
    public let refillAmount: Double?
}

public enum MapError: Error, Equatable, CustomStringConvertible {
    case invalid([String])

    public var description: String {
        switch self {
        case .invalid(let errors): return "invalid map: " + errors.joined(separator: "; ")
        }
    }
}

/// 不可变地图数据：符号格网 + 由符号推导出的占地、初始通路与源。
/// 房间贴图不是碰撞数据；碰撞只看这里的格子。
public struct MapDefinition: Sendable {
    public let id: String
    /// 地图内容版本，存档用来拒绝不兼容的旧布局
    public let version: Int
    public let rows: [String]
    public let width: Int
    public let height: Int
    public let entrance: GridPoint
    public let initialWalkable: Set<GridPoint>
    public let queenCells: Set<GridPoint>
    public let sources: [SourceDefinition]
    private let tiles: [GridPoint: Tile]

    public init(id: String, version: Int, text: String) throws {
        let rows = text.split(separator: "\n", omittingEmptySubsequences: false)
            .map { String($0.filter { $0 != "\r" }) }
            .filter { !$0.isEmpty }
        let errors = MapDefinition.validate(rows)
        guard errors.isEmpty else { throw MapError.invalid(errors) }
        var tiles: [GridPoint: Tile] = [:]
        for (y, row) in rows.enumerated() {
            for (x, ch) in row.enumerated() {
                tiles[GridPoint(x, y)] = Tile(rawValue: ch)
            }
        }
        func cells(_ tile: Tile) -> Set<GridPoint> { Set(tiles.filter { $0.value == tile }.keys) }
        let entrance = cells(.entrance).first!
        self.id = id
        self.version = version
        self.rows = rows
        self.width = rows[0].count
        self.height = rows.count
        self.tiles = tiles
        self.entrance = entrance
        self.initialWalkable = cells(.tunnel).union(cells(.queen)).union([entrance])
        self.queenCells = cells(.queen)
        self.sources = [
            SourceDefinition(id: "cookie", kind: .patch, cells: cells(.cookie), initialRemaining: 600,
                             priority: 0, extraSeconds: 0, refillAmount: Rules.cookieRefill),
            SourceDefinition(id: "sugar", kind: .patch, cells: cells(.sugar), initialRemaining: 0,
                             priority: 0, extraSeconds: 0, refillAmount: Rules.sugarRefill),
            SourceDefinition(id: "sap", kind: .permanent, cells: cells(.sap), initialRemaining: nil,
                             priority: 1, extraSeconds: 0, refillAmount: nil),
            SourceDefinition(id: "surface", kind: .surface, cells: [entrance], initialRemaining: nil,
                             priority: 2, extraSeconds: Rules.surfaceExtraSeconds, refillAmount: nil),
        ]
    }

    public func tile(at p: GridPoint) -> Tile? { tiles[p] }

    public func contains(_ p: GridPoint) -> Bool { tiles[p] != nil }

    /// 所有可挖的 Soil 格
    public var soilCells: Set<GridPoint> { Set(tiles.filter { $0.value == .soil }.keys) }

    public func source(_ id: String) -> SourceDefinition? { sources.first { $0.id == id } }

    /// 与 tools/check_map.py `validate` 相同的检查；返回错误列表（空表示通过）。
    public static func validate(_ grid: [String]) -> [String] {
        guard grid.count == 10, grid.allSatisfy({ $0.count == 9 }) else {
            return ["size must be 9 columns x 10 rows"]
        }
        var errors: [String] = []
        var tiles: [GridPoint: Character] = [:]
        for (y, row) in grid.enumerated() {
            for (x, ch) in row.enumerated() { tiles[GridPoint(x, y)] = ch }
        }
        let known = Set("~E.#QCSRX")
        let unknown = Set(tiles.values).subtracting(known)
        if !unknown.isEmpty { errors.append("unknown symbols: \(unknown.sorted())") }
        if grid[0] != "~~~~E~~~~" || grid.dropFirst().contains(where: { $0.contains("~") || $0.contains("E") }) {
            errors.append("invalid surface/entrance")
        }
        for (symbol, size) in [("Q", (3, 2)), ("C", (2, 2)), ("S", (1, 1)), ("R", (1, 1))] {
            let cells = Set(tiles.filter { String($0.value) == symbol }.keys)
            if cells.isEmpty {
                errors.append("missing \(symbol)")
                continue
            }
            let x = cells.map(\.x).min()!, y = cells.map(\.y).min()!
            var expected = Set<GridPoint>()
            for dx in 0..<size.0 { for dy in 0..<size.1 { expected.insert(GridPoint(x + dx, y + dy)) } }
            if cells != expected { errors.append("invalid \(symbol) footprint") }
        }
        let entrance = GridPoint(4, 0)
        let initial = Set(tiles.filter { ".QE".contains($0.value) }.keys)
        if !initial.isSubset(of: flood(initial, from: entrance)) {
            errors.append("initial tunnels/Queen are disconnected")
        }
        let potential = Set(tiles.filter { "#.QE".contains($0.value) }.keys)
        let seen = flood(potential, from: entrance)
        if seen != potential { errors.append("some legal soil cannot be reached by digging") }
        for symbol in ["C", "S", "R"] {
            let cells = tiles.filter { String($0.value) == symbol }.keys
            if !cells.contains(where: { cell in cell.neighbors.contains(where: seen.contains) }) {
                errors.append("source \(symbol) has no reachable loading edge")
            }
        }
        let roomCells = potential.filter { "#.".contains(tiles[$0]!) }
        let hasPantrySpace = roomCells.contains { p in
            [GridPoint(p.x, p.y), GridPoint(p.x + 1, p.y), GridPoint(p.x, p.y + 1), GridPoint(p.x + 1, p.y + 1)]
                .allSatisfy(roomCells.contains)
        }
        if !hasPantrySpace { errors.append("no legal 2 x 2 Pantry space") }
        return errors
    }

    static func flood(_ cells: Set<GridPoint>, from start: GridPoint) -> Set<GridPoint> {
        var seen: Set<GridPoint> = [start]
        var queue = [start]
        var head = 0
        while head < queue.count {
            let p = queue[head]
            head += 1
            for q in p.neighbors where cells.contains(q) && !seen.contains(q) {
                seen.insert(q)
                queue.append(q)
            }
        }
        return seen
    }
}

extension MapDefinition {
    /// 当前验证版地图，内容必须与 design/map_prototype.txt 完全一致（测试会比对）。
    public static let backyardText = """
    ~~~~E~~~~
    ####.####
    ####.##S#
    ###QQQ###
    ###QQQ###
    #######XX
    CC######R
    CC#######
    #####X###
    #########
    """

    public static let backyard: MapDefinition = {
        // 内置地图在构建期已通过测试，失败属于开发错误。
        do { return try MapDefinition(id: "backyard", version: 1, text: backyardText) }
        catch { fatalError("built-in map invalid: \(error)") }
    }()
}
