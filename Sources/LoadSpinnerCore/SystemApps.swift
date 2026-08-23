import Foundation

/// The bundle identifier of macOS's Activity Monitor.
public let activityMonitorBundleID = "com.apple.ActivityMonitor"

/// Where macOS keeps the bundled utilities since the system volume was sealed
/// (10.15+). Only consulted when the Launch Services lookup comes up empty.
public let activityMonitorFallbackPath = "/System/Applications/Utilities/Activity Monitor.app"

/// Locate Activity Monitor. Launch Services is asked first because it follows the
/// app wherever the OS actually keeps it; the well-known path is the fallback for
/// the case where that lookup fails (a damaged Launch Services database).
///
/// Both probes are injected so this stays a pure function: the app passes
/// `NSWorkspace`/`FileManager`, tests pass stubs.
///
/// Returns `nil` when neither finds it, so the caller can disable its control
/// rather than offer a button that does nothing.
public func resolveActivityMonitorURL(
    lookupBundleID: (String) -> URL?,
    fileExists: (String) -> Bool
) -> URL? {
    if let url = lookupBundleID(activityMonitorBundleID) {
        return url
    }
    if fileExists(activityMonitorFallbackPath) {
        return URL(fileURLWithPath: activityMonitorFallbackPath)
    }
    return nil
}
