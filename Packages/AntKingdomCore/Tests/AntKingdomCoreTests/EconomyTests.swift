import XCTest
@testable import AntKingdomCore

/// 移植 tests/test_economy.py 的 EconomyTests（行为逐条对应）。
final class EconomyTests: XCTestCase {
    var colony: Colony!

    override func setUp() {
        colony = Colony()
    }

    /// 原 Python TransportTests 中的全挖地图人口扫描；依赖 Colony，放在 C03。
    func testFixedGeometryPopulationSweep() throws {
        let colony = Colony()
        try excavateAll(colony)
        for ants in 1...Rules.populationCap {
            colony.ants = ants
            let plan = try colony.plan()
            XCTAssertTrue(plan.converged, "ants=\(ants)")
            XCTAssertGreaterThan(plan.rate, 0, "ants=\(ants)")
            XCTAssertEqual(plan.routes.map(\.ants).reduce(0, +), ants)
        }
    }

    func testNoAutoConnectionAndInfiniteFallback() throws {
        XCTAssertEqual(try colony.plan().sourceRates.map(\.sourceId), ["surface"])
        try colony.advance(10)
        XCTAssertGreaterThan(colony.food, 0)
        XCTAssertEqual(colony.sources[0].remaining, 600)
    }

    func testActualDigConnectsFiniteSource() throws {
        try connectCookie(colony)
        XCTAssertEqual(try colony.plan().sourceRates.map(\.sourceId), ["cookie"])
        let before = colony.sources[0].remaining!
        try colony.advance(10)
        XCTAssertLessThan(colony.sources[0].remaining!, before)
    }

    func testFullStorageDoesNotDepleteSource() throws {
        try connectCookie(colony)
        colony.hatching = false
        colony.food = colony.capacity
        try colony.advance(120)
        XCTAssertEqual(colony.sources[0].remaining, 600)
        XCTAssertEqual(colony.hauled, 0)
    }

    func testPartialStorageOnlyDeductsCreditedFood() throws {
        try connectCookie(colony)
        colony.hatching = false
        colony.food = colony.capacity - 0.5
        try colony.harvest(seconds: 60, efficiency: 1)
        XCTAssertEqual(colony.food, colony.capacity)
        XCTAssertEqual(colony.sources[0].remaining, 599.5)
        XCTAssertEqual(colony.hauled, 0.5)
    }

    func testSourceCannotGoNegative() throws {
        try connectCookie(colony)
        colony.hatching = false
        colony.sources[0].remaining = 0.125
        try colony.harvest(seconds: 60, efficiency: 1)
        XCTAssertEqual(colony.food, 0.125)
        XCTAssertEqual(colony.sources[0].remaining, 0)
    }

    func testRepeatedRefillAfterAllLegalSoilIsDug() throws {
        try excavateAll(colony)
        colony.hatching = false
        let originalWalkable = colony.walkable
        for (expectedId, expectedAmount) in [("sugar", 150.0), ("cookie", 600.0), ("sugar", 150.0)] {
            colony.sources[0].remaining = 0
            colony.sources[1].remaining = 0
            try colony.advance(60)
            let source = try XCTUnwrap(colony.sources.first { $0.id == expectedId })
            XCTAssertEqual(source.remaining, expectedAmount)
            XCTAssertEqual(colony.walkable, originalWalkable)
        }
        XCTAssertEqual(colony.refills, 3)
    }

    func testUnconnectedRefillRemainsAvailable() throws {
        colony.sources[0].remaining = 0
        try colony.advance(120)
        XCTAssertEqual(colony.sources[1].remaining, 150)
        XCTAssertEqual(try colony.plan().sourceRates.map(\.sourceId), ["surface"])
    }

    func testPantryCostMovementAndRouteGain() throws {
        try connectCookie(colony)
        for p in [(1, 4), (1, 5), (2, 3), (1, 3), (2, 2), (1, 2)] { try colony.dig(GridPoint(p.0, p.1)) }
        colony.ants = 7
        colony.food = 80
        try colony.placePantry(topLeft: GridPoint(1, 2))
        let before = try colony.plan().rate
        XCTAssertEqual(colony.food, 30)
        XCTAssertEqual(colony.capacity, 1100)
        try colony.placePantry(topLeft: GridPoint(1, 4))
        XCTAssertGreaterThan(try colony.plan().rate, before)
        XCTAssertEqual(colony.food, 30)
        XCTAssertEqual(colony.spent, 50)
        XCTAssertTrue(points([(1, 3), (2, 3)]).isSubset(of: colony.walkable))
    }

