import Foundation

/// Represents a single frequency point on an FRD/ZMA response curve.
public struct ResponseDataPoint: Identifiable, Codable, Sendable {
    public var id = UUID()
    public var frequency: Double // Hz
    public var magnitude: Double // dB SPL or Ohms
    public var phase: Double     // Degrees

    public init(id: UUID = UUID(), frequency: Double, magnitude: Double, phase: Double = 0.0) {
        self.id = id
        self.frequency = frequency
        self.magnitude = magnitude
        self.phase = phase
    }
}

/// Thiele-Small (T/S) parameters and specifications for the woofer section of a coaxial driver.
public struct WooferTSParameters: Codable, Sendable {
    public var fs: Double   // Free air resonance frequency (Hz)
    public var qes: Double {
        didSet { recalculateQts() }
    }
    public var qms: Double {
        didSet { recalculateQts() }
    }
    public var qts: Double  // Total Q
    public var vas: Double  // Equivalent compliance volume (Liters)
    public var re: Double   // DC Resistance (Ohms)
    public var le: Double   // Voice coil inductance (mH)
    public var sd: Double   // Effective cone area (cm^2)
    public var xmax: Double // Max linear excursion (mm)
    public var spl: Double  // Nominal sensitivity (dB @ 2.83V / 1m)
    public var pe: Double   // Max continuous electrical power (Watts)

    public mutating func recalculateQts() {
        if qes > 0 && qms > 0 {
            qts = (qes * qms) / (qes + qms)
        }
    }

    public init(
        fs: Double = 45.0,
        qes: Double = 0.35,
        qms: Double = 4.5,
        qts: Double = 0.325,
        vas: Double = 28.0,
        re: Double = 6.2,
        le: Double = 0.85,
        sd: Double = 210.0,
        xmax: Double = 5.5,
        spl: Double = 89.0,
        pe: Double = 150.0
    ) {
        self.fs = fs
        self.qes = qes
        self.qms = qms
        self.qts = (qes > 0 && qms > 0) ? (qes * qms) / (qes + qms) : qts
        self.vas = vas
        self.re = re
        self.le = le
        self.sd = sd
        self.xmax = xmax
        self.spl = spl
        self.pe = pe
    }
}

/// Specifications for the integrated tweeter / compression driver section of a coaxial driver.
public struct TweeterParameters: Codable, Sendable {
    public var fs: Double     // Resonance frequency (Hz)
    public var re: Double     // DC Resistance (Ohms)
    public var le: Double     // Voice coil inductance (mH)
    public var spl: Double    // Nominal sensitivity (dB @ 2.83V / 1m)
    public var pe: Double     // Max power (Watts)
    public var nominalImpedance: Double // Ohms (typically 8.0)

    public init(
        fs: Double = 1200.0,
        re: Double = 5.8,
        le: Double = 0.08,
        spl: Double = 94.0,
        pe: Double = 50.0,
        nominalImpedance: Double = 8.0
    ) {
        self.fs = fs
        self.re = re
        self.le = le
        self.spl = spl
        self.pe = pe
        self.nominalImpedance = nominalImpedance
    }
}

/// Complete Coaxial Driver specification model.
public struct CoaxialDriver: Codable, Sendable {
    public var name: String
    public var manufacturer: String
    public var datasheetURL: String?
    
    public var wooferTS: WooferTSParameters
    public var tweeter: TweeterParameters
    
    // Raw acoustic frequency response curves
    public var wooferAcousticCurve: [ResponseDataPoint]
    public var tweeterAcousticCurve: [ResponseDataPoint]
    public var hasCustomWooferCurve: Bool = false
    public var hasCustomTweeterCurve: Bool = false
    public var customWooferReferenceSPL: Double? = nil
    public var customTweeterReferenceSPL: Double? = nil
    
    // Raw electrical impedance curves
    public var wooferImpedanceCurve: [ResponseDataPoint]
    public var tweeterImpedanceCurve: [ResponseDataPoint]

