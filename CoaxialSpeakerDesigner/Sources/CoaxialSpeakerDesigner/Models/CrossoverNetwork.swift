import Foundation

/// Crossover Filter Type
public enum FilterOrder: String, CaseIterable, Identifiable, Codable, Sendable {
    case firstOrder = "1st Order (6 dB/oct)"
    case secondOrderLR = "2nd Order Linkwitz-Riley (12 dB/oct)"
    case secondOrderBW = "2nd Order Butterworth (12 dB/oct)"
    case thirdOrderBW = "3rd Order Butterworth (18 dB/oct)"
    case fourthOrderLR = "4th Order Linkwitz-Riley (24 dB/oct)"

    public var id: String { rawValue }

    public var orderNumber: Int {
        switch self {
        case .firstOrder: return 1
        case .secondOrderLR, .secondOrderBW: return 2
        case .thirdOrderBW: return 3
        case .fourthOrderLR: return 4
        }
    }
}

/// Represents the calculated passive crossover electrical component values.
public struct CalculatedComponents: Codable, Sendable {
    // Woofer Low-Pass components
    public var L1_mH: Double? = nil
    public var C1_uF: Double? = nil
    public var L2_mH: Double? = nil
    public var C2_uF: Double? = nil

    // Tweeter High-Pass components
    public var C_HP1_uF: Double? = nil
    public var L_HP1_mH: Double? = nil
    public var C_HP2_uF: Double? = nil
    public var L_HP2_mH: Double? = nil

    // Zobel
    public var R_zobel_ohms: Double? = nil
    public var C_zobel_uF: Double? = nil

    // L-Pad
    public var R1_lpad_ohms: Double? = nil // Series
    public var R2_lpad_ohms: Double? = nil // Parallel
}

/// Coaxial Crossover Network model and calculation engine.
public struct CrossoverNetwork: Codable, Sendable {
    public var crossoverFrequency: Double  // Crossover frequency fx (Hz, e.g. 2200 Hz)
    public var wooferOrder: FilterOrder      // Woofer filter topology
    public var tweeterOrder: FilterOrder     // Tweeter filter topology
    
    // Compensation circuits
    public var enableZobelNetwork: Bool = true
    public var enableLPadAttenuator: Bool = true
    public var userTargetAttenuationdB: Double = 5.0 // dB attenuation for tweeter
    
    // Coaxial Acoustic Alignment
    public var acousticCenterOffsetMM: Double = 35.0 // Tweeter physical delay offset behind woofer cone (mm)
    public var invertTweeterPolarity: Bool = false  // Tweeter inverted polarity (+180 deg)
    public var snapToStandardValues: Bool = false    // Snap component values to commercial E12 series

    public init(
        crossoverFrequency: Double = 2200.0,
        wooferOrder: FilterOrder = .secondOrderLR,
        tweeterOrder: FilterOrder = .secondOrderLR,
        enableZobelNetwork: Bool = true,
        enableLPadAttenuator: Bool = true,
        userTargetAttenuationdB: Double = 5.0,
        acousticCenterOffsetMM: Double = 35.0,
        invertTweeterPolarity: Bool = false,
        snapToStandardValues: Bool = false
    ) {
        self.crossoverFrequency = crossoverFrequency
        self.wooferOrder = wooferOrder
        self.tweeterOrder = tweeterOrder
        self.enableZobelNetwork = enableZobelNetwork
        self.enableLPadAttenuator = enableLPadAttenuator
        self.userTargetAttenuationdB = userTargetAttenuationdB
        self.acousticCenterOffsetMM = acousticCenterOffsetMM
        self.invertTweeterPolarity = invertTweeterPolarity
        self.snapToStandardValues = snapToStandardValues
    }

