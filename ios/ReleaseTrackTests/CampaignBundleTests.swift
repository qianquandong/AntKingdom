import AntKingdomCore
import XCTest
@testable import CrumbKingdom

/// C10：发行轨 bundle 内的章节数据与英文文案（宿主为 CrumbKingdom App）。
@MainActor
final class CampaignBundleTests: XCTestCase {
    func testBundledCatalogMatchesTheCoreMap() throws {
        let catalog = try CampaignModel.loadCatalog()
        // 第二、三章地图待 Codex A04；发行包里不能出现复制改名的地图
        XCTAssertEqual(catalog.chapters.map(\.id), ["backyard"])
        XCTAssertEqual(catalog.first.map.rows, MapDefinition.backyard.rows)
        XCTAssertEqual(catalog.first.titleKey, "world.backyard")
    }

    func testDebugFixtureIsOnlyAddedOnRequest() throws {
        let catalog = try CampaignModel.loadCatalog(fixture: true)
        XCTAssertEqual(catalog.chapters.map(\.id), ["backyard", DebugFixtureChapter.id])
        XCTAssertNotEqual(catalog.chapters[1].map.rows, MapDefinition.backyard.rows)
    }

    func testReleaseAndCoreStringsResolve() {
        let keys = ChapterGoal.allCases.map(\.stringKey) + [
            "chapter.select", "chapter.locked", "chapter.complete", "chapter.next", "chapter.replay",
            "chapter.replay_confirm", "chapter.keep_building", "chapter.main_goals", "chapter.extra_goals",
            "chapter.completed", "chapter.playing", "chapter.goal_count", "goal.done", "settings.reset_all",
            "dialog.reset_all", "error.chapter_save", "error.progress_newer",
            // 核心表仍从 Localizable 读取
            "hud.food", "world.backyard", "action.close",
        ]
        for key in keys {
            XCTAssertTrue(L10n.has(key), key)
        }
        XCTAssertEqual(L10n.text("goal.done", ["goal": L10n.text("goal.build_pantry")]), "Goal complete: Build a Pantry")
        XCTAssertEqual(L10n.text("chapter.goal_count", ["done": "3", "total": "6"]), "3/6 goals")
    }
}
