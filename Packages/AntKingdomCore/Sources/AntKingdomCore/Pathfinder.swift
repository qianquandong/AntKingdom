/// 四邻 BFS 与有界候选路线（PRD 4.3 第 1–2 条）。
/// 起点按 (y, x) 排序，邻居固定上/左/右/下；不依赖 Set/Dictionary 的枚举顺序。
public enum Pathfinder {
    /// 对应 Python `shortest_path`。到达任一卸货点（出队时判断）即返回包含两端的路径。
    public static func shortestPath(walkable: Set<GridPoint>, starts: Set<GridPoint>,
                                    sinks: Set<GridPoint>, blocked: Set<GridPoint> = []) -> [GridPoint]? {
        let available = blocked.isEmpty ? walkable : walkable.subtracting(blocked)
        var queue = starts.intersection(available).sortedByKey()
        var visited = Set(queue)
        var parent: [GridPoint: GridPoint] = [:]
        var head = 0
        while head < queue.count {
            let p = queue[head]
            head += 1
            if sinks.contains(p) {
                var path = [p]
                var cursor = p
                while let previous = parent[cursor] {
                    path.append(previous)
                    cursor = previous
                }
                return path.reversed()
            }
            for q in p.neighbors where available.contains(q) && !visited.contains(q) {
                visited.insert(q)
                parent[q] = p
                queue.append(q)
            }
        }
        return nil
    }

    /// 对应 Python `candidate_paths`：主路径 + 逐一避开主路径非终点格的替代 BFS，
    /// 去重后按（长度，坐标序列）排序，最多保留 `Rules.maxPaths` 条。
    /// 这是有界候选集，不声称找到所有路线或全局最优。
    public static func candidatePaths(walkable: Set<GridPoint>, starts: Set<GridPoint>,
                                      sinks: Set<GridPoint>) -> [[GridPoint]] {
        guard let primary = shortestPath(walkable: walkable, starts: starts, sinks: sinks) else { return [] }
        var found: [[GridPoint]] = [primary]
        for p in primary.dropLast() {
            if let alternate = shortestPath(walkable: walkable, starts: starts, sinks: sinks, blocked: [p]),
               !found.contains(alternate) {
                found.append(alternate)
            }
        }
        found.sort(by: routeLess)
        return Array(found.prefix(Rules.maxPaths))
    }

    /// Python 的 `(len(route), tuple(map(point_key, route)))` 元组比较。
    static func routeLess(_ a: [GridPoint], _ b: [GridPoint]) -> Bool {
        if a.count != b.count { return a.count < b.count }
        for (p, q) in zip(a, b) where p != q {
            return GridPoint.keyLess(p, q)
        }
        return false
    }
}
