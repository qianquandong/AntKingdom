import AntKingdomCore
import CoreGraphics

/// 格坐标 ↔ SpriteKit 场景坐标。规则层 y 向下；只在这里翻转为 SpriteKit 的 y 向上。
/// 地图左上角格 (0,0) 的左上角位于场景原点，单元格 48pt（ART_DIRECTION 2：默认 48pt）。
enum MapGeometry {
    static let tile: CGFloat = 48

    static func center(of p: GridPoint) -> CGPoint {
        CGPoint(x: (CGFloat(p.x) + 0.5) * tile, y: -(CGFloat(p.y) + 0.5) * tile)
    }

    /// 多格占地（房间、补给区）的外接矩形中心与尺寸
    static func frame(of cells: Set<GridPoint>) -> CGRect {
        guard let minX = cells.map(\.x).min(), let maxX = cells.map(\.x).max(),
              let minY = cells.map(\.y).min(), let maxY = cells.map(\.y).max() else { return .zero }
        return CGRect(x: CGFloat(minX) * tile, y: -CGFloat(maxY + 1) * tile,
                      width: CGFloat(maxX - minX + 1) * tile, height: CGFloat(maxY - minY + 1) * tile)
    }

    static func cell(at point: CGPoint) -> GridPoint {
        GridPoint(Int((point.x / tile).rounded(.down)), Int((-point.y / tile).rounded(.down)))
    }

    static func mapSize(_ map: MapDefinition) -> CGSize {
        CGSize(width: CGFloat(map.width) * tile, height: CGFloat(map.height) * tile)
    }

    /// 场景中的地图矩形（y 向上）
    static func mapRect(_ map: MapDefinition) -> CGRect {
        let size = mapSize(map)
        return CGRect(x: 0, y: -size.height, width: size.width, height: size.height)
    }
}
