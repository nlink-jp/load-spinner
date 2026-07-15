import Foundation

/// The color stops for the load-linked gradient: cool (idle) to warm (busy).
/// Exposed so the UI can render a matching gradient preview.
public let loadGradientStops: [(location: Double, hex: String)] = [
    (0.0, "#5DCAA5"), // teal
    (0.5, "#EF9F27"), // amber
    (1.0, "#D85A30"), // coral
]

/// The color stops for the memory used-ratio gradient. Unlike CPU/GPU load —
/// where less is simply calmer — memory has a *sweet spot*: barely-used RAM is
/// "cold" (blue), healthy mid-range usage is green, and only the high range
/// warms toward orange/red. Exposed for the settings preview.
public let memoryGradientStops: [(location: Double, hex: String)] = [
    (0.0, "#378ADD"),  // blue — mostly idle
    (0.5, "#5DCAA5"),  // green — the sweet spot
    (0.75, "#EF9F27"), // orange — getting full
    (1.0, "#D85A30"),  // red — full
]

private func rgbComponents(_ hex: String) -> (Double, Double, Double) {
    var string = hex
    if string.hasPrefix("#") { string.removeFirst() }
    let value = UInt32(string, radix: 16) ?? 0
    return (Double((value >> 16) & 0xFF), Double((value >> 8) & 0xFF), Double(value & 0xFF))
}

/// Map a normalized value (0...1) onto a color along the given stops, returning
/// a `#RRGGBB` hex string. Pure and side-effect free.
public func gradientColorHex(at value: Double, stops: [(location: Double, hex: String)]) -> String {
    let x = min(max(value, 0), 1)
    var lower = stops[0]
    var upper = stops[stops.count - 1]
    for index in 0..<(stops.count - 1) {
        if x >= stops[index].location && x <= stops[index + 1].location {
            lower = stops[index]
            upper = stops[index + 1]
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

/// Map a normalized load (0...1) onto the CPU/GPU load gradient.
public func loadGradientColorHex(forLoad load: Double) -> String {
    gradientColorHex(at: load, stops: loadGradientStops)
}

/// Map a memory used ratio (0...1) onto the memory gradient
/// (blue → green → orange → red).
public func memoryGradientColorHex(forUsedRatio ratio: Double) -> String {
    gradientColorHex(at: ratio, stops: memoryGradientStops)
}
