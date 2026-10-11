import Foundation
import XCTest
@testable import AntKingdomCore

/// C11：外观权益缓存、启用规则、撤销回退、全局进度保留；外观对经济零影响（QA T38、T39）。
final class CosmeticsTests: XCTestCase {
    private let bundleId = "com.example.CrumbKingdom"
    private var garden: String { "\(bundleId).garden_decor" }

    final class FakeWall: WallClock {
        var time: Double
        init(_ time: Double) { self.time = time }
        func now() -> Double { time }
    }

    func testProductIdFollowsTheBundleId() {
        XCTAssertNil(RoomStyle.standard.productId(bundleId: bundleId))
        XCTAssertEqual(RoomStyle.garden.productId(bundleId: bundleId), "com.example.CrumbKingdom.garden_decor")
        XCTAssertEqual(RoomStyle.garden.productId(bundleId: "com.real.App"), "com.real.App.garden_decor")
    }

    func testOnlyOwnedStylesCanBeSelected() {
        var progress = PlayerProgress.fresh(.coreOnly)
        XCTAssertEqual(progress.selectedRoomStyle, .standard)
        XCTAssertFalse(progress.select(.garden, bundleId: bundleId), "no free unlock")
        XCTAssertEqual(progress.selectedRoomStyle, .standard)
        progress.setEntitlements([garden], bundleId: bundleId)
        XCTAssertTrue(progress.select(.garden, bundleId: bundleId))
        XCTAssertEqual(progress.selectedRoomStyle, .garden)
        XCTAssertTrue(progress.select(.standard, bundleId: bundleId), "default style is always available")
    }

    func testRevokedEntitlementFallsBackToDefaultStyle() {
        var progress = PlayerProgress.fresh(.coreOnly)
        progress.setEntitlements([garden], bundleId: bundleId)
        progress.select(.garden, bundleId: bundleId)
        XCTAssertTrue(progress.setEntitlements([], bundleId: bundleId), "refund/revocation reverts the style")
        XCTAssertEqual(progress.selectedRoomStyle, .standard)
        XCTAssertEqual(progress.ownedProducts, [])
        XCTAssertFalse(progress.setEntitlements([], bundleId: bundleId))
    }

    func testCosmeticsSurviveSaveAndOldProgressDecodes() throws {
        let store = MemorySaveStore()
        let repository = ProgressRepository(store: store)
        var progress = PlayerProgress.fresh(.coreOnly)
        progress.setEntitlements([garden], bundleId: bundleId)
        progress.select(.garden, bundleId: bundleId)
        progress.firstPantryBuilt = true
        try repository.save(&progress, now: 5)
        guard case .loaded(let loaded, false) = repository.load() else { return XCTFail("load") }
        XCTAssertEqual(loaded, progress)
        // C10 进度文件没有这些键：取默认值
        let old = #"{"schemaVersion":1,"activeChapterId":"backyard","unlockedChapterIds":["backyard"]}"#
        let decoded = try ProgressRepository.decodeValid(Data(old.utf8))
        XCTAssertEqual(decoded.selectedRoomStyle, .standard)
        XCTAssertEqual(decoded.ownedProducts, [])
        XCTAssertFalse(decoded.firstPantryBuilt)
        let bad = #"{"schemaVersion":1,"activeChapterId":"backyard","unlockedChapterIds":["backyard"],"roomStyle":"gold"}"#
        XCTAssertThrowsError(try ProgressRepository.decodeValid(Data(bad.utf8)))
    }

    func testFirstPantryIsAGlobalAchievement() throws {
        let store = MemorySaveStore()
        let (campaign, _) = CampaignCoordinator.launch(store: store, appVersion: "t", wallClock: FakeWall(1),
                                                       catalog: try twoChapterCatalog())
        let c = try XCTUnwrap(campaign)
        XCTAssertFalse(c.progress.firstPantryBuilt)
        try DebugScenario.pantryBuilt.apply(to: c.session)
        c.evaluate()
        XCTAssertTrue(c.progress.firstPantryBuilt)
        c.replayActiveChapter()
        XCTAssertTrue(c.progress.firstPantryBuilt, "replay keeps global achievements")
    }

    func testResetAllProgressKeepsPurchasesAndStyle() throws {
        let store = MemorySaveStore()
        let (campaign, _) = CampaignCoordinator.launch(store: store, appVersion: "t", wallClock: FakeWall(1),
                                                       catalog: try twoChapterCatalog())
        let c = try XCTUnwrap(campaign)
        c.updateEntitlements([garden], bundleId: bundleId)
        XCTAssertTrue(c.selectRoomStyle(.garden, bundleId: bundleId))
        try DebugScenario.replay600.apply(to: c.session)
        c.evaluate()
        c.resetAllProgress()
        XCTAssertEqual(c.progress.unlockedChapterIds, ["backyard"])
        XCTAssertEqual(c.progress.ownedProducts, [garden])
        XCTAssertEqual(c.progress.selectedRoomStyle, .garden)
        XCTAssertFalse(c.progress.firstPantryBuilt)
    }

    /// QA T39：购买/启用外观前后，600 秒固定回放的经济状态逐字段相同。
    func testStyleHasZeroEconomicEffect() throws {
        func run(style: RoomStyle) throws -> GameState {
            let store = MemorySaveStore()
            let (campaign, _) = CampaignCoordinator.launch(store: store, appVersion: "t", wallClock: FakeWall(1),
                                                           catalog: .coreOnly)
            let c = try XCTUnwrap(campaign)
            c.updateEntitlements([garden], bundleId: bundleId)
            XCTAssertTrue(c.selectRoomStyle(style, bundleId: bundleId))
            try DebugScenario.replay600.apply(to: c.session)
            return c.session.makeState()
        }
        let plain = try run(style: .standard)
        let decorated = try run(style: .garden)
        XCTAssertEqual(plain, decorated)
        XCTAssertEqual(decorated.ants, Rules.populationCap)
    }
}