    public init(
        name: String = "8CX21 Coaxial 8-inch Driver",
        manufacturer: String = "AudioPro",
        datasheetURL: String? = nil,
        wooferTS: WooferTSParameters = WooferTSParameters(),
        tweeter: TweeterParameters = TweeterParameters(),
        wooferAcousticCurve: [ResponseDataPoint] = [],
        tweeterAcousticCurve: [ResponseDataPoint] = [],
        wooferImpedanceCurve: [ResponseDataPoint] = [],
        tweeterImpedanceCurve: [ResponseDataPoint] = [],
        hasCustomWooferCurve: Bool? = nil,
        hasCustomTweeterCurve: Bool? = nil,
        customWooferReferenceSPL: Double? = nil,
        customTweeterReferenceSPL: Double? = nil
    ) {
        self.name = name
        self.manufacturer = manufacturer
        self.datasheetURL = datasheetURL
        self.wooferTS = wooferTS
        self.tweeter = tweeter
        let isCustomWoofer = hasCustomWooferCurve ?? !wooferAcousticCurve.isEmpty
        let isCustomTweeter = hasCustomTweeterCurve ?? !tweeterAcousticCurve.isEmpty
        self.hasCustomWooferCurve = isCustomWoofer
        self.hasCustomTweeterCurve = isCustomTweeter
        self.customWooferReferenceSPL = customWooferReferenceSPL ?? (isCustomWoofer ? wooferTS.spl : nil)
        self.customTweeterReferenceSPL = customTweeterReferenceSPL ?? (isCustomTweeter ? tweeter.spl : nil)
        self.wooferAcousticCurve = wooferAcousticCurve.isEmpty ? CoaxialDriver.generateSyntheticWooferCurve(ts: wooferTS) : wooferAcousticCurve
        self.tweeterAcousticCurve = tweeterAcousticCurve.isEmpty ? CoaxialDriver.generateSyntheticTweeterCurve(tw: tweeter) : tweeterAcousticCurve
        self.wooferImpedanceCurve = wooferImpedanceCurve.isEmpty ? CoaxialDriver.generateSyntheticWooferImpedance(ts: wooferTS) : wooferImpedanceCurve
        self.tweeterImpedanceCurve = tweeterImpedanceCurve.isEmpty ? CoaxialDriver.generateSyntheticTweeterImpedance(tw: tweeter) : tweeterImpedanceCurve
    }

    enum CodingKeys: String, CodingKey {
        case name
        case manufacturer
        case datasheetURL
        case wooferTS
        case tweeter
        case wooferAcousticCurve
        case tweeterAcousticCurve
        case hasCustomWooferCurve
        case hasCustomTweeterCurve
        case customWooferReferenceSPL
        case customTweeterReferenceSPL
        case wooferImpedanceCurve
        case tweeterImpedanceCurve
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try container.decodeIfPresent(String.self, forKey: .name) ?? "8CX21 Coaxial 8-inch Driver"
        self.manufacturer = try container.decodeIfPresent(String.self, forKey: .manufacturer) ?? "AudioPro"
        self.datasheetURL = try container.decodeIfPresent(String.self, forKey: .datasheetURL)
        let decodedTS = try container.decodeIfPresent(WooferTSParameters.self, forKey: .wooferTS) ?? WooferTSParameters()
        let decodedTw = try container.decodeIfPresent(TweeterParameters.self, forKey: .tweeter) ?? TweeterParameters()
        self.wooferTS = decodedTS
        self.tweeter = decodedTw
        let decodedWC = try container.decodeIfPresent([ResponseDataPoint].self, forKey: .wooferAcousticCurve) ?? []
        let decodedTC = try container.decodeIfPresent([ResponseDataPoint].self, forKey: .tweeterAcousticCurve) ?? []
        let isCustomW = try container.decodeIfPresent(Bool.self, forKey: .hasCustomWooferCurve) ?? (!decodedWC.isEmpty && decodedWC.count != 201)
        let isCustomT = try container.decodeIfPresent(Bool.self, forKey: .hasCustomTweeterCurve) ?? (!decodedTC.isEmpty && decodedTC.count != 201)
        self.hasCustomWooferCurve = isCustomW
        self.hasCustomTweeterCurve = isCustomT
        self.customWooferReferenceSPL = try container.decodeIfPresent(Double.self, forKey: .customWooferReferenceSPL) ?? (isCustomW ? decodedTS.spl : nil)
        self.customTweeterReferenceSPL = try container.decodeIfPresent(Double.self, forKey: .customTweeterReferenceSPL) ?? (isCustomT ? decodedTw.spl : nil)
        self.wooferAcousticCurve = decodedWC.isEmpty ? CoaxialDriver.generateSyntheticWooferCurve(ts: decodedTS) : decodedWC
        self.tweeterAcousticCurve = decodedTC.isEmpty ? CoaxialDriver.generateSyntheticTweeterCurve(tw: decodedTw) : decodedTC
        let decodedWImp = try container.decodeIfPresent([ResponseDataPoint].self, forKey: .wooferImpedanceCurve) ?? []
        let decodedTImp = try container.decodeIfPresent([ResponseDataPoint].self, forKey: .tweeterImpedanceCurve) ?? []
        self.wooferImpedanceCurve = decodedWImp.isEmpty ? CoaxialDriver.generateSyntheticWooferImpedance(ts: decodedTS) : decodedWImp
        self.tweeterImpedanceCurve = decodedTImp.isEmpty ? CoaxialDriver.generateSyntheticTweeterImpedance(tw: decodedTw) : decodedTImp
    }
    
