import AntKingdomCore
import SpriteKit
import UIKit

/// 蚂蚁动画：沿已分配路线循环“装货 2s → 带粮去程 → 卸货 1s → 空手回程”，周期等于逻辑 Trip。
/// 纯表现：到达卸货点不发 Food，收入只来自 Colony 的平均流量账本（PRD 4.1）。
/// 满仓时搬运表现转为待命（站在装货点不动）。
@MainActor
struct AntSwarm {
    private struct Ant {
        let node: SKNode
        /// 正式帧资源存在时的身体精灵（idle2 / walk6 / carry6）；占位时为 nil
        let body: SKSpriteNode?
        let cargo: SKNode
        let route: Int
        let phase: Double
        let lateral: CGFloat
    }

    private var ants: [Ant] = []
    private var routes: [SessionSnapshot.RouteView] = []
    private var polylines: [[CGPoint]] = []
    private var cumulative: [[CGFloat]] = []
    private var adultCount = -1

    mutating func update(layer: SKNode, snapshot: SessionSnapshot, queen: Set<GridPoint>, time: TimeInterval) {
        if snapshot.routes != routes || snapshot.ants != adultCount {
            rebuild(layer: layer, snapshot: snapshot)
        }
        let queenFrame = MapGeometry.frame(of: queen)
        for (index, ant) in ants.enumerated() {
            guard ant.route >= 0, ant.route < routes.count else {
                // 无活跃路线：在 Queen Chamber 内缓慢徘徊
                let angle = time * 0.4 + Double(index)
                ant.node.position = CGPoint(x: queenFrame.midX + CGFloat(cos(angle)) * 30,
                                            y: queenFrame.midY + CGFloat(sin(angle * 1.3)) * 12)
                ant.node.zRotation = CGFloat(angle) + .pi / 2
                ant.cargo.isHidden = true
                animate(ant, pose: .walk, time: time)
                continue
            }
            let route = routes[ant.route]
            if snapshot.isStorageFull {
                place(ant, fraction: 0, carrying: false, returning: false)
                animate(ant, pose: .idle, time: time)
                continue
            }
            let trip = max(route.tripSeconds, 3.01)
            let move = (trip - 3) / 2
            let t = (time / trip + ant.phase).truncatingRemainder(dividingBy: 1) * trip
            switch t {
            case ..<2:
                place(ant, fraction: 0, carrying: t > 1.2, returning: false)
                animate(ant, pose: .idle, time: time)
            case ..<(2 + move):
                place(ant, fraction: (t - 2) / move, carrying: true, returning: false)
                animate(ant, pose: .carry, time: time)
            case ..<(3 + move):
                place(ant, fraction: 1, carrying: t < 2.6 + move, returning: true)
                animate(ant, pose: .idle, time: time)
            default:
                place(ant, fraction: 1 - (t - 3 - move) / move, carrying: false, returning: true)
                animate(ant, pose: .walk, time: time)
            }
        }
    }

    /// 按姿态播帧（idle 4fps，walk/carry 10fps），帧序 1→N→1 循环。只换纹理：不加 SKAction、
    /// 不改节点位置（世界坐标只由 place 按路线计算），身体只有一个精灵。
    private func animate(_ ant: Ant, pose: AssetNames.AntPose, time: TimeInterval) {
        guard let body = ant.body, let frames = ArtLibrary.antFrames()?[pose], !frames.isEmpty else { return }
        let fps = pose == .idle ? 4.0 : 10.0
        let index = Int(max(0, (time + ant.phase) * fps)) % frames.count
        if body.texture !== frames[index] { body.texture = frames[index] }
    }

