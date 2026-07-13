import AppKit
import LoadSpinnerCore

/// A layer-backed menu bar view that draws one or two fixed frames (circle or
/// rounded square) with a lit segment travelling around each perimeter, and an
/// optional vertical text badge next to each frame.
///
/// The frames never rotate; only the lit segments move, each at a speed set by
/// its `rpm`. Driven by animating each `CAShapeLayer`'s `lineDashPhase`.
final class SpinnerView: NSView {
    struct Spec: Equatable {
        var shape: IndicatorShape
        var colorHex: String
        var rpm: Double
        var label: String?
    }

    private final class Cell {
        let track = CAShapeLayer()
        let highlight = CAShapeLayer()
        let badge = CALayer()
        let text = CATextLayer()
        var shape: IndicatorShape = .circle
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
            cell.rpm = spec.rpm
            cell.label = spec.label
            cell.highlight.strokeColor = (NSColor(hex: spec.colorHex) ?? .systemTeal).cgColor
            cell.text.string = spec.label ?? ""
            cell.text.isHidden = spec.label == nil
            cell.badge.isHidden = spec.label == nil
        }
        needsLayout = true
        layoutSubtreeIfNeeded()
    }

    private func width(for cell: Cell) -> CGFloat {
        (cell.label != nil ? labelColumnWidth : 0) + iconWidth
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
            let hasLabel = cell.label != nil
            let currentLabelWidth = hasLabel ? labelColumnWidth : 0
            if hasLabel {
                layoutLabel(cell, centerX: originX + currentLabelWidth / 2, scale: scale)
            }
            let iconRect = NSRect(x: originX + currentLabelWidth, y: 0, width: iconWidth, height: bounds.height)
            layoutIcon(cell, in: iconRect, scale: scale)
            originX += currentLabelWidth + iconWidth
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

        let path: CGPath
        switch cell.shape {
        case .circle:
            path = CGPath(ellipseIn: square, transform: nil)
            cell.perimeter = .pi * side
        case .square:
            let radius = side * 0.22
            path = CGPath(roundedRect: square, cornerWidth: radius, cornerHeight: radius, transform: nil)
            cell.perimeter = 4 * (side - 2 * radius) + 2 * .pi * radius
        }

        for shapeLayer in [cell.track, cell.highlight] {
            shapeLayer.frame = bounds
            shapeLayer.path = path
            shapeLayer.contentsScale = scale
        }
        let lit = cell.perimeter * litFraction
        cell.highlight.lineDashPattern = [NSNumber(value: Double(lit)), NSNumber(value: Double(cell.perimeter - lit))]
    }

    private func startAnimating() {
        let timer = Timer(timeInterval: 1.0 / frameRate, target: self, selector: #selector(step), userInfo: nil, repeats: true)
        RunLoop.main.add(timer, forMode: .common)
        frameTimer = timer
    }

    @objc private func step() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for cell in cells {
            let revolutionsPerSecond = cell.rpm / 60.0
            cell.phase += CGFloat(revolutionsPerSecond / frameRate) * cell.perimeter
            if cell.phase > cell.perimeter { cell.phase -= cell.perimeter }
            cell.highlight.lineDashPhase = -cell.phase
        }
        CATransaction.commit()
    }
}
