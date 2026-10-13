import AntKingdomCore
import SpriteKit
import UIKit

/// Queen Chamber 里的卵（D-16）。每枚卵按核心模型给的固定槽绘制：槽 0 中心在房间左上起 (22,22) pt，
/// 槽 1 在 (40,22) pt。一枚卵从下单到孵化始终是同一个节点、同一个位置；先孵化只移除它自己，
/// 另一枚留在原槽。normal / ready 只换纹理，大小固定 24 pt。
/// 节点身份跟着卵的生命周期：同一槽上剩余时间变大说明旧卵已孵化、新卵占了这个空槽（可能发生在同一次更新里），
/// 这时换新节点；不以卵的数量或数组下标作为身份。纯表现，不改会话。
@MainActor
struct EggClutch {
    /// 槽中心相对 Queen Chamber 左上角的偏移（pt，向右、向下）
    static func slotOffset(_ slot: Int) -> CGPoint { CGPoint(x: 22 + CGFloat(slot) * 18, y: 22) }
    /// “将孵化”态：剩余孵化时间 ≤ 2 秒（A02-01 表现阈值）
    static let readySeconds = 2.0
    static let size = CGSize(width: 24, height: 24)

    private struct Entry {
        let node: SKNode
        var remaining: Double
    }

    private var entries: [Int: Entry] = [:]

    /// 当前各槽的节点（测试与调试用）
    var nodes: [Int: SKNode] { entries.mapValues(\.node) }

    mutating func update(layer: SKNode, queen: CGRect, eggs: [Double], slots: [Int]) {
        let live = Dictionary(zip(slots, eggs), uniquingKeysWith: { first, _ in first })
        for slot in entries.keys where live[slot] == nil {
            entries.removeValue(forKey: slot)?.node.removeFromParent()   // 孵化：只移除这一枚
        }
        let textures = ArtLibrary.eggTextures()
        for (slot, remaining) in live {
            if let entry = entries[slot], remaining <= entry.remaining + 1e-6 {
                entries[slot]?.remaining = remaining                      // 同一枚卵继续倒计时
            } else {
                entries.removeValue(forKey: slot)?.node.removeFromParent() // 新卵占了这个槽
                let node = EggClutch.makeNode(textures: textures)
                node.name = "egg.slot.\(slot)"
                let offset = EggClutch.slotOffset(slot)
                node.position = CGPoint(x: queen.minX + offset.x, y: queen.maxY - offset.y)
                node.zPosition = 2
                layer.addChild(node)
                entries[slot] = Entry(node: node, remaining: remaining)
            }
            if let textures, let sprite = entries[slot]?.node as? SKSpriteNode {
                let texture = remaining <= EggClutch.readySeconds ? textures.ready : textures.normal
                if sprite.texture !== texture { sprite.texture = texture }
            }
        }
    }

    private static func makeNode(textures: (normal: SKTexture, ready: SKTexture)?) -> SKNode {
        if let textures {
            // catalog @3x 的 96 px 默认是 32 pt；卵显式按 24 pt 显示（A02-01 显示契约）
            return SKSpriteNode(texture: textures.normal, size: size)
        }
        let shape = SKShapeNode(ellipseOf: CGSize(width: 12, height: 16))
        shape.fillColor = UIColor(hex: 0xFFF8EC)
        shape.strokeColor = ArtLibrary.Palette.soilDeep.withAlphaComponent(0.6)
        return shape
    }
}
