import Foundation
import XCTest
@testable import AntKingdomCore

/// C01：地图解析与占地/边界与 design/map_prototype.txt、tools/check_map.py 一致。
final class MapTests: XCTestCase {
    func testBuiltInMapMatchesDesignFile() throws {
        let design = try String(contentsOf: repoFile("design/map_prototype.txt"), encoding: .utf8)
        let normalize = { (text: String) in text.split(whereSeparator: \.isNewline).map(String.init) }
        XCTAssertEqual(normalize(MapDefinition.backyardText), normalize(design))
    }

    func testFootprintsAndCountsMatchPRD() {
        let map = MapDefinition.backyard
        XCTAssertEqual(map.width, 9)
        XCTAssertEqual(map.height, 10)
        XCTAssertEqual(map.entrance, GridPoint(4, 0))
        XCTAssertEqual(map.queenCells, points([(3, 3), (4, 3), (5, 3), (3, 4), (4, 4), (5, 4)]))
        XCTAssertEqual(map.source("cookie")?.cells, points([(0, 6), (1, 6), (0, 7), (1, 7)]))
        XCTAssertEqual(map.source("sugar")?.cells, points([(7, 2)]))
        XCTAssertEqual(map.source("sap")?.cells, points([(8, 6)]))
        XCTAssertEqual(map.initialWalkable, map.queenCells.union(points([(4, 0), (4, 1), (4, 2)])))
        XCTAssertEqual(map.soilCells.count, 64)
        let stones = (0..<map.height).flatMap { y in (0..<map.width).map { GridPoint($0, y) } }
            .filter { map.tile(at: $0) == .stone }
        XCTAssertEqual(Set(stones), points([(7, 5), (8, 5), (5, 8)]))
        XCTAssertNil(map.tile(at: GridPoint(9, 0)))
        XCTAssertNil(map.tile(at: GridPoint(0, 10)))
    }

    func testSourceOrderAndPriorities() {
        let sources = MapDefinition.backyard.sources
        XCTAssertEqual(sources.map(\.id), ["cookie", "sugar", "sap", "surface"])
        XCTAssertEqual(sources.map(\.priority), [0, 0, 1, 2])
        XCTAssertEqual(sources.map(\.initialRemaining), [600, 0, nil, nil])
        XCTAssertEqual(sources[3].extraSeconds, 12)
    }

    func testValidatorRejectsBrokenMaps() {
        var grid = MapDefinition.backyard.rows
        XCTAssertEqual(MapDefinition.validate(grid), [])
        grid[3] = "###QQ####"
        grid[9] = ".########"
        let errors = MapDefinition.validate(grid)
        XCTAssertTrue(errors.contains { $0.contains("footprint") })
        XCTAssertTrue(errors.contains { $0.contains("disconnected") })
        XCTAssertEqual(MapDefinition.validate(["bad map"]), ["size must be 9 columns x 10 rows"])
        XCTAssertThrowsError(try MapDefinition(id: "x", version: 1, text: "bad map"))
    }
}
