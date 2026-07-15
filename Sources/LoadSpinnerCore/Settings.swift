import Foundation

/// The symbol drawn in the menu bar. Both are rendered as a fixed frame with a
/// lit segment travelling around the perimeter — the frame never rotates.
public enum IndicatorShape: String, Codable, Sendable, CaseIterable {
    case circle
    case square
}

/// How the indicator color is chosen.
public enum ColorMode: String, Codable, Sendable, CaseIterable {
    /// Use the per-source color the user selected.
    case fixed
    /// Derive the color from the current load (cool = idle, warm = busy).
    case gradient
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
    /// Show a vertical "CPU"/"GPU" label next to each menu bar indicator.
    public var showLabels: Bool
    /// Fixed per-source color, or a load-linked gradient.
    public var colorMode: ColorMode
    /// Show the memory gauge (a filling ring) in the menu bar. Independent of
    /// `mode`: memory is additive, not an alternative to CPU/GPU.
    public var showMemory: Bool
    /// Frame used for the memory gauge. The gauge fills with the used ratio.
    public var memoryShape: IndicatorShape
    /// How the memory gauge is colored: a fixed accent, or a used-ratio gradient.
    /// The same two-way axis as CPU/GPU's `colorMode`, but independent of it.
    public var memoryColorMode: ColorMode
    /// Fixed accent color for the memory gauge (used when `memoryColorMode == .fixed`).
    public var memoryColorHex: String

    public init(
        mode: DisplayMode,
        cpuShape: IndicatorShape,
        gpuShape: IndicatorShape,
        combinedShape: IndicatorShape,
        cpuColorHex: String,
        gpuColorHex: String,
        combinedColorHex: String,
        launchAtLogin: Bool,
        showLabels: Bool,
        colorMode: ColorMode,
        showMemory: Bool,
        memoryShape: IndicatorShape,
        memoryColorMode: ColorMode,
        memoryColorHex: String
    ) {
        self.mode = mode
        self.cpuShape = cpuShape
        self.gpuShape = gpuShape
        self.combinedShape = combinedShape
        self.cpuColorHex = cpuColorHex
        self.gpuColorHex = gpuColorHex
        self.combinedColorHex = combinedColorHex
        self.launchAtLogin = launchAtLogin
        self.showLabels = showLabels
        self.colorMode = colorMode
        self.showMemory = showMemory
        self.memoryShape = memoryShape
        self.memoryColorMode = memoryColorMode
        self.memoryColorHex = memoryColorHex
    }

    /// Tolerant decoding: any field missing from persisted JSON (e.g. after a new
    /// field is added) falls back to its default rather than failing the whole blob.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let fallback = AppSettings.default
        mode = try container.decodeIfPresent(DisplayMode.self, forKey: .mode) ?? fallback.mode
        cpuShape = try container.decodeIfPresent(IndicatorShape.self, forKey: .cpuShape) ?? fallback.cpuShape
        gpuShape = try container.decodeIfPresent(IndicatorShape.self, forKey: .gpuShape) ?? fallback.gpuShape
        combinedShape = try container.decodeIfPresent(IndicatorShape.self, forKey: .combinedShape) ?? fallback.combinedShape
        cpuColorHex = try container.decodeIfPresent(String.self, forKey: .cpuColorHex) ?? fallback.cpuColorHex
        gpuColorHex = try container.decodeIfPresent(String.self, forKey: .gpuColorHex) ?? fallback.gpuColorHex
        combinedColorHex = try container.decodeIfPresent(String.self, forKey: .combinedColorHex) ?? fallback.combinedColorHex
        launchAtLogin = try container.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? fallback.launchAtLogin
        showLabels = try container.decodeIfPresent(Bool.self, forKey: .showLabels) ?? fallback.showLabels
        colorMode = try container.decodeIfPresent(ColorMode.self, forKey: .colorMode) ?? fallback.colorMode
        showMemory = try container.decodeIfPresent(Bool.self, forKey: .showMemory) ?? fallback.showMemory
        memoryShape = try container.decodeIfPresent(IndicatorShape.self, forKey: .memoryShape) ?? fallback.memoryShape
        memoryColorMode = try container.decodeIfPresent(ColorMode.self, forKey: .memoryColorMode) ?? fallback.memoryColorMode
        memoryColorHex = try container.decodeIfPresent(String.self, forKey: .memoryColorHex) ?? fallback.memoryColorHex
    }

    public static let `default` = AppSettings(
        mode: .max,
        cpuShape: .circle,
        gpuShape: .square,
        combinedShape: .circle,
        cpuColorHex: "#378ADD",
        gpuColorHex: "#5DCAA5",
        combinedColorHex: "#5DCAA5",
        launchAtLogin: false,
        showLabels: false,
        colorMode: .fixed,
        showMemory: false,
        memoryShape: .circle,
        memoryColorMode: .gradient,
        memoryColorHex: "#7F77DD"
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
