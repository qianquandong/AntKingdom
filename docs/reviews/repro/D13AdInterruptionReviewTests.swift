import XCTest
@testable import AntKingdomCore

/// Review-only reproduction of CampaignModel's actual ad/lifecycle call order.
final class D13AdInterruptionReviewTests: XCTestCase {
    final class Wall: WallClock {
        var value = 50_000.0
        func now() -> Double { value }
    }

    private func make(_ wall: Wall) throws -> CampaignCoordinator {
        let (campaign, _) = CampaignCoordinator.launch(store: MemorySaveStore(), appVersion: "review",
                                                       wallClock: wall, catalog: .coreOnly)
        let result = try XCTUnwrap(campaign)
        try DebugScenario.connected.apply(to: result.session)
        _ = result.session.drainEvents()
        return result
    }

    func testHomeDuringAdDoesNotCountTheAdAsOffline() throws {
        let wall = Wall()
        let campaign = try make(wall)
        XCTAssertEqual(campaign.admitForegroundFrame(), .run)
        // CampaignModel.suspend(true) sets only controller.isSuspended.
        // SpriteKit emits no frames while the full-screen ad is visible.
        wall.value += 30
        campaign.enterBackground() // player presses Home during the ad
        wall.value += 65
        let summary = try XCTUnwrap(campaign.becomeActive())
        XCTAssertEqual(summary.simulatedSeconds, 65,
                       "The 30 seconds spent watching the ad in foreground must be excluded")
    }

    func testFrameBeforeAdDismissalDoesNotSettleTheAdGap() throws {
        let wall = Wall()
        let campaign = try make(wall)
        XCTAssertEqual(campaign.admitForegroundFrame(), .run)
        let before = campaign.session.makeState()
        wall.value += 30
        // GameController.frame calls admitFrame BEFORE its isSuspended guard.
        // The first SpriteKit frame resumes before service.present returns.
        let admission = campaign.admitForegroundFrame()
        if case .resumed = admission {
            XCTFail("Ad gap was settled before the suspended-frame guard")
        }
        XCTAssertEqual(campaign.session.makeState(), before,
                       "A frame emitted while the ad is still presented must not generate income")
    }
}
