import Foundation

/// Which load source an indicator reflects.
public enum LoadSource: String, Sendable, Equatable {
    case cpu
    case gpu
    case combined
}

/// A resolved indicator to render: its source, appearance, and current load.
public struct IndicatorPlan: Sendable, Equatable {
    public let source: LoadSource
    public let shape: IndicatorShape
    public let colorHex: String
    public let load: Double

    public init(source: LoadSource, shape: IndicatorShape, colorHex: String, load: Double) {
        self.source = source
        self.shape = shape
        self.colorHex = colorHex
        self.load = load
    }
}

/// Resolve the set of indicators to display for the current mode, settings, and
/// live loads. When GPU is unavailable this degrades gracefully: GPU-only falls
/// back to CPU, `both` drops the GPU indicator, and `max` ignores GPU.
///
/// Pure and side-effect free so the degrade behavior is exhaustively testable.
public func indicatorPlans(
    mode: DisplayMode,
    settings: AppSettings,
    cpuLoad: Double,
    gpuLoad: Double?,
    gpuAvailable: Bool
) -> [IndicatorPlan] {
    let gpu = gpuAvailable ? (gpuLoad ?? 0) : 0

    let cpuPlan = IndicatorPlan(
        source: .cpu, shape: settings.cpuShape, colorHex: settings.cpuColorHex, load: cpuLoad
    )
    let gpuPlan = IndicatorPlan(
        source: .gpu, shape: settings.gpuShape, colorHex: settings.gpuColorHex, load: gpu
    )

    switch mode {
    case .cpu:
        return [cpuPlan]
    case .gpu:
        return gpuAvailable ? [gpuPlan] : [cpuPlan]
    case .max:
        return [IndicatorPlan(
            source: .combined,
            shape: settings.combinedShape,
            colorHex: settings.combinedColorHex,
            load: max(cpuLoad, gpu)
        )]
    case .both:
        return gpuAvailable ? [cpuPlan, gpuPlan] : [cpuPlan]
    }
}
