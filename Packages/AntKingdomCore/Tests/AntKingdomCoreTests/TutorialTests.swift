import Foundation
import XCTest
@testable import AntKingdomCore

/// C05：首局引导顺序、建仓建议位置、补给刷新提示与旧存档标记兼容。
final class TutorialTests: XCTestCase {
    func testHintSequenceFollowsPlayerProgress() throws {
        let session = GameSession()
        XCTAssertEqual(TutorialGuide.hint(for: session.snapshot()), .dig)
        for p in [GridPoint(2, 4), GridPoint(2, 5), GridPoint(2, 6)] { session.apply(.debugCompleteCell(p)) }
        XCTAssertEqual(TutorialGuide.hint(for: session.snapshot()), .hatching)
        for _ in 0..<(4 * 60) { session.tick(frameDelta: 0.25) }
        XCTAssertGreaterThan(session.colony.ants, 5)
        if session.colony.food < 50 {
            XCTAssertEqual(TutorialGuide.hint(for: session.snapshot()), .saveFood)
        }
        session.apply(.setHatching(false))
        XCTAssertEqual(TutorialGuide.hint(for: session.snapshot()), .pantry)
        for p in [GridPoint(1, 4), GridPoint(1, 5)] { session.apply(.debugCompleteCell(p)) }
        while session.colony.food < 50 { session.tick(frameDelta: 0.25) }
        XCTAssertEqual(session.apply(.buildPantry(topLeft: GridPoint(1, 4))), .pantryBuilt(topLeft: GridPoint(1, 4)))
        XCTAssertEqual(TutorialGuide.hint(for: session.snapshot()), .move)
        session.apply(.debugCompleteCell(GridPoint(2, 3)))
        session.apply(.debugCompleteCell(GridPoint(1, 3)))
        XCTAssertEqual(session.apply(.movePantry(topLeft: GridPoint(1, 3))), .pantryMoved(topLeft: GridPoint(1, 3)))
        XCTAssertTrue(session.flags.pantryMovedOnce)
        XCTAssertNil(TutorialGuide.hint(for: session.snapshot()))
    }

    func testBusyTunnelShowsBypassHint() throws {
        let session = GameSession()
        try DebugScenario.busy.apply(to: session)
        XCTAssertEqual(TutorialGuide.hint(for: session.snapshot()), .bypass)
    }

    func testCompletionHintAfterReplay() throws {
        let session = GameSession()
        try DebugScenario.replay600.apply(to: session)
        XCTAssertEqual(TutorialGuide.hint(for: session.snapshot()), .complete)
    }

    func testSuggestedPantrySpotIsLegalAndNearTheSource() throws {
        let session = GameSession()
        XCTAssertNil(TutorialGuide.suggestedPantrySpot(in: session), "no 2x2 tunnel space at start")
        try DebugScenario.pantryReady.apply(to: session)
        let spot = try XCTUnwrap(TutorialGuide.suggestedPantrySpot(in: session))
        XCTAssertTrue(session.colony.isValidPantryFootprint(topLeft: spot))
        XCTAssertEqual(spot, GridPoint(1, 4))
    }

    func testRefillEmitsFoodArrivedForTheRefilledPatch() throws {
        let session = GameSession()
        try excavateAllInSession(session)
        try session.debugReplaceState { state in
            state.patchRemaining = ["cookie": 0, "sugar": 0]
            state.hatching = false
        }
        _ = session.drainEvents()
        for _ in 0..<(4 * 60) { session.tick(frameDelta: 0.25) }   // 两处都空后整 60 秒刷新
        XCTAssertTrue(session.drainEvents().contains(.foodArrived("sugar")))
        XCTAssertEqual(session.snapshot().sources.first { $0.id == "sugar" }?.remaining, 150)
    }

    func testOldSaveWithoutNewFlagStillDecodes() throws {
        let json = #"{"firstSourceConnected":true,"pantryBuiltOnce":true,"prototypeComplete":false}"#
        let flags = try JSONDecoder().decode(GameState.Flags.self, from: Data(json.utf8))
        XCTAssertTrue(flags.pantryBuiltOnce)
        XCTAssertFalse(flags.pantryMovedOnce)
    }

    private func excavateAllInSession(_ session: GameSession) throws {
        while true {
            let frontier = session.snapshot().frontier.sortedByKey()
            if frontier.isEmpty { return }
            for p in frontier { session.apply(.debugCompleteCell(p)) }
        }
    }
}
