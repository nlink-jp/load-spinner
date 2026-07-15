import AppKit
import Combine
import LoadSpinnerCore
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var spinnerView: SpinnerView!
    private var popover: NSPopover!
    private var model: AppModel!

    private let cpuMonitor = LoadMonitor()
    private let gpuSampler = IOKitGPUSampler()
    private let memorySampler = MachMemorySampler()
    private var gpuAvailable = false
    private var sampleTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        gpuAvailable = gpuSampler.sample() != nil
        model = AppModel(store: SettingsStore(), gpuAvailable: gpuAvailable)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let view = SpinnerView(frame: NSRect(x: 0, y: 0, width: NSStatusBar.system.thickness, height: NSStatusBar.system.thickness))
        spinnerView = view
        if let button = statusItem.button {
            button.addSubview(view)
            view.frame = button.bounds
            view.autoresizingMask = [.width, .height]
            button.target = self
            button.action = #selector(togglePopover)
        }

        popover = NSPopover()
        popover.behavior = .transient
        popover.delegate = self

        // Re-apply the menu bar appearance the instant settings change.
        model.$settings
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.refreshIndicators() }
            .store(in: &cancellables)

        cpuMonitor.refresh() // prime the CPU baseline
        refreshIndicators()

        let timer = Timer(timeInterval: 1.0, target: self, selector: #selector(tick), userInfo: nil, repeats: true)
        RunLoop.main.add(timer, forMode: .common)
        sampleTimer = timer
    }

    @objc private func tick() {
        let cpu = cpuMonitor.refresh()
        let gpu = gpuAvailable ? gpuSampler.sample() : nil
        let memory = memorySampler.sample().map(memoryReading(from:)) ?? .zero
        model.record(cpu: cpu, gpu: gpu, memory: memory)
        refreshIndicators()
    }

    private func refreshIndicators() {
        let plans = indicatorPlans(
            mode: model.settings.mode,
            settings: model.settings,
            cpuLoad: model.cpuLoad,
            gpuLoad: gpuAvailable ? model.gpuLoad : nil,
            gpuAvailable: gpuAvailable
        )
        let showLabels = model.settings.showLabels
        let gradient = model.settings.colorMode == .gradient
        var specs = plans.map { plan in
            SpinnerView.Spec(
                shape: plan.shape,
                colorHex: gradient ? loadGradientColorHex(forLoad: plan.load) : plan.colorHex,
                kind: .spinner(rpm: rotationsPerMinute(forLoad: plan.load)),
                label: showLabels ? label(for: plan.source) : nil
            )
        }
        if model.settings.showMemory {
            specs.append(memorySpec(showLabels: showLabels))
        }
        spinnerView.update(specs: specs)
        statusItem.length = spinnerView.preferredWidth
    }

    /// Build the memory *gauge* spec: fill = used ratio, color = fixed or gradient.
    private func memorySpec(showLabels: Bool) -> SpinnerView.Spec {
        let reading = model.memoryReading
        let settings = model.settings
        return SpinnerView.Spec(
            shape: settings.memoryShape,
            colorHex: memoryGaugeColorHex(
                mode: settings.memoryColorMode,
                fixedHex: settings.memoryColorHex,
                usedRatio: reading.usedRatio
            ),
            kind: .gauge(fill: reading.usedRatio),
            label: showLabels ? "MEM" : nil
        )
    }

    private func label(for source: LoadSource) -> String {
        switch source {
        case .cpu: return "CPU"
        case .gpu: return "GPU"
        case .combined: return "MAX"
        }
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            // Build the SwiftUI panel only while it is on screen so it does no
            // rendering work when closed.
            let hosting = NSHostingController(
                rootView: PanelView(model: model, onQuit: { NSApplication.shared.terminate(nil) })
            )
            // Size the popover to the SwiftUI content's ideal size, otherwise the
            // top of the panel is clipped.
            hosting.sizingOptions = [.preferredContentSize]
            popover.contentViewController = hosting
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }
}

extension AppDelegate: NSPopoverDelegate {
    func popoverDidClose(_ notification: Notification) {
        // Release the SwiftUI panel so it stops consuming resources when hidden.
        popover.contentViewController = nil
    }
}
