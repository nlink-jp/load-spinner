import XCTest
@testable import LoadSpinnerCore

final class SystemAppsTests: XCTestCase {
    private let launchServicesHit = URL(fileURLWithPath: "/System/Applications/Utilities/Activity Monitor.app")
    private let relocated = URL(fileURLWithPath: "/Volumes/Spare/Activity Monitor.app")

    func testUsesLaunchServicesResult() {
        let url = resolveActivityMonitorURL(
            lookupBundleID: { bundleID in
                XCTAssertEqual(bundleID, "com.apple.ActivityMonitor")
                return self.launchServicesHit
            },
            fileExists: { _ in XCTFail("the fallback must not be probed after a hit"); return true }
        )
        XCTAssertEqual(url, launchServicesHit)
    }

    func testLaunchServicesWinsOverTheWellKnownPath() {
        // Whatever Launch Services reports is authoritative, even off the system volume.
        let url = resolveActivityMonitorURL(
            lookupBundleID: { _ in self.relocated },
            fileExists: { _ in true }
        )
        XCTAssertEqual(url, relocated)
    }

    func testFallsBackToTheWellKnownPath() {
        var probed: [String] = []
        let url = resolveActivityMonitorURL(
            lookupBundleID: { _ in nil },
            fileExists: { path in
                probed.append(path)
                return true
            }
        )
        XCTAssertEqual(probed, ["/System/Applications/Utilities/Activity Monitor.app"])
        XCTAssertEqual(url, URL(fileURLWithPath: activityMonitorFallbackPath))
    }

    func testNilWhenNeitherProbeFindsIt() {
        let url = resolveActivityMonitorURL(lookupBundleID: { _ in nil }, fileExists: { _ in false })
        XCTAssertNil(url)
    }
}
