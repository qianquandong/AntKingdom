import SpriteKit
import SwiftUI

/// 承载 SpriteKit 场景的 SKView。地图铺满屏幕；SwiftUI 的 HUD/面板盖在上面，
/// 有内容的 SwiftUI 区域会拦截触摸，因此 UI 上的点击不会穿透到地图。
struct GameMapView: UIViewRepresentable {
    let controller: GameController
    let insets: UIEdgeInsets

    func makeCoordinator() -> GameScene {
        let scene = GameScene(size: CGSize(width: 390, height: 844))
        scene.scaleMode = .resizeFill
        scene.controller = controller
        return scene
    }

    func makeUIView(context: Context) -> SKView {
        let view = SKView()
        view.ignoresSiblingOrder = true
        view.preferredFramesPerSecond = 60
        view.isMultipleTouchEnabled = true
        view.accessibilityIdentifier = "map"
        context.coordinator.contentInsets = insets
        view.presentScene(context.coordinator)
        return view
    }

    func updateUIView(_ view: SKView, context: Context) {
        if context.coordinator.contentInsets != insets {
            context.coordinator.contentInsets = insets
        }
    }
}
