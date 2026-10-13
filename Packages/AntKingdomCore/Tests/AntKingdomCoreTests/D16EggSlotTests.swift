import Foundation
import XCTest
@testable import AntKingdomCore

/// D-16（Codex 10-12 交接）：每枚卵从下单到孵化固定占一个槽，先孵化只移除自己，另一枚留在原槽；
/// 新订单占编号最小的空槽；槽随存档保存（可选字段），旧存档按顺序分配一次。槽只影响表现，不改经济。
/// 节点位置与身份（GameScene 的 EggClutch）另见 AntKingdomTests。
final class D16EggSlotTests: XCTestCase {
    private func session(_ scenario: DebugScenario = .connected,
                         _ transform: ((inout GameState) -> Void)? = nil) throws -> GameSession {
        let session = GameSession()
        try scenario.apply(to: session)
        if let transform { try session.debugReplaceState(transform) }
        _ = session.drainEvents()
        return session
    }

    /// (槽, 剩余秒) 按卵的创建顺序
    private func eggs(_ s: GameSession) -> [(slot: Int, remaining: Double)] {
        s.colony.eggs.map { ($0.slot, $0.remaining) }
    }

    private func tick(_ s: GameSession, seconds: Double) {
        for _ in 0..<Int((seconds / Rules.tick).rounded()) { s.tick(frameDelta: Rules.tick) }
    }

    // MARK: E01 顺次孵化

    func testE01RightEggKeepsItsSlotWhenTheLeftOneHatches() throws {
        let s = try session(.eggsTwo)                       // 剩余 20 / 25 秒，孵化订单关闭
        XCTAssertEqual(eggs(s).map(\.slot), [0, 1])
        XCTAssertEqual(s.colony.ants, 5)
        tick(s, seconds: 20)
        XCTAssertEqual(eggs(s).map(\.slot), [1], "the right egg stays in the right slot")
        XCTAssertEqual(eggs(s).first?.remaining ?? 0, 5, accuracy: 1e-9)
        XCTAssertEqual(s.colony.ants, 6)
        tick(s, seconds: 5)
        XCTAssertTrue(eggs(s).isEmpty)
        XCTAssertEqual(s.colony.ants, 7)
        XCTAssertEqual(s.snapshot().eggSlots, [])
    }

    // MARK: E02 新订单填空槽

    func testE02NewOrderFillsTheFreedSlotWithoutTouchingTheOtherEgg() throws {
        let s = try session(.eggsRefill)                    // 槽 0 剩 15 秒、槽 1 剩 25 秒，订单开启
        tick(s, seconds: 15)
        XCTAssertEqual(eggs(s).map(\.slot), [1, 0], "old right egg first, new egg in the freed left slot")
        XCTAssertEqual(eggs(s)[0].remaining, 10, accuracy: 1e-9, "the right egg's timer is not reset")
        XCTAssertEqual(eggs(s)[1].remaining, Rules.hatchSeconds, accuracy: 1e-9)
        XCTAssertEqual(s.snapshot().eggSlots, [1, 0])
    }

    // MARK: E03 同一步孵化一枚并新增一枚（数量不变）

    func testE03HatchAndNewOrderInOneStepKeepsCountButReplacesTheEgg() throws {
        let s = try session(.connected) { state in
            state.larvae = [10, 0.25]
            state.eggSlots = [1, 0]
            state.hauled += 50 - state.food
            state.food = 50
            state.hatching = true
        }
        let ants = s.colony.ants
        s.tick(frameDelta: Rules.tick)
        XCTAssertEqual(eggs(s).count, 2, "count unchanged")
        XCTAssertEqual(eggs(s).map(\.slot), [1, 0])
        XCTAssertEqual(eggs(s)[0].remaining, 9.75, accuracy: 1e-9, "the slot-1 egg continues")
        XCTAssertEqual(eggs(s)[1].remaining, Rules.hatchSeconds, accuracy: 1e-9, "a new egg took slot 0")
        XCTAssertEqual(s.colony.ants, ants + 1, "hatched exactly once")
    }

    // MARK: E04 同时完成

    func testE04BothHatchTogetherThenNewOrdersTakeSlotsZeroAndOne() throws {
        let s = try session(.connected) { state in
            state.larvae = [0.25, 0.25]
            state.eggSlots = [1, 0]
            state.hauled += 60 - state.food
            state.food = 60
            state.hatching = true
        }
        let ants = s.colony.ants
        s.tick(frameDelta: Rules.tick)
        XCTAssertEqual(s.colony.ants, ants + 2, "each egg hatches once")
        XCTAssertEqual(eggs(s).map(\.slot), [0, 1], "new orders take the lowest free slots")
        XCTAssertTrue(eggs(s).allSatisfy { abs($0.remaining - Rules.hatchSeconds) < 1e-9 })
        XCTAssertLessThanOrEqual(eggs(s).count, Rules.larvaSlots)
        XCTAssertEqual(s.colony.spent, 40, accuracy: 1e-9)
    }

    // MARK: E05 关订单 / 满仓：已有卵继续

