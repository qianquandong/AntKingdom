import XCTest
@testable import AntKingdomCore

/// C01：时间接口与输入频率限制。
final class TimeAndInputTests: XCTestCase {
    func testOfflineClockClamps() {
        XCTAssertEqual(OfflineClock.cappedSeconds(savedAt: 1000, now: 1240), 240)
        XCTAssertEqual(OfflineClock.cappedSeconds(savedAt: 1000, now: 900), 0, "clock moved backwards")
        XCTAssertEqual(OfflineClock.cappedSeconds(savedAt: 0, now: 7200), 3600)
        XCTAssertEqual(OfflineClock.cappedSeconds(savedAt: .nan, now: 10), 0)
    }

    func testTickAccumulatorQuantizes() {
        var accumulator = TickAccumulator()
        var quanta = 0
        for _ in 0..<60 { quanta += accumulator.add(1.0 / 60.0) }
        XCTAssertEqual(quanta, 4)
        XCTAssertEqual(accumulator.add(-1), 0)
        XCTAssertEqual(accumulator.add(.nan), 0)
    }

    func testManualTapLimitIsEightPerSecond() {
        var limiter = TapRateLimiter()
        var accepted = 0
        for i in 0..<100 { if limiter.acceptManualTap(at: Double(i) * 0.01) { accepted += 1 } }   // 100 次/秒
        XCTAssertEqual(accepted, 8)
    }

    func testHoldDigsFiveTimesPerSecond() {
        XCTAssertEqual(TapRateLimiter.holdTaps(from: 10, to: 10), 1)
        XCTAssertEqual(TapRateLimiter.holdTaps(from: 10, to: 10.19), 1)
        XCTAssertEqual(TapRateLimiter.holdTaps(from: 10, to: 10.2), 2)
        XCTAssertEqual(TapRateLimiter.holdTaps(from: 10, to: 12), 11)
        XCTAssertEqual(TapRateLimiter.holdTaps(from: 10, to: 9), 0)
    }
}
