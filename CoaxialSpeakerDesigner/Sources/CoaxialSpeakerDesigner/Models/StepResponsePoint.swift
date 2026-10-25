import Foundation

/// Calculated time-domain acoustic step response sample point.
public struct StepResponsePoint: Identifiable, Codable, Sendable {
    public var id = UUID()
    public var timeMs: Double
    public var woofer: Double
    public var tweeter: Double
    public var total: Double

    public init(timeMs: Double, woofer: Double, tweeter: Double, total: Double) {
        self.timeMs = timeMs
        self.woofer = woofer
        self.tweeter = tweeter
        self.total = total
    }
}
