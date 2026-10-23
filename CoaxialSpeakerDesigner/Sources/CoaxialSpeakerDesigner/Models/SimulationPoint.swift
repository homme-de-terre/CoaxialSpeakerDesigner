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
        totalSystemImpedancePhaseDeg: Double
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
    }
}
