import AppKit
import LoadSpinnerCore

/// A layer-backed menu bar view that draws one or two fixed frames (circle or
/// rounded square) with a lit segment travelling around each perimeter.
///
/// The frames never rotate; only the lit segments move, each at a speed set by
/// its `rpm`. Driven by animating each `CAShapeLayer`'s `lineDashPhase`.
final class SpinnerView: NSView {
    struct Spec: Equatable {
        var shape: IndicatorShape
        var colorHex: String
        var rpm: Double
    }

    private final class Cell {
        let track = CAShapeLayer()
        let highlight = CAShapeLayer()
        var shape: IndicatorShape = .circle
        var rpm: Double = 8
        var phase: CGFloat = 0
        var perimeter: CGFloat = 1
    }

    private var cells: [Cell] = []
    private var frameTimer: Timer?

    private let lineWidth: CGFloat = 2.4
    private let litFraction: CGFloat = 0.28
    private let frameRate: Double = 30

    private var cellWidth: CGFloat { NSStatusBar.system.thickness }

    /// Preferred status item width for the current indicator count.
    var preferredWidth: CGFloat { max(CGFloat(cells.count), 1) * cellWidth }

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

    func update(specs: [Spec]) {
        if specs.count != cells.count {
            rebuildCells(count: specs.count)
        }
        for (index, spec) in specs.enumerated() {
            let cell = cells[index]
            cell.shape = spec.shape
            cell.rpm = spec.rpm
            cell.highlight.strokeColor = (NSColor(hex: spec.colorHex) ?? .systemTeal).cgColor
        }
        needsLayout = true
        layoutSubtreeIfNeeded()
    }

    private func rebuildCells(count: Int) {
        for cell in cells {
            cell.track.removeFromSuperlayer()
            cell.highlight.removeFromSuperlayer()
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
            return cell
        }
    }

    override func layout() {
        super.layout()
        let scale = window?.backingScaleFactor ?? 2
        layer?.contentsScale = scale
        for (index, cell) in cells.enumerated() {
            layoutCell(cell, column: index, scale: scale)
        }
    }

    private func layoutCell(_ cell: Cell, column: Int, scale: CGFloat) {
        let cellRect = NSRect(x: CGFloat(column) * cellWidth, y: 0, width: cellWidth, height: bounds.height)
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
