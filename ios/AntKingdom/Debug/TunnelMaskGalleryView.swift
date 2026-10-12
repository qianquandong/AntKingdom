#if DEBUG
import AntKingdomCore
import SwiftUI
import UIKit

/// 仅 Debug：通路遮罩与土层的逐格检视页（启动参数 `-ak-gallery`），供 Codex 逐边核对 A01-02 的 16 种遮罩
/// （含游戏中不会出现的 0 号独立格）与 A01-01 土层拼接。不是游戏画面，不进 TestFlight/AppStore 构建。
/// 每格标出编号与开口方向（N1 E2 S4 W8，N = 图片上方）；放大显示为 96 pt（原尺寸 48 pt 的 2 倍）。
struct TunnelMaskGalleryView: View {
    private let columns = Array(repeating: GridItem(.fixed(88), spacing: 6), count: 4)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Tunnel masks (A01-02), 2x of 48 pt")
                    .font(.headline.monospaced())
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(0..<16, id: \.self) { mask in
                        VStack(spacing: 2) {
                            tile(AssetNames.tunnel(mask: mask), size: 88)
                            Text("\(mask) \(Self.openings(mask))")
                                .font(.caption2.monospaced())
                        }
                        .accessibilityIdentifier("gallery.mask.\(mask)")
                    }
                }
                Text("Tunnel masks at 48 pt")
                    .font(.headline.monospaced())
                HStack(spacing: 0) {
                    ForEach(0..<8, id: \.self) { tile(AssetNames.tunnel(mask: $0), size: 48) }
                }
                HStack(spacing: 0) {
                    ForEach(8..<16, id: \.self) { tile(AssetNames.tunnel(mask: $0), size: 48) }
                }
                Text("Soil 3x3 (A01-01), 2x")
                    .font(.headline.monospaced())
                Grid(horizontalSpacing: 0, verticalSpacing: 0) {
                    ForEach(0..<3, id: \.self) { y in
                        GridRow {
                            ForEach(0..<3, id: \.self) { x in
                                tile(AssetNames.soil(variantFor: GridPoint(x, y)), size: 96)
                            }
                        }
                    }
                }
            }
            .padding(12)
        }
        .background(Color(red: 0.31, green: 0.23, blue: 0.2))
        .foregroundStyle(.white)
        .accessibilityIdentifier("gallery")
    }

    private func tile(_ name: String, size: CGFloat) -> some View {
        Group {
            if let image = UIImage(named: name) {
                Image(uiImage: image).resizable()
            } else {
                Rectangle().fill(.red).overlay(Text("missing").font(.caption2))
            }
        }
        .frame(width: size, height: size)
    }

    /// 开口方向文字：N1 E2 S4 W8
    static func openings(_ mask: Int) -> String {
        let names = [(1, "N"), (2, "E"), (4, "S"), (8, "W")].filter { mask & $0.0 != 0 }.map(\.1)
        return names.isEmpty ? "-" : names.joined()
    }
}
#endif
