import AntKingdomCore
import SpriteKit
import UIKit

/// 地图渲染与手势。只读取 GameController 的快照；所有修改都通过控制器发出命令。
/// 手势互斥：单击挖/选、长按连续挖、单指拖动镜头、双指缩放；拖动永远不会触发挖掘。
@MainActor
final class GameScene: SKScene, UIGestureRecognizerDelegate {
    weak var controller: GameController?

    private let world = SKNode()
    private let tileLayer = SKNode()
    private let entityLayer = SKNode()
    private let crackLayer = SKNode()
    private let routeLayer = SKNode()
    private let busyLayer = SKNode()
    private let antLayer = SKNode()
    private let overlayLayer = SKNode()
    private let cameraNode = SKCameraNode()

    private var tileNodes: [GridPoint: SKSpriteNode] = [:]
    private var crackNodes: [GridPoint: SKNode] = [:]
    private var frontierNodes: [GridPoint: SKShapeNode] = [:]
    private var sourceNodes: [String: SKShapeNode] = [:]
    private var pantryNode: SKNode?
    private var selectionNode: SKShapeNode?
    private var eggNodes: [SKNode] = []

    private var renderedWalkable: Set<GridPoint> = []
    private var renderedDigTaps: [GridPoint: Int] = [:]
    private var renderedFrontier: Set<GridPoint> = []
    private var renderedPantry: Set<GridPoint>?
    private var renderedRoutes: [SessionSnapshot.RouteView] = []
    private var renderedBusy: Set<GridPoint> = []
    private var renderedEmpty: [String: Bool] = [:]
    private var renderedSelection: Selection?
    private var renderedEggs = -1
    private var placementNode: SKNode?
    private var renderedPlacement: PantryPlacement?
    private var renderedValidity: PlacementValidity?
    private var ants = AntSwarm()

    private var lastUpdate: TimeInterval?
    private var zoom: CGFloat = 1
    private var pinchStartZoom: CGFloat = 1
    private var configured = false

    /// HUD 与底栏遮挡的屏幕区域（pt）；镜头把地图放在剩余区域内
    var contentInsets = UIEdgeInsets(top: 132, left: 0, bottom: 150, right: 0) {
        didSet { clampCamera() }
    }

    // MARK: 生命周期

    override func didMove(to view: SKView) {
        backgroundColor = ArtLibrary.Palette.soilDeep
        guard !configured, let controller else { return }
        configured = true
        addChild(world)
        for (layer, z) in [(tileLayer, 0), (entityLayer, 1), (crackLayer, 2), (routeLayer, 3), (busyLayer, 4),
                           (antLayer, 5), (overlayLayer, 6)] as [(SKNode, CGFloat)] {
            layer.zPosition = z
            world.addChild(layer)
        }
        addChild(cameraNode)
        camera = cameraNode
        buildStaticMap(controller.session.map)
        installGestures(on: view)
        controller.onRoutePulse = { [weak self] in self?.pulseRoutes() }
        controller.onRejectedTap = { [weak self] cell in self?.shake(cell) }
        controller.onReset = { [weak self] in self?.resetCamera() }
        controller.onResume = { [weak self] in self?.resetFrameClock() }
        resetCamera()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        clampZoom()
        clampCamera()
    }

    override func update(_ currentTime: TimeInterval) {
        guard let controller else { return }
        let delta = lastUpdate.map { currentTime - $0 } ?? 0
        lastUpdate = currentTime
        controller.frame(delta: delta)
        render(controller.latest, selection: controller.selection, time: currentTime)
        publishProbe(controller)
    }

    /// 回到前台时丢弃暂停期间的帧间隔（后台时长由离线结算处理）。
    func resetFrameClock() {
        lastUpdate = nil
    }

    // MARK: 静态地图