    private func place(_ ant: Ant, fraction: Double, carrying: Bool, returning: Bool) {
        let points = polylines[ant.route]
        let lengths = cumulative[ant.route]
        ant.cargo.isHidden = !carrying
        guard points.count >= 2, let total = lengths.last, total > 0 else {
            ant.node.position = points.first ?? .zero
            return
        }
        let target = CGFloat(min(max(fraction, 0), 1)) * total
        var segment = 1
        while segment < lengths.count - 1, lengths[segment] < target { segment += 1 }
        let a = points[segment - 1], b = points[segment]
        let span = max(lengths[segment] - lengths[segment - 1], 0.001)
        let local = (target - lengths[segment - 1]) / span
        let dx = b.x - a.x, dy = b.y - a.y
        let length = max(hypot(dx, dy), 0.001)
        let normal = CGPoint(x: -dy / length, y: dx / length)
        ant.node.position = CGPoint(x: a.x + dx * local + normal.x * ant.lateral,
                                    y: a.y + dy * local + normal.y * ant.lateral)
        let heading = atan2(dy, dx)
        ant.node.zRotation = returning ? heading + .pi : heading
    }

    private mutating func rebuild(layer: SKNode, snapshot: SessionSnapshot) {
        layer.removeAllChildren()
        ants = []
        routes = snapshot.routes
        adultCount = snapshot.ants
        polylines = routes.map { $0.cells.map(MapGeometry.center(of:)) }
        cumulative = polylines.map { points in
            var total: CGFloat = 0
            var result: [CGFloat] = [0]
            for (a, b) in zip(points, points.dropFirst()) {
                total += hypot(b.x - a.x, b.y - a.y)
                result.append(total)
            }
            return result
        }
        var assigned = 0
        for (routeIndex, route) in routes.enumerated() {
            for i in 0..<route.ants {
                let lateral = CGFloat((i % 3) - 1) * 5
                ants.append(makeAnt(layer: layer, route: routeIndex, phase: Double(i) / Double(route.ants),
                                    lateral: lateral))
                assigned += 1
            }
        }
        for i in assigned..<max(assigned, snapshot.ants) {
            ants.append(makeAnt(layer: layer, route: -1, phase: Double(i), lateral: 0))
        }
    }

    private func makeAnt(layer: SKNode, route: Int, phase: Double, lateral: CGFloat) -> Ant {
        let node = SKNode()
        var body: SKSpriteNode?
        if let frames = ArtLibrary.antFrames(), let first = frames[.walk]?.first {
            // 96 px @3x → 32 pt，中心锚点，朝右（与占位相同的朝向约定）
            let sprite = SKSpriteNode(texture: first, size: CGSize(width: 32, height: 32))
            sprite.name = "body"
            node.addChild(sprite)
            body = sprite
        } else {
            // 占位：三节身体 + 触角，朝右
            for (x, w, h) in [(-6.0, 9.0, 7.0), (0.0, 6.0, 5.0), (5.0, 6.0, 6.0)] {
                let part = SKShapeNode(ellipseOf: CGSize(width: w, height: h))
                part.position = CGPoint(x: x, y: 0)
                part.fillColor = ArtLibrary.Palette.ant
                part.strokeColor = .clear
                node.addChild(part)
            }
            let antenna = CGMutablePath()
            antenna.move(to: CGPoint(x: 7, y: 2)); antenna.addLine(to: CGPoint(x: 11, y: 5))
            antenna.move(to: CGPoint(x: 7, y: -2)); antenna.addLine(to: CGPoint(x: 11, y: -5))
            let antennae = SKShapeNode(path: antenna)
            antennae.strokeColor = ArtLibrary.Palette.ant
            antennae.lineWidth = 1
            node.addChild(antennae)
        }
        // 货物独立一层：父节点局部 (11,0)pt，随父节点一起旋转（不再按世界坐标旋转）；身体帧里没有食物
        let cargo: SKNode
        if let texture = ArtLibrary.texture(AssetNames.cargo) {
            cargo = SKSpriteNode(texture: texture, size: CGSize(width: 16, height: 16))
        } else {
            let shape = SKShapeNode(circleOfRadius: 3.5)
            shape.fillColor = ArtLibrary.Palette.food
            shape.strokeColor = ArtLibrary.Palette.soilDeep
            shape.lineWidth = 0.5
            cargo = shape
        }
        cargo.position = CGPoint(x: 11, y: 0)
        cargo.isHidden = true
        cargo.name = "cargo"
        cargo.zPosition = 1
        node.addChild(cargo)
        layer.addChild(node)
        return Ant(node: node, body: body, cargo: cargo, route: route, phase: phase, lateral: lateral)
    }
}
