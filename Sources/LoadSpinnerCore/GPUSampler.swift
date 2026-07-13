import Foundation
import IOKit

/// Something that can read the current GPU utilization (0...1), or nil when the
/// metric is unavailable on this system.
public protocol GPUSampling {
    func sample() -> Double?
}

/// The undocumented IOKit `PerformanceStatistics` keys that expose GPU
/// utilization. They differ across GPU drivers / macOS versions, so we try each
/// in turn and gracefully report nil when none is present.
public let gpuUtilizationKeys: [String] = [
    "Device Utilization %",
    "GPU Activity(%)",
    "Renderer Utilization %",
]

/// Extract a GPU utilization (0...1) from a `PerformanceStatistics` dictionary.
///
/// Pure and IOKit-free so it can be unit-tested with a hand-built dictionary.
/// Returns nil when no known key is present.
public func gpuUtilization(fromPerformanceStatistics stats: [String: Any]) -> Double? {
    for key in gpuUtilizationKeys {
        guard let raw = stats[key] else { continue }
        let percent: Double?
        switch raw {
        case let number as NSNumber: percent = number.doubleValue
        case let integer as Int: percent = Double(integer)
        case let double as Double: percent = double
        default: percent = nil
        }
        if let percent {
            return min(max(percent / 100.0, 0), 1)
        }
    }
    return nil
}

/// Reads GPU utilization from the IOKit registry (`IOAccelerator` services'
/// `PerformanceStatistics`). No entitlement or root required.
public struct IOKitGPUSampler: GPUSampling {
    public init() {}

    public func sample() -> Double? {
        guard let matching = IOServiceMatching("IOAccelerator") else { return nil }
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS else {
            return nil
        }
        defer { IOObjectRelease(iterator) }

        var best: Double?
        var service = IOIteratorNext(iterator)
        while service != 0 {
            var properties: Unmanaged<CFMutableDictionary>?
            if IORegistryEntryCreateCFProperties(service, &properties, kCFAllocatorDefault, 0) == KERN_SUCCESS,
               let dictionary = properties?.takeRetainedValue() as? [String: Any],
               let performance = dictionary["PerformanceStatistics"] as? [String: Any],
               let utilization = gpuUtilization(fromPerformanceStatistics: performance) {
                best = max(best ?? 0, utilization)
            }
            IOObjectRelease(service)
            service = IOIteratorNext(iterator)
        }
        return best
    }
}
