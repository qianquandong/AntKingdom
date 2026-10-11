import SpriteKit
import UIKit

/// 资源 ID（与 design/asset_manifest.json 一致）→ 纹理。
/// Codex 交付前全部使用程序绘制的占位：形状和配色来自 ART_DIRECTION 调色板，
/// Debug 构建在占位上标出资源 ID；占位不能通过美术终验或进入 App Store 包
/// （tools/check_assets.py --strict 在发行检查中失败）。
enum ArtLibrary {
    enum Palette {
        static let paper = UIColor(hex: 0xF6ECD8)
        static let soil = UIColor(hex: 0x986B4C)
        static let soilDeep = UIColor(hex: 0x503B32)
        static let tunnel = UIColor(hex: 0xDDBF91)
        static let ant = UIColor(hex: 0x302925)
        static let food = UIColor(hex: 0xE8B654)
        static let connected = UIColor(hex: 0x688C70)
        static let busy = UIColor(hex: 0xD57A3B)
        static let stone = UIColor(hex: 0x7A6E66)
        static let room = UIColor(hex: 0xC79B6E)
        static let selection = UIColor(hex: 0xFFF3B0)
    }

    @MainActor private static var cache: [String: SKTexture?] = [:]

    /// 正式资源存在时返回纹理；否则返回 nil，调用方画占位。结果缓存（蚂蚁帧每帧都会查询）。
    /// 名称见 AssetNames（资源 ID → 运行时 imageset 名）。
    @MainActor static func texture(_ name: String) -> SKTexture? {
        if let hit = cache[name] { return hit }
        let texture = UIImage(named: name) != nil ? SKTexture(imageNamed: name) : nil
        cache[name] = .some(texture)
        return texture
    }

    /// 是否显示占位资源 ID（仅 Debug）
    static var labelsPlaceholders: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }

    static func placeholderLabel(_ assetID: String, in size: CGSize) -> SKNode? {
        guard labelsPlaceholders else { return nil }
        let label = SKLabelNode(text: assetID)
        label.fontName = "Menlo"
        label.fontSize = 7
        label.fontColor = UIColor.black.withAlphaComponent(0.55)
        label.verticalAlignmentMode = .center
        label.position = CGPoint(x: 0, y: -size.height / 2 + 7)
        label.zPosition = 1
        return label
    }
}

extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
    }
}
