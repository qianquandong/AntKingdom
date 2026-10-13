import AntKingdomCore
import UIKit
import SpriteKit
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

    /// A02-T01：A02-01 的 17 张都能加载，按 @3x 解读（工蚁 96 px = 32 pt、货物 48 px = 16 pt、卵 96 px = 32 pt，
    /// 卵节点另按 24 pt 显示）；14 帧身体整组可用，卵两态都在。文件与 metadata 的 SHA-256 由 import_art.py --check 校验。
    func testA02ArtLoadsAsCompleteGroups() throws {
        var expected: [String: CGSize] = [AssetNames.cargo: .init(width: 16, height: 16)]
        for pose in AssetNames.AntPose.allCases {
            for frame in 1...pose.frameCount { expected[AssetNames.ant(pose, frame: frame)] = .init(width: 32, height: 32) }
        }
        expected[AssetNames.egg(ready: false)] = .init(width: 32, height: 32)
        expected[AssetNames.egg(ready: true)] = .init(width: 32, height: 32)
        XCTAssertEqual(expected.count, 17)
        for (name, size) in expected {
            let image = UIImage(named: name)
            XCTAssertNotNil(image, name)
            XCTAssertEqual(image?.size, size, name)
            XCTAssertEqual(image?.scale, 3, name)
        }
        let frames = try XCTUnwrap(ArtLibrary.antFrames(), "all 14 body frames load as one group")
        XCTAssertEqual(frames[.idle]?.count, 2)
        XCTAssertEqual(frames[.walk]?.count, 6)
        XCTAssertEqual(frames[.carry]?.count, 6)
        XCTAssertNotNil(ArtLibrary.eggTextures())
    }

    /// A02-T03（结构部分）：每只蚂蚁只有一个身体精灵和一份货物；货物在父节点局部 (11,0)pt、随父节点旋转；
    /// 反复更新不积累节点或 SKAction；满仓待命时不显示货物。收入不由表现层决定（AntSwarm 不改会话）。
    func testAntsHaveOneBodyAndOneCargoAndDoNotAccumulateNodes() throws {
        let session = GameSession(map: .backyard)
        try DebugScenario.pantryBuilt.apply(to: session)
        _ = session.drainEvents()
        let before = session.makeState()
        let snapshot = session.snapshot()
        XCTAssertFalse(snapshot.routes.isEmpty)
        let layer = SKNode()
        var swarm = AntSwarm()
        var sawCargo = false
        for step in 0..<400 {
            swarm.update(layer: layer, snapshot: snapshot, queen: session.map.queenCells, time: Double(step) * 0.05)
            XCTAssertEqual(layer.children.count, snapshot.ants)
            for ant in layer.children {
                XCTAssertEqual(ant.children.filter { $0.name == "body" }.count, 1)
                let cargo = try XCTUnwrap(ant.childNode(withName: "cargo"))
                XCTAssertEqual(ant.children.filter { $0.name == "cargo" }.count, 1)
                XCTAssertEqual(ant.children.count, 2, "no placeholder parts next to the formal body")
                XCTAssertEqual(cargo.position, CGPoint(x: 11, y: 0))
                XCTAssertEqual(cargo.zRotation, 0, "cargo turns with its parent, not on its own")
                XCTAssertFalse(ant.hasActions())
                XCTAssertEqual((ant.childNode(withName: "body") as? SKSpriteNode)?.size, CGSize(width: 32, height: 32))
                if !cargo.isHidden { sawCargo = true }
            }
        }
        XCTAssertTrue(sawCargo, "some ant carries food along the route")
        XCTAssertEqual(session.makeState(), before, "animation never changes the economy")

        let capacity = session.colony.capacity
        try session.debugReplaceState { $0.hauled += capacity - $0.food; $0.food = capacity }
        let full = session.snapshot()
        XCTAssertTrue(full.isStorageFull)
        swarm.update(layer: layer, snapshot: full, queen: session.map.queenCells, time: 3)
        for ant in layer.children where ant.childNode(withName: "cargo") != nil {
            XCTAssertTrue(ant.childNode(withName: "cargo")?.isHidden ?? false, "waiting at full storage carries nothing")
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
