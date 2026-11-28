import Foundation

/// Calculated simulation values at a single logarithmic frequency sample point.
public struct SimulationPoint: Identifiable, Codable, Sendable {
    public var id = UUID()
    public var frequency: Double // Hz

    // Woofer Acoustic Response (inside cabinet + through Low-Pass filter)
    public var wooferRawSPL: Double
    public var wooferCabinetSPL: Double
    public var wooferFinalSPL: Double
    public var wooferPhaseDeg: Double

    // Tweeter Acoustic Response (through High-Pass filter + L-Pad + Delay)
    public var tweeterRawSPL: Double
    public var tweeterFinalSPL: Double
    public var tweeterPhaseDeg: Double

    // Combined Total Acoustic System Response
    public var totalSystemSPL: Double
    public var totalSystemPhaseDeg: Double
    public var phaseDifferenceDeg: Double // Delta Phase between woofer and tweeter

    // System Electrical Load Impedance
    public var wooferImpedanceMag: Double
    public var tweeterImpedanceMag: Double
    public var totalSystemImpedanceMag: Double
    public var totalSystemImpedancePhaseDeg: Double

    // Unwrapped Continuous Phase (Degrees)
    public var wooferUnwrappedPhaseDeg: Double
    public var tweeterUnwrappedPhaseDeg: Double
    public var tweeterAltUnwrappedPhaseDeg: Double
    public var totalSystemUnwrappedPhaseDeg: Double
    public var totalSystemAltUnwrappedPhaseDeg: Double
    public var tweeterDelayCompensatedPhaseDeg: Double
    public var tweeterDelayCompUnwrappedPhaseDeg: Double
    public var tweeterDelayCompAltUnwrappedPhaseDeg: Double

    // Acoustic & Electrical Group Delay (Milliseconds)
    public var wooferGroupDelayMs: Double
    public var tweeterGroupDelayMs: Double
    public var totalSystemGroupDelayMs: Double

    public init(
        frequency: Double,
        wooferRawSPL: Double,
        wooferCabinetSPL: Double,
        wooferFinalSPL: Double,
        wooferPhaseDeg: Double,
        tweeterRawSPL: Double,
        tweeterFinalSPL: Double,
        tweeterPhaseDeg: Double,
        totalSystemSPL: Double,
        totalSystemPhaseDeg: Double,
        phaseDifferenceDeg: Double,
        wooferImpedanceMag: Double,
        tweeterImpedanceMag: Double,
        totalSystemImpedanceMag: Double,
        totalSystemImpedancePhaseDeg: Double,
        wooferUnwrappedPhaseDeg: Double = 0.0,
        tweeterUnwrappedPhaseDeg: Double = 0.0,
        tweeterAltUnwrappedPhaseDeg: Double = 0.0,
        totalSystemUnwrappedPhaseDeg: Double = 0.0,
        totalSystemAltUnwrappedPhaseDeg: Double = 0.0,
        tweeterDelayCompensatedPhaseDeg: Double = 0.0,
        tweeterDelayCompUnwrappedPhaseDeg: Double = 0.0,
        tweeterDelayCompAltUnwrappedPhaseDeg: Double = 0.0,
        wooferGroupDelayMs: Double = 0.0,
        tweeterGroupDelayMs: Double = 0.0,
        totalSystemGroupDelayMs: Double = 0.0
    ) {
        self.frequency = frequency
        self.wooferRawSPL = wooferRawSPL
        self.wooferCabinetSPL = wooferCabinetSPL
        self.wooferFinalSPL = wooferFinalSPL
        self.wooferPhaseDeg = wooferPhaseDeg
        self.tweeterRawSPL = tweeterRawSPL
        self.tweeterFinalSPL = tweeterFinalSPL
        self.tweeterPhaseDeg = tweeterPhaseDeg
        self.totalSystemSPL = totalSystemSPL
        self.totalSystemPhaseDeg = totalSystemPhaseDeg
        self.phaseDifferenceDeg = phaseDifferenceDeg
        self.wooferImpedanceMag = wooferImpedanceMag
        self.tweeterImpedanceMag = tweeterImpedanceMag
        self.totalSystemImpedanceMag = totalSystemImpedanceMag
        self.totalSystemImpedancePhaseDeg = totalSystemImpedancePhaseDeg
        self.wooferUnwrappedPhaseDeg = wooferUnwrappedPhaseDeg
        self.tweeterUnwrappedPhaseDeg = tweeterUnwrappedPhaseDeg
        self.tweeterAltUnwrappedPhaseDeg = tweeterAltUnwrappedPhaseDeg
        self.totalSystemUnwrappedPhaseDeg = totalSystemUnwrappedPhaseDeg
        self.totalSystemAltUnwrappedPhaseDeg = totalSystemAltUnwrappedPhaseDeg
        self.tweeterDelayCompensatedPhaseDeg = tweeterDelayCompensatedPhaseDeg
        self.tweeterDelayCompUnwrappedPhaseDeg = tweeterDelayCompUnwrappedPhaseDeg
        self.tweeterDelayCompAltUnwrappedPhaseDeg = tweeterDelayCompAltUnwrappedPhaseDeg
        self.wooferGroupDelayMs = wooferGroupDelayMs
        self.tweeterGroupDelayMs = tweeterGroupDelayMs
        self.totalSystemGroupDelayMs = totalSystemGroupDelayMs
    }
}
