import Foundation

/// The color stops for the load-linked gradient: cool (idle) to warm (busy).
/// Exposed so the UI can render a matching gradient preview.
public let loadGradientStops: [(location: Double, hex: String)] = [
    (0.0, "#5DCAA5"), // teal
    (0.5, "#EF9F27"), // amber
    (1.0, "#D85A30"), // coral
]

private func rgbComponents(_ hex: String) -> (Double, Double, Double) {
    var string = hex
    if string.hasPrefix("#") { string.removeFirst() }
    let value = UInt32(string, radix: 16) ?? 0
    return (Double((value >> 16) & 0xFF), Double((value >> 8) & 0xFF), Double(value & 0xFF))
}

/// Map a normalized load (0...1) onto a color along `loadGradientStops`,
/// returning a `#RRGGBB` hex string. Pure and side-effect free.
public func loadGradientColorHex(forLoad load: Double) -> String {
    let x = min(max(load, 0), 1)
    var lower = loadGradientStops[0]
    var upper = loadGradientStops[loadGradientStops.count - 1]
    for index in 0..<(loadGradientStops.count - 1) {
        if x >= loadGradientStops[index].location && x <= loadGradientStops[index + 1].location {
            lower = loadGradientStops[index]
            upper = loadGradientStops[index + 1]
            break
        }
    }
    let span = upper.location - lower.location
    let t = span > 0 ? (x - lower.location) / span : 0
    let a = rgbComponents(lower.hex)
    let b = rgbComponents(upper.hex)
    let r = Int((a.0 + (b.0 - a.0) * t).rounded())
    let g = Int((a.1 + (b.1 - a.1) * t).rounded())
    let bl = Int((a.2 + (b.2 - a.2) * t).rounded())
    return String(format: "#%02X%02X%02X", r, g, bl)
}