    func testRejectIllegalDig() {
        for p in [(0, 9), (4, 3), (7, 5), (0, 6), (20, 20)] {
            XCTAssertThrowsError(try colony.dig(GridPoint(p.0, p.1)), "\(p)")
        }
    }

    func testRejectIllegalOrUnaffordablePantry() throws {
        for p in [(0, 9), (3, 3), (4, 0)] {
            XCTAssertThrowsError(try colony.placePantry(topLeft: GridPoint(p.0, p.1)), "\(p)")
        }
        try connectCookie(colony)
        try colony.dig(GridPoint(1, 4))
        try colony.dig(GridPoint(1, 5))
        XCTAssertThrowsError(try colony.placePantry(topLeft: GridPoint(1, 4))) { error in
            XCTAssertEqual(error as? ColonyError, .notEnoughFood)
        }
        XCTAssertEqual(colony.food, 0)
        XCTAssertTrue(colony.pantry.isEmpty)
    }

    func testOfflineMatchesSameEfficiencyOnline() throws {
        try connectCookie(colony)
        let other = colony.copy()
        let result = try colony.offline(240)
        try other.advance(240, efficiency: 0.25)
        XCTAssertEqual(colony.food, other.food)
        XCTAssertEqual(colony.ants, other.ants)
        XCTAssertEqual(colony.larvae, other.larvae)
        XCTAssertEqual(colony.sources, other.sources)
        XCTAssertEqual(result.hauledFood, colony.hauled, accuracy: 1e-9)
    }

    func testOfflineIsNotQuarterOfFullEfficiencySimulation() throws {
        try connectCookie(colony)
        let other = colony.copy()
        try colony.offline(240)
        try other.advance(240)
        // 孵化和容量是非线性的：在线完整运行结果不能事后乘 25%。
        XCTAssertGreaterThan(abs(colony.hauled - other.hauled * 0.25), 0.005)
    }

    func testOfflineCapAppliesToAllClocks() throws {
        try connectCookie(colony)
        let other = colony.copy()
        let result = try colony.offline(7200)
        try other.offline(3600)
        XCTAssertEqual(result.simulatedSeconds, 3600)
        XCTAssertEqual(colony.elapsed, 3600)
        XCTAssertEqual(colony.food, other.food)
        XCTAssertEqual(colony.ants, other.ants)
        XCTAssertEqual(colony.refills, other.refills)
    }

    func testPopulationSlotsAndConservation() throws {
        try connectCookie(colony)
        for _ in 0..<600 {
            try colony.advance(1)
            XCTAssertLessThanOrEqual(colony.larvae.count, 2)
            XCTAssertLessThanOrEqual(colony.ants + colony.larvae.count, 24)
            XCTAssertGreaterThanOrEqual(colony.food, 0)
            XCTAssertLessThanOrEqual(colony.food, colony.capacity)
            XCTAssertEqual(colony.hauled, colony.food + colony.spent, accuracy: 1e-7)
        }
    }

    func testPauseHatchingAllowsSavingForPantry() throws {
        try connectCookie(colony)
        colony.hatching = false
        try colony.advance(60)
        XCTAssertGreaterThanOrEqual(colony.food, Rules.pantryCost)
        XCTAssertEqual(colony.ants, 5)
        XCTAssertTrue(colony.larvae.isEmpty)
    }

    func testInvalidTimeInputs() {
        for duration in [-1.0, .infinity, .nan] {
            XCTAssertThrowsError(try colony.offline(duration))
        }
        for (duration, efficiency) in [(-1.0, 1.0), (.infinity, 1.0), (1.0, -1.0), (1.0, 1.1), (1.0, .nan)] {
            XCTAssertThrowsError(try colony.advance(duration, efficiency: efficiency))
        }
    }

    func testFixedReplayResourcesBalance() throws {
        let (_, summary) = try ScriptedReplay.run()
        XCTAssertEqual(summary.ants, 24)
        XCTAssertEqual(summary.larvae, 0)
        XCTAssertEqual(summary.food, 1100, accuracy: 1e-6)
        XCTAssertEqual(summary.capacity, 1100)
        XCTAssertEqual(summary.hauled, 1530, accuracy: 1e-6)
        XCTAssertEqual(summary.spent, 430)
        XCTAssertEqual(summary.refills, 2)
        XCTAssertEqual(summary.conservationError, 0, accuracy: 1e-6)
    }
}
