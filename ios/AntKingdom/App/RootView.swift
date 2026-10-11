import AntKingdomCore
import SwiftUI

/// 主界面：地图铺底，顶部 HUD，底部上下文面板，提示条浮在 HUD 下方。
struct RootView: View {
    @ObservedObject var controller: GameController
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .top) {
                GameMapView(controller: controller,
                            insets: UIEdgeInsets(top: proxy.safeAreaInsets.top + 112, left: 0,
                                                 bottom: proxy.safeAreaInsets.bottom + 132, right: 0))
                    .ignoresSafeArea()
                VStack(spacing: 8) {
                    HUDView(controller: controller)
                    ToastStack(toasts: controller.toasts,
                               reduceMotion: systemReduceMotion || controller.forceReduceMotion)
                    Spacer(minLength: 0)
                    BottomPanel(controller: controller)
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
                #if DEBUG
                DebugProbeView(text: controller.debugProbe, identifier: "debug.probe")
                DebugProbeView(text: controller.debugLifecycle, identifier: "debug.lifecycle")
                #endif
            }
        }
    }
}

#if DEBUG
/// UI 测试读取的调试探针（地图变换与已挖格数；生命周期日志）；只在 Debug 构建存在。
private struct DebugProbeView: View {
    let text: String
    let identifier: String
    var body: some View {
        Text(text)
            .font(.system(size: 1))
            .opacity(0.02)
            .frame(width: 1, height: 1)
            .accessibilityIdentifier(identifier)
            .allowsHitTesting(false)
    }
}
#endif
