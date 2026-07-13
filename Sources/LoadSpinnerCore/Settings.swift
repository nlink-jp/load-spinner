import Foundation

/// The symbol drawn in the menu bar. Both are rendered as a fixed frame with a
/// lit segment travelling around the perimeter — the frame never rotates.
public enum IndicatorShape: String, Codable, Sendable, CaseIterable {
    case circle
    case square
}

/// Which source(s) drive the menu bar indicator(s).
public enum DisplayMode: String, Codable, Sendable, CaseIterable {
    /// One indicator showing the higher of CPU and GPU.
    case max
    /// One indicator for CPU only.
    case cpu
    /// One indicator for GPU only.
    case gpu
    /// Two indicators side by side, CPU and GPU independently configured.
    case both
}

/// The selectable accent colors, as hex strings.
public let indicatorPalette: [String] = [
    "#5DCAA5", // teal
    "#378ADD", // blue
    "#EF9F27", // amber
    "#D85A30", // coral
    "#7F77DD", // purple
]

/// User-configurable, persisted application settings.
public struct AppSettings: Codable, Equatable, Sendable {
    public var mode: DisplayMode
    public var cpuShape: IndicatorShape
    public var gpuShape: IndicatorShape
    public var combinedShape: IndicatorShape
    public var cpuColorHex: String
    public var gpuColorHex: String
    public var combinedColorHex: String
    public var launchAtLogin: Bool

    public init(
        mode: DisplayMode,
        cpuShape: IndicatorShape,
        gpuShape: IndicatorShape,
        combinedShape: IndicatorShape,
        cpuColorHex: String,
        gpuColorHex: String,
        combinedColorHex: String,
        launchAtLogin: Bool
    ) {
        self.mode = mode
        self.cpuShape = cpuShape
        self.gpuShape = gpuShape
        self.combinedShape = combinedShape
        self.cpuColorHex = cpuColorHex
        self.gpuColorHex = gpuColorHex
        self.combinedColorHex = combinedColorHex
        self.launchAtLogin = launchAtLogin
    }

    public static let `default` = AppSettings(
        mode: .max,
        cpuShape: .circle,
        gpuShape: .square,
        combinedShape: .circle,
        cpuColorHex: "#378ADD",
        gpuColorHex: "#5DCAA5",
        combinedColorHex: "#5DCAA5",
        launchAtLogin: false
    )
}

extension AppSettings {
    /// Decode from persisted JSON, tolerating a missing or corrupt blob by
    /// falling back to defaults. Unknown/extra keys are ignored so older data
    /// still loads after new fields are added.
    public static func decode(from data: Data?) -> AppSettings {
        guard let data, let decoded = try? JSONDecoder().decode(AppSettings.self, from: data) else {
            return .default
        }
        return decoded
    }

    /// Encode to JSON for persistence.
    public func encoded() -> Data? {
        try? JSONEncoder().encode(self)
    }
}
