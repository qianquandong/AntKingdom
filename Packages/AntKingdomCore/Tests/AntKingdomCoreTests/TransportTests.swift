import XCTest
@testable import AntKingdomCore

/// 移植 tests/test_economy.py 的 TransportTests，并补充 BFS 顺序与候选集测试。
final class TransportTests: XCTestCase {
    func testThreeHandCalculatedCases() throws {
        let cases = try TransportCase.load(from: repoFile("design/transport_cases.json"))
        XCTAssertEqual(cases.count, 3)
        for testCase in cases {
            let result = testCase.result()
            XCTAssertTrue(result.converged, testCase.id)
            for (key, expected) in testCase.expected {
                let actual = try XCTUnwrap(result.value(forExpectedKey: key), key)
                XCTAssertEqual(actual, expected, accuracy: 1e-5, "\(testCase.id) \(key)")
            }
        }
        XCTAssertEqual(cases[1].result().afterAllocations, [8, 8])
    }

    func testOneCellSevenAntsHasNoSelfCongestion() {
        let plan = TransportPlanner.plan(walkable: points([(0, 0), (1, 0)]), sinks: points([(1, 0)]),
                                         demands: [Demand(id: "food", starts: points([(0, 0)]), ants: 7)])
        XCTAssertEqual(plan.tripSeconds, [4.0])
        XCTAssertEqual(plan.rate * 60, 210, accuracy: 1e-9)
        XCTAssertTrue(plan.loads.isEmpty)
    }

    func testMultipleSourcesShareCorridorCapacity() {
        // 两个装货口共用中间一格：8 + 8 只，必须按 16 只计拥堵。
        let cells = points([(0, 0), (0, 1), (1, 0), (2, 0)])
        let plan = TransportPlanner.plan(walkable: cells, sinks: points([(2, 0)]), demands: [
            Demand(id: "a", starts: points([(0, 0)]), ants: 8),
            Demand(id: "b", starts: points([(0, 1)]), ants: 8),
        ])
        XCTAssertEqual(plan.loads[GridPoint(1, 0)], 16)
        XCTAssertEqual(plan.tripSeconds, [6.0, 7.0])
        XCTAssertEqual(plan.rate, 16.0 / 6.0 + 16.0 / 7.0, accuracy: 1e-12)
    }

    func testDisconnectedSourceDoesNotGenerateIncome() {
        let plan = TransportPlanner.plan(walkable: points([(0, 0), (2, 0)]), sinks: points([(2, 0)]),
                                         demands: [Demand(id: "a", starts: points([(0, 0)]), ants: 7)])
        XCTAssertEqual(plan.rate, 0)
        XCTAssertTrue(plan.converged)
    }

    func testDeterministicBoundedMonotonicRerouting() throws {
        let fixture = try TransportCase.load(from: repoFile("design/transport_cases.json"))[1]
        let cells = Set(fixture.after.walkable), sinks = Set(fixture.after.sinks)
        let demand = [Demand(id: "a", starts: points([(1, 2)]), ants: 16)]
        let first = TransportPlanner.plan(walkable: cells, sinks: sinks, demands: demand)
        // 以不同插入顺序构造同一集合，结果必须完全相同。
        var reversed = Set<GridPoint>()
        for p in cells.sortedByKey().reversed() { reversed.insert(p) }
        let second = TransportPlanner.plan(walkable: reversed, sinks: sinks, demands: demand)
        XCTAssertEqual(first, second)
        XCTAssertLessThan(first.moves, Rules.maxMoves)
        for (a, b) in zip(first.improvements, first.improvements.dropFirst()) { XCTAssertGreaterThan(b, a) }
        XCTAssertEqual(first.routes.map(\.ants).reduce(0, +), 16)
    }

    func testLongerBypassCanRelieveCongestion() {
        // 旁路比主路长两格；应按实际拥堵后的总产量判断，而非只选最短路。
        var before = points([(1, 2), (7, 2)])
        for x in 1...7 { before.insert(GridPoint(x, 1)) }
        var after = before.union(points([(1, 3), (7, 3)]))
        for x in 1...7 { after.insert(GridPoint(x, 4)) }
        let demands = [Demand(id: "food", starts: points([(1, 2)]), ants: 16)]
        let planBefore = TransportPlanner.plan(walkable: before, sinks: points([(7, 2)]), demands: demands)
        let planAfter = TransportPlanner.plan(walkable: after, sinks: points([(7, 2)]), demands: demands)
        XCTAssertTrue(planAfter.converged)
        XCTAssertTrue(planAfter.routes.contains { $0.distance > 8 && $0.ants > 0 })
        XCTAssertGreaterThan(planAfter.rate, planBefore.rate)
        XCTAssertEqual(planAfter.routes.map(\.ants).reduce(0, +), 16)
    }

    func testBFSUsesRowMajorStartsAndUpLeftRightDownNeighbors() {
        // 两个等距起点：必须从 (y, x) 最小的起点出发；等长分支按 上/左/右/下 先到者。
        let walkable = points([(0, 0), (2, 0), (0, 1), (1, 1), (2, 1), (1, 2)])
        let path = Pathfinder.shortestPath(walkable: walkable, starts: points([(2, 0), (0, 0)]),
                                           sinks: points([(1, 2)]))
        XCTAssertEqual(path, [GridPoint(0, 0), GridPoint(0, 1), GridPoint(1, 1), GridPoint(1, 2)])
    }

    func testCandidatePathsAreBoundedAndSorted() {
        var walkable = Set<GridPoint>()
        for x in 0...6 { for y in 0...4 { walkable.insert(GridPoint(x, y)) } }
        let paths = Pathfinder.candidatePaths(walkable: walkable, starts: points([(0, 2)]), sinks: points([(6, 2)]))
        XCTAssertLessThanOrEqual(paths.count, Rules.maxPaths)
        XCTAssertEqual(paths.count, Set(paths.map { $0.map(\.description).joined() }).count)
        for (a, b) in zip(paths, paths.dropFirst()) {
            XCTAssertFalse(Pathfinder.routeLess(b, a), "paths must stay sorted")
        }
    }

    func testStartOnSinkIsOneCellService() {
        let plan = TransportPlanner.plan(walkable: points([(0, 0)]), sinks: points([(0, 0)]),
                                         demands: [Demand(id: "a", starts: points([(0, 0)]), ants: 3)])
        XCTAssertEqual(plan.routes.first?.distance, 1)
        XCTAssertEqual(plan.tripSeconds, [4.0])
    }
}
