import AppKit
import LoadSpinnerCore

/// A layer-backed menu bar view that draws one or more indicators. Two kinds
/// share the same circle / rounded-square frame vocabulary:
///
/// - **spinner** (CPU/GPU, a *rate*): the frame stays fixed while a lit segment
///   travels around its perimeter, at a speed set by `rpm`.
/// - **gauge** (memory, a *level*): the frame's stroke fills from the top in
///   proportion to `fill`, and does not move. Its stillness signals "this is a
///   level, not a rate."
///
/// Each indicator may carry an optional vertical source badge ("CPU"/"GPU").
final class SpinnerView: NSView {
    /// What an indicator represents and how it animates.
    enum Kind: Equatable {
        /// A rate: a lit segment travels the perimeter at `rpm`.
        case spinner(rpm: Double)
        /// A level: the stroke fills to `fill` (0...1), static.
        case gauge(fill: Double)
    }

    struct Spec: Equatable {
        var shape: IndicatorShape
        var colorHex: String
        var kind: Kind
        /// Vertical source badge drawn to the left of the frame.
        var label: String?
    }

    private final class Cell {
        let track = CAShapeLayer()
        let highlight = CAShapeLayer()
        let badge = CALayer()
        let text = CATextLayer()
        var shape: IndicatorShape = .circle
        var isGauge = false
        var rpm: Double = 8
        var phase: CGFloat = 0
        var perimeter: CGFloat = 1
        var label: String?
    }

    private var cells: [Cell] = []
    private var frameTimer: Timer?

    private let lineWidth: CGFloat = 2.4
    private let litFraction: CGFloat = 0.28
    private let frameRate: Double = 30
    private let labelColumnWidth: CGFloat = 15
    private let labelFontSize: CGFloat = 7
    private let cellGap: CGFloat = 2

    private var labelFont: NSFont { .systemFont(ofSize: labelFontSize, weight: .semibold) }
    private var iconWidth: CGFloat { NSStatusBar.system.thickness }

    /// Preferred status item width for the current indicators (+ labels + gaps).
    var preferredWidth: CGFloat {
        let content = cells.reduce(0) { $0 + width(for: $1) }
        let gaps = CGFloat(max(cells.count - 1, 0)) * cellGap
        return max(content + gaps, iconWidth)
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        startAnimating()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Let clicks fall through to the status item button.
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsLayout = true
    }

    func update(specs: [Spec]) {
        if specs.count != cells.count {
            rebuildCells(count: specs.count)
        }
        for (index, spec) in specs.enumerated() {
            let cell = cells[index]
            cell.shape = spec.shape
            cell.label = spec.label
            cell.highlight.strokeColor = (NSColor(hex: spec.colorHex) ?? .systemTeal).cgColor

            switch spec.kind {
            case .spinner(let rpm):
                cell.isGauge = false
                cell.rpm = rpm
                cell.highlight.strokeStart = 0
                cell.highlight.strokeEnd = 1
            case .gauge(let fill):
                cell.isGauge = true
                cell.rpm = 0
                cell.phase = 0
                cell.highlight.lineDashPattern = nil
                cell.highlight.lineDashPhase = 0
                cell.highlight.strokeStart = 0
                // Animatable: the fill eases smoothly to its new value.
                cell.highlight.strokeEnd = CGFloat(min(max(fill, 0), 1))
            }

            cell.text.string = spec.label ?? ""
            cell.text.isHidden = spec.label == nil
            cell.badge.isHidden = spec.label == nil
        }
        needsLayout = true
        layoutSubtreeIfNeeded()
    }

    private func width(for cell: Cell) -> CGFloat {
        let labelW = cell.label != nil ? labelColumnWidth : 0
        return labelW + iconWidth
    }

    private func rebuildCells(count: Int) {
        for cell in cells {
            cell.track.removeFromSuperlayer()
            cell.highlight.removeFromSuperlayer()
            cell.badge.removeFromSuperlayer()
            cell.text.removeFromSuperlayer()
        }
        cells = (0..<count).map { _ in
            let cell = Cell()
            for shapeLayer in [cell.track, cell.highlight] {
                shapeLayer.fillColor = NSColor.clear.cgColor
                shapeLayer.lineWidth = lineWidth
                shapeLayer.lineCap = .round
                layer?.addSublayer(shapeLayer)
            }
            cell.track.strokeColor = NSColor.tertiaryLabelColor.cgColor

            cell.badge.masksToBounds = true
            cell.badge.cornerRadius = 2
            cell.badge.isHidden = true
            cell.text.font = labelFont
            cell.text.fontSize = labelFontSize
            cell.text.alignmentMode = .center
            cell.text.isHidden = true
            // Rotate 90° counter-clockwise so labels read bottom-to-top.
            let rotation = CATransform3DMakeRotation(.pi / 2, 0, 0, 1)
            cell.badge.transform = rotation
            cell.text.transform = rotation
            layer?.addSublayer(cell.badge)
            layer?.addSublayer(cell.text)
            return cell
        }
    }

