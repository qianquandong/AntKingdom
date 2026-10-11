@testable import AntKingdomCore

func connectCookie(_ colony: Colony) throws {
    for p in [GridPoint(2, 4), GridPoint(2, 5), GridPoint(2, 6)] { try colony.dig(p) }
}

/// 把全部合法土格挖完（按 Python 测试的逐轮前沿顺序）。
func excavateAll(_ colony: Colony) throws {
    while true {
        let frontier = colony.map.soilCells.filter { colony.isFrontier($0) }
        if frontier.isEmpty { return }
        for p in frontier.sortedByKey() { try colony.dig(p) }
    }
}