    /// Default realistic template driver for initial application state.
    public static var defaultSampleDriver: CoaxialDriver {
        var driver = CoaxialDriver()
        driver.wooferAcousticCurve = generateSyntheticWooferCurve()
        driver.tweeterAcousticCurve = generateSyntheticTweeterCurve()
        driver.wooferImpedanceCurve = generateSyntheticWooferImpedance(ts: driver.wooferTS)
        driver.tweeterImpedanceCurve = generateSyntheticTweeterImpedance(tw: driver.tweeter)
        return driver
    }

    /// Factory preset for classic Altec Lansing 604-8K with digitized CLIO curves.
    public static var altec604Driver: CoaxialDriver {
        return Altec604Data.createDriver()
    }
    
    public static func generateSyntheticWooferCurve(ts: WooferTSParameters = WooferTSParameters()) -> [ResponseDataPoint] {
        var points: [ResponseDataPoint] = []
        let logFreqs = stride(from: log10(20.0), through: log10(20000.0), by: (log10(20000.0) - log10(20.0)) / 200.0)
        let passbandSPL = ts.spl > 0 ? ts.spl : 89.0
        for logF in logFreqs {
            let f = pow(10.0, logF)
            var spl = passbandSPL
            if f > 2000.0 {
                let diff = f - 2000.0
                spl -= 0.003 * diff
                if f > 3000.0 && f < 4500.0 {
                    spl += 3.5 * exp(-pow((f - 3800.0)/400.0, 2)) // Cone breakup resonance
                }
            }
            points.append(ResponseDataPoint(frequency: f, magnitude: spl, phase: 0.0))
        }
        return points
    }
    
    public static func generateSyntheticTweeterCurve(tw: TweeterParameters = TweeterParameters()) -> [ResponseDataPoint] {
        var points: [ResponseDataPoint] = []
        let logFreqs = stride(from: log10(20.0), through: log10(20000.0), by: (log10(20000.0) - log10(20.0)) / 200.0)
        let passbandSPL = tw.spl > 0 ? tw.spl : 94.0
        let xoverF = tw.fs > 0 ? tw.fs : 1500.0
        for logF in logFreqs {
            let f = pow(10.0, logF)
            var spl = passbandSPL
            if f < xoverF {
                spl -= 18.0 * log2(xoverF / max(f, 10.0))
            } else if f > 15000.0 {
                spl -= 0.0008 * (f - 15000.0) // Mild high frequency roll-off
            }
            points.append(ResponseDataPoint(frequency: f, magnitude: spl, phase: 0.0))
        }
        return points
    }
    
    public static func generateSyntheticWooferImpedance(ts: WooferTSParameters) -> [ResponseDataPoint] {
        var points: [ResponseDataPoint] = []
        let logFreqs = stride(from: log10(20.0), through: log10(20000.0), by: (log10(20000.0) - log10(20.0)) / 200.0)
        let res = ts.re * (ts.qms / ts.qes)
        for logF in logFreqs {
            let f = pow(10.0, logF)
            let w = 2.0 * .pi * f
            let indReactance = w * (ts.le / 1000.0)
            
            // Motional impedance peak at Fs
            let denom = 1.0 + pow(ts.qms * (f/ts.fs - ts.fs/f), 2)
            let rMotional = res / denom
            
            let zMag = hypot(ts.re + rMotional, indReactance)
            points.append(ResponseDataPoint(frequency: f, magnitude: zMag, phase: 0.0))
        }
        return points
    }
    
    public static func generateSyntheticTweeterImpedance(tw: TweeterParameters) -> [ResponseDataPoint] {
        var points: [ResponseDataPoint] = []
        let logFreqs = stride(from: log10(20.0), through: log10(20000.0), by: (log10(20000.0) - log10(20.0)) / 200.0)
        for logF in logFreqs {
            let f = pow(10.0, logF)
            let w = 2.0 * .pi * f
            let indReactance = w * (tw.le / 1000.0)
            let zMag = hypot(tw.re, indReactance)
            points.append(ResponseDataPoint(frequency: f, magnitude: zMag, phase: 0.0))
        }
        return points
    }
}
