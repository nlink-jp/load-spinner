import XCTest
@testable import LoadSpinnerCore

final class GradientTests: XCTestCase {
    func testEndpointsMatchStops() {
        XCTAssertEqual(loadGradientColorHex(forLoad: 0), "#5DCAA5")
        XCTAssertEqual(loadGradientColorHex(forLoad: 0.5), "#EF9F27")
        XCTAssertEqual(loadGradientColorHex(forLoad: 1), "#D85A30")
    }

    func testLoadIsClamped() {
        XCTAssertEqual(loadGradientColorHex(forLoad: -3), "#5DCAA5")
        XCTAssertEqual(loadGradientColorHex(forLoad: 9), "#D85A30")
    }

    func testMidpointOfLowerSegmentIsInterpolated() {
        // Halfway between teal (93,202,165) and amber (239,159,39).
        // r=166=A6, g=180.5->181=B5, b=102=66
        XCTAssertEqual(loadGradientColorHex(forLoad: 0.25), "#A6B566")
    }

    func testOutputIsAlwaysValidHex() {
        for i in 0...20 {
            let hex = loadGradientColorHex(forLoad: Double(i) / 20.0)
            XCTAssertTrue(hex.hasPrefix("#"))
            XCTAssertEqual(hex.count, 7)
            XCTAssertNotNil(UInt32(hex.dropFirst(), radix: 16))
        }
    }
}
