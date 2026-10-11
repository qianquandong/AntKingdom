import Foundation
import XCTest
@testable import AntKingdomCore

/// C01/C03：命令、三次点击、事件、帧率无关推进、状态往返与校验。
final class SessionTests: XCTestCase {
    func testThreeEffectiveTapsOpenACell() {
        let session = GameSession()
        let cell = GridPoint(3, 1)   // 与初始通路 (4,1) 相邻
        XCTAssertEqual(session.apply(.tapSoil(cell)), .tapAccepted(cell, taps: 1))
        XCTAssertEqual(session.apply(.tapSoil(cell)), .tapAccepted(cell, taps: 2))
        XCTAssertFalse(session.colony.walkable.contains(cell))
        XCTAssertEqual(session.apply(.tapSoil(cell)), .cellOpened(cell))
        XCTAssertTrue(session.colony.walkable.contains(cell))
        XCTAssertNil(session.digTaps[cell])
        XCTAssertTrue(session.drainEvents().contains(.cellOpened(cell)))
    }

    func testRejectedTapsDoNotChangeState() {
        let session = GameSession()
        let before = session.makeState()
        for (p, reason) in [((0, 9), RejectReason.notFrontier), ((4, 3), .notSoil), ((7, 5), .notSoil),
                            ((0, 6), .notSoil), ((20, 20), .notSoil), ((4, 1), .notSoil)] {
            XCTAssertEqual(session.apply(.tapSoil(GridPoint(p.0, p.1))), .rejected(reason), "\(p)")
        }
        XCTAssertEqual(session.makeState(), before)
    }

    func testConnectingCookieEmitsConnectedAndSwitchesSource() {
        let session = GameSession()
        for p in [GridPoint(2, 4), GridPoint(2, 5)] {
            for _ in 0..<3 { session.apply(.tapSoil(p)) }
        }
        _ = session.drainEvents()
        for _ in 0..<3 { session.apply(.tapSoil(GridPoint(2, 6))) }
        let events = session.drainEvents()
        XCTAssertTrue(events.contains(.sourceConnected("cookie")))
        XCTAssertTrue(events.contains(.activeSourceChanged(from: "surface", to: "cookie", reason: .connected)))
        XCTAssertFalse(events.contains { if case .routeImproved = $0 { return true }; return false },
                       "new connection is exploration, not optimisation")
        XCTAssertTrue(session.flags.firstSourceConnected)
    }

    func testRouteImprovedOnlyWhenSameSourceGetsFaster() throws {
        let session = GameSession()
        for p in [(2, 4), (2, 5), (2, 6), (1, 4), (1, 5), (2, 3), (1, 3), (2, 2), (1, 2)] {
            session.apply(.debugCompleteCell(GridPoint(p.0, p.1)))
        }
        session.colony.food = 80
        session.colony.hauled = 80
        session.colony.ants = 7
        XCTAssertEqual(session.apply(.buildPantry(topLeft: GridPoint(1, 2))), .pantryBuilt(topLeft: GridPoint(1, 2)))
        _ = session.drainEvents()
        XCTAssertEqual(session.apply(.movePantry(topLeft: GridPoint(1, 4))), .pantryMoved(topLeft: GridPoint(1, 4)))
        let events = session.drainEvents()
        let improvement = events.compactMap { event -> Double? in
            if case .routeImproved("cookie", let percent) = event { return percent }
            return nil
        }.first
        XCTAssertNotNil(improvement)
        XCTAssertGreaterThan(improvement ?? 0, 0)
        // 移回原位：产量下降，不报告改善
        session.apply(.movePantry(topLeft: GridPoint(1, 2)))
        XCTAssertFalse(session.drainEvents().contains { if case .routeImproved = $0 { return true }; return false })
    }

