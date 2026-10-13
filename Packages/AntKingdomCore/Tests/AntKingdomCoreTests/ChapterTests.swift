import Foundation
import XCTest
@testable import AntKingdomCore

/// C10：章节清单、目录与目标判定（RELEASE_SCOPE 第 1 章；QA T33）。
final class ChapterTests: XCTestCase {
    func testDesignManifestLoadsOnlyDeliveredMaps() throws {
        let data = try Data(contentsOf: repoFile("design/chapters.json"))
        let manifest = try JSONDecoder().decode(ChapterManifest.self, from: data)
        XCTAssertEqual(manifest.chapters.map(\.id), ["backyard", "garden_edge", "stone_corner"])
        let catalog = try ChapterCatalog(manifest: manifest) { file in
            try String(contentsOf: repoFile("design/\(file)"), encoding: .utf8)
        }
        // 第二、三章地图由 Codex A04 交付；未交付前不能用复制的地图冒充
        XCTAssertEqual(catalog.chapters.map(\.id), ["backyard"])
        XCTAssertEqual(catalog.first.map.rows, MapDefinition.backyard.rows)
        XCTAssertEqual(catalog.first.map.id, MapDefinition.backyard.id)
        XCTAssertEqual(catalog.first.map.version, MapDefinition.backyard.version)
        XCTAssertEqual(catalog.first.titleKey, "world.backyard")
    }

    func testCatalogOrderAndNext() throws {
        let catalog = try twoChapterCatalog()
        XCTAssertEqual(catalog.next(after: "backyard")?.id, "fixture_two")
        XCTAssertNil(catalog.next(after: "fixture_two"))
        XCTAssertNil(catalog.next(after: "missing"))
    }

    func testCatalogRejectsInvalidMapsAndDuplicates() throws {
        let bad = ChapterManifest(version: 1, chapters: [
            .init(id: "broken", title: "x", map: "broken.txt", mapVersion: 1, status: "ready"),
        ])
        XCTAssertThrowsError(try ChapterCatalog(manifest: bad) { _ in "~~~~E~~~~\n#########" })
        let empty = ChapterManifest(version: 1, chapters: [
            .init(id: "later", title: "x", map: nil, mapVersion: 1, status: "awaiting_A04"),
        ])
        XCTAssertThrowsError(try ChapterCatalog(manifest: empty) { _ in "" }) { error in
            XCTAssertEqual(error as? ChapterError, .emptyCatalog)
        }
        XCTAssertThrowsError(try ChapterCatalog(chapters: [
            ChapterDefinition(id: "a", titleKey: "x", map: .backyard),
            ChapterDefinition(id: "a", titleKey: "y", map: .backyard),
        ]))
    }

    func testFreshSessionHasNoGoals() {
        XCTAssertEqual(ChapterGoal.achieved(in: GameSession()), [])
    }

    func testConnectingCookieIsTheFirstMainGoal() throws {
        let session = GameSession()
        try DebugScenario.connected.apply(to: session)
        XCTAssertEqual(ChapterGoal.achieved(in: session), [.connectCookie])
        XCTAssertFalse(ChapterGoal.isComplete(ChapterGoal.achieved(in: session)))
        XCTAssertEqual(session.flags.connectedSources, ["cookie"])
    }

    func testScriptedReplayCompletesAllMainGoals() throws {
        let session = GameSession()
        try DebugScenario.replay600.apply(to: session)
        let goals = ChapterGoal.achieved(in: session)
        XCTAssertTrue(ChapterGoal.isComplete(goals), "\(goals)")
        XCTAssertTrue(goals.isSuperset(of: [.connectSugar, .connectSap]))
        XCTAssertEqual(session.flags.connectedSources, ["cookie", "sap", "sugar"])
    }

    func testBetterRouteNeedsFivePercentAtFixedPopulation() throws {
        let session = GameSession()
        try DebugScenario.pantryBuilt.apply(to: session)
        let before = session.flags.bestRouteGain
        // 移到离 Cookie 更近的 (1,4)：冻结人口与源后的真实改善（UI 测试里显示 +25.0%）
        session.apply(.movePantry(topLeft: GridPoint(1, 4)))
        XCTAssertGreaterThanOrEqual(session.flags.bestRouteGain, ChapterGoal.betterRouteThreshold)
        XCTAssertGreaterThan(session.flags.bestRouteGain, before)
        XCTAssertTrue(ChapterGoal.achieved(in: session).contains(.betterRoute))
    }

    func testGoalFlagsSurviveSaveAndOldSavesDecode() throws {
        let session = GameSession()
        try DebugScenario.replay600.apply(to: session)
        let restored = try GameSession(state: session.makeState())
        XCTAssertEqual(restored.flags, session.flags)
        XCTAssertEqual(ChapterGoal.achieved(in: restored), ChapterGoal.achieved(in: session))
        // 核心版（C06）存档没有这些键：取默认值，且仍按当前连通状态识别目标
        let old = #"{"firstSourceConnected":true,"pantryBuiltOnce":true,"prototypeComplete":false}"#
        let flags = try JSONDecoder().decode(GameState.Flags.self, from: Data(old.utf8))
        XCTAssertEqual(flags.connectedSources, [])
        XCTAssertEqual(flags.bestRouteGain, 0)
        XCTAssertFalse(flags.chapterComplete)
    }

    func testInvalidGoalFlagsAreRejected() throws {
        let session = GameSession()
        try DebugScenario.connected.apply(to: session)
        var state = session.makeState()
        state.flags.connectedSources = ["surface"]
        XCTAssertThrowsError(try GameSession(state: state))
        state.flags.connectedSources = ["sugar", "cookie"]
        XCTAssertThrowsError(try GameSession(state: state), "must be sorted")
        state.flags.connectedSources = ["cookie"]
        state.flags.bestRouteGain = .nan
        XCTAssertThrowsError(try GameSession(state: state))
    }
}

/// 测试专用的第二张合法地图（不进 App；正式第二、三章由 Codex A04 交付）。
let fixtureTwoMapText = """
~~~~E~~~~
####.####
#S##.####
###QQQ###
###QQQ###
#X#####XX
######CC#
R#####CC#
#####X###
#########
"""

func twoChapterCatalog() throws -> ChapterCatalog {
    try ChapterCatalog(chapters: [
        ChapterDefinition(id: "backyard", titleKey: "world.backyard", map: .backyard),
        ChapterDefinition(id: "fixture_two", titleKey: "chapter.garden_edge",
                          map: try MapDefinition(id: "fixture_two", version: 1, text: fixtureTwoMapText)),
    ])
}
