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
    /// Resolved once at launch: re-probing on every popover open would cost a
    /// Launch Services round trip for a location that does not move.
    private var activityMonitorURL: URL?
    private var sampleTimer: Timer?
    private var popoverClickMonitors: [Any] = []
    /// Whether the panel is up, and which of the two events of one click on
    /// our own status item has already acted. Never `popover.isShown`, which
    /// lags a close by about half a second (see `PanelToggle`).
    private var panelToggle = PanelToggle()
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        gpuAvailable = gpuSampler.sample() != nil
        activityMonitorURL = ActivityMonitor.locate()
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
        installPopoverClickMonitors()

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

    /// The button's action — the only way the panel opens (a show issued from
    /// the monitor is dismissed within the same click; measured). Not
    /// `popover.isShown`: that stays true for about half a second after a close,
    /// and reading it is what kept a re-click from opening the panel at all
    /// (see `PanelToggle`).
    @objc private func togglePopover() {
        switch panelToggle.statusItemAction(at: Date()) {
        case .close: popover.performClose(nil)
        case .open: showPanel()
        case .none: break
        }
    }

    private func showPanel() {
        guard let button = statusItem.button else { return }
        let opening = PanelOpening()
        // Build the SwiftUI panel only while it is on screen so it does no
        // rendering work when closed. It resets to the status face on each open.
        let hosting = NSHostingController(
            rootView: PanelContainer(
                model: model,
                opening: opening,
                onOpenActivityMonitor: activityMonitorURL.map { url in
                    { [weak self] in
                        self?.closePanelFromApp()
                        ActivityMonitor.open(at: url)
                    }
                },
                onQuit: { NSApplication.shared.terminate(nil) }
            )
        )
        // Size the popover to the SwiftUI content's ideal size, otherwise the
        // top of the panel is clipped.
        hosting.sizingOptions = [.preferredContentSize]
        popover.contentViewController = hosting
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
        // The hidden settings face is built now, after `show` has returned.
        // On macOS 27 the button's action arrives while the button is still
        // held; the menu bar drops the pressed highlight at the release and
        // shows the popover's own highlight only once `show` is done, so a show
        // still running at the release leaves the item dark for a frame or
        // three. Building both faces inside `show` took 92–94 ms, the front
        // alone 41–49 ms (measured on macOS 27.0).
        DispatchQueue.main.async { opening.popoverIsUp = true }
    }

    private func closePanelFromApp() {
        if panelToggle.closeFromApp() == .close { popover.performClose(nil) }
    }

    /// Installed at launch and kept for as long as the app runs: it is what
    /// dismisses the panel, including for a click on our own status item, whose
    /// button action arrives 23–41 ms later and often not at all (measured —
    /// see `PanelToggle`). `.transient` alone only closes the popover when the
    /// outside click lands in a window that takes activation; a click on a
    /// surface that does not — an empty stretch of the menu bar, another
    /// process's non-activating panel — leaves it open (measured on macOS 27.0,
    /// with and without the `makeKey()` in `showPanel`).
    private func installPopoverClickMonitors() {
        removePopoverClickMonitors()
        let events: NSEvent.EventTypeMask = [.leftMouseDown, .rightMouseDown]
        let global = NSEvent.addGlobalMonitorForEvents(matching: events) { [weak self] event in
            // A global monitor's event has no window, so this is already in
            // screen coordinates. NSEvent is not Sendable; the point is.
            let location = event.locationInWindow
            MainActor.assumeIsolated { self?.globalMouseDown(at: location) }
        }
        let local = NSEvent.addLocalMonitorForEvents(matching: events) { [weak self] event in
            let window = event.window
            MainActor.assumeIsolated {
                guard let self else { return }
                let site: PopoverClickSite
                if window === self.statusItem.button?.window {
                    site = .statusItemButton
                } else if window === self.popover.contentViewController?.view.window {
                    site = .popover
                } else {
                    site = .elsewhere
                }
                if shouldClosePopover(panelIsUp: self.panelToggle.isUp, clickSite: site) {
                    self.closePanelFromApp()
                }
            }
            return event
        }
        popoverClickMonitors = [global, local].compactMap { $0 }
    }

    /// Every global mouse-down: it dismisses a panel that is up, wherever the
    /// click landed. A click on our own status item is noted, so that the same
    /// click's button action does not open the panel again.
    private func globalMouseDown(at location: CGPoint) {
        // The frame is read now: the item is as wide as its content.
        let onItem = statusItemOwns(
            location, itemWindowFrame: statusItem.button?.window?.frame)
        if panelToggle.globalMouseDown(onStatusItem: onItem, at: Date()) == .close {
            popover.performClose(nil)
        }
    }

    private func removePopoverClickMonitors() {
        for monitor in popoverClickMonitors {
            NSEvent.removeMonitor(monitor)
        }
        popoverClickMonitors = []
    }
}

extension AppDelegate: NSPopoverDelegate {
    func popoverDidClose(_ notification: Notification) {
        // Arrives about half a second after the close, which can be after the
        // panel has been opened again; `PanelToggle` tells the two apart.
        panelToggle.panelReportedClose()
        guard !panelToggle.isUp else { return }
        // Release the SwiftUI panel so it stops consuming resources when hidden.
        popover.contentViewController = nil
    }
}
