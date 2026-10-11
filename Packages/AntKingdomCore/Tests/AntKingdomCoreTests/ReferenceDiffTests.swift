import Foundation
import XCTest
@testable import AntKingdomCore

/// 与 Python 基准的逐项差分：design/reference/core_reference.json
/// 由 `python tools/export_reference.py` 生成。浮点容差 1e-9（相对/绝对取大），整数与路线逐项相等。
final class ReferenceDiffTests: XCTestCase {
    private var reference: [String: Any] = [:]

    override func setUpWithError() throws {
        let data = try Data(contentsOf: repoFile("design/reference/core_reference.json"))
        reference = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    /// JSON 数字统一按 NSNumber 取值（Python 的整数 0 也可能出现在浮点字段）。
    private func double(_ value: Any?) -> Double {
        (value as? NSNumber)?.doubleValue ?? .nan
    }

    private func gridPoints(_ value: Any?) -> [GridPoint] {
        (value as? [[Int]] ?? []).map { GridPoint($0[0], $0[1]) }
    }

    func testFixtureResultsMatchPython() throws {
        let cases = try TransportCase.load(from: repoFile("design/transport_cases.json"))
        let rows = try XCTUnwrap(reference["fixtures"] as? [[String: Any]])
        XCTAssertEqual(rows.count, cases.count)
        for (row, testCase) in zip(rows, cases) {
            let result = testCase.result()
            XCTAssertEqual(row["case"] as? String, testCase.id)
            // Python 输出保留 6 位小数；夹具验收要求误差 ≤ 1e-5 Food/min
            XCTAssertEqual(result.beforeFoodPerMin, double(row["before_food_per_min"]), accuracy: 1e-5)
            XCTAssertEqual(result.afterFoodPerMin, double(row["after_food_per_min"]), accuracy: 1e-5)
            XCTAssertEqual(result.gainPercent, double(row["gain_percent"]), accuracy: 1e-5)
            XCTAssertEqual(result.beforeMaxLoad, row["before_max_load"] as? Int)
            XCTAssertEqual(result.afterMaxLoad, row["after_max_load"] as? Int)
            XCTAssertEqual(result.afterAllocations, row["after_allocations"] as? [Int])
            XCTAssertEqual(result.converged, row["converged"] as? Bool)
        }
    }

    func testTransportScenariosMatchPythonRouteByRoute() throws {
        let rows = try XCTUnwrap(reference["transport_scenarios"] as? [[String: Any]])
        XCTAssertGreaterThanOrEqual(rows.count, 11)
        for row in rows {
            let id = row["id"] as! String
            let demands = (row["demands"] as! [[String: Any]]).map {
                Demand(id: $0["id"] as! String, starts: Set(gridPoints($0["starts"])), ants: $0["ants"] as! Int,
                       extraSeconds: double($0["extra_seconds"]))
            }
            let plan = TransportPlanner.plan(walkable: Set(gridPoints(row["walkable"])),
                                             sinks: Set(gridPoints(row["sinks"])), demands: demands)
            let expected = row["plan"] as! [String: Any]
            let routes = expected["routes"] as! [[String: Any]]
            XCTAssertEqual(plan.routes.count, routes.count, id)
            for (route, want) in zip(plan.routes, routes) {
                XCTAssertEqual(route.sourceId, want["source"] as? String, id)
                XCTAssertEqual(route.cells, gridPoints(want["cells"]), id)
                XCTAssertEqual(route.ants, want["ants"] as? Int, id)
            }
            XCTAssertTrue(isClose(plan.rate, double(expected["rate"])), "\(id) rate \(plan.rate)")
            let trips = (expected["trip_seconds"] as! [NSNumber]).map(\.doubleValue)
            XCTAssertEqual(plan.tripSeconds.count, trips.count, id)
            for (a, b) in zip(plan.tripSeconds, trips) { XCTAssertTrue(isClose(a, b), "\(id) trip") }
            let loads = (expected["loads"] as! [[Int]]).reduce(into: [GridPoint: Int]()) { $0[GridPoint($1[0], $1[1])] = $1[2] }
            XCTAssertEqual(plan.loads, loads, id)
            XCTAssertEqual(plan.moves, expected["moves"] as? Int, id)
            XCTAssertEqual(plan.converged, expected["converged"] as? Bool, id)
            let improvements = (expected["improvements"] as! [NSNumber]).map(\.doubleValue)
            XCTAssertEqual(plan.improvements.count, improvements.count, id)
            for (a, b) in zip(plan.improvements, improvements) { XCTAssertTrue(isClose(a, b), "\(id) improvement") }
        }
    }

    func testPopulationSweepOnFullyDugMapMatchesPython() throws {
        let sweep = try XCTUnwrap(reference["population_sweep"] as? [String: Any])
        let colony = Colony()
        try excavateAll(colony)
        XCTAssertEqual(colony.walkable, Set(gridPoints(sweep["walkable"])))
        for row in sweep["rows"] as! [[String: Any]] {
            let ants = row["ants"] as! Int
            colony.ants = ants
            let plan = try colony.plan()
            XCTAssertEqual(plan.routes.first?.sourceId, row["source"] as? String)
            XCTAssertTrue(isClose(plan.rate, double(row["rate"])), "ants=\(ants)")
            XCTAssertEqual(plan.routes.map(\.ants), row["allocations"] as? [Int], "ants=\(ants)")
            XCTAssertEqual(plan.routes.map(\.cells.count), row["route_lengths"] as? [Int], "ants=\(ants)")
            XCTAssertEqual(plan.moves, row["moves"] as? Int, "ants=\(ants)")
        }
    }

    private func assertState(_ colony: Colony, _ want: [String: Any], _ label: String,
                             file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(isClose(colony.elapsed, double(want["elapsed"])), "\(label) elapsed", file: file, line: line)
        XCTAssertTrue(isClose(colony.food, double(want["food"])), "\(label) food \(colony.food)", file: file, line: line)
        XCTAssertEqual(colony.ants, want["ants"] as? Int, "\(label) ants", file: file, line: line)
        let larvae = (want["larvae"] as! [NSNumber]).map(\.doubleValue)
        XCTAssertEqual(colony.larvae.count, larvae.count, "\(label) larvae", file: file, line: line)
        for (a, b) in zip(colony.larvae, larvae) {
            XCTAssertTrue(isClose(a, b), "\(label) larva", file: file, line: line)
        }
        XCTAssertTrue(isClose(colony.hauled, double(want["hauled"])), "\(label) hauled", file: file, line: line)
        XCTAssertTrue(isClose(colony.spent, double(want["spent"])), "\(label) spent", file: file, line: line)
        XCTAssertEqual(colony.refills, want["refills"] as? Int, "\(label) refills", file: file, line: line)
        XCTAssertTrue(isClose(colony.refillLeft, double(want["refill_left"])), "\(label) refill_left",
                      file: file, line: line)
        XCTAssertEqual(colony.nextPatch, want["next_patch"] as? Int, "\(label) next_patch", file: file, line: line)
        let remaining = want["remaining"] as! [Any]
        for (state, value) in zip(colony.sources, remaining) {
            if let number = value as? NSNumber {
                XCTAssertTrue(isClose(state.remaining ?? -1, number.doubleValue), "\(label) remaining \(state.id)",
                              file: file, line: line)
            } else {
                XCTAssertNil(state.remaining, "\(label) remaining \(state.id)", file: file, line: line)
            }
        }
    }

    /// 600 秒回放逐秒比对（PRD 6.2；TECHNICAL_HANDOFF 第 4 章“逐步断言”）。
    func testReplayTraceMatchesPythonEverySecond() throws {
        let replay = try XCTUnwrap(reference["replay"] as? [String: Any])
        let trace = replay["trace"] as! [[String: Any]]
        XCTAssertEqual(trace.count, 600)
        var compared = 0
        let (colony, summary) = try ScriptedReplay.run { colony, second in
            let want = trace[second]
            self.assertState(colony, want, "t=\(second)")
            XCTAssertEqual(!colony.pantry.isEmpty, want["pantry_built"] as? Bool, "t=\(second) pantry")
            XCTAssertEqual(colony.activeSourceId, want["active_source"] as? String, "t=\(second) source")
            // 过程守恒：容量与人口
            XCTAssertLessThanOrEqual(colony.food, colony.capacity + 1e-9)
            XCTAssertLessThanOrEqual(colony.ants + colony.larvae.count, Rules.populationCap)
            XCTAssertEqual(colony.hauled - colony.spent, colony.food, accuracy: 1e-7)
            compared += 1
        }
        XCTAssertEqual(compared, 600)
        let want = replay["summary"] as! [String: Any]
        XCTAssertEqual(summary.ants, want["ants"] as? Int)
        XCTAssertEqual(summary.refills, want["refills"] as? Int)
        XCTAssertEqual(colony.capacity, double(want["capacity"]))
    }

    func testOfflineScenariosMatchPython() throws {
        let rows = try XCTUnwrap(reference["offline"] as? [[String: Any]])
        for row in rows {
            let id = row["id"] as! String
            let colony = Colony()
            try connectCookie(colony)
            switch id {
            case "offline_240": try check(colony.offline(240), row)
            case "offline_3600": try check(colony.offline(3600), row)
            case "offline_7200": try check(colony.offline(7200), row)
            case "online_quarter_240": try colony.advance(240, efficiency: 0.25)
            case "online_full_240": try colony.advance(240)
            default: XCTFail("unknown offline scenario \(id)")
            }
            assertState(colony, row["state"] as! [String: Any], id)
        }
    }

    private func check(_ result: OfflineResult, _ row: [String: Any]) {
        let want = row["result"] as! [String: Any]
        XCTAssertTrue(isClose(result.netFood, double(want["net_food"])))
        XCTAssertTrue(isClose(result.hauledFood, double(want["hauled_food"])))
        XCTAssertEqual(result.simulatedSeconds, double(want["simulated_seconds"]))
    }
}
