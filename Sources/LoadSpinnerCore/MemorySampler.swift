import Darwin
import Foundation

/// Something that can produce a memory snapshot.
///
/// Abstracted behind a protocol so callers can be tested with a scripted sampler
/// instead of the live kernel — mirroring `CPUSampling` / `GPUSampling`.
public protocol MemorySampling {
    func sample() -> MemorySnapshot?
}

/// Reads memory counters from the Mach kernel (`host_statistics64(HOST_VM_INFO64)`)
/// and the physical memory total.
///
/// Uses only public interfaces — no entitlement, no root. All derivation lives in
/// the pure `memoryReading(from:)`; this type just gathers the raw numbers.
public struct MachMemorySampler: MemorySampling {
    public init() {}

    public func sample() -> MemorySnapshot? {
        var pageSize: vm_size_t = 0
        guard host_page_size(mach_host_self(), &pageSize) == KERN_SUCCESS else { return nil }

        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride
        )
        var info = vm_statistics64_data_t()
        let result = withUnsafeMutablePointer(to: &info) { pointer -> kern_return_t in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { rebound in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, rebound, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }

        return MemorySnapshot(
            internalPages: UInt64(info.internal_page_count),
            purgeablePages: UInt64(info.purgeable_count),
            wiredPages: UInt64(info.wire_count),
            compressedPages: UInt64(info.compressor_page_count),
            pageSize: UInt64(pageSize),
            totalBytes: ProcessInfo.processInfo.physicalMemory
        )
    }
}