    override func layout() {
        super.layout()
        let scale = window?.backingScaleFactor ?? 2
        layer?.contentsScale = scale

        var originX: CGFloat = 0
        for (index, cell) in cells.enumerated() {
            let labelW = cell.label != nil ? labelColumnWidth : 0
            if cell.label != nil {
                layoutLabel(cell, centerX: originX + labelW / 2, scale: scale)
            }
            let iconRect = NSRect(x: originX + labelW, y: 0, width: iconWidth, height: bounds.height)
            layoutIcon(cell, in: iconRect, scale: scale)
            originX += labelW + iconWidth
            if index < cells.count - 1 { originX += cellGap }
        }
    }

    private func layoutLabel(_ cell: Cell, centerX: CGFloat, scale: CGFloat) {
        let center = CGPoint(x: centerX, y: bounds.midY)
        let textSize = ((cell.label ?? "") as NSString).size(withAttributes: [.font: labelFont])
        // Long axis = the glyph run (runs vertically once rotated); short axis =
        // the line height (the badge's width in the menu bar).
        let glyphLength = min(ceil(textSize.width), bounds.height - 2)
        let lineHeight = ceil(textSize.height)

        cell.text.bounds = CGRect(x: 0, y: 0, width: glyphLength, height: lineHeight)
        cell.text.position = center
        cell.text.contentsScale = scale

        cell.badge.bounds = CGRect(x: 0, y: 0, width: glyphLength + 2, height: lineHeight)
        cell.badge.position = center
        cell.badge.contentsScale = scale

        // Monochrome badge, inverted for the menu bar's light/dark appearance.
        let isDark = effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        cell.badge.backgroundColor = (isDark ? NSColor.white : NSColor.black).cgColor
        cell.text.foregroundColor = (isDark ? NSColor.black : NSColor.white).cgColor
    }

    private func layoutIcon(_ cell: Cell, in cellRect: NSRect, scale: CGFloat) {
        let inset = lineWidth + 2
        let available = cellRect.insetBy(dx: inset, dy: inset)
        let side = max(min(available.width, available.height), 1)
        let square = NSRect(
            x: cellRect.midX - side / 2,
            y: cellRect.midY - side / 2,
            width: side,
            height: side
        )

        let framePath: CGPath
        switch cell.shape {
        case .circle:
            framePath = CGPath(ellipseIn: square, transform: nil)
            cell.perimeter = .pi * side
        case .square:
            let radius = side * 0.22
            framePath = CGPath(roundedRect: square, cornerWidth: radius, cornerHeight: radius, transform: nil)
            cell.perimeter = 4 * (side - 2 * radius) + 2 * .pi * radius
        }

        cell.track.frame = bounds
        cell.track.path = framePath
        cell.track.contentsScale = scale
        cell.highlight.frame = bounds
        cell.highlight.contentsScale = scale

        if cell.isGauge {
            cell.highlight.lineDashPattern = nil
            switch cell.shape {
            case .circle:
                // Fill clockwise from the top (12 o'clock) so the ring reads as a
                // conventional gauge. Layer coordinates are y-up, so the top is at
                // +π/2 and clockwise means a decreasing sweep.
                let center = CGPoint(x: square.midX, y: square.midY)
                let arc = CGMutablePath()
                arc.addArc(
                    center: center, radius: side / 2,
                    startAngle: .pi / 2, endAngle: .pi / 2 - 2 * .pi, clockwise: true
                )
                cell.highlight.path = arc
            case .square:
                cell.highlight.path = framePath
            }
        } else {
            cell.highlight.path = framePath
            let lit = cell.perimeter * litFraction
            cell.highlight.lineDashPattern = [NSNumber(value: Double(lit)), NSNumber(value: Double(cell.perimeter - lit))]
        }
    }

    private func startAnimating() {
        let timer = Timer(timeInterval: 1.0 / frameRate, target: self, selector: #selector(step), userInfo: nil, repeats: true)
        RunLoop.main.add(timer, forMode: .common)
        frameTimer = timer
    }

    @objc private func step() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        // Gauges are levels, not rates — they do not travel.
        for cell in cells where !cell.isGauge {
            let revolutionsPerSecond = cell.rpm / 60.0
            cell.phase += CGFloat(revolutionsPerSecond / frameRate) * cell.perimeter
            if cell.phase > cell.perimeter { cell.phase -= cell.perimeter }
            cell.highlight.lineDashPhase = -cell.phase
        }
        CATransaction.commit()
    }
}
