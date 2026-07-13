import Darwin
import Foundation

/// Something that can produce a CPU tick snapshot.
///
/// Abstracted behind a protocol so `LoadMonitor` can be unit-tested with a
/// scripted sampler instead of the live kernel.
public protocol CPUSampling {
    func sample() -> CPUTicks?
}

/// Reads aggregate CPU ticks from the Mach kernel via `host_statistics`.
///
/// Uses the public `HOST_CPU_LOAD_INFO` flavor — no entitlement, no root.
public struct MachCPUSampler: CPUSampling {
    public init() {}

    public func sample() -> CPUTicks? {
        var count = mach_msg_type_number_t(
            MemoryLayout<host_cpu_load_info_data_t>.stride / MemoryLayout<integer_t>.stride
        )
        var info = host_cpu_load_info_data_t()
        let result = withUnsafeMutablePointer(to: &info) { pointer -> kern_return_t in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { reboundPointer in
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, reboundPointer, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }

        // cpu_ticks is a fixed 4-tuple: (user, system, idle, nice).
        let user = UInt64(info.cpu_ticks.0)
        let system = UInt64(info.cpu_ticks.1)
        let idle = UInt64(info.cpu_ticks.2)
        let nice = UInt64(info.cpu_ticks.3)
        let used = user + system + nice
        return CPUTicks(used: used, total: used + idle)
    }
}

/// Tracks CPU load over time by diffing successive tick snapshots.
///
/// Not thread-safe by design: instantiate and drive it from the main actor.
public final class LoadMonitor {
    private let sampler: CPUSampling
    private var previous: CPUTicks?

    /// The most recently computed CPU load (0...1).
    public private(set) var cpuLoad: Double = 0

    public init(sampler: CPUSampling = MachCPUSampler()) {
        self.sampler = sampler
    }

    /// Sample the CPU and update `cpuLoad`. Returns the current load.
    ///
    /// The first call only primes the baseline (there is no prior snapshot to
    /// diff against) and reports 0.
    @discardableResult
    public func refresh() -> Double {
        guard let current = sampler.sample() else { return cpuLoad }
        defer { previous = current }
        guard let previous else { return cpuLoad }
        cpuLoad = cpuUsage(from: previous, to: current)
        return cpuLoad
    }
}
