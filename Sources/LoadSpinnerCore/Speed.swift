import Foundation

/// Maps a normalized load (0...1) onto a rotation speed in RPM.
public struct SpeedRange: Sendable, Equatable {
    public let minRPM: Double
    public let maxRPM: Double

    public init(minRPM: Double = 8, maxRPM: Double = 180) {
        self.minRPM = minRPM
        self.maxRPM = maxRPM
    }

    public static let `default` = SpeedRange()
}

/// Linear mapping from load (0...1) to revolutions-per-minute.
///
/// Load is clamped to 0...1, so a load of 0 spins at `minRPM` (a slow idle
/// turn) and a load of 1 spins at `maxRPM`. Pure and side-effect free.
public func rotationsPerMinute(forLoad load: Double, in range: SpeedRange = .default) -> Double {
    let clamped = min(max(load, 0), 1)
    return range.minRPM + clamped * (range.maxRPM - range.minRPM)
}
