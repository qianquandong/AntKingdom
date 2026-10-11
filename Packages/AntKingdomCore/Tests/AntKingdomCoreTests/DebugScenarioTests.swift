import XCTest
@testable import AntKingdomCore

final class DebugScenarioTests: XCTestCase {
    func testEveryScenarioProducesAValidState() throws {
        for scenario in DebugScenario.allCases {
            let session = GameSession()
            try scenario.apply(to: session)
            XCTAssertNoThrow(try GameSession(state: session.makeState()), scenario.rawValue)
        }
    }

    func testScenarioContents() throws {
        let session = GameSession()
        try DebugScenario.busy.apply(to: session)
        XCTAssertFalse(session.snapshot().busyCells.isEmpty)
        try DebugScenario.pantryReady.apply(to: session)
        XCTAssertEqual(session.apply(.buildPantry(topLeft: GridPoint(1, 4))), .pantryBuilt(topLeft: GridPoint(1, 4)))
        try DebugScenario.pantryBuilt.apply(to: session)
        XCTAssertEqual(session.colony.pantry, Colony.pantryCells(topLeft: GridPoint(1, 2)))
        XCTAssertEqual(session.colony.food, 30)
        _ = session.drainEvents()
        session.apply(.movePantry(topLeft: GridPoint(1, 4)))
        XCTAssertTrue(session.drainEvents().contains { if case .routeImproved = $0 { return true }; return false })
        try DebugScenario.replay600.apply(to: session)
        XCTAssertEqual(session.colony.ants, 24)
        XCTAssertEqual(session.colony.capacity, 1100)
        XCTAssertTrue(session.flags.prototypeComplete)
    }

    func testRejectedDebugReplacementLeavesStateUntouched() {
        let session = GameSession()
        let before = session.makeState()
        XCTAssertThrowsError(try session.debugReplaceState { $0.food = 99 })   // 不守恒
        XCTAssertEqual(session.makeState(), before)
    }
}
