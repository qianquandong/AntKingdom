import AntKingdomCore
import SpriteKit
import XCTest
@testable import AntKingdom

/// A02-02（Issue #19）：地表等比裁切、两级裂纹与土屑的资源契约，以及“第 2 次有效命中”事件只在真实命中时触发一次。
/// 画面（裁切对照、三种 Soil 的三击录屏、Reduce Motion）另由 UI 测试与 CI 录像产出。
@MainActor
final class DigFeedbackArtTests: XCTestCase {
    private final class FakeClock: MonotonicClock {
        var now = 100.0
        func uptime() -> Double { now }
    }

    // MARK: A02B-01 资源

    func testA02BatchTwoLoadsAtItsDisplaySizes() {
        let expected: [String: CGSize] = [
            AssetNames.surface: .init(width: 432, height: 96),
            AssetNames.crack(level: 1): .init(width: 48, height: 48),
            AssetNames.crack(level: 2): .init(width: 48, height: 48),
            AssetNames.crumb: .init(width: 12, height: 12),
        ]
        for (name, size) in expected {
            let image = UIImage(named: name)
            XCTAssertNotNil(image, name)
            XCTAssertEqual(image?.size, size, name)
            XCTAssertEqual(image?.scale, 3, name)
        }
    }

    // MARK: A02B-02 地表等比裁切

    func testSurfaceCropMatchesTheHandoffRectForTheNineColumnRow() {
        let crop = SurfaceBackdrop.cropRect(target: CGSize(width: 432, height: 48), source: CGSize(width: 432, height: 96))
        XCTAssertEqual(crop, CGRect(x: 0, y: 0.25, width: 1, height: 0.5), "pixels (0, 72, 1296, 144) of 1296×288")
    }

    func testSurfaceCropNeverStretches() {
        let source = CGSize(width: 432, height: 96)
        for target in [CGSize(width: 432, height: 48), CGSize(width: 336, height: 48), CGSize(width: 144, height: 48),
                       CGSize(width: 864, height: 48), CGSize(width: 432, height: 96)] {
            let crop = SurfaceBackdrop.cropRect(target: target, source: source)
            let cropped = CGSize(width: crop.width * source.width, height: crop.height * source.height)
            XCTAssertEqual(cropped.width / cropped.height, target.width / target.height, accuracy: 1e-9, "\(target)")
            XCTAssertEqual(crop.midX, 0.5, accuracy: 1e-9, "centered")
            XCTAssertEqual(crop.midY, 0.5, accuracy: 1e-9, "centered")
            XCTAssertTrue(CGRect(x: 0, y: 0, width: 1, height: 1).contains(crop), "\(target)")
        }
    }

    func testTheRealSurfaceSubtextureIsNotSquashed() throws {
        let full = try XCTUnwrap(ArtLibrary.texture(AssetNames.surface))
        XCTAssertEqual(full.size(), CGSize(width: 432, height: 96))
        let crop = SurfaceBackdrop.cropRect(target: CGSize(width: 432, height: 48), source: full.size())
        let sub = SKTexture(rect: crop, in: full)
        XCTAssertEqual(sub.size().width / sub.size().height, 9, accuracy: 1e-6, "same aspect as the 432×48 pt row")
    }

    // MARK: A02B-03 / 04 命中事件

    func testSecondHitEventFiresOncePerAcceptedHitAndNeverForOpeningOrRejection() throws {
        let clock = FakeClock()
        let controller = GameController(session: GameSession(), clock: clock)
        var hits: [(GridPoint, Int)] = []
        controller.onDigHit = { hits.append(($0, $1)) }
        let cell = GridPoint(3, 1)
        XCTAssertTrue(controller.latest.frontier.contains(cell))
        for _ in 0..<3 {
            clock.now += 1                                   // 每次间隔 1 秒，不触发点击限频
            controller.tapCell(cell)
        }
        XCTAssertEqual(hits.map(\.0), [cell, cell])
        XCTAssertEqual(hits.map(\.1), [1, 2], "hit 1 and hit 2; the third hit opens the tunnel instead")
        XCTAssertTrue(controller.latest.walkable.contains(cell))
        clock.now += 1
        controller.tapCell(GridPoint(0, 9))                  // 不可挖（不在前沿）：没有命中事件
        clock.now += 1
        controller.tapCell(cell)                             // 已挖开：没有命中事件
        XCTAssertEqual(hits.count, 2)
        clock.now += 1
        controller.tapCell(GridPoint(5, 1))                  // 另一格命中 1 次后存档
        XCTAssertEqual(hits.count, 3)
        // 读档恢复到“已命中 1 次”的格：静态裂纹按进度显示，不重播旧事件
        let state = controller.session.makeState()
        XCTAssertEqual(state.digTaps.map(\.taps), [1])
        let reloaded = GameController(session: try GameSession(state: state), clock: clock)
        var replayed = 0
        reloaded.onDigHit = { _, _ in replayed += 1 }
        reloaded.frame(delta: 0.25)
        XCTAssertEqual(replayed, 0)
    }

    func testLongPressReportsEachAcceptedHitOnce() {
        let clock = FakeClock()
        let controller = GameController(session: GameSession(), clock: clock)
        var hits: [Int] = []
        controller.onDigHit = { _, taps in hits.append(taps) }
        let cell = GridPoint(5, 1)
        controller.holdBegan(cell)
        for _ in 0..<40 {
            clock.now += 0.1
            controller.frame(delta: 0.1)
        }
        controller.holdEnded()
        XCTAssertEqual(hits, [1, 2], "two hits reported, the third opened the cell")
        XCTAssertTrue(controller.latest.walkable.contains(cell))
    }
}
