import Charts
import LoadSpinnerCore
import SwiftUI

/// A shape drawn as a fixed frame (circle or rounded square), used both for the
/// live mini-spinner and its background track.
private struct IndicatorShapePath: Shape {
    var kind: IndicatorShape

    func path(in rect: CGRect) -> Path {
        let side = min(rect.width, rect.height) - 3
        let square = CGRect(x: rect.midX - side / 2, y: rect.midY - side / 2, width: side, height: side)
        switch kind {
        case .circle: return Path(ellipseIn: square)
        case .square: return Path(roundedRect: square, cornerRadius: side * 0.22)
        }
    }

    func perimeter(for rect: CGRect) -> CGFloat {
        let side = min(rect.width, rect.height) - 3
        switch kind {
        case .circle:
            return .pi * side
        case .square:
            let radius = side * 0.22
            return 4 * (side - 2 * radius) + 2 * .pi * radius
        }
    }
}

/// A static live gauge: a fixed frame whose stroke fills in proportion to load.
/// The menu bar carries the animation, so the panel stays render-cheap.
private struct LoadRing: View {
    var shape: IndicatorShape
    var color: Color
    var load: Double
    var size: CGFloat = 24

    var body: some View {
        let pathShape = IndicatorShapePath(kind: shape)
        return ZStack {
            pathShape.stroke(Color.secondary.opacity(0.25), style: StrokeStyle(lineWidth: 3))
            pathShape
                .trim(from: 0, to: max(0.02, min(load, 1)))
                .stroke(color, style: StrokeStyle(lineWidth: 3, lineCap: .round))
        }
        .frame(width: size, height: size)
    }
}

struct PanelView: View {
    @ObservedObject var model: AppModel
    var onQuit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            liveCards
            historyChart
            Divider()
            settingsSection
            Divider()
            footer
        }
        .padding(16)
        .frame(width: 340)
    }

    private var header: some View {
        HStack {
            Text("負荷モニター").font(.headline)
            Spacer()
            Circle().fill(.green).frame(width: 7, height: 7)
            Text("ライブ").font(.caption).foregroundStyle(.secondary)
        }
    }

    private var liveCards: some View {
        HStack(spacing: 10) {
            liveCard(title: "CPU", load: model.cpuLoad, shape: model.settings.cpuShape,
                     colorHex: model.settings.cpuColorHex, enabled: true)
            liveCard(title: "GPU", load: model.gpuLoad, shape: model.settings.gpuShape,
                     colorHex: model.settings.gpuColorHex, enabled: model.gpuAvailable)
        }
    }

    private func liveCard(title: String, load: Double, shape: IndicatorShape, colorHex: String, enabled: Bool) -> some View {
        HStack(spacing: 10) {
            if enabled {
                LoadRing(shape: shape, color: effectiveColor(fixedHex: colorHex, load: load), load: load)
            } else {
                IndicatorShapePath(kind: shape)
                    .stroke(Color.secondary.opacity(0.25), style: StrokeStyle(lineWidth: 3))
                    .frame(width: 24, height: 24)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.caption).foregroundStyle(.secondary)
                Text(enabled ? "\(Int((load * 100).rounded()))%" : "—")
                    .font(.title3).fontWeight(.medium).monospacedDigit()
            }
            Spacer()
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color(nsColor: .controlBackgroundColor)))
    }

    private var historyChart: some View {
        // The history chart uses fixed, distinct colors (CPU green, GPU blue) —
        // independent of the indicator color mode — so the two lines are always
        // distinguishable.
        let cpuColor = Color.green
        let gpuColor = Color.blue
        // Anchor the newest sample to the right edge and keep a fixed 3-minute
        // window, so the line scrolls in from the right instead of compressing.
        let capacity = model.historyCapacity
        let cpuOffset = capacity - model.cpuHistory.count
        let gpuOffset = capacity - model.gpuHistory.count
        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text("過去 3 分").font(.caption2).foregroundStyle(.secondary)
                Spacer()
                legendChip(color: cpuColor, label: "CPU")
                if model.gpuAvailable {
                    legendChip(color: gpuColor, label: "GPU")
                }
            }
            Chart {
                ForEach(Array(model.cpuHistory.enumerated()), id: \.offset) { index, value in
                    LineMark(x: .value("t", cpuOffset + index), y: .value("load", value * 100), series: .value("s", "CPU"))
                        .foregroundStyle(cpuColor)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                    AreaMark(x: .value("t", cpuOffset + index), y: .value("load", value * 100), series: .value("s", "CPU"))
                        .foregroundStyle(cpuColor.opacity(0.12))
                }
                if model.gpuAvailable {
                    ForEach(Array(model.gpuHistory.enumerated()), id: \.offset) { index, value in
                        LineMark(x: .value("t", gpuOffset + index), y: .value("load", value * 100), series: .value("s", "GPU"))
                            .foregroundStyle(gpuColor)
                            .lineStyle(StrokeStyle(lineWidth: 2))
                    }
                }
            }
            .chartXScale(domain: 0...(capacity - 1))
            .chartYScale(domain: 0...100)
            .chartXAxis(.hidden)
            .chartYAxis { AxisMarks(values: [0, 50, 100]) }
            .frame(height: 74)
        }
    }

    private func legendChip(color: Color, label: String) -> some View {
        HStack(spacing: 3) {
            Rectangle().fill(color).frame(width: 12, height: 2)
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
    }

    // MARK: - Settings

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
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

            Toggle("ログイン時に起動", isOn: loginBinding)
                .toggleStyle(.switch)
                .font(.subheadline)
        }
    }

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

    private var gradientPreview: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(LinearGradient(
                colors: loadGradientStops.map { Color(hex: $0.hex) ?? .gray },
                startPoint: .leading,
                endPoint: .trailing
            ))
            .frame(width: 104, height: 14)
    }

    private var footer: some View {
        HStack {
            Text("load-spinner \(appVersion)").font(.caption2).foregroundStyle(.secondary)
            Spacer()
            Button("終了") { onQuit() }
        }
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

    /// The color to draw for a source: its fixed color, or the load-linked
    /// gradient color when the gradient color mode is active.
    private func effectiveColor(fixedHex: String, load: Double) -> Color {
        if model.settings.colorMode == .gradient {
            return Color(hex: loadGradientColorHex(forLoad: load)) ?? .teal
        }
        return Color(hex: fixedHex) ?? .teal
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
