import XCTest
@testable import LoadSpinnerCore

final class IndicatorTests: XCTestCase {
    private let settings = AppSettings.default

    func testCPUModeShowsOneCPUIndicator() {
        let plans = indicatorPlans(mode: .cpu, settings: settings, cpuLoad: 0.4, gpuLoad: 0.9, gpuAvailable: true)
        XCTAssertEqual(plans.count, 1)
        XCTAssertEqual(plans[0].source, .cpu)
        XCTAssertEqual(plans[0].load, 0.4, accuracy: 1e-9)
    }

    func testMaxModeUsesHigherOfTheTwo() {
        let plans = indicatorPlans(mode: .max, settings: settings, cpuLoad: 0.3, gpuLoad: 0.7, gpuAvailable: true)
        XCTAssertEqual(plans.count, 1)
        XCTAssertEqual(plans[0].source, .combined)
        XCTAssertEqual(plans[0].load, 0.7, accuracy: 1e-9)
    }

    func testMaxModeIgnoresGPUWhenUnavailable() {
        let plans = indicatorPlans(mode: .max, settings: settings, cpuLoad: 0.3, gpuLoad: 0.7, gpuAvailable: false)
        XCTAssertEqual(plans[0].load, 0.3, accuracy: 1e-9)
    }

    func testBothModeShowsTwoIndicatorsWhenGPUAvailable() {
        let plans = indicatorPlans(mode: .both, settings: settings, cpuLoad: 0.2, gpuLoad: 0.8, gpuAvailable: true)
        XCTAssertEqual(plans.map(\.source), [.cpu, .gpu])
        XCTAssertEqual(plans[1].load, 0.8, accuracy: 1e-9)
    }

    func testBothModeDropsGPUWhenUnavailable() {
        let plans = indicatorPlans(mode: .both, settings: settings, cpuLoad: 0.2, gpuLoad: nil, gpuAvailable: false)
        XCTAssertEqual(plans.map(\.source), [.cpu])
    }

    func testGPUOnlyFallsBackToCPUWhenUnavailable() {
        let plans = indicatorPlans(mode: .gpu, settings: settings, cpuLoad: 0.5, gpuLoad: nil, gpuAvailable: false)
        XCTAssertEqual(plans.count, 1)
        XCTAssertEqual(plans[0].source, .cpu)
        XCTAssertEqual(plans[0].load, 0.5, accuracy: 1e-9)
    }

    func testPlansCarryPerSourceAppearance() {
        var custom = AppSettings.default
        custom.cpuShape = .circle
        custom.cpuColorHex = "#378ADD"
        custom.gpuShape = .square
        custom.gpuColorHex = "#5DCAA5"
        let plans = indicatorPlans(mode: .both, settings: custom, cpuLoad: 0.1, gpuLoad: 0.1, gpuAvailable: true)
        XCTAssertEqual(plans[0].shape, .circle)
        XCTAssertEqual(plans[0].colorHex, "#378ADD")
        XCTAssertEqual(plans[1].shape, .square)
        XCTAssertEqual(plans[1].colorHex, "#5DCAA5")
    }
}