    private func buildStaticMap(_ map: MapDefinition) {
        let tile = MapGeometry.tile
        for y in 0..<map.height {
            for x in 0..<map.width {
                let p = GridPoint(x, y)
                let node = SKSpriteNode(color: baseColor(map, p, walkable: map.initialWalkable.contains(p)),
                                        size: CGSize(width: tile, height: tile))
                node.position = MapGeometry.center(of: p)
                tileNodes[p] = node
                tileLayer.addChild(node)
                applyTileTexture(p, map: map, walkable: map.initialWalkable)
                if map.tile(at: p) == .stone, ArtLibrary.texture(AssetNames.stone) == nil { node.addChild(stoneMarks()) }
                if map.tile(at: p) == .entrance { node.addChild(entranceMark()) }
            }
        }
        addSurfaceBackdrop(map)
        let queen = roomNode(cells: map.queenCells, color: ArtLibrary.Palette.room, assetID: AssetNames.queen)
        entityLayer.addChild(queen)
        for source in map.sources where source.kind != .surface {
            let color: UIColor = {
                switch source.id {
                case "cookie": return ArtLibrary.Palette.food
                case "sugar": return UIColor(hex: 0xFFF4DD)
                default: return ArtLibrary.Palette.connected
                }
            }()
            let node = roomNode(cells: source.cells, color: color, assetID: AssetNames.source(source.id, empty: false))
            sourceNodes[source.id] = node
            entityLayer.addChild(node)
        }
    }

    /// 正式地形资源（有则用，无则保持占位色块）：土块三变化、石块、隧道 16 种遮罩。
    /// 隧道遮罩依赖四邻，所以开格时要连同邻格一起重算。
    private func applyTileTexture(_ p: GridPoint, map: MapDefinition, walkable: Set<GridPoint>) {
        guard let node = tileNodes[p] else { return }
        switch map.tile(at: p) {
        case .surface?:
            return
        case .stone?:
            // A01-01：石块贴图带透明区，底下铺同一格的土层（固定变体；无土层贴图时用土色），不留灰色方块底板
            guard let stone = ArtLibrary.texture(AssetNames.stone) else {
                node.texture = nil
                return
            }
            node.texture = ArtLibrary.texture(AssetNames.soil(variantFor: p))
            node.color = soilColor(p)
            if node.childNode(withName: "stoneArt") == nil {
                let art = SKSpriteNode(texture: stone, size: node.size)
                art.name = "stoneArt"
                node.addChild(art)
            }
        case .soil? where !walkable.contains(p):
            node.texture = ArtLibrary.texture(AssetNames.soil(variantFor: p))
        case .cookie?, .sugar?, .sap?:
            // D-15：食物源格不可通行（含 empty），底下铺同一格的正式土层；源贴图的透明 padding 自然露出土层，
            // 不再露出通路色的浅色方板。不裁 padding、不放大源贴图、不改占地与碰撞
            node.texture = ArtLibrary.texture(AssetNames.soil(variantFor: p))
            node.color = soilColor(p)
        default:
            let mask = AssetNames.tunnelMask(at: p, open: walkable)
            node.texture = walkable.contains(p) ? ArtLibrary.texture(AssetNames.tunnel(mask: mask)) : nil
        }
    }

    /// 地表背景（1296×288 可裁切）：铺在地表行下面，地表格改为透明。
    private func addSurfaceBackdrop(_ map: MapDefinition) {
        let cells = Set(tileNodes.keys.filter { map.tile(at: $0) == .surface })
        guard !cells.isEmpty, let texture = ArtLibrary.texture(AssetNames.surface) else { return }
        let frame = MapGeometry.frame(of: cells)
        let backdrop = SKSpriteNode(texture: texture, size: frame.size)
        backdrop.position = CGPoint(x: frame.midX, y: frame.midY)
        backdrop.zPosition = -1
        tileLayer.addChild(backdrop)
        for p in cells { tileNodes[p]?.color = .clear }
    }

    private func baseColor(_ map: MapDefinition, _ p: GridPoint, walkable: Bool) -> UIColor {
        switch map.tile(at: p) {
        case .surface?: return ArtLibrary.Palette.paper
        case .stone?: return ArtLibrary.Palette.stone
        case .soil? where !walkable: return soilColor(p)
        case .cookie?, .sugar?, .sap?: return soilColor(p)
        default: return ArtLibrary.Palette.tunnel
        }
    }

