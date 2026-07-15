import AppKit
import Combine
import LoadSpinnerCore

/// Observable application state shared between the menu bar view and the SwiftUI
/// panel: current loads, history, GPU availability, and persisted settings.
@MainActor
final class AppModel: ObservableObject {
    @Published var settings: AppSettings
    @Published private(set) var cpuLoad: Double = 0
    @Published private(set) var gpuLoad: Double = 0
    @Published private(set) var memoryReading: MemoryReading = .zero
    @Published private(set) var gpuAvailable: Bool
    @Published private(set) var cpuHistory: [Double] = []
    @Published private(set) var gpuHistory: [Double] = []
    @Published private(set) var memoryHistory: [Double] = []

    /// Roughly three minutes of 1 Hz samples.
    let historyCapacity = 180

    private let store: SettingsStore

    init(store: SettingsStore, gpuAvailable: Bool) {
        self.store = store
        self.settings = store.settings
        self.gpuAvailable = gpuAvailable
    }

    /// Record a fresh sample, updating live values and the history buffers.
    func record(cpu: Double, gpu: Double?, memory: MemoryReading) {
        cpuLoad = cpu
        gpuLoad = gpu ?? 0
        memoryReading = memory
        appendClamped(&cpuHistory, cpu)
        appendClamped(&gpuHistory, gpu ?? 0)
        appendClamped(&memoryHistory, memory.usedRatio)
    }

    /// Mutate and persist the settings in one step.
    func updateSettings(_ mutate: (inout AppSettings) -> Void) {
        var copy = settings
        mutate(&copy)
        settings = copy
        store.update { $0 = copy }
    }

    private func appendClamped(_ buffer: inout [Double], _ value: Double) {
        buffer.append(value)
        if buffer.count > historyCapacity {
            buffer.removeFirst(buffer.count - historyCapacity)
        }
    }
}
