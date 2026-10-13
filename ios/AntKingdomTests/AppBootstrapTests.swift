import AntKingdomCore
import XCTest
@testable import AntKingdom

/// 宿主 App 内的集成测试：核心包已链接、英文 String Catalog 已编译进包。
final class AppBootstrapTests: XCTestCase {
    func testCorePackageIsLinked() {
        XCTAssertEqual(CoreInfo.saveSchemaVersion, 1)
    }

    func testStringCatalogResolvesPRDKeys() {
        XCTAssertEqual(L10n.text("game.title"), "Crumb Kingdom")
        XCTAssertEqual(L10n.text("hud.food", ["food": "12", "capacity": "100"]), "Food: 12/100")
        for key in ["world.backyard", "tutorial.dig", "offline.summary", "settings.haptics"] {
            XCTAssertTrue(L10n.has(key), "missing \(key)")
        }
    }
}
