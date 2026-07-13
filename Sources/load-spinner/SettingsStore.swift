import Foundation
import LoadSpinnerCore

/// Persists `AppSettings` to `UserDefaults` as a JSON blob.
final class SettingsStore {
    private let defaultsKey = "settings"
    private let defaults: UserDefaults

    private(set) var settings: AppSettings

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.settings = AppSettings.decode(from: defaults.data(forKey: defaultsKey))
    }

    /// Mutate and persist the settings in one step.
    func update(_ mutate: (inout AppSettings) -> Void) {
        mutate(&settings)
        if let data = settings.encoded() {
            defaults.set(data, forKey: defaultsKey)
        }
    }
}
