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

/// The memory donut: a filling ring (a *level*, not a rate) with the used
/// percentage in the hole. Fills clockwise from the top for the circle frame.
private struct MemoryDonut: View {
    var shape: IndicatorShape
    var color: Color
    var usedRatio: Double
    var size: CGFloat = 52

    var body: some View {
        let path = IndicatorShapePath(kind: shape)
        let ratio = max(0.0, min(usedRatio, 1))
        return ZStack {
            path.stroke(Color.secondary.opacity(0.2), style: StrokeStyle(lineWidth: 5))
            path
                .trim(from: 0, to: max(0.001, ratio))
                .stroke(color, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                // Only the circle rotates to start at 12 o'clock; rotating a
                // rounded square would just tilt the frame.
                .rotationEffect(shape == .circle ? .degrees(-90) : .degrees(0))
            Text(memoryPercentLabel(usedRatio: ratio))
                .font(.system(size: 13, weight: .semibold))
                .monospacedDigit()
        }
        .frame(width: size, height: size)
    }
}

struct PanelView: View {
    @ObservedObject var model: AppModel
    var onOpenSettings: () -> Void
    var onQuit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            liveCards
            memoryCard
            historyChart
            Divider()
            footer
        }
        .padding(16)
        .frame(width: 340)
    }

    private var header: some View {
        HStack(spacing: 6) {
            Text("負荷モニター").font(.headline)
            Circle().fill(.green).frame(width: 7, height: 7)
            Text("ライブ").font(.caption).foregroundStyle(.secondary)
            Spacer()
            // Flip-to-settings control, pinned top-right; the settings face puts its
            // flip-back control in the same corner so the toggle never moves.
            Button(action: onOpenSettings) {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.borderless)
            // Keep the flip toggle out of the key-view loop (no auto focus ring).
            .focusable(false)
            .help("設定")
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

    // MARK: - Memory

    private var memoryCard: some View {
        let reading = model.memoryReading
        return HStack(spacing: 12) {
            MemoryDonut(shape: model.settings.memoryShape, color: memoryColor(reading), usedRatio: reading.usedRatio)
            VStack(alignment: .leading, spacing: 4) {
                Text("メモリ").font(.caption).foregroundStyle(.secondary)
                Text(memoryGBText(reading)).font(.callout).monospacedDigit()
            }
            Spacer()
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color(nsColor: .controlBackgroundColor)))
    }

    /// The donut color: fixed accent, or a used-ratio gradient — matching the
    /// menu-bar gauge and the CPU/GPU color axis.
    private func memoryColor(_ reading: MemoryReading) -> Color {
        let hex = memoryGaugeColorHex(
            mode: model.settings.memoryColorMode,
            fixedHex: model.settings.memoryColorHex,
            usedRatio: reading.usedRatio
        )
        return Color(hex: hex) ?? .teal
    }

    private func memoryGBText(_ reading: MemoryReading) -> String {
        String(format: "%.1f / %.1f GB", gigabytes(reading.usedBytes), gigabytes(reading.totalBytes))
    }

    private var historyChart: some View {
        // The history chart uses fixed, distinct colors (CPU green, GPU blue) —
        // independent of the indicator color mode — so the two lines are always
        // distinguishable.
        let cpuColor = Color.green
        let gpuColor = Color.blue
        let memoryLineColor = Color.purple
        // Anchor the newest sample to the right edge and keep a fixed 3-minute
        // window, so the line scrolls in from the right instead of compressing.
        let capacity = model.historyCapacity
        let cpuOffset = capacity - model.cpuHistory.count
        let gpuOffset = capacity - model.gpuHistory.count
        let memoryOffset = capacity - model.memoryHistory.count
        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text("過去 3 分").font(.caption2).foregroundStyle(.secondary)
                Spacer()
                legendChip(color: cpuColor, label: "CPU")
                if model.gpuAvailable {
                    legendChip(color: gpuColor, label: "GPU")
                }
                legendChip(color: memoryLineColor, label: "MEM")
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
                // Memory (used ratio) — always available, on the same 0...100 axis.
                ForEach(Array(model.memoryHistory.enumerated()), id: \.offset) { index, value in
                    LineMark(x: .value("t", memoryOffset + index), y: .value("load", value * 100), series: .value("s", "MEM"))
                        .foregroundStyle(memoryLineColor)
                        .lineStyle(StrokeStyle(lineWidth: 2))
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

    private var footer: some View {
        HStack {
            Text("load-spinner \(appVersion)").font(.caption2).foregroundStyle(.secondary)
            Spacer()
            Button("終了") { onQuit() }
        }
    }

    // MARK: - Helpers

    /// The color to draw for a source: its fixed color, or the load-linked
    /// gradient color when the gradient color mode is active.
    private func effectiveColor(fixedHex: String, load: Double) -> Color {
        if model.settings.colorMode == .gradient {
            return Color(hex: loadGradientColorHex(forLoad: load)) ?? .teal
        }
        return Color(hex: fixedHex) ?? .teal
    }
}