    private func soilColor(_ p: GridPoint) -> UIColor {
        let shade = CGFloat((p.x * 7 + p.y * 3) % 3) * 0.035
        return ArtLibrary.Palette.soil.adjustedBrightness(by: shade)
    }

    private func roomNode(cells: Set<GridPoint>, color: UIColor, assetID: String) -> SKShapeNode {
        let cellsFrame = MapGeometry.frame(of: cells)
        let frame = cellsFrame.insetBy(dx: 3, dy: 3)
        let node = SKShapeNode(rect: CGRect(x: -frame.width / 2, y: -frame.height / 2,
                                            width: frame.width, height: frame.height), cornerRadius: 10)
        node.position = CGPoint(x: frame.midX, y: frame.midY)
        node.fillColor = color
        node.strokeColor = ArtLibrary.Palette.soilDeep.withAlphaComponent(0.7)
        node.lineWidth = 2
        if let texture = ArtLibrary.texture(assetID) {
            // A01-01：正式贴图自带土边与透明留白，按完整逻辑格绘制（Cookie 2×2 = 96pt，Sugar/Sap 1×1 = 48pt），
            // 不再缩进 3pt；去掉占位填色与描边，避免双重边框。选中状态由独立的选中描边绘制。
            let sprite = SKSpriteNode(texture: texture, size: cellsFrame.size)
            sprite.name = "art"
            node.addChild(sprite)
            node.fillColor = .clear
            node.strokeColor = .clear
        } else if let label = ArtLibrary.placeholderLabel(assetID, in: frame.size) {
            node.addChild(label)
        }
        return node
    }

