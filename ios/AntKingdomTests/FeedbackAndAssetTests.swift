import AntKingdomCore
import UIKit
import XCTest
@testable import AntKingdom

/// C07（不依赖正式资源的部分）：反馈开关不影响核心状态、资源命名约定、缺资源时安全回退。
@MainActor
final class FeedbackAndAssetTests: XCTestCase {
    private final class FakeClock: MonotonicClock {
        var now = 100.0
        func uptime() -> Double { now }
    }

    func testEveryAudioCategoryHasACue() {
        XCTAssertEqual(Set(FeedbackCue.allCases.compactMap(\.sound)), Set(SoundCue.allCases))
    }

    /// QA T31：关闭音效与触觉只影响反馈出口；同样的操作得到逐字段相同的核心状态。
    func testFeedbackOffEmitsNothingAndLeavesStateIdentical() throws {
        func play(sound: Bool, haptics: Bool) throws -> (state: Data, emitted: Int) {
            let clock = FakeClock()
            let controller = GameController(session: GameSession(), clock: clock)
            controller.send(.setSound(sound))
            controller.send(.setHaptics(haptics))
            var emitted = 0
            controller.feedback.onEmit = { _, _ in emitted += 1 }
            for cell in [GridPoint(2, 4), GridPoint(2, 5), GridPoint(2, 6)] {
                for _ in 0..<3 {
                    controller.tapCell(cell)
                    clock.now += 0.2
                }
            }
            controller.tapCell(GridPoint(4, 3))   // 选中 Queen Chamber
            for _ in 0..<40 { controller.frame(delta: 0.25) }
            var state = controller.session.makeState()
            state.settings = .init()
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            return (try encoder.encode(state), emitted)
        }
        let on = try play(sound: true, haptics: true)
        let off = try play(sound: false, haptics: false)
        XCTAssertEqual(on.state, off.state, "feedback settings must not change core state")
        XCTAssertGreaterThan(on.emitted, 0)
        XCTAssertEqual(off.emitted, 0)
    }

    /// 隧道遮罩位序与 manifest 一致：N1 E2 S4 W8，N 为地图上方（y − 1）。
    func testTunnelMaskBits() {
        let c = GridPoint(4, 4)
        XCTAssertEqual(AssetNames.tunnelMask(at: c, open: []), 0)
        XCTAssertEqual(AssetNames.tunnelMask(at: c, open: [GridPoint(4, 3)]), 1)
        XCTAssertEqual(AssetNames.tunnelMask(at: c, open: [GridPoint(5, 4)]), 2)
        XCTAssertEqual(AssetNames.tunnelMask(at: c, open: [GridPoint(4, 5)]), 4)
        XCTAssertEqual(AssetNames.tunnelMask(at: c, open: [GridPoint(3, 4)]), 8)
        XCTAssertEqual(AssetNames.tunnelMask(at: c, open: Set(c.neighbors)), 15)
        XCTAssertEqual(AssetNames.tunnel(mask: 15), "terrain_tunnel_masks_15")
    }

    /// 客户端请求的名称与 design/asset_runtime_names.json（check_assets.py 使用）完全一致。
    func testRuntimeNamesMatchDesignContract() throws {
        let url = try XCTUnwrap(Bundle(for: FeedbackAndAssetTests.self)
            .url(forResource: "asset_runtime_names", withExtension: "json"))
        let doc = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        let names = try XCTUnwrap(doc["names"] as? [String: [String]])
        XCTAssertEqual(names, AssetNames.contract)
    }

    /// A01-01 + A01-02：已导入的 27 张运行时 PNG 都能从 App 加载，且按 @3x 解读
    /// （144 px = 48 pt，288 px = 96 pt，432×288 px = 144×96 pt），不会被当成像素尺寸的 pt 绘制。
    func testA01ArtLoadsAtItsPointSize() {
        var expected: [String: CGSize] = [
            "terrain_soil_1": .init(width: 48, height: 48), "terrain_soil_2": .init(width: 48, height: 48),
            "terrain_soil_3": .init(width: 48, height: 48), "terrain_stone": .init(width: 48, height: 48),
            "source_cookie_full": .init(width: 96, height: 96), "source_cookie_empty": .init(width: 96, height: 96),
            "source_sugar_full": .init(width: 48, height: 48), "source_sugar_empty": .init(width: 48, height: 48),
            "source_sap": .init(width: 48, height: 48),
            "room_queen": .init(width: 144, height: 96), "room_pantry": .init(width: 96, height: 96),
        ]
        for mask in 0...15 { expected[AssetNames.tunnel(mask: mask)] = .init(width: 48, height: 48) }
        XCTAssertEqual(expected.count, 27)
        for (name, size) in expected {
            let image = UIImage(named: name)
            XCTAssertNotNil(image, name)
            XCTAssertEqual(image?.size, size, name)
            XCTAssertEqual(image?.scale, 3, name)
        }
    }

    /// 每个资源要么完整导入、要么完全缺失（客户端整组用占位），不允许半套资源混用；
    /// 缺音效文件时播放静默跳过。
    func testAssetsAreAllOrNothingAndMissingAudioIsSilent() {
        for (assetID, names) in AssetNames.contract {
            let present = names.filter { name in
                if name.hasPrefix("audio_core_") {
                    return SoundCue.allCases.contains { AssetNames.sound($0) == name && SoundPlayer.url(for: $0) != nil }
                }
                return UIImage(named: name) != nil
            }
            XCTAssertTrue(present.isEmpty || present.count == names.count,
                          "\(assetID) partially imported: \(present.count)/\(names.count)")
        }
        let player = FeedbackPlayer()
        for cue in FeedbackCue.allCases { player.play(cue, settings: .init()) }
    }
}
