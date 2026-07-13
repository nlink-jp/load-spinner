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

        let data = settings.encoded()
        XCTAssertNotNil(data)
        XCTAssertEqual(AppSettings.decode(from: data), settings)
    }

    func testPaletteColorsAreValidHex() {
        for hex in indicatorPalette {
            XCTAssertTrue(hex.hasPrefix("#"))
            XCTAssertEqual(hex.count, 7)
        }
    }
}
