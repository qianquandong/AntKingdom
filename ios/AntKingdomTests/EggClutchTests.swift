import AntKingdomCore
import SpriteKit
import XCTest
@testable import AntKingdom

/// D-16 表现层：EggClutch 按核心模型的槽绘制卵。断言具体卵节点的身份（同一对象）、位置与大小，
/// 而不只检查总数（Codex 10-12 交接 E01–E04）。模型侧见 AntKingdomCoreTests.D16EggSlotTests。
@MainActor
final class EggClutchTests: XCTestCase {
    private let queen = CGRect(x: 100, y: -300, width: 144, height: 96)   // 场景坐标（y 向上）
    private func center(_ slot: Int) -> CGPoint { CGPoint(x: 100 + 22 + CGFloat(slot) * 18, y: -300 + 96 - 22) }

    private func session(_ scenario: DebugScenario, _ transform: ((inout GameState) -> Void)? = nil) throws -> GameSession {
        let session = GameSession()
        try scenario.apply(to: session)
        if let transform { try session.debugReplaceState(transform) }
        _ = session.drainEvents()
        return session
    }

    private func render(_ clutch: inout EggClutch, _ layer: SKNode, _ s: GameSession) {
        let snapshot = s.snapshot()
        clutch.update(layer: layer, queen: queen, eggs: snapshot.eggs, slots: snapshot.eggSlots)
    }

    /// 逐 0.25 秒推进并每步渲染（相当于每帧）
    private func run(_ clutch: inout EggClutch, _ layer: SKNode, _ s: GameSession, seconds: Double) {
        for _ in 0..<Int((seconds / Rules.tick).rounded()) {
            s.tick(frameDelta: Rules.tick)
            render(&clutch, layer, s)
        }
    }

    func testE01SecondEggNeverMovesWhenTheFirstHatches() throws {
        let s = try session(.eggsTwo)
        let layer = SKNode()
        var clutch = EggClutch()
        render(&clutch, layer, s)
        let right = try XCTUnwrap(clutch.nodes[1])
        XCTAssertEqual(right.position, center(1))
        XCTAssertEqual(clutch.nodes[0]?.position, center(0))
        for _ in 0..<100 {                                   // 25 秒，每帧检查右卵
            s.tick(frameDelta: Rules.tick)
            render(&clutch, layer, s)
            if let node = clutch.nodes[1] {
                XCTAssertTrue(node === right, "the right egg keeps its node until it hatches")
                XCTAssertEqual(node.position, center(1), "no 18 pt shift")
                if let sprite = node as? SKSpriteNode { XCTAssertEqual(sprite.size, EggClutch.size) }
            }
            XCTAssertEqual(layer.children.count, clutch.nodes.count, "no orphan or duplicate egg nodes")
        }
        XCTAssertTrue(clutch.nodes.isEmpty)
        XCTAssertNil(right.parent, "removed only when it hatched")
        XCTAssertEqual(s.colony.ants, 7)
    }

    func testE02NewEggTakesTheFreedLeftSlotAndTheRightEggIsUntouched() throws {
        let s = try session(.eggsRefill)
        let layer = SKNode()
        var clutch = EggClutch()
        render(&clutch, layer, s)
        let left = try XCTUnwrap(clutch.nodes[0])
        let right = try XCTUnwrap(clutch.nodes[1])
        run(&clutch, layer, s, seconds: 15)
        let newLeft = try XCTUnwrap(clutch.nodes[0])
        XCTAssertFalse(newLeft === left, "the hatched egg's node is gone; the new order has its own node")
        XCTAssertNil(left.parent)
        XCTAssertTrue(clutch.nodes[1] === right, "the right egg keeps its identity")
        XCTAssertEqual(right.position, center(1))
        XCTAssertEqual(newLeft.position, center(0))
        XCTAssertEqual(layer.children.count, 2)
    }

    func testE03HatchAndNewOrderInTheSameUpdateReplacesTheNodeEvenThoughCountIsUnchanged() throws {
        let s = try session(.connected) { state in
            state.larvae = [10, 0.25]
            state.eggSlots = [1, 0]
            state.hauled += 50 - state.food
            state.food = 50
            state.hatching = true
        }
        let layer = SKNode()
        var clutch = EggClutch()
        render(&clutch, layer, s)
        let oldLeft = try XCTUnwrap(clutch.nodes[0])
        let right = try XCTUnwrap(clutch.nodes[1])
        run(&clutch, layer, s, seconds: Rules.tick)
        XCTAssertEqual(s.snapshot().eggs.count, 2, "count unchanged")
        XCTAssertFalse(clutch.nodes[0] === oldLeft, "old egg removed, new egg drawn")
        XCTAssertNil(oldLeft.parent)
        XCTAssertTrue(clutch.nodes[1] === right)
        XCTAssertEqual(layer.children.count, 2, "no duplicate nodes")
    }

    func testE04BothHatchTogetherAndTwoNewEggsAppearOnce() throws {
        let s = try session(.connected) { state in
            state.larvae = [0.25, 0.25]
            state.eggSlots = [0, 1]
            state.hauled += 60 - state.food
            state.food = 60
            state.hatching = true
        }
        let layer = SKNode()
        var clutch = EggClutch()
        render(&clutch, layer, s)
        let old = [clutch.nodes[0], clutch.nodes[1]]
        run(&clutch, layer, s, seconds: Rules.tick)
        XCTAssertEqual(layer.children.count, 2)
        for slot in 0...1 {
            XCTAssertFalse(clutch.nodes[slot] === old[slot], "slot \(slot) holds a new egg")
            XCTAssertEqual(clutch.nodes[slot]?.position, center(slot))
        }
    }

    func testReadyStateOnlySwapsTheTexture() throws {
        guard let textures = ArtLibrary.eggTextures() else { throw XCTSkip("egg art not imported") }
        let s = try session(.eggsTwo)
        let layer = SKNode()
        var clutch = EggClutch()
        render(&clutch, layer, s)
        let left = try XCTUnwrap(clutch.nodes[0] as? SKSpriteNode)
        XCTAssertTrue(left.texture === textures.normal)
        run(&clutch, layer, s, seconds: 18)                  // 剩 2 秒
        XCTAssertTrue(clutch.nodes[0] === left)
        XCTAssertTrue(left.texture === textures.ready)
        XCTAssertEqual(left.size, EggClutch.size)
        XCTAssertEqual(left.position, center(0))
    }
}
