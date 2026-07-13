import AppKit
import LoadSpinnerCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var spinnerView: SpinnerView!
    private let monitor = LoadMonitor()
    private let settingsStore = SettingsStore()
    private var sampleTimer: Timer?
    private var cpuInfoItem: NSMenuItem?

    private let statusItemWidth: CGFloat = 26

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: statusItemWidth)
        let view = SpinnerView(frame: NSRect(x: 0, y: 0, width: statusItemWidth, height: NSStatusBar.system.thickness))
        spinnerView = view
        if let button = statusItem.button {
            button.addSubview(view)
            view.frame = button.bounds
            view.autoresizingMask = [.width, .height]
        }

        applySettings()
        rebuildMenu()

        monitor.refresh() // prime the baseline snapshot

        let timer = Timer(timeInterval: 1.0, target: self, selector: #selector(tick), userInfo: nil, repeats: true)
        RunLoop.main.add(timer, forMode: .common)
        sampleTimer = timer
    }

    @objc private func tick() {
        let load = monitor.refresh()
        spinnerView.rpm = rotationsPerMinute(forLoad: load)
        cpuInfoItem?.title = "CPU  \(Int((load * 100).rounded()))%"
    }

    // MARK: - Settings application

    private func applySettings() {
        let settings = settingsStore.settings
        spinnerView.shape = activeShape(for: settings)
        spinnerView.color = NSColor(hex: activeColorHex(for: settings)) ?? .systemTeal
    }

    /// The shape driving the single Phase 1 indicator, per the current mode.
    private func activeShape(for settings: AppSettings) -> IndicatorShape {
        switch settings.mode {
        case .cpu: return settings.cpuShape
        default: return settings.combinedShape
        }
    }

    private func activeColorHex(for settings: AppSettings) -> String {
        switch settings.mode {
        case .cpu: return settings.cpuColorHex
        default: return settings.combinedColorHex
        }
    }

    // MARK: - Menu

    private func rebuildMenu() {
        let settings = settingsStore.settings
        let menu = NSMenu()

        let info = NSMenuItem(title: "CPU  —", action: nil, keyEquivalent: "")
        info.isEnabled = false
        menu.addItem(info)
        cpuInfoItem = info

        menu.addItem(.separator())

        let modeMenu = NSMenu()
        addItem(to: modeMenu, title: "高い方", value: DisplayMode.max.rawValue,
                checked: settings.mode == .max, action: #selector(selectMode(_:)))
        addItem(to: modeMenu, title: "CPUのみ", value: DisplayMode.cpu.rawValue,
                checked: settings.mode == .cpu, action: #selector(selectMode(_:)))
        let modeItem = NSMenuItem(title: "表示モード", action: nil, keyEquivalent: "")
        modeItem.submenu = modeMenu
        menu.addItem(modeItem)

        let shapeMenu = NSMenu()
        let currentShape = activeShape(for: settings)
        addItem(to: shapeMenu, title: "● 丸", value: IndicatorShape.circle.rawValue,
                checked: currentShape == .circle, action: #selector(selectShape(_:)))
        addItem(to: shapeMenu, title: "■ 四角", value: IndicatorShape.square.rawValue,
                checked: currentShape == .square, action: #selector(selectShape(_:)))
        let shapeItem = NSMenuItem(title: "シンボル", action: nil, keyEquivalent: "")
        shapeItem.submenu = shapeMenu
        menu.addItem(shapeItem)

        let colorMenu = NSMenu()
        let currentColorHex = activeColorHex(for: settings)
        for hex in indicatorPalette {
            let item = NSMenuItem(title: hex, action: #selector(selectColor(_:)), keyEquivalent: "")
            item.representedObject = hex
            item.target = self
            item.state = (hex.caseInsensitiveCompare(currentColorHex) == .orderedSame) ? .on : .off
            item.image = colorSwatch(hex)
            colorMenu.addItem(item)
        }
        let colorItem = NSMenuItem(title: "色", action: nil, keyEquivalent: "")
        colorItem.submenu = colorMenu
        menu.addItem(colorItem)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "load-spinner を終了", action: #selector(quit), keyEquivalent: "q"))

        statusItem.menu = menu
    }

    private func addItem(to menu: NSMenu, title: String, value: String, checked: Bool, action: Selector) {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.representedObject = value
        item.target = self
        item.state = checked ? .on : .off
        menu.addItem(item)
    }

    private func colorSwatch(_ hex: String) -> NSImage? {
        guard let color = NSColor(hex: hex) else { return nil }
        let size = NSSize(width: 12, height: 12)
        let image = NSImage(size: size)
        image.lockFocus()
        color.setFill()
        NSBezierPath(roundedRect: NSRect(origin: .zero, size: size), xRadius: 3, yRadius: 3).fill()
        image.unlockFocus()
        return image
    }

    // MARK: - Actions

    @objc private func selectMode(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let mode = DisplayMode(rawValue: raw) else { return }
        settingsStore.update { $0.mode = mode }
        applySettings()
        rebuildMenu()
    }

    @objc private func selectShape(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let shape = IndicatorShape(rawValue: raw) else { return }
        settingsStore.update { settings in
            switch settings.mode {
            case .cpu: settings.cpuShape = shape
            default: settings.combinedShape = shape
            }
        }
        applySettings()
        rebuildMenu()
    }

    @objc private func selectColor(_ sender: NSMenuItem) {
        guard let hex = sender.representedObject as? String else { return }
        settingsStore.update { settings in
            switch settings.mode {
            case .cpu: settings.cpuColorHex = hex
            default: settings.combinedColorHex = hex
            }
        }
        applySettings()
        rebuildMenu()
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
}
