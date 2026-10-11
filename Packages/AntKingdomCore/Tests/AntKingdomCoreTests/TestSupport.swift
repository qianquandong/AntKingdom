import Foundation
@testable import AntKingdomCore

/// 仓库根目录（测试从源码树读取共享夹具，保证与 Python 用同一份输入）。
let repoRoot = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()   // AntKingdomCoreTests
    .deletingLastPathComponent()   // Tests
    .deletingLastPathComponent()   // AntKingdomCore
    .deletingLastPathComponent()   // Packages
    .deletingLastPathComponent()   // repo

func repoFile(_ relative: String) -> URL {
    repoRoot.appendingPathComponent(relative)
}

func points(_ list: [(Int, Int)]) -> Set<GridPoint> {
    Set(list.map { GridPoint($0.0, $0.1) })
}

/// Python 3.12+ 的 sum() 为补偿求和，与 Swift 的顺序求和可能差 1 ulp；比对使用此容差。
let referenceTolerance = 1e-9

func isClose(_ a: Double, _ b: Double, tolerance: Double = referenceTolerance) -> Bool {
    abs(a - b) <= tolerance * max(1.0, abs(a), abs(b))
}
