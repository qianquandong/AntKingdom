import AntKingdomCore
import SpriteKit
import XCTest
@testable import AntKingdom

/// A02-T03（确定性，Codex 10-12 交接第 3 节）：同一批蚂蚁沿 ant_four_way 的蜿蜒路线取货 → 东/南/西/北 → 转弯 → 卸货 → 返程；
/// 另测改路（移 Pantry）、取消移动（路线不变）、满仓。断言每只始终一个身体、至多一份货物、货物在嘴前随身体转向，
/// 无孤立节点；表现层更新前后会话状态（账本）不变——动画到达不是收益事件。
@MainActor
final class AntRouteTests: XCTestCase {
    private func session(_ scenario: DebugScenario) throws -> GameSession {
        let session = GameSession()
        try scenario.apply(to: session)
        _ = session.drainEvents()
        return session
    }

    /// 场景坐标（y 向上 = 地图北）里的移动方向；斜向或静止返回 nil
    private func compass(_ v: CGVector) -> String? {
        guard hypot(v.dx, v.dy) > 0.2 else { return nil }
        if abs(v.dx) > abs(v.dy) * 4 { return v.dx > 0 ? "E" : "W" }
        if abs(v.dy) > abs(v.dx) * 4 { return v.dy > 0 ? "N" : "S" }
        return nil
    }

    private func assertStructure(_ layer: SKNode, ants: Int, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(layer.children.count, ants, "one node per adult ant", file: file, line: line)
        for ant in layer.children {
            XCTAssertEqual(ant.children.filter { $0.name == "body" }.count, 1, file: file, line: line)
            XCTAssertEqual(ant.children.filter { $0.name == "cargo" }.count, 1, "at most one cargo", file: file, line: line)
            XCTAssertEqual(ant.children.count, 2, "no stray nodes", file: file, line: line)
            XCTAssertFalse(ant.hasActions(), file: file, line: line)
            XCTAssertEqual(ant.childNode(withName: "cargo")?.position, CGPoint(x: 11, y: 0), file: file, line: line)
            XCTAssertEqual(ant.childNode(withName: "cargo")?.zRotation, 0, file: file, line: line)
        }
    }

    func testCargoStaysAtTheMouthInAllFourDirections() throws {
        guard ArtLibrary.antFrames() != nil else { throw XCTSkip("A02 ant art not imported") }
        let s = try session(.antFourWay)
        let snapshot = s.snapshot()
        let route = try XCTUnwrap(snapshot.routes.first)
        let before = s.makeState()
        let layer = SKNode()
        var swarm = AntSwarm()
        var last: [ObjectIdentifier: (position: CGPoint, rotation: CGFloat)] = [:]
        var carried = Set<String>(), empty = Set<String>()
        var checked = 0
        var time = 0.0
        while time < route.tripSeconds * 2 {
            swarm.update(layer: layer, snapshot: snapshot, queen: s.map.queenCells, time: time)
            assertStructure(layer, ants: snapshot.ants)
            for ant in layer.children {
                let id = ObjectIdentifier(ant)
                defer { last[id] = (ant.position, ant.zRotation) }
                // 只看同一段直线上的两帧（转角处横向偏移会换边，跨段的位移不代表朝向）
                guard let previous = last[id], abs(previous.rotation - ant.zRotation) < 1e-9 else { continue }
                let move = CGVector(dx: ant.position.x - previous.position.x, dy: ant.position.y - previous.position.y)
                guard let direction = compass(move) else { continue }
                let facing = CGVector(dx: cos(ant.zRotation), dy: sin(ant.zRotation))
                let length = hypot(move.dx, move.dy)
                XCTAssertGreaterThan((move.dx * facing.dx + move.dy * facing.dy) / length, 0.999,
                                     "the body faces where it walks (\(direction))")
                let cargo = try XCTUnwrap(ant.childNode(withName: "cargo"))
                if cargo.isHidden {
                    empty.insert(direction)
                } else {
                    carried.insert(direction)
                    // 货物的世界位置在身体中心前方 11 pt（嘴前），不绕错轴
                    let world = layer.convert(cargo.position, from: ant)
                    // SpriteKit 的节点变换是单精度：允许 0.01 pt 误差（远小于 1 px）
                    XCTAssertEqual(world.x, ant.position.x + facing.dx * 11, accuracy: 0.01)
                    XCTAssertEqual(world.y, ant.position.y + facing.dy * 11, accuracy: 0.01)
                }
                checked += 1
            }
            time += 0.02
        }
        XCTAssertGreaterThan(checked, 100)
        XCTAssertEqual(carried, ["E", "S", "W", "N"], "loaded leg covers four directions")
        XCTAssertEqual(empty, ["E", "S", "W", "N"], "return leg covers four directions")
        XCTAssertEqual(s.makeState(), before, "drawing ants never changes the colony or the ledger")
    }

    func testRouteChangeRebuildsCleanlyCancelKeepsNodesAndFullStorageCarriesNothing() throws {
        let s = try session(.pantryBuilt)
        let layer = SKNode()
        var swarm = AntSwarm()
        var snapshot = s.snapshot()
        swarm.update(layer: layer, snapshot: snapshot, queen: s.map.queenCells, time: 0)
        assertStructure(layer, ants: snapshot.ants)
        // 取消移动：会话没有收到命令，路线不变 → 节点不重建
        let oldNodes = layer.children                       // 强引用：避免已释放对象的地址被新节点复用
        let nodes = oldNodes.map(ObjectIdentifier.init)
        for step in 1...20 {
            swarm.update(layer: layer, snapshot: snapshot, queen: s.map.queenCells, time: Double(step) * 0.1)
        }
        XCTAssertEqual(layer.children.map(ObjectIdentifier.init), nodes, "same ants, nothing rebuilt")
        // 改路：把 Pantry 从 (1,2) 移到 (1,4)，路线变化 → 整组重建，没有残留旧节点
        let routesBefore = snapshot.routes
        let foodBefore = s.colony.food
        XCTAssertEqual(s.apply(.movePantry(topLeft: GridPoint(1, 4))), .pantryMoved(topLeft: GridPoint(1, 4)))
        XCTAssertTrue(s.drainEvents().contains(.pantryMoved))
        snapshot = s.snapshot()
        XCTAssertNotEqual(snapshot.routes, routesBefore)
        XCTAssertEqual(s.colony.food, foodBefore, accuracy: 1e-9, "moving is free; animation adds nothing")
        for step in 0..<50 {
            swarm.update(layer: layer, snapshot: snapshot, queen: s.map.queenCells, time: 3 + Double(step) * 0.1)
            assertStructure(layer, ants: snapshot.ants)
        }
        for old in oldNodes {
            XCTAssertNil(old.parent, "old nodes removed")
            XCTAssertFalse(layer.children.contains { $0 === old }, "no old node reused")
        }
        // 满仓：运输待命，没有任何蚂蚁带货
        let capacity = s.colony.capacity
        try s.debugReplaceState { $0.hauled += capacity - $0.food; $0.food = capacity }
        snapshot = s.snapshot()
        XCTAssertTrue(snapshot.isStorageFull)
        for step in 0..<30 {
            swarm.update(layer: layer, snapshot: snapshot, queen: s.map.queenCells, time: 10 + Double(step) * 0.2)
            assertStructure(layer, ants: snapshot.ants)
            XCTAssertTrue(layer.children.allSatisfy { $0.childNode(withName: "cargo")?.isHidden == true })
        }
    }
}