    /// Compute ideal passive filter component values based on target driver nominal impedances.
    public func computeComponentValues(wooferRe: Double, tweeterRe: Double, wooferLe: Double) -> CalculatedComponents {
        var comp = CalculatedComponents()
        let fx = crossoverFrequency
        let w = 2.0 * .pi * fx
        let Zw = max(wooferRe, 4.0)
        let Zt = max(tweeterRe, 4.0)

        // 1. Woofer Low-Pass Components
        switch wooferOrder {
        case .firstOrder:
            comp.L1_mH = (Zw / w) * 1000.0
        case .secondOrderLR:
            comp.L1_mH = (Zw / (w * .pi)) * 1000.0 * 2.0 // L = Zw / (2*pi*fx) = Zw/w
            comp.C1_uF = (1.0 / (2.0 * .pi * fx * Zw)) * 1e6
        case .secondOrderBW:
            comp.L1_mH = ((sqrt(2.0) * Zw) / w) * 1000.0
            comp.C1_uF = (1.0 / (sqrt(2.0) * w * Zw)) * 1e6
        case .thirdOrderBW:
            comp.L1_mH = ((1.5 * Zw) / w) * 1000.0
            comp.C1_uF = (1.033 / (w * Zw)) * 1e6
            comp.L2_mH = ((0.5 * Zw) / w) * 1000.0
        case .fourthOrderLR:
            comp.L1_mH = ((1.2 * Zw) / w) * 1000.0
            comp.C1_uF = (0.33 / (w * Zw)) * 1e6
            comp.L2_mH = ((0.4 * Zw) / w) * 1000.0
            comp.C2_uF = (0.75 / (w * Zw)) * 1e6
        }

        // 2. Tweeter High-Pass Components
        switch tweeterOrder {
        case .firstOrder:
            comp.C_HP1_uF = (1.0 / (w * Zt)) * 1e6
        case .secondOrderLR:
            comp.C_HP1_uF = (1.0 / (w * Zt)) * 1e6
            comp.L_HP1_mH = (Zt / w) * 1000.0
        case .secondOrderBW:
            comp.C_HP1_uF = (1.0 / (sqrt(2.0) * w * Zt)) * 1e6
            comp.L_HP1_mH = ((sqrt(2.0) * Zt) / w) * 1000.0
        case .thirdOrderBW:
            comp.C_HP1_uF = (1.0 / (1.5 * w * Zt)) * 1e6
            comp.L_HP1_mH = (Zt / (1.033 * w)) * 1000.0
            comp.C_HP2_uF = (1.0 / (0.5 * w * Zt)) * 1e6
        case .fourthOrderLR:
            comp.C_HP1_uF = (1.0 / (1.2 * w * Zt)) * 1e6
            comp.L_HP1_mH = (Zt / (0.33 * w)) * 1000.0
            comp.C_HP2_uF = (1.0 / (0.4 * w * Zt)) * 1e6
            comp.L_HP2_mH = (Zt / (0.75 * w)) * 1000.0
        }

        // 3. Zobel Network for Woofer (Rz = 1.25 * Re, Cz = Le / Rz^2)
        if enableZobelNetwork && wooferLe > 0 {
            let rz = 1.25 * wooferRe
            let czFarads = (wooferLe / 1000.0) / (rz * rz)
            comp.R_zobel_ohms = rz
            comp.C_zobel_uF = czFarads * 1e6
        }

        // 4. L-Pad Attenuator for Tweeter
        if enableLPadAttenuator && userTargetAttenuationdB > 0 {
            let k = pow(10.0, -userTargetAttenuationdB / 20.0)
            if k < 1.0 {
                let r1 = Zt * (1.0 - k)
                let r2 = Zt * (k / (1.0 - k))
                comp.R1_lpad_ohms = r1
                comp.R2_lpad_ohms = r2
            }
        }

        // Snap to standard E12 values if requested
        if snapToStandardValues {
            comp.L1_mH = comp.L1_mH.map { snapE12($0) }
            comp.C1_uF = comp.C1_uF.map { snapE12($0) }
            comp.L2_mH = comp.L2_mH.map { snapE12($0) }
            comp.C2_uF = comp.C2_uF.map { snapE12($0) }

            comp.C_HP1_uF = comp.C_HP1_uF.map { snapE12($0) }
            comp.L_HP1_mH = comp.L_HP1_mH.map { snapE12($0) }
            comp.C_HP2_uF = comp.C_HP2_uF.map { snapE12($0) }
            comp.L_HP2_mH = comp.L_HP2_mH.map { snapE12($0) }

            comp.R_zobel_ohms = comp.R_zobel_ohms.map { snapE12($0) }
            comp.C_zobel_uF = comp.C_zobel_uF.map { snapE12($0) }
            comp.R1_lpad_ohms = comp.R1_lpad_ohms.map { snapE12($0) }
            comp.R2_lpad_ohms = comp.R2_lpad_ohms.map { snapE12($0) }
        }

        return comp
    }

