import XCTest

/// The app layer's part of opening the panel fast enough, machine-checked at the
/// source: the hidden settings face must not be built inside `NSPopover.show`.
///
/// What this cannot see is the thing it protects. The symptom — the menu bar
/// item going dark for a frame or three when the panel opens — lives in another
/// process and was measured by filming the item's rectangle while clicking it
/// (macOS 27.0, 2026-09-21): 5 of 5 opens blinked with both faces built inside
/// `show` (92–94 ms), 0 of 4 after the first with the settings face built on the
/// next turn (37–65 ms). These tests only keep the code in the shape that was
/// measured.
final class PanelOpeningRuleTests: XCTestCase {
    private func source(_ name: String) throws -> String {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()      // the test directory
            .deletingLastPathComponent()      // Tests/
            .deletingLastPathComponent()      // the repository
            .appendingPathComponent("Sources/load-spinner/\(name)")
        return try String(contentsOf: url, encoding: .utf8)
    }

    /// Code lines only: a comment that mentions a call is not the call.
    private func codeLines(_ text: String) -> [String] {
        text.split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
    }

    func testTheSettingsFaceWaitsForThePopover() throws {
        let lines = codeLines(try source("PanelContainer.swift"))
        guard let settings = lines.firstIndex(where: { $0.contains("SettingsView(") }) else {
            return XCTFail("wrong file, or the settings face moved")
        }
        let guardLine = lines[..<settings].last(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) ?? ""
        XCTAssertTrue(guardLine.contains("if opening.popoverIsUp"),
                      "the settings face must be built only once the popover is up; the line before it is: \(guardLine)")
    }

    func testThePopoverIsReportedUpAfterShowReturns() throws {
        let lines = codeLines(try source("AppDelegate.swift"))
        guard let show = lines.firstIndex(where: { $0.contains("popover.show(") }) else {
            return XCTFail("wrong file, or the popover is no longer shown here")
        }
        let reports = lines.indices.filter { lines[$0].contains("popoverIsUp = true") }
        XCTAssertEqual(reports.count, 1, "exactly one place says the popover is up")
        guard let report = reports.first else { return }
        XCTAssertGreaterThan(report, show, "the report must come after show, not before it")
        XCTAssertTrue(lines[report].contains("DispatchQueue.main.async"),
                      "on the next turn of the run loop — SwiftUI's .task runs inside show: \(lines[report])")
    }
}