    func testPantryCommandsAreAtomic() {
        let session = GameSession()
        for p in [(2, 4), (2, 5), (2, 6), (1, 4), (1, 5)] { session.apply(.debugCompleteCell(GridPoint(p.0, p.1))) }
        let before = session.makeState()
        XCTAssertEqual(session.apply(.buildPantry(topLeft: GridPoint(1, 4))), .rejected(.notEnoughFood))
        XCTAssertEqual(session.apply(.buildPantry(topLeft: GridPoint(3, 3))), .rejected(.invalidPantrySpace))
        XCTAssertEqual(session.apply(.movePantry(topLeft: GridPoint(1, 4))), .rejected(.noPantryToMove))
        XCTAssertEqual(session.makeState(), before)
        session.colony.food = 60
        session.colony.hauled = 60
        XCTAssertEqual(session.apply(.buildPantry(topLeft: GridPoint(1, 4))), .pantryBuilt(topLeft: GridPoint(1, 4)))
        XCTAssertEqual(session.colony.food, 10)
        XCTAssertEqual(session.apply(.buildPantry(topLeft: GridPoint(1, 4))), .rejected(.pantryAlreadyBuilt))
        XCTAssertEqual(session.colony.food, 10)
        XCTAssertEqual(session.colony.capacity, 1100)
    }

    func testPauseHatchingKeepsExistingEggs() {
        let session = GameSession()
        session.colony.larvae = [12]
        XCTAssertEqual(session.apply(.setHatching(false)), .hatchingChanged(false))
        session.colony.food = 60
        session.colony.hauled = 60
        session.tick(frameDelta: 1.0)
        XCTAssertEqual(session.colony.larvae.count, 1, "no new orders while paused")
        for _ in 0..<12 { session.tick(frameDelta: 1.0) }
        XCTAssertEqual(session.colony.ants, 6, "existing egg still hatches")
        XCTAssertTrue(session.drainEvents().contains(.antsHatched(1)))
    }

    /// TECHNICAL_HANDOFF：30/60/120Hz 不改变收益；同命令时序下结果完全相同。
    func testFrameRateDoesNotChangeEconomy() throws {
        func run(hz: Double) -> GameState {
            let session = GameSession()
            let plan: [(Double, [GridPoint])] = [
                (30, [GridPoint(2, 4), GridPoint(2, 5), GridPoint(2, 6)]),
                (150, [GridPoint(1, 4), GridPoint(1, 5)]),
                (300, [GridPoint(6, 3), GridPoint(6, 2)]),
            ]
            var nextAction = 0
            let frame = 1.0 / hz
            var pantryDone = false
            while session.colony.elapsed < 600 - 1e-9 {
                if nextAction < plan.count, session.colony.elapsed >= plan[nextAction].0 - 1e-9 {
                    for p in plan[nextAction].1 { session.apply(.debugCompleteCell(p)) }
                    nextAction += 1
                }
                if !pantryDone, session.colony.elapsed >= 150 - 1e-9, session.colony.food >= 50 {
                    pantryDone = session.apply(.buildPantry(topLeft: GridPoint(1, 4))) == .pantryBuilt(topLeft: GridPoint(1, 4))
                }
                session.tick(frameDelta: frame)
            }
            var state = session.makeState()
            state.pendingTick = 0
            return state
        }
        let at60 = run(hz: 60)
        XCTAssertEqual(run(hz: 30), at60)
        XCTAssertEqual(run(hz: 120), at60)
        XCTAssertEqual(at60.ants + at60.larvae.count, 24)
    }

    func testLongFrameHiccupIsCappedNotDoubleCounted() {
        let session = GameSession()
        session.tick(frameDelta: 30)
        XCTAssertEqual(session.colony.elapsed, TickAccumulator.maxFrameDelta, accuracy: 1e-9)
    }

    func testStateRoundTripAfterReplay() throws {
        let session = GameSession()
        for p in [(2, 4), (2, 5), (2, 6)] { session.apply(.debugCompleteCell(GridPoint(p.0, p.1))) }
        session.apply(.tapSoil(GridPoint(1, 4)))
        for _ in 0..<(4 * 95) { session.tick(frameDelta: 0.25) }
        session.tick(frameDelta: 0.1)
        let state = session.makeState()
        let data = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(GameState.self, from: data)
        XCTAssertEqual(decoded, state)
        let restored = try GameSession(state: decoded)
        XCTAssertEqual(restored.makeState(), state)
        // 恢复后继续推进，与未中断的会话完全一致
        for _ in 0..<40 {
            session.tick(frameDelta: 0.25)
            restored.tick(frameDelta: 0.25)
        }
        XCTAssertEqual(restored.makeState(), session.makeState())
    }

