import XCTest
@testable import AntKingdomCore

final class CoreInfoTests: XCTestCase {
    func testBaselineIsRecorded() {
        XCTAssertTrue(CoreInfo.rulesBaseline.contains("PRD v0.2"))
        XCTAssertEqual(CoreInfo.saveSchemaVersion, 1)
    }
}
