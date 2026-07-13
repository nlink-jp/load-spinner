import AppKit

// Renders the load-spinner app icon (1024x1024 PNG): a dark rounded-rect plate
// with a teal "comet" spinner ring — a bright rounded head fading into a tail,
// echoing the menu bar indicator. Run: swift scripts/gen-icon.swift [out.png]

let size = 1024
let outPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "assets/AppIcon-1024.png"

let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
)!

let ctx = NSGraphicsContext(bitmapImageRep: rep)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = ctx
let cg = ctx.cgContext

let S = CGFloat(size)
let center = CGPoint(x: S / 2, y: S / 2)

// Rounded-rect plate (macOS squircle proportions).
let inset: CGFloat = 96
let plate = CGRect(x: inset, y: inset, width: S - 2 * inset, height: S - 2 * inset)
let radius = plate.width * 0.2237
let platePath = CGPath(roundedRect: plate, cornerWidth: radius, cornerHeight: radius, transform: nil)

cg.saveGState()
cg.addPath(platePath)
cg.clip()
let bgColors = [
    NSColor(srgbRed: 0.17, green: 0.17, blue: 0.19, alpha: 1).cgColor,
    NSColor(srgbRed: 0.08, green: 0.08, blue: 0.09, alpha: 1).cgColor,
] as CFArray
let bg = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: bgColors, locations: [0, 1])!
cg.drawLinearGradient(bg, start: CGPoint(x: 0, y: S), end: CGPoint(x: 0, y: 0), options: [])
cg.restoreGState()

let ringRadius: CGFloat = 250
let lineW: CGFloat = 80

// Track ring.
cg.setLineWidth(lineW)
cg.setLineCap(.round)
cg.setStrokeColor(NSColor(srgbRed: 0.27, green: 0.27, blue: 0.30, alpha: 1).cgColor)
cg.addArc(center: center, radius: ringRadius, startAngle: 0, endAngle: .pi * 2, clockwise: false)
cg.strokePath()

// Teal comet arc: many butt-capped segments, alpha fading head -> tail.
let teal = NSColor(srgbRed: 0.36, green: 0.79, blue: 0.65, alpha: 1)
let headAngle: CGFloat = .pi / 2          // 12 o'clock
let sweep: CGFloat = .pi * 2 * 0.80        // 288°, wrapping clockwise
let segments = 180
cg.setLineCap(.butt)
for i in 0..<segments {
    let t0 = CGFloat(i) / CGFloat(segments)
    let t1 = CGFloat(i + 1) / CGFloat(segments)
    let a0 = headAngle - t0 * sweep
    let a1 = headAngle - t1 * sweep
    let alpha = pow(1 - (t0 + t1) / 2, 1.4) * 0.95 + 0.05
    cg.setStrokeColor(teal.withAlphaComponent(alpha).cgColor)
    cg.setLineWidth(lineW)
    cg.addArc(center: center, radius: ringRadius, startAngle: a0, endAngle: a1, clockwise: true)
    cg.strokePath()
}

// Rounded bright head.
let head = CGPoint(x: center.x + ringRadius * cos(headAngle), y: center.y + ringRadius * sin(headAngle))
cg.setFillColor(teal.cgColor)
cg.fillEllipse(in: CGRect(x: head.x - lineW / 2, y: head.y - lineW / 2, width: lineW, height: lineW))

NSGraphicsContext.restoreGraphicsState()

let png = rep.representation(using: .png, properties: [:])!
try! png.write(to: URL(fileURLWithPath: outPath))
print("wrote \(outPath)")