    func testValidationRejectsCorruptStates() throws {
        let good = GameSession().makeState()
        var cases: [(String, GameState)] = []
        var s = good; s.food = -1; s.hauled = -1; cases.append(("negative food", s))
        s = good; s.ants = 30; cases.append(("over population", s))
        s = good; s.larvae = [10, 10, 10]; cases.append(("too many eggs", s))
        s = good; s.dugCells = [GridPoint(0, 9)]; cases.append(("disconnected dig", s))
        s = good; s.dugCells = [GridPoint(7, 5)]; cases.append(("stone dug", s))
        s = good; s.pantryTopLeft = GridPoint(3, 3); cases.append(("pantry on queen", s))
        s = good; s.food = .nan; cases.append(("nan", s))
        s = good; s.mapVersion = 99; cases.append(("map version", s))
        s = good; s.food = 50; cases.append(("not conserved", s))
        s = good; s.patchRemaining["cookie"] = -3; cases.append(("negative patch", s))
        s = good; s.digTaps = [.init(cell: GridPoint(3, 1), taps: 3)]; cases.append(("bad taps", s))
        for (label, state) in cases {
            XCTAssertThrowsError(try GameSession(state: state), label)
        }
        XCTAssertNoThrow(try GameSession(state: good))
    }

    func testPrototypeCompleteIsReportedOnce() throws {
        let session = GameSession()
        for (second, cells) in ScriptedReplay.actions.sorted(by: { $0.key < $1.key }) {
            while session.colony.elapsed < Double(second) - 1e-9 {
                if session.colony.elapsed >= 150, !session.snapshot().hasPantry, session.colony.food >= 50 {
                    session.apply(.buildPantry(topLeft: GridPoint(1, 4)))
                }
                session.tick(frameDelta: 0.25)
            }
            for p in cells { session.apply(.debugCompleteCell(p)) }
        }
        var complete = 0
        for _ in 0..<(4 * 400) {
            if !session.snapshot().hasPantry, session.colony.food >= 50 {
                session.apply(.buildPantry(topLeft: GridPoint(1, 4)))
            }
            session.tick(frameDelta: 0.25)
            complete += session.drainEvents().filter { $0 == .prototypeComplete }.count
        }
        XCTAssertEqual(complete, 1)
        XCTAssertTrue(session.flags.prototypeComplete)
    }

    func testSnapshotReportsRoutesAndBusyCells() throws {
        let session = GameSession()
        for p in [(2, 4), (2, 5), (2, 6)] { session.apply(.debugCompleteCell(GridPoint(p.0, p.1))) }
        session.colony.ants = 20
        let snapshot = session.snapshot()
        XCTAssertEqual(snapshot.activeSourceId, "cookie")
        XCTAssertEqual(snapshot.routes.map(\.ants).reduce(0, +), 20)
        XCTAssertFalse(snapshot.busyCells.isEmpty, "20 ants on one corridor exceeds the budget of 8")
        XCTAssertTrue(snapshot.busyCells.allSatisfy { (snapshot.loads[$0] ?? 0) > 8 })
        XCTAssertNotNil(snapshot.averageTripSeconds)
        XCTAssertTrue(snapshot.sources.first { $0.id == "sugar" }!.isEmptyPatch)
        XCTAssertGreaterThan(snapshot.expectedFoodPerMinute, 0)
    }

    func testResetRestoresInitialStateButKeepsSettings() {
        let session = GameSession()
        session.apply(.setSound(false))
        session.apply(.debugCompleteCell(GridPoint(3, 1)))
        session.tick(frameDelta: 0.5)
        XCTAssertEqual(session.apply(.reset), .didReset)
        let fresh = GameSession(settings: .init(sound: false, haptics: true)).makeState()
        XCTAssertEqual(session.makeState(), fresh)
    }
}
