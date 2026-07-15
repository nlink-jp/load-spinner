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

    // MARK: - Memory gradient (blue → green → orange → red)

    func testMemoryGradientStopsMatchColors() {
        XCTAssertEqual(memoryGradientColorHex(forUsedRatio: 0), "#378ADD")     // blue: mostly idle
        XCTAssertEqual(memoryGradientColorHex(forUsedRatio: 0.5), "#5DCAA5")   // green: sweet spot
        XCTAssertEqual(memoryGradientColorHex(forUsedRatio: 0.75), "#EF9F27")  // orange: getting full
        XCTAssertEqual(memoryGradientColorHex(forUsedRatio: 1), "#D85A30")     // red: full
    }

    func testMemoryGradientIsClamped() {
        XCTAssertEqual(memoryGradientColorHex(forUsedRatio: -1), "#378ADD")
        XCTAssertEqual(memoryGradientColorHex(forUsedRatio: 2), "#D85A30")
    }

    func testMemoryGradientInterpolatesBetweenStops() {
        // Halfway between blue (55,138,221) and green (93,202,165):
        // r=74=4A, g=170=AA, b=193=C1
        XCTAssertEqual(memoryGradientColorHex(forUsedRatio: 0.25), "#4AAAC1")
    }

    func testMemoryGradientOutputIsAlwaysValidHex() {
        for i in 0...20 {
            let hex = memoryGradientColorHex(forUsedRatio: Double(i) / 20.0)
            XCTAssertTrue(hex.hasPrefix("#"))
            XCTAssertEqual(hex.count, 7)
            XCTAssertNotNil(UInt32(hex.dropFirst(), radix: 16))
        }
    }
}