    func testE05PausedOrdersAndFullStorageDoNotFreezeExistingEggs() throws {
        let s = try session(.connected) { state in
            state.larvae = [4, 8]
            state.eggSlots = [0, 1]
            state.hauled += 100 - state.food
            state.food = 100                                 // 满仓（无 Pantry 容量 100）
            state.hatching = false
        }
        XCTAssertTrue(s.colony.isStorageFull)
        tick(s, seconds: 4)
        XCTAssertEqual(eggs(s).map(\.slot), [1])
        tick(s, seconds: 4)
        XCTAssertTrue(eggs(s).isEmpty, "existing eggs finish while orders are off and storage is full")
        XCTAssertEqual(s.colony.larvae.count, 0, "no new orders while paused")
    }

    // MARK: E06 生命周期与存档

    func testE06SlotsSurviveSaveAndLoad() throws {
        let s = try session(.eggsTwo)
        tick(s, seconds: 20)                                 // 只剩右卵（槽 1）
        let state = s.makeState()
        XCTAssertEqual(state.eggSlots, [1])
        let data = try JSONEncoder().encode(state)
        let restored = try GameSession(state: JSONDecoder().decode(GameState.self, from: data))
        XCTAssertEqual(restored.colony.eggs, s.colony.eggs, "identity, count and timer restored")
        XCTAssertEqual(restored.makeState(), state)
    }

    func testE06OldSaveWithoutSlotsIsAssignedOnceInOrder() throws {
        let data = try Data(contentsOf: repoFile("Packages/AntKingdomCore/Tests/AntKingdomCoreTests/Fixtures/save_v1_sample.json"))
        let envelope = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let stateJSON = try JSONSerialization.data(withJSONObject: envelope["state"]!)
        let state = try JSONDecoder().decode(GameState.self, from: stateJSON)
        XCTAssertNil(state.eggSlots, "old save has no slot key")
        let s = try GameSession(state: state)
        XCTAssertEqual(eggs(s).map(\.slot), [0, 1])
        XCTAssertEqual(s.colony.larvae, [2, 14], "timers unchanged")
        XCTAssertEqual(s.makeState().eggSlots, [0, 1], "saved from now on")
    }

    func testE06OfflineSettlementKeepsTheSurvivorsSlot() throws {
        let s = try session(.eggsTwo)
        tick(s, seconds: 20)
        _ = try s.settleOffline(seconds: 2)                  // 离线 2 秒（25% 效率不影响孵化倒计时）
        XCTAssertEqual(eggs(s).map(\.slot), [1])
        XCTAssertEqual(eggs(s)[0].remaining, 3, accuracy: 1e-9)
    }

    func testInvalidStoredSlotsFallBackToOrderWithoutRejectingTheSave() throws {
        for bad in [[0, 0], [2, 1], [0], [-1, 1]] {
            let s = try session(.connected) { state in
                state.larvae = [5, 9]
                state.eggSlots = bad
            }
            XCTAssertEqual(eggs(s).map(\.slot), [0, 1], "\(bad)")
        }
    }

    // MARK: 不变量

    /// 槽只是表现：600 秒脚本流程中任何时刻，卵数 ≤ 2、槽在 0…1 且互不重复。
    /// 孵化时间、人口、Food、花费与 Python 基准一致由 ReferenceDiffTests 对照（larvae 仍按创建顺序导出）。
    func testSlotsStayUniqueAndInRangeThroughTheScriptedSession() throws {
        let s = try session(.replay300)
        for _ in 0..<300 {
            tick(s, seconds: 1)
            let slots = s.colony.eggs.map(\.slot)
            XCTAssertLessThanOrEqual(slots.count, Rules.larvaSlots)
            XCTAssertEqual(Set(slots).count, slots.count)
            XCTAssertTrue(slots.allSatisfy { (0..<Rules.larvaSlots).contains($0) })
            XCTAssertEqual(s.snapshot().eggSlots, slots)
        }
    }
}

/// A02-T03 的路线前提：ant_four_way 只有一条 Cookie → Queen 通路，按设计的蜿蜒格序。
final class AntFourWayScenarioTests: XCTestCase {
    func testTheOnlyRouteWindsThroughEveryDugCell() throws {
        let session = GameSession()
        try DebugScenario.antFourWay.apply(to: session)
        let routes = session.snapshot().routes
        XCTAssertEqual(routes.count, 1, "\(routes.map(\.sourceId))")
        let route = try XCTUnwrap(routes.first)
        XCTAssertEqual(route.sourceId, "cookie")
        for cell in DebugScenario.antFourWayCells {
            XCTAssertTrue(route.cells.contains(cell), "route passes \(cell)")
        }
        // 相邻两格的方向覆盖东南西北
        var steps = Set<String>()
        for (a, b) in zip(route.cells, route.cells.dropFirst()) {
            switch (b.x - a.x, b.y - a.y) {
            case (1, 0): steps.insert("E")
            case (-1, 0): steps.insert("W")
            case (0, 1): steps.insert("S")
            case (0, -1): steps.insert("N")
            default: XCTFail("route jumps from \(a) to \(b)")
            }
        }
        XCTAssertEqual(steps, ["E", "W", "S", "N"])
    }
}
