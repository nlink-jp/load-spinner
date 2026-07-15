import Foundation

/// A snapshot of the raw kernel memory counters needed to derive a usage level.
///
/// Page counts come from `host_statistics64(HOST_VM_INFO64)`; `totalBytes` from
/// `hw.memsize`. Kept as plain numbers so the derivation is a pure function,
/// unit-testable without touching the kernel — mirroring `CPUTicks` and the GPU
/// stats dict.
public struct MemorySnapshot: Equatable, Sendable {
    /// Internal (anonymous, app-owned) pages, before subtracting purgeable.
    public let internalPages: UInt64
    /// Purgeable pages — freely reclaimable, so excluded from "used".
    public let purgeablePages: UInt64
    /// Wired (unswappable) pages.
    public let wiredPages: UInt64
    /// Pages currently held by the compressor.
    public let compressedPages: UInt64
    /// Size of one VM page in bytes.
    public let pageSize: UInt64
    /// Total physical memory in bytes.
    public let totalBytes: UInt64

    public init(
        internalPages: UInt64,
        purgeablePages: UInt64,
        wiredPages: UInt64,
        compressedPages: UInt64,
        pageSize: UInt64,
        totalBytes: UInt64
    ) {
        self.internalPages = internalPages
        self.purgeablePages = purgeablePages
        self.wiredPages = wiredPages
        self.compressedPages = compressedPages
        self.pageSize = pageSize
        self.totalBytes = totalBytes
    }
}

/// A resolved memory reading: bytes used, the total, and the used ratio (0...1).
public struct MemoryReading: Equatable, Sendable {
    public let usedBytes: UInt64
    public let totalBytes: UInt64
    public let usedRatio: Double

    public init(usedBytes: UInt64, totalBytes: UInt64, usedRatio: Double) {
        self.usedBytes = usedBytes
        self.totalBytes = totalBytes
        self.usedRatio = usedRatio
    }

    public static let zero = MemoryReading(usedBytes: 0, totalBytes: 0, usedRatio: 0)
}

/// Derive a `MemoryReading` from a snapshot.
///
/// "Used" follows Activity Monitor's *Memory Used* = App + Wired + Compressed,
/// where App memory is the internal page count minus freely-reclaimable purgeable
/// pages. This is what a user means by "how full is my RAM" on macOS, where plain
/// `free` is misleadingly near-zero because the OS fills idle RAM with file cache.
///
/// Pure and side-effect free. Counter overcount (used > total) is capped, and a
/// non-positive total yields a 0 ratio rather than a spurious value.
public func memoryReading(from snapshot: MemorySnapshot) -> MemoryReading {
    let appPages = snapshot.internalPages >= snapshot.purgeablePages
        ? snapshot.internalPages - snapshot.purgeablePages
        : 0
    let usedPages = appPages + snapshot.wiredPages + snapshot.compressedPages
    let usedBytes = usedPages.multipliedReportingOverflow(by: snapshot.pageSize)
    let rawUsed = usedBytes.overflow ? snapshot.totalBytes : usedBytes.partialValue
    let cappedUsed = min(rawUsed, snapshot.totalBytes)
    let ratio = snapshot.totalBytes > 0 ? Double(cappedUsed) / Double(snapshot.totalBytes) : 0
    return MemoryReading(
        usedBytes: cappedUsed,
        totalBytes: snapshot.totalBytes,
        usedRatio: min(max(ratio, 0), 1)
    )
}

/// Resolve the memory gauge color for the current color mode.
///
/// Mirrors the CPU/GPU color axis (fixed accent or gradient), but the gradient is
/// memory's own blue → green → orange → red mapping: barely-used RAM reads "cold,"
/// the healthy mid-range sweet spot is green, and only the high range warms.
/// Pure, so both branches are testable.
public func memoryGaugeColorHex(mode: ColorMode, fixedHex: String, usedRatio: Double) -> String {
    switch mode {
    case .fixed: return fixedHex
    case .gradient: return memoryGradientColorHex(forUsedRatio: usedRatio)
    }
}

/// The short "63%" used-ratio label shown in the panel donut's hole. Pure.
public func memoryPercentLabel(usedRatio: Double) -> String {
    let percent = Int((min(max(usedRatio, 0), 1) * 100).rounded())
    return "\(percent)%"
}

/// Convert bytes to binary gigabytes (GiB, conventionally labelled "GB" for RAM).
public func gigabytes(_ bytes: UInt64) -> Double {
    Double(bytes) / 1_073_741_824.0
}
