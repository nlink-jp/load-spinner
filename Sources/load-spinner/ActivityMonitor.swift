import AppKit
import LoadSpinnerCore

/// Opening macOS's Activity Monitor — the natural next step once the menu bar has
/// told you the machine is busy but not *which process* is doing it.
///
/// The location is resolved once at launch (see `AppDelegate`) so the panel can
/// disable its control when Activity Monitor cannot be found, instead of showing a
/// button that silently does nothing.
enum ActivityMonitor {
    /// Resolve Activity Monitor's location via Launch Services, falling back to
    /// the well-known utilities path.
    static func locate() -> URL? {
        resolveActivityMonitorURL(
            lookupBundleID: { NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0) },
            fileExists: { FileManager.default.fileExists(atPath: $0) }
        )
    }

    /// Launch (or focus, if already running) Activity Monitor.
    static func open(at url: URL) {
        let configuration = NSWorkspace.OpenConfiguration()
        // We are an accessory app, so bring Activity Monitor to the front for the
        // user rather than leaving it launched behind whatever they were doing.
        configuration.activates = true
        NSWorkspace.shared.openApplication(at: url, configuration: configuration, completionHandler: nil)
    }
}
