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
                continue
            }
            let route = routes[ant.route]
            if snapshot.isStorageFull {
                place(ant, fraction: 0, carrying: false, returning: false)
                continue
            }
            let trip = max(route.tripSeconds, 3.01)
            let move = (trip - 3) / 2
            let t = (time / trip + ant.phase).truncatingRemainder(dividingBy: 1) * trip
            switch t {
            case ..<2: place(ant, fraction: 0, carrying: t > 1.2, returning: false)
            case ..<(2 + move): place(ant, fraction: (t - 2) / move, carrying: true, returning: false)
            case ..<(3 + move): place(ant, fraction: 1, carrying: t < 2.6 + move, returning: true)
            default: place(ant, fraction: 1 - (t - 3 - move) / move, carrying: false, returning: true)
            }
        }
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
        if let texture = ArtLibrary.texture("ant_worker") {
            node.addChild(SKSpriteNode(texture: texture, size: CGSize(width: 32, height: 32)))
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
        let cargo = SKShapeNode(circleOfRadius: 3.5)
        cargo.position = CGPoint(x: 11, y: 0)
        cargo.fillColor = ArtLibrary.Palette.food
        cargo.strokeColor = ArtLibrary.Palette.soilDeep
        cargo.lineWidth = 0.5
        cargo.isHidden = true
        node.addChild(cargo)
        layer.addChild(node)
        return Ant(node: node, cargo: cargo, route: route, phase: phase, lateral: lateral)
    }
}
