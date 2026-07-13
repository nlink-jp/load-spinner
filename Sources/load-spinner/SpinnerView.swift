import AppKit
import LoadSpinnerCore

/// A layer-backed menu bar view that draws a fixed frame (circle or rounded
/// square) with a single lit segment travelling around its perimeter.
///
/// The frame itself never rotates; only the lit segment moves, at a speed set
/// by `rpm`. This is driven by animating a `CAShapeLayer`'s `lineDashPhase`.
final class SpinnerView: NSView {
    var shape: IndicatorShape = .circle {
        didSet { if shape != oldValue { rebuild() } }
    }

    var color: NSColor = .systemTeal {
        didSet { highlightLayer.strokeColor = color.cgColor }
    }

    /// Rotation speed in revolutions per minute.
    var rpm: Double = 8

    private let trackLayer = CAShapeLayer()
    private let highlightLayer = CAShapeLayer()
    private var frameTimer: Timer?
    private var phase: CGFloat = 0
    private var perimeter: CGFloat = 1

    private let lineWidth: CGFloat = 2.4
    private let litFraction: CGFloat = 0.28
    private let frameRate: Double = 30

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        configureLayers()
        startAnimating()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Let clicks fall through to the status item button so its menu opens.
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func layout() {
        super.layout()
        applyContentsScale()
        rebuild()
    }

    private func configureLayers() {
        for shapeLayer in [trackLayer, highlightLayer] {
            shapeLayer.fillColor = NSColor.clear.cgColor
            shapeLayer.lineWidth = lineWidth
            shapeLayer.lineCap = .round
            layer?.addSublayer(shapeLayer)
        }
        trackLayer.strokeColor = NSColor.tertiaryLabelColor.cgColor
        highlightLayer.strokeColor = color.cgColor
    }

    private func applyContentsScale() {
        let scale = window?.backingScaleFactor ?? 2
        layer?.contentsScale = scale
        trackLayer.contentsScale = scale
        highlightLayer.contentsScale = scale
    }

    private func rebuild() {
        let inset = lineWidth + 2
        let available = bounds.insetBy(dx: inset, dy: inset)
        let side = max(min(available.width, available.height), 1)
        let square = NSRect(
            x: bounds.midX - side / 2,
            y: bounds.midY - side / 2,
            width: side,
            height: side
        )

        let path: CGPath
        switch shape {
        case .circle:
            path = CGPath(ellipseIn: square, transform: nil)
            perimeter = .pi * side
        case .square:
            let radius = side * 0.22
            path = CGPath(roundedRect: square, cornerWidth: radius, cornerHeight: radius, transform: nil)
            perimeter = 4 * (side - 2 * radius) + 2 * .pi * radius
        }

        for shapeLayer in [trackLayer, highlightLayer] {
            shapeLayer.frame = bounds
            shapeLayer.path = path
        }
        let lit = perimeter * litFraction
        highlightLayer.lineDashPattern = [NSNumber(value: Double(lit)), NSNumber(value: Double(perimeter - lit))]
    }

    private func startAnimating() {
        let timer = Timer(timeInterval: 1.0 / frameRate, target: self, selector: #selector(step), userInfo: nil, repeats: true)
        RunLoop.main.add(timer, forMode: .common)
        frameTimer = timer
    }

    @objc private func step() {
        let revolutionsPerSecond = rpm / 60.0
        phase += CGFloat(revolutionsPerSecond / frameRate) * perimeter
        if phase > perimeter { phase -= perimeter }

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        highlightLayer.lineDashPhase = -phase
        CATransaction.commit()
    }
}