    private func stoneMarks() -> SKNode {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: -14, y: 6)); path.addLine(to: CGPoint(x: 4, y: 12))
        path.move(to: CGPoint(x: -6, y: -10)); path.addLine(to: CGPoint(x: 12, y: -4))
        let node = SKShapeNode(path: path)
        node.strokeColor = ArtLibrary.Palette.soilDeep.withAlphaComponent(0.6)
        node.lineWidth = 2
        return node
    }

    private func entranceMark() -> SKNode {
        let node = SKShapeNode(rectOf: CGSize(width: 28, height: 20), cornerRadius: 10)
        node.position = CGPoint(x: 0, y: -6)
        node.fillColor = ArtLibrary.Palette.soilDeep.withAlphaComponent(0.55)
        node.strokeColor = .clear
        return node
    }

    // MARK: 每帧渲染（只在快照变化时重建对应图层）

    private func render(_ snapshot: SessionSnapshot, selection: Selection?, time: TimeInterval) {
        let map = controller!.session.map
        if snapshot.walkable != renderedWalkable {
            let changed = snapshot.walkable.symmetricDifference(renderedWalkable)
            var retexture = changed
            for p in changed {
                tileNodes[p]?.color = baseColor(map, p, walkable: snapshot.walkable.contains(p))
                retexture.formUnion(p.neighbors)
                if snapshot.walkable.contains(p), renderedWalkable.isEmpty == false { burst(at: p) }
            }
            for p in retexture { applyTileTexture(p, map: map, walkable: snapshot.walkable) }
            renderedWalkable = snapshot.walkable
        }
        if snapshot.digTaps != renderedDigTaps {
            renderCracks(snapshot.digTaps)
            renderedDigTaps = snapshot.digTaps
        }
        if snapshot.frontier != renderedFrontier {
            renderFrontier(snapshot.frontier)
            renderedFrontier = snapshot.frontier
        }
        if snapshot.pantryCells != renderedPantry {
            renderPantry(snapshot.pantryCells)
            renderedPantry = snapshot.pantryCells
        }
        let empty = Dictionary(uniqueKeysWithValues: snapshot.sources.map { ($0.id, $0.isEmptyPatch) })
        if empty != renderedEmpty {
            for (id, isEmpty) in empty { sourceNodes[id].map { styleSource($0, id: id, empty: isEmpty) } }
            renderedEmpty = empty
        }
        if snapshot.routes != renderedRoutes {
            renderRoutes(snapshot.routes)
            renderedRoutes = snapshot.routes
        }
        if snapshot.busyCells != renderedBusy {
            renderBusy(snapshot.busyCells)
            renderedBusy = snapshot.busyCells
        }
        if snapshot.eggs.count != renderedEggs {
            renderEggs(snapshot.eggs.count, queen: map.queenCells)
            renderedEggs = snapshot.eggs.count
        }
        if selection != renderedSelection {
            renderSelection(selection, snapshot: snapshot, map: map)
            renderedSelection = selection
        }
        if let controller, controller.placement != renderedPlacement || controller.placementValidity != renderedValidity {
            renderPlacement(controller.placement, validity: controller.placementValidity)
            renderedPlacement = controller.placement
            renderedValidity = controller.placementValidity
        }
        ants.update(layer: antLayer, snapshot: snapshot, queen: map.queenCells, time: time)
        updateEggStates(snapshot.eggs)
        // 可挖前沿呼吸提示；减少动态时保持静态（虚线框仍在，不只靠动画）
        let still = controller?.reduceMotion ?? false
        for (index, node) in frontierNodes.values.enumerated() {
            node.alpha = still ? 0.75 : 0.55 + 0.25 * CGFloat(sin(time * 3 + Double(index % 3)))
        }
    }

    private func renderCracks(_ taps: [GridPoint: Int]) {
        for (cell, node) in crackNodes where taps[cell] == nil {
            node.removeFromParent()
            crackNodes[cell] = nil
        }
        for (cell, count) in taps {
            crackNodes[cell]?.removeFromParent()
            let node = SKNode()
            node.position = MapGeometry.center(of: cell)
            crackLayer.addChild(node)
            crackNodes[cell] = node
            if let texture = ArtLibrary.texture(AssetNames.crack(level: count)) {
                node.addChild(SKSpriteNode(texture: texture, size: CGSize(width: MapGeometry.tile, height: MapGeometry.tile)))
                continue
            }
            let path = CGMutablePath()
            path.move(to: CGPoint(x: -16, y: 12)); path.addLine(to: CGPoint(x: -2, y: 2)); path.addLine(to: CGPoint(x: 6, y: 14))
            if count >= 2 {
                path.move(to: CGPoint(x: -14, y: -12)); path.addLine(to: CGPoint(x: 0, y: -2))
                path.addLine(to: CGPoint(x: 16, y: -10)); path.move(to: CGPoint(x: 0, y: -2)); path.addLine(to: CGPoint(x: 4, y: -18))
            }
            let crack = SKShapeNode(path: path)
            crack.strokeColor = ArtLibrary.Palette.soilDeep
            crack.lineWidth = count >= 2 ? 3 : 2
            node.addChild(crack)
            if count >= 2 {
                for offset in [CGPoint(x: -8, y: -16), CGPoint(x: 12, y: 4), CGPoint(x: -18, y: 0)] {
                    let crumb = SKShapeNode(circleOfRadius: 2.5)
                    crumb.position = offset
                    crumb.fillColor = ArtLibrary.Palette.soilDeep
                    crumb.strokeColor = .clear
                    node.addChild(crumb)
                }
            }
        }
    }

    private func renderFrontier(_ frontier: Set<GridPoint>) {
        for (cell, node) in frontierNodes where !frontier.contains(cell) {
            node.removeFromParent()
            frontierNodes[cell] = nil
        }
        let tile = MapGeometry.tile
        for cell in frontier where frontierNodes[cell] == nil {
            let rect = CGRect(x: -tile / 2 + 4, y: -tile / 2 + 4, width: tile - 8, height: tile - 8)
            let dashed = CGPath(roundedRect: rect, cornerWidth: 6, cornerHeight: 6, transform: nil)
                .copy(dashingWithPhase: 0, lengths: [6, 4])
            let node = SKShapeNode(path: dashed)
            node.strokeColor = ArtLibrary.Palette.paper
            node.lineWidth = 1.5
            node.position = MapGeometry.center(of: cell)
            crackLayer.addChild(node)
            frontierNodes[cell] = node
        }
    }

    private func renderPantry(_ cells: Set<GridPoint>) {
        pantryNode?.removeFromParent()
        pantryNode = nil
        guard !cells.isEmpty else { return }
        let node = roomNode(cells: cells, color: UIColor(hex: 0xB98A5E), assetID: "room_pantry")
        let shelves = CGMutablePath()
        for dy in [-20.0, 0.0, 20.0] {
            shelves.move(to: CGPoint(x: -30, y: dy)); shelves.addLine(to: CGPoint(x: 30, y: dy))
        }
        let lines = SKShapeNode(path: shelves)
        lines.strokeColor = ArtLibrary.Palette.soilDeep.withAlphaComponent(0.5)
        lines.lineWidth = 2
        node.addChild(lines)
        entityLayer.addChild(node)
        pantryNode = node
    }

    private func styleSource(_ node: SKShapeNode, id: String, empty: Bool) {
        node.childNode(withName: "emptyMark")?.removeFromParent()
        if let art = node.childNode(withName: "art") as? SKSpriteNode,
           let texture = ArtLibrary.texture(AssetNames.source(id, empty: empty)) {
            art.texture = texture
            node.alpha = 1
            return
        }
        node.alpha = empty ? 0.45 : 1
        guard empty else { return }
        // 空盘标记：虚线框 + 斜线，不只靠颜色
        let frame = node.frame
        let rect = CGRect(x: -frame.width / 2 + 4, y: -frame.height / 2 + 4, width: frame.width - 8, height: frame.height - 8)
        let path = CGMutablePath()
        path.addPath(CGPath(rect: rect, transform: nil).copy(dashingWithPhase: 0, lengths: [5, 4]))
        path.move(to: CGPoint(x: rect.minX, y: rect.minY)); path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        let mark = SKShapeNode(path: path)
        mark.name = "emptyMark"
        mark.strokeColor = ArtLibrary.Palette.soilDeep
        mark.lineWidth = 2
        node.addChild(mark)
    }

    private func renderRoutes(_ routes: [SessionSnapshot.RouteView]) {
        routeLayer.removeAllChildren()
        for route in routes where route.cells.count >= 2 {
            let path = CGMutablePath()
            path.move(to: MapGeometry.center(of: route.cells[0]))
            for cell in route.cells.dropFirst() { path.addLine(to: MapGeometry.center(of: cell)) }
            let line = SKShapeNode(path: path)
            line.strokeColor = ArtLibrary.Palette.connected.withAlphaComponent(0.7)
            line.lineWidth = 5
            line.lineCap = .round
            line.lineJoin = .round
            line.name = "route"
            routeLayer.addChild(line)
        }
    }

    private func renderBusy(_ busy: Set<GridPoint>) {
        busyLayer.removeAllChildren()
        let tile = MapGeometry.tile
        for cell in busy {
            let square = SKShapeNode(rectOf: CGSize(width: tile - 6, height: tile - 6), cornerRadius: 6)
            square.position = MapGeometry.center(of: cell)
            square.fillColor = ArtLibrary.Palette.busy.withAlphaComponent(0.35)
            square.strokeColor = ArtLibrary.Palette.busy
            square.lineWidth = 2
            // 队列图标：三条短横线（颜色之外的第二编码）
            let bars = CGMutablePath()
            for dy in [-6.0, 0.0, 6.0] {
                bars.move(to: CGPoint(x: -8, y: dy)); bars.addLine(to: CGPoint(x: 8, y: dy))
            }
            let icon = SKShapeNode(path: bars)
            icon.strokeColor = ArtLibrary.Palette.soilDeep
            icon.lineWidth = 2.5
            square.addChild(icon)
            busyLayer.addChild(square)
        }
    }

    private func renderEggs(_ count: Int, queen: Set<GridPoint>) {
        eggNodes.forEach { $0.removeFromParent() }
        eggNodes = []
        let frame = MapGeometry.frame(of: queen)
        for index in 0..<count {
            let egg: SKNode
            if let texture = ArtLibrary.texture(AssetNames.egg(ready: false)) {
                egg = SKSpriteNode(texture: texture, size: CGSize(width: 24, height: 24))
            } else {
                let shape = SKShapeNode(ellipseOf: CGSize(width: 12, height: 16))
                shape.fillColor = UIColor(hex: 0xFFF8EC)
                shape.strokeColor = ArtLibrary.Palette.soilDeep.withAlphaComponent(0.6)
                egg = shape
            }
            egg.position = CGPoint(x: frame.minX + 22 + CGFloat(index) * 18, y: frame.maxY - 22)
            egg.zPosition = 2
            entityLayer.addChild(egg)
            eggNodes.append(egg)
        }
    }

    /// 卵的“将孵化”态（只在有正式资源时切图；阈值为表现层暂定值，待 Codex 确认）。
    private static let eggReadySeconds = 2.0

    private func updateEggStates(_ remaining: [Double]) {
        guard let ready = ArtLibrary.texture(AssetNames.egg(ready: true)),
              let normal = ArtLibrary.texture(AssetNames.egg(ready: false)) else { return }
        for (node, seconds) in zip(eggNodes, remaining) {
            (node as? SKSpriteNode)?.texture = seconds <= GameScene.eggReadySeconds ? ready : normal
        }
    }

    private func renderSelection(_ selection: Selection?, snapshot: SessionSnapshot, map: MapDefinition) {
        selectionNode?.removeFromParent()
        selectionNode = nil
        let cells: Set<GridPoint>
        switch selection {
        case .source(let id)?: cells = snapshot.sources.first { $0.id == id }?.cells ?? []
        case .queen?: cells = map.queenCells
        case .pantry?: cells = snapshot.pantryCells
        case nil: return
        }
        guard !cells.isEmpty else { return }
        let frame = MapGeometry.frame(of: cells).insetBy(dx: -2, dy: -2)
        let outline = CGMutablePath()
        outline.addPath(CGPath(roundedRect: frame, cornerWidth: 10, cornerHeight: 10, transform: nil))
        let node = SKShapeNode(path: outline)
        node.strokeColor = ArtLibrary.Palette.selection
        node.lineWidth = 4
        // 第二层虚线：选中状态不只靠颜色
        let dashes = SKShapeNode(path: CGPath(roundedRect: frame.insetBy(dx: 5, dy: 5), cornerWidth: 8, cornerHeight: 8,
                                              transform: nil).copy(dashingWithPhase: 0, lengths: [8, 5]))
        dashes.strokeColor = ArtLibrary.Palette.ant
        dashes.lineWidth = 2
        node.addChild(dashes)
        overlayLayer.addChild(node)
        selectionNode = node
    }

    /// 2×2 摆放预览：合法 = 绿色实线框 + 勾；非法 = 橙色虚线框 + 叉（不只靠颜色区分）。
    private func renderPlacement(_ placement: PantryPlacement?, validity: PlacementValidity) {
        placementNode?.removeFromParent()
        placementNode = nil
        guard let topLeft = placement?.topLeft else { return }
        let frame = MapGeometry.frame(of: Colony.pantryCells(topLeft: topLeft)).insetBy(dx: 2, dy: 2)
        let ok = validity == .ok
        let box = CGPath(roundedRect: frame, cornerWidth: 10, cornerHeight: 10, transform: nil)
        let node = SKShapeNode(path: ok ? box : box.copy(dashingWithPhase: 0, lengths: [10, 6]))
        node.fillColor = (ok ? ArtLibrary.Palette.connected : ArtLibrary.Palette.busy).withAlphaComponent(0.35)
        node.strokeColor = ok ? ArtLibrary.Palette.connected : ArtLibrary.Palette.busy
        node.lineWidth = 4
        let mark = CGMutablePath()
        let c = CGPoint(x: frame.midX, y: frame.midY)
        if ok {
            mark.move(to: CGPoint(x: c.x - 16, y: c.y)); mark.addLine(to: CGPoint(x: c.x - 4, y: c.y - 12))
            mark.addLine(to: CGPoint(x: c.x + 18, y: c.y + 14))
        } else {
            mark.move(to: CGPoint(x: c.x - 14, y: c.y - 14)); mark.addLine(to: CGPoint(x: c.x + 14, y: c.y + 14))
            mark.move(to: CGPoint(x: c.x - 14, y: c.y + 14)); mark.addLine(to: CGPoint(x: c.x + 14, y: c.y - 14))
        }
        let glyph = SKShapeNode(path: mark)
        glyph.strokeColor = ArtLibrary.Palette.ant
        glyph.lineWidth = 5
        glyph.lineCap = .round
        node.addChild(glyph)
        node.zPosition = 1
        overlayLayer.addChild(node)
        placementNode = node
    }

    // MARK: 一次性视觉反馈

    private func burst(at cell: GridPoint) {
        let still = controller?.reduceMotion ?? false
        for index in 0..<(still ? 1 : 6) {
            let crumb: SKNode
            if let texture = ArtLibrary.texture(AssetNames.crumb) {
                crumb = SKSpriteNode(texture: texture, size: CGSize(width: 12, height: 12))
            } else {
                let shape = SKShapeNode(circleOfRadius: 3)
                shape.fillColor = ArtLibrary.Palette.soil
                shape.strokeColor = .clear
                crumb = shape
            }
            crumb.position = MapGeometry.center(of: cell)
            overlayLayer.addChild(crumb)
            if still {
                // 减少动态：只淡出，不飞散
                crumb.run(.sequence([.fadeOut(withDuration: 0.35), .removeFromParent()]))
                continue
            }
            let angle = Double(index) / 6 * 2 * .pi
            let move = SKAction.moveBy(x: CGFloat(cos(angle)) * 22, y: CGFloat(sin(angle)) * 22, duration: 0.35)
            crumb.run(.sequence([.group([move, .fadeOut(withDuration: 0.35)]), .removeFromParent()]))
        }
    }

    private func pulseRoutes() {
        for case let line as SKShapeNode in routeLayer.children {
            line.run(.sequence([.run { line.lineWidth = 10; line.strokeColor = ArtLibrary.Palette.connected },
                                .wait(forDuration: 0.6),
                                .run { line.lineWidth = 5
                                    line.strokeColor = ArtLibrary.Palette.connected.withAlphaComponent(0.7) }]))
        }
    }

    private func shake(_ cell: GridPoint) {
        guard let node = tileNodes[cell] else { return }
        if controller?.reduceMotion ?? false {
            // 减少动态：橙色闪框代替左右抖动
            let tile = MapGeometry.tile
            let flash = SKShapeNode(rectOf: CGSize(width: tile - 6, height: tile - 6), cornerRadius: 6)
            flash.position = MapGeometry.center(of: cell)
            flash.strokeColor = ArtLibrary.Palette.busy
            flash.lineWidth = 3
            overlayLayer.addChild(flash)
            flash.run(.sequence([.wait(forDuration: 0.25), .fadeOut(withDuration: 0.2), .removeFromParent()]))
            return
        }
        let center = MapGeometry.center(of: cell)
        node.removeAction(forKey: "shake")
        node.run(.sequence([.moveBy(x: 4, y: 0, duration: 0.04), .moveBy(x: -8, y: 0, duration: 0.08),
                            .moveBy(x: 4, y: 0, duration: 0.04), .move(to: center, duration: 0)]), withKey: "shake")
    }

    // MARK: 手势

    private func installGestures(on view: SKView) {
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        let hold = UILongPressGestureRecognizer(target: self, action: #selector(handleHold(_:)))
        hold.minimumPressDuration = 0.35
        hold.allowableMovement = 12
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        pan.maximumNumberOfTouches = 2
        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        for recognizer in [tap, hold, pan, pinch] as [UIGestureRecognizer] {
            recognizer.delegate = self
            view.addGestureRecognizer(recognizer)
        }
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
        // 只允许拖动与缩放同时进行；挖掘手势与镜头手势互斥
        let cameraGestures = [gestureRecognizer, other].allSatisfy { $0 is UIPanGestureRecognizer || $0 is UIPinchGestureRecognizer }
        return cameraGestures
    }

    private func cell(for recognizer: UIGestureRecognizer) -> GridPoint? {
        guard let view = recognizer.view else { return nil }
        let point = convertPoint(fromView: recognizer.location(in: view))
        let cell = MapGeometry.cell(at: point)
        return controller?.session.map.contains(cell) == true ? cell : nil
    }

    @objc private func handleTap(_ recognizer: UITapGestureRecognizer) {
        guard recognizer.state == .ended, let controller else { return }
        guard let cell = cell(for: recognizer) else {
            controller.selection = nil
            return
        }
        controller.tapCell(cell)
    }

    @objc private func handleHold(_ recognizer: UILongPressGestureRecognizer) {
        guard let controller else { return }
        switch recognizer.state {
        case .began:
            if let cell = cell(for: recognizer) { controller.holdBegan(cell) }
        case .ended, .cancelled, .failed:
            controller.holdEnded()
        default:
            break
        }
    }

    @objc private func handlePan(_ recognizer: UIPanGestureRecognizer) {
        guard let view = recognizer.view else { return }
        let translation = recognizer.translation(in: view)
        cameraNode.position = CGPoint(x: cameraNode.position.x - translation.x / zoom,
                                      y: cameraNode.position.y + translation.y / zoom)
        recognizer.setTranslation(.zero, in: view)
        clampCamera()
    }

    @objc private func handlePinch(_ recognizer: UIPinchGestureRecognizer) {
        switch recognizer.state {
        case .began: pinchStartZoom = zoom
        case .changed:
            zoom = pinchStartZoom * recognizer.scale
            clampZoom()
            clampCamera()
        default: break
        }
    }

    // MARK: 镜头

    private var minimumZoom: CGFloat {
        guard let controller, size.width > 0 else { return 0.6 }
        let mapSize = MapGeometry.mapSize(controller.session.map)
        let visibleHeight = max(200, size.height - contentInsets.top - contentInsets.bottom)
        return min(1, min(size.width / mapSize.width, visibleHeight / mapSize.height))
    }

    private let maximumZoom: CGFloat = 1.6

    private func clampZoom() {
        zoom = min(max(zoom, minimumZoom), maximumZoom)
        cameraNode.setScale(1 / zoom)
    }

    /// 默认 48pt 格；水平居中在 Cookie 与 Queen 之间，首个挖掘目标一定在视野内。
    func resetCamera() {
        zoom = 1
        clampZoom()
        cameraNode.position = CGPoint(x: 3.6 * MapGeometry.tile, y: -5 * MapGeometry.tile)
        clampCamera()
    }

    private func clampCamera() {
        guard let controller, size.width > 0 else { return }
        let rect = MapGeometry.mapRect(controller.session.map)
        let visibleWidth = size.width / zoom
        let visibleHeight = max(1, size.height - contentInsets.top - contentInsets.bottom) / zoom
        // 可见区中心相对视图中心向下偏移 (top − bottom)/2 pt
        let offset = (contentInsets.top - contentInsets.bottom) / 2 / zoom
        var x = cameraNode.position.x
        var y = cameraNode.position.y - offset
        x = visibleWidth >= rect.width ? rect.midX : min(max(x, rect.minX + visibleWidth / 2), rect.maxX - visibleWidth / 2)
        y = visibleHeight >= rect.height ? rect.midY : min(max(y, rect.minY + visibleHeight / 2), rect.maxY - visibleHeight / 2)
        cameraNode.position = CGPoint(x: x, y: y + offset)
    }

    /// 调试/UI 测试：发布格 (0,0) 左上角的屏幕坐标与格尺寸（仅 Debug 构建显示）。
    private func publishProbe(_ controller: GameController) {
        #if DEBUG
        guard let view else { return }
        let origin = convertPoint(toView: CGPoint(x: 0, y: 0))
        let probe = String(format: "origin=%.1f,%.1f tile=%.2f dug=%ld view=%.0fx%.0f",
                           locale: Locale(identifier: "en_US_POSIX"),
                           origin.x, origin.y, MapGeometry.tile * zoom,
                           controller.latest.walkable.count - controller.session.map.initialWalkable.count,
                           view.bounds.width, view.bounds.height)
        if probe != controller.debugProbe { controller.debugProbe = probe }
        controller.refreshDebugLifecycle()
        #endif
    }
}

extension UIColor {
    func adjustedBrightness(by amount: CGFloat) -> UIColor {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard getHue(&h, saturation: &s, brightness: &b, alpha: &a) else { return self }
        return UIColor(hue: h, saturation: s, brightness: min(1, max(0, b + amount)), alpha: a)
    }
}
