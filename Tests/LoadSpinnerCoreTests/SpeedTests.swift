import XCTest
@testable import LoadSpinnerCore

final class SpeedTests: XCTestCase {
    func testIdleSpinsAtMinimum() {
        XCTAssertEqual(rotationsPerMinute(forLoad: 0), 8, accuracy: 1e-9)
    }

    func testFullLoadSpinsAtMaximum() {
        XCTAssertEqual(rotationsPerMinute(forLoad: 1), 180, accuracy: 1e-9)
    }

    func testHalfLoadIsMidpoint() {
        XCTAssertEqual(rotationsPerMinute(forLoad: 0.5), 94, accuracy: 1e-9)
    }

    func testLoadIsClampedBelowZero() {
        XCTAssertEqual(rotationsPerMinute(forLoad: -2), 8, accuracy: 1e-9)
    }

    func testLoadIsClampedAboveOne() {
        XCTAssertEqual(rotationsPerMinute(forLoad: 5), 180, accuracy: 1e-9)
    }

    func testCustomRange() {
        let range = SpeedRange(minRPM: 0, maxRPM: 100)
        XCTAssertEqual(rotationsPerMinute(forLoad: 0.25, in: range), 25, accuracy: 1e-9)
    }
}