    /// Snap value to closest E12 standard commercial electronic series.
    private func snapE12(_ val: Double) -> Double {
        guard val > 0 else { return 0 }
        let e12Base = [1.0, 1.2, 1.5, 1.8, 2.2, 2.7, 3.3, 3.9, 4.7, 5.6, 6.8, 8.2, 10.0]
        let exponent = floor(log10(val))
        let normalized = val / pow(10.0, exponent)
        let closest = e12Base.min(by: { abs($0 - normalized) < abs($1 - normalized) }) ?? normalized
        return closest * pow(10.0, exponent)
    }

    /// Complex electrical low-pass filter transfer function H_LP(f)
    public func wooferFilterTransferFunction(frequency f: Double) -> ComplexNumber {
        let x = f / crossoverFrequency
        switch wooferOrder {
        case .firstOrder:
            // 1 / (1 + jx)
            return ComplexNumber(real: 1.0, imag: 0.0) / ComplexNumber(real: 1.0, imag: x)
        case .secondOrderLR:
            // 1 / ( (1 - x^2) + j(2x) )
            return ComplexNumber(real: 1.0, imag: 0.0) / ComplexNumber(real: 1.0 - x*x, imag: 2.0*x)
        case .secondOrderBW:
            // 1 / ( (1 - x^2) + j(sqrt(2)*x) )
            return ComplexNumber(real: 1.0, imag: 0.0) / ComplexNumber(real: 1.0 - x*x, imag: sqrt(2.0)*x)
        case .thirdOrderBW:
            // 1 / ( (1 - 2x^2) + j(2x - x^3) )
            return ComplexNumber(real: 1.0, imag: 0.0) / ComplexNumber(real: 1.0 - 2.0*x*x, imag: 2.0*x - x*x*x)
        case .fourthOrderLR:
            // [1 / ((1-x^2) + j*sqrt(2)x)]^2
            let h2 = ComplexNumber(real: 1.0, imag: 0.0) / ComplexNumber(real: 1.0 - x*x, imag: sqrt(2.0)*x)
            return h2 * h2
        }
    }

    /// Complex electrical high-pass filter transfer function H_HP(f)
    public func tweeterFilterTransferFunction(frequency f: Double) -> ComplexNumber {
        let x = f / crossoverFrequency
        switch tweeterOrder {
        case .firstOrder:
            // jx / (1 + jx)
            return ComplexNumber(real: 0.0, imag: x) / ComplexNumber(real: 1.0, imag: x)
        case .secondOrderLR:
            // -x^2 / ( (1 - x^2) + j(2x) )
            return ComplexNumber(real: -x*x, imag: 0.0) / ComplexNumber(real: 1.0 - x*x, imag: 2.0*x)
        case .secondOrderBW:
            // -x^2 / ( (1 - x^2) + j(sqrt(2)*x) )
            return ComplexNumber(real: -x*x, imag: 0.0) / ComplexNumber(real: 1.0 - x*x, imag: sqrt(2.0)*x)
        case .thirdOrderBW:
            // -j x^3 / ( (1 - 2x^2) + j(2x - x^3) )
            return ComplexNumber(real: 0.0, imag: -x*x*x) / ComplexNumber(real: 1.0 - 2.0*x*x, imag: 2.0*x - x*x*x)
        case .fourthOrderLR:
            // [-x^2 / ((1-x^2) + j*sqrt(2)x)]^2
            let h2 = ComplexNumber(real: -x*x, imag: 0.0) / ComplexNumber(real: 1.0 - x*x, imag: sqrt(2.0)*x)
            return h2 * h2
        }
    }

    /// Acoustic center time delay offset factor e^(-j * 2 * pi * f * dt) * Polarity
    public func tweeterAcousticDelayFactor(frequency f: Double) -> ComplexNumber {
        let speedOfSoundMS = 343.0 // m/s
        let delaySeconds = (acousticCenterOffsetMM / 1000.0) / speedOfSoundMS
        let phaseShiftRad = 2.0 * .pi * f * delaySeconds
        let polarityMultiplier = invertTweeterPolarity ? -1.0 : 1.0

        return ComplexNumber(r: polarityMultiplier, theta: -phaseShiftRad)
    }

    /// L-Pad complex attenuation factor
    public var lpadVoltageGain: Double {
        if enableLPadAttenuator && userTargetAttenuationdB > 0 {
            return pow(10.0, -userTargetAttenuationdB / 20.0)
        }
        return 1.0
    }
}
