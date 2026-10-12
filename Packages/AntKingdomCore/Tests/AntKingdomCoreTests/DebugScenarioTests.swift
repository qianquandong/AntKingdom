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

    /// A01-02：通路截图场景让四邻遮罩 1–15 全部出现在可见通路格上（N1 E2 S4 W8，N = y − 1）。
    func testTunnelGalleryCoversEveryReachableMask() throws {
        let session = GameSession()
        try DebugScenario.tunnelGallery.apply(to: session)
        let open = session.colony.walkable
        XCTAssertTrue(DebugScenario.tunnelGalleryCells.allSatisfy(open.contains), "every gallery cell was dug")
        var seen = Set<Int>()
        for p in open where session.map.tile(at: p) == .soil || session.map.tile(at: p) == .tunnel {
            var mask = 0
            if open.contains(GridPoint(p.x, p.y - 1)) { mask |= 1 }
            if open.contains(GridPoint(p.x + 1, p.y)) { mask |= 2 }
            if open.contains(GridPoint(p.x, p.y + 1)) { mask |= 4 }
            if open.contains(GridPoint(p.x - 1, p.y)) { mask |= 8 }
            seen.insert(mask)
        }
        XCTAssertEqual(seen, Set(1...15))
    }
}
