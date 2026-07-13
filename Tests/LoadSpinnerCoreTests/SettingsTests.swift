import XCTest
@testable import LoadSpinnerCore

final class SettingsTests: XCTestCase {
    func testDecodeFromNilReturnsDefault() {
        XCTAssertEqual(AppSettings.decode(from: nil), .default)
    }

    func testDecodeFromCorruptReturnsDefault() {
        let garbage = Data("not json".utf8)
        XCTAssertEqual(AppSettings.decode(from: garbage), .default)
    }

    func testEncodeDecodeRoundTrip() {
        var settings = AppSettings.default
        settings.mode = .both
        settings.cpuShape = .square
        settings.gpuColorHex = "#EF9F27"
        settings.launchAtLogin = true
        settings.showLabels = true

        let data = settings.encoded()
        XCTAssertNotNil(data)
        XCTAssertEqual(AppSettings.decode(from: data), settings)
    }

    func testDecodeToleratesMissingFieldAndPreservesOthers() {
        // Older persisted JSON without the showLabels field.
        let json = """
        {"mode":"cpu","cpuShape":"square","gpuShape":"square","combinedShape":"circle",\
        "cpuColorHex":"#378ADD","gpuColorHex":"#5DCAA5","combinedColorHex":"#5DCAA5","launchAtLogin":true}
        """
        let decoded = AppSettings.decode(from: Data(json.utf8))
        XCTAssertEqual(decoded.mode, .cpu)
        XCTAssertEqual(decoded.cpuShape, .square)
        XCTAssertTrue(decoded.launchAtLogin)
        XCTAssertFalse(decoded.showLabels) // defaulted, other fields preserved
    }

    func testPaletteColorsAreValidHex() {
        for hex in indicatorPalette {
            XCTAssertTrue(hex.hasPrefix("#"))
            XCTAssertEqual(hex.count, 7)
        }
    }
}
