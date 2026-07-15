import XCTest
@testable import LoadSpinnerCore

final class MemoryTests: XCTestCase {
    // A page size of 1 keeps the byte arithmetic readable: 1 page == 1 byte.
    private func snapshot(
        internalPages: UInt64 = 0,
        purgeablePages: UInt64 = 0,
        wiredPages: UInt64 = 0,
        compressedPages: UInt64 = 0,
        pageSize: UInt64 = 1,
        totalBytes: UInt64 = 100
    ) -> MemorySnapshot {
        MemorySnapshot(
            internalPages: internalPages,
            purgeablePages: purgeablePages,
            wiredPages: wiredPages,
            compressedPages: compressedPages,
            pageSize: pageSize,
            totalBytes: totalBytes
        )
    }

    // MARK: - Used ratio derivation

    func testUsedIsAppPlusWiredPlusCompressed() {
        // app = internal(40) - purgeable(10) = 30; + wired(15) + compressed(5) = 50
        let reading = memoryReading(from: snapshot(
            internalPages: 40, purgeablePages: 10, wiredPages: 15, compressedPages: 5, totalBytes: 100
        ))
        XCTAssertEqual(reading.usedBytes, 50)
        XCTAssertEqual(reading.usedRatio, 0.5, accuracy: 1e-9)
    }

    func testPurgeableIsExcludedFromUsed() {
        let withPurgeable = memoryReading(from: snapshot(internalPages: 80, purgeablePages: 30, totalBytes: 100))
        XCTAssertEqual(withPurgeable.usedBytes, 50) // 80 - 30
    }

    func testPageSizeScalesBytes() {
        let reading = memoryReading(from: snapshot(
            internalPages: 10, pageSize: 4096, totalBytes: 40960
        ))
        XCTAssertEqual(reading.usedBytes, 40960)
        XCTAssertEqual(reading.usedRatio, 1.0, accuracy: 1e-9)
    }

    func testPurgeableExceedingInternalClampsToZero() {
        let reading = memoryReading(from: snapshot(internalPages: 10, purgeablePages: 40, totalBytes: 100))
        XCTAssertEqual(reading.usedBytes, 0)
        XCTAssertEqual(reading.usedRatio, 0.0)
    }

    func testUsedIsCappedAtTotal() {
        let reading = memoryReading(from: snapshot(internalPages: 500, totalBytes: 100))
        XCTAssertEqual(reading.usedBytes, 100)
        XCTAssertEqual(reading.usedRatio, 1.0)
    }

    func testZeroTotalYieldsZeroRatio() {
        let reading = memoryReading(from: snapshot(internalPages: 10, totalBytes: 0))
        XCTAssertEqual(reading.usedRatio, 0.0)
    }

    // MARK: - Color resolution

    func testGaugeColorFixedMode() {
        let hex = memoryGaugeColorHex(mode: .fixed, fixedHex: "#123456", usedRatio: 0.9)
        XCTAssertEqual(hex, "#123456")
    }

    func testGaugeColorGradientModeTracksUsedRatio() {
        let hex = memoryGaugeColorHex(mode: .gradient, fixedHex: "#123456", usedRatio: 0.5)
        // The gradient branch uses memory's own stops (sweet spot green at 0.5),
        // not the CPU/GPU load gradient (amber at 0.5).
        XCTAssertEqual(hex, memoryGradientColorHex(forUsedRatio: 0.5))
        XCTAssertNotEqual(hex, loadGradientColorHex(forLoad: 0.5))
        // Gradient ignores the fixed color and follows the used ratio.
        XCTAssertNotEqual(hex, "#123456")
    }

    // MARK: - Labels

    func testPercentLabelRoundsAndClamps() {
        XCTAssertEqual(memoryPercentLabel(usedRatio: 0.634), "63%")
        XCTAssertEqual(memoryPercentLabel(usedRatio: 0.636), "64%")
        XCTAssertEqual(memoryPercentLabel(usedRatio: 1.5), "100%")
        XCTAssertEqual(memoryPercentLabel(usedRatio: -0.2), "0%")
    }

    func testGigabytes() {
        XCTAssertEqual(gigabytes(1_073_741_824), 1.0, accuracy: 1e-9)
        XCTAssertEqual(gigabytes(0), 0.0)
    }

    // MARK: - Live sampler smoke test

    // Guards against the kernel field names / API drifting out from under us.
    // Memory is always available on macOS, so this must produce a plausible
    // reading on any test host.
    func testLiveSamplerProducesPlausibleReading() throws {
        let snapshot = try XCTUnwrap(MachMemorySampler().sample())
        XCTAssertGreaterThan(snapshot.totalBytes, 0)
        XCTAssertGreaterThan(snapshot.pageSize, 0)
        let reading = memoryReading(from: snapshot)
        XCTAssertGreaterThan(reading.usedRatio, 0)
        XCTAssertLessThanOrEqual(reading.usedRatio, 1)
    }
}
