import AntKingdomCore
import UIKit
import XCTest
@testable import CrumbKingdom

/// A02-01-RELEASE / A01：发行 CrumbKingdom target 的 Assets.car 实际加载 A01-01、A01-02、A02-01 共 44 张，
/// 按 @3x 解读出正确的 pt 尺寸；14 帧身体整组、卵两态都可用。文件与交付源 / metadata 的 SHA-256 一致由
/// tools/import_art.py --check 校验（Assets.car 会重新编码，运行时不按字节比较）。
@MainActor
final class ReleaseArtAssetTests: XCTestCase {
    func testAll44CoreImagesLoadFromTheReleaseBundle() throws {
        var expected: [String: CGSize] = [
            "terrain_soil_1": .init(width: 48, height: 48), "terrain_soil_2": .init(width: 48, height: 48),
            "terrain_soil_3": .init(width: 48, height: 48), "terrain_stone": .init(width: 48, height: 48),
            "source_cookie_full": .init(width: 96, height: 96), "source_cookie_empty": .init(width: 96, height: 96),
            "source_sugar_full": .init(width: 48, height: 48), "source_sugar_empty": .init(width: 48, height: 48),
            "source_sap": .init(width: 48, height: 48),
            AssetNames.queen: .init(width: 144, height: 96), AssetNames.pantry: .init(width: 96, height: 96),
            AssetNames.cargo: .init(width: 16, height: 16),
            AssetNames.egg(ready: false): .init(width: 32, height: 32), AssetNames.egg(ready: true): .init(width: 32, height: 32),
        ]
        for mask in 0...15 { expected[AssetNames.tunnel(mask: mask)] = .init(width: 48, height: 48) }
        for pose in AssetNames.AntPose.allCases {
            for frame in 1...pose.frameCount { expected[AssetNames.ant(pose, frame: frame)] = .init(width: 32, height: 32) }
        }
        XCTAssertEqual(expected.count, 44)
        let bundle = Bundle(for: CampaignModel.self)
        XCTAssertTrue(bundle.bundlePath.hasSuffix("CrumbKingdom.app"), bundle.bundlePath)
        for (name, size) in expected {
            let image = UIImage(named: name, in: bundle, with: nil)
            XCTAssertNotNil(image, name)
            XCTAssertEqual(image?.size, size, name)
            XCTAssertEqual(image?.scale, 3, name)
        }
        let frames = try XCTUnwrap(ArtLibrary.antFrames(), "14 body frames load as one group in the release target")
        XCTAssertEqual(frames.values.map(\.count).reduce(0, +), 14)
        XCTAssertNotNil(ArtLibrary.eggTextures())
    }
}
