import CoreGraphics

/// 地表背景的等比裁切（A02-02 显示契约）。返回 SKTexture(rect:in:) 用的单位矩形（原点在左下，居中裁切）：
/// 目标比源宽（如 9 列 × 1 行 = 432×48 pt，源 432×96 pt）时保留全宽、裁上下；目标比源窄时保留全高、裁左右。
/// 从不非等比拉伸。超出当前验证宽度的地图（A04）另行检查，不假设这张图可以横向无缝重复。
enum SurfaceBackdrop {
    static func cropRect(target: CGSize, source: CGSize) -> CGRect {
        guard target.width > 0, target.height > 0, source.width > 0, source.height > 0 else {
            return CGRect(x: 0, y: 0, width: 1, height: 1)
        }
        let targetAspect = target.width / target.height
        let sourceAspect = source.width / source.height
        if targetAspect >= sourceAspect {
            let height = sourceAspect / targetAspect
            return CGRect(x: 0, y: (1 - height) / 2, width: 1, height: height)
        }
        let width = targetAspect / sourceAspect
        return CGRect(x: (1 - width) / 2, y: 0, width: width, height: 1)
    }
}
