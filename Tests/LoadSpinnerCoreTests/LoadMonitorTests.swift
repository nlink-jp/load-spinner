import XCTest
@testable import LoadSpinnerCore

/// A sampler that replays a fixed sequence of snapshots for deterministic tests.
private final class ScriptedSampler: CPUSampling {
    private let samples: [CPUTicks?]
    private var index = 0

    init(_ samples: [CPUTicks?]) {
        self.samples = samples
    }

    func sample() -> CPUTicks? {
        guard index < samples.count else { return nil }
        defer { index += 1 }
        return samples[index]
    }
}

final class LoadMonitorTests: XCTestCase {
    func testFirstRefreshOnlyPrimesBaseline() {
        let monitor = LoadMonitor(sampler: ScriptedSampler([
            CPUTicks(used: 100, total: 200),
            CPUTicks(used: 150, total: 300),
        ]))
        XCTAssertEqual(monitor.refresh(), 0)
    }

    func testSecondRefreshComputesUsage() {
        let monitor = LoadMonitor(sampler: ScriptedSampler([
            CPUTicks(used: 100, total: 200),
            CPUTicks(used: 150, total: 300),
        ]))
        _ = monitor.refresh()
        XCTAssertEqual(monitor.refresh(), 0.5, accuracy: 1e-9)
        XCTAssertEqual(monitor.cpuLoad, 0.5, accuracy: 1e-9)
    }

    func testFailedSampleKeepsPreviousLoad() {
        let monitor = LoadMonitor(sampler: ScriptedSampler([
            CPUTicks(used: 100, total: 200),
            CPUTicks(used: 150, total: 300),
            nil,
        ]))
        _ = monitor.refresh()
        _ = monitor.refresh()
        XCTAssertEqual(monitor.refresh(), 0.5, accuracy: 1e-9)
    }
}
