import LoadSpinnerCore
import SwiftUI

/// The back face of the click-to-open popover: everything configurable, reached by
/// flipping the status readout over via its gear button (see `PanelContainer`). A
/// back chevron flips it back. Keeping settings off the front face leaves the
/// glance uncluttered without sending the user to a separate window. See
/// docs/adr/0003-settings-on-popover-back.md.
struct SettingsView: View {
    @ObservedObject var model: AppModel
    var onBack: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            indicatorSection
            Divider()
            memorySection
            Divider()
            generalSection
        }
        .padding(16)
        .frame(width: 340)
    }

    // MARK: - Sections

    private var header: some View {
        HStack(spacing: 8) {
            Text("設定").font(.headline)
            Spacer()
            // Flip-back control, pinned top-right — the same corner as the info
            // face's gear, so the flip toggle stays put across both faces.
            Button(action: onBack) {
                Image(systemName: "chevron.backward")
            }
            .buttonStyle(.borderless)
            // Keep the flip toggle out of the key-view loop; otherwise it grabs
            // keyboard focus (and draws a focus ring) the moment this face appears.
            .focusable(false)
            .help("情報に戻る")
        }
    }

    private var indicatorSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("インジケーター")

            Picker("表示モード", selection: modeBinding) {
                ForEach(availableModes, id: \.self) { mode in
                    Text(modeLabel(mode)).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            Picker("色", selection: colorModeBinding) {
                Text("単色").tag(ColorMode.fixed)
                Text("負荷連動").tag(ColorMode.gradient)
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            configRows

            Toggle("アイコンにラベルを表示", isOn: boolBinding(\.showLabels))
                .toggleStyle(.switch)
                .font(.subheadline)
        }
    }

    /// Memory-specific controls: menu-bar visibility, frame shape, and color mode
    /// (all also restyle the panel donut). The gauge fills with the used ratio; its
    /// color is a fixed accent or a used-ratio gradient.
    private var memorySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("メモリ")

            Toggle("メモリをメニューバーに表示", isOn: boolBinding(\.showMemory))
                .toggleStyle(.switch)
                .font(.subheadline)

            HStack(spacing: 8) {
                Text("メモリ").font(.subheadline).frame(width: 34, alignment: .leading)
                Picker("", selection: shapeBinding(\.memoryShape)) {
                    Text("● 丸").tag(IndicatorShape.circle)
                    Text("■ 四角").tag(IndicatorShape.square)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 104)
                Spacer(minLength: 8)
                if model.settings.memoryColorMode == .fixed {
                    colorSwatches(\.memoryColorHex)
                } else {
                    memoryGradientPreview
                }
            }

            Picker("メモリ色", selection: memoryColorModeBinding) {
                Text("単色").tag(ColorMode.fixed)
                Text("使用率連動").tag(ColorMode.gradient)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
    }

    private var generalSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("全般")

            Toggle("ログイン時に起動", isOn: loginBinding)
                .toggleStyle(.switch)
                .font(.subheadline)
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundStyle(.secondary)
    }

    // MARK: - Per-source config rows

    @ViewBuilder
    private var configRows: some View {
        switch model.settings.mode {
        case .both:
            configRow("CPU", shape: \.cpuShape, color: \.cpuColorHex)
            if model.gpuAvailable {
                configRow("GPU", shape: \.gpuShape, color: \.gpuColorHex)
            }
        case .cpu:
            configRow("CPU", shape: \.cpuShape, color: \.cpuColorHex)
        case .gpu:
            configRow("GPU", shape: \.gpuShape, color: \.gpuColorHex)
        case .max:
            configRow("合成", shape: \.combinedShape, color: \.combinedColorHex)
        }
    }

    private func configRow(
        _ title: String,
        shape: WritableKeyPath<AppSettings, IndicatorShape>,
        color: WritableKeyPath<AppSettings, String>
    ) -> some View {
        HStack(spacing: 8) {
            Text(title).font(.subheadline).frame(width: 34, alignment: .leading)
            Picker("", selection: shapeBinding(shape)) {
                Text("● 丸").tag(IndicatorShape.circle)
                Text("■ 四角").tag(IndicatorShape.square)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 104)
            Spacer(minLength: 8)
            if model.settings.colorMode == .fixed {
                colorSwatches(color)
            } else {
                gradientPreview
            }
        }
    }

    private func colorSwatches(_ keyPath: WritableKeyPath<AppSettings, String>) -> some View {
        HStack(spacing: 6) {
            ForEach(indicatorPalette, id: \.self) { hex in
                let selected = model.settings[keyPath: keyPath].caseInsensitiveCompare(hex) == .orderedSame
                Circle()
                    .fill(Color(hex: hex) ?? .gray)
                    .frame(width: 16, height: 16)
                    .overlay(Circle().stroke(Color.primary, lineWidth: selected ? 2 : 0))
                    .onTapGesture { model.updateSettings { $0[keyPath: keyPath] = hex } }
            }
        }
    }

    /// The CPU/GPU load gradient preview (teal → amber → coral).
    private var gradientPreview: some View {
        gradientPreview(stops: loadGradientStops)
    }

    /// The memory used-ratio gradient preview (blue → green → orange → red).
    private var memoryGradientPreview: some View {
        gradientPreview(stops: memoryGradientStops)
    }

    private func gradientPreview(stops: [(location: Double, hex: String)]) -> some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(LinearGradient(
                gradient: Gradient(stops: stops.map {
                    .init(color: Color(hex: $0.hex) ?? .gray, location: $0.location)
                }),
                startPoint: .leading,
                endPoint: .trailing
            ))
            .frame(width: 104, height: 14)
    }

    // MARK: - Bindings & helpers

    private var availableModes: [DisplayMode] {
        model.gpuAvailable ? [.max, .cpu, .gpu, .both] : [.max, .cpu]
    }

    private func modeLabel(_ mode: DisplayMode) -> String {
        switch mode {
        case .max: return "高い方"
        case .cpu: return "CPU"
        case .gpu: return "GPU"
        case .both: return "2つ"
        }
    }

    private var modeBinding: Binding<DisplayMode> {
        Binding(
            get: { model.settings.mode },
            set: { newValue in model.updateSettings { $0.mode = newValue } }
        )
    }

    private var colorModeBinding: Binding<ColorMode> {
        Binding(
            get: { model.settings.colorMode },
            set: { newValue in model.updateSettings { $0.colorMode = newValue } }
        )
    }

    private var memoryColorModeBinding: Binding<ColorMode> {
        Binding(
            get: { model.settings.memoryColorMode },
            set: { newValue in model.updateSettings { $0.memoryColorMode = newValue } }
        )
    }

    private func shapeBinding(_ keyPath: WritableKeyPath<AppSettings, IndicatorShape>) -> Binding<IndicatorShape> {
        Binding(
            get: { model.settings[keyPath: keyPath] },
            set: { newValue in model.updateSettings { $0[keyPath: keyPath] = newValue } }
        )
    }

    private func boolBinding(_ keyPath: WritableKeyPath<AppSettings, Bool>) -> Binding<Bool> {
        Binding(
            get: { model.settings[keyPath: keyPath] },
            set: { newValue in model.updateSettings { $0[keyPath: keyPath] = newValue } }
        )
    }

    private var loginBinding: Binding<Bool> {
        Binding(
            get: { model.settings.launchAtLogin },
            set: { isOn in
                model.updateSettings { $0.launchAtLogin = isOn }
                LoginItem.setEnabled(isOn)
            }
        )
    }
}
