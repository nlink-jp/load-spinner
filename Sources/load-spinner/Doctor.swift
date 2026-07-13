import Foundation
import LoadSpinnerCore

/// Diagnose whether CPU (and, in a later phase, GPU) metrics can be read.
/// Returns a process exit code: 0 = healthy, 1 = a required source failed.
func runDoctor() -> Int32 {
    print("load-spinner doctor (\(appVersion))")
    print("")

    var healthy = true

    let sampler = MachCPUSampler()
    if let first = sampler.sample() {
        Thread.sleep(forTimeInterval: 0.3)
        if let second = sampler.sample() {
            let usage = cpuUsage(from: first, to: second)
            print("CPU: ok — \(Int((usage * 100).rounded()))% over 0.3s (host_statistics)")
        } else {
            print("CPU: failed — second sample returned no data")
            healthy = false
        }
    } else {
        print("CPU: failed — host_statistics returned an error")
        healthy = false
    }

    // GPU is optional: unavailability is a degrade (indicator disabled), not a
    // hard failure, so it does not flip the overall status.
    if let utilization = IOKitGPUSampler().sample() {
        print("GPU: ok — \(Int((utilization * 100).rounded()))% (IOKit PerformanceStatistics)")
    } else {
        print("GPU: unavailable — no IOAccelerator utilization key found; GPU display will be disabled")
    }

    print("")
    print(healthy ? "Status: healthy" : "Status: degraded")
    return healthy ? 0 : 1
}
