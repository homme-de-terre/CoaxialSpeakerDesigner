import Foundation

/// Defines enclosure architecture: Sealed (Closed box) or Vented (Bass-Reflex)
public enum EnclosureType: String, CaseIterable, Identifiable, Codable, Sendable {
    case sealed = "Sealed (Closed Box, 2nd-Order High-Pass)"
    case vented = "Vented (Bass-Reflex, 4th-Order High-Pass)"

    public var id: String { rawValue }
}

/// Standard 4th-order vented box alignment presets (Small / Margolis / Keele)
public enum VentedAlignmentType: String, CaseIterable, Identifiable, Codable, Sendable {
    case qb3 = "QB3 (Quasi-Butterworth 3 - Best for Low Qts Pro Transducers)"
    case b4 = "B4 (Butterworth 4 - Maximally Flat)"
    case sc4 = "SC4 (Sub-Chebyshev 4 - Compact Enclosure)"
    case custom = "Custom Tuning (Fb & Vb)"

    public var id: String { rawValue }
}

/// Defines design alignment modes and presets for closed/sealed enclosures.
public enum AlignmentType: String, CaseIterable, Identifiable, Codable, Sendable {
    case targetF3 = "Target Cut-off Frequency (f3)"
    case butterworth = "Butterworth B2 (Qtc = 0.707 - Maximally Flat)"
    case bessel = "Bessel (Qtc = 0.577 - Best Transient Response)"
    case criticallyDamped = "Critically Damped (Qtc = 0.500 - No Overshoot)"
    case customQtc = "Custom Target Qtc Alignment"

    public var id: String { rawValue }

    public var targetQtc: Double? {
        switch self {
        case .butterworth: return 0.7071
        case .bessel: return 0.5774
        case .criticallyDamped: return 0.5000
        case .targetF3, .customQtc: return nil
        }
    }
}

/// Absorption filling / stuffing levels for closed cabinets.
public enum StuffingLevel: String, CaseIterable, Identifiable, Codable, Sendable {
    case none = "Unfilled / Minimal (0% Volume Gain)"
    case light = "Light Lining (+10% Acoustic Volume Gain)"
    case medium = "Medium Polyfill (+18% Acoustic Volume Gain)"
    case heavy = "Heavy 100% Polyfill (+25% Acoustic Volume Gain)"

    public var id: String { rawValue }

    public var volumeGainFactor: Double {
        switch self {
        case .none: return 1.00
        case .light: return 1.10
        case .medium: return 1.18
        case .heavy: return 1.25
        }
    }

    public var enclosureLossQb: Double {
        switch self {
        case .none: return 30.0   // minimal enclosure absorption loss
        case .light: return 15.0  // light lining on walls
        case .medium: return 7.0  // typical 50% polyfill
        case .heavy: return 4.0   // heavy 100% dense fiber stuffing
        }
    }
}

/// Parameters and computed physics metrics for a closed or vented loudspeaker enclosure.
public struct SealedCabinet: Equatable, Codable, Sendable {
    // Enclosure Architecture
    public var enclosureType: EnclosureType = .sealed
    public var ventedAlignment: VentedAlignmentType = .qb3
    public var tuningFrequencyFb: Double = 35.0  // Port / Helmholtz resonance Fb (Hz)
    public var portDiameterCm: Double = 10.2     // Port internal diameter (cm, default 4-inch duct)
    public var numberOfPorts: Int = 1            // Number of vents
    public var portLossQl: Double = 15.0         // Port / leakage acoustic loss Q (typically 10.0 - 20.0, default 15.0)

    // Sealed Alignment Parameters
    public var alignment: AlignmentType = .butterworth
    public var targetF3: Double = 55.0   // Target lower -3 dB cutoff frequency (Hz)
    public var targetQtc: Double = 0.707 // Target total system Q (Qtc)
    public var stuffing: StuffingLevel = .none
    public var enclosureLossQb: Double = 7.0 // Enclosure absorption loss Q (typically 5.0 - 10.0, default 7.0)
    public var isManualVolumeOverride: Bool = false
    public var manualNetVolumeLiters: Double = 25.0

    public init(
        alignment: AlignmentType = .butterworth,
        targetF3: Double = 55.0,
        targetQtc: Double = 0.7071,
        stuffing: StuffingLevel = .none,
        enclosureLossQb: Double = 7.0,
        isManualVolumeOverride: Bool = false,
        manualNetVolumeLiters: Double = 25.0,
        enclosureType: EnclosureType = .sealed,
        ventedAlignment: VentedAlignmentType = .qb3,
        tuningFrequencyFb: Double = 35.0,
        portDiameterCm: Double = 10.2,
        numberOfPorts: Int = 1,
        portLossQl: Double = 15.0
    ) {
        self.alignment = alignment
        self.targetF3 = targetF3
        self.targetQtc = targetQtc
        self.stuffing = stuffing
        self.enclosureLossQb = enclosureLossQb
        self.isManualVolumeOverride = isManualVolumeOverride
        self.manualNetVolumeLiters = manualNetVolumeLiters
        self.enclosureType = enclosureType
        self.ventedAlignment = ventedAlignment
        self.tuningFrequencyFb = tuningFrequencyFb
        self.portDiameterCm = portDiameterCm
        self.numberOfPorts = numberOfPorts
        self.portLossQl = portLossQl
    }

    /// Baseline alignment alpha (unfilled) for target Q or target f3
    public func computedBaseAlignmentAlpha(for ts: WooferTSParameters) -> Double {
        let effectiveQts = ts.qts > 0 ? ts.qts : (ts.qes > 0 && ts.qms > 0 ? (ts.qes * ts.qms) / (ts.qes + ts.qms) : 0.35)

        switch alignment {
        case .targetF3:
            let effQts = ts.qts > 0 ? ts.qts : (ts.qes > 0 && ts.qms > 0 ? (ts.qes * ts.qms) / (ts.qes + ts.qms) : 0.35)
            let minF3 = ts.fs * (0.70710678 / max(effQts, 0.01))
            let effectiveF3 = max(targetF3, minF3)
            let r = pow(effectiveF3 / max(ts.fs, 1.0), 2)
            let q2 = pow(effQts, 2)
            let disc = 2.0 * r * r - (r / max(q2, 1e-4))
            if disc <= 0 || targetF3 < minF3 {
                let ratio = 0.70710678 / max(effQts, 0.01)
                return max(pow(ratio, 2) - 1.0, 0.05)
            }
            let y = r + sqrt(disc)
            let alpha = max(y - 1.0, 0.05)
            return alpha

        case .butterworth, .bessel, .criticallyDamped:
            if let targetQ = alignment.targetQtc {
                if targetQ <= effectiveQts { return 0.05 }
                let ratio = targetQ / max(effectiveQts, 0.01)
                let alpha = pow(ratio, 2) - 1.0
                return max(alpha, 0.05)
            }
            return 1.0

        case .customQtc:
            if targetQtc <= effectiveQts { return 0.05 }
            let ratio = targetQtc / max(effectiveQts, 0.01)
            let alpha = pow(ratio, 2) - 1.0
            return max(alpha, 0.05)
        }
    }

    /// Physical Internal Box Volume required for the cabinet structure
    public func computedPhysicalVolumeLiters(for ts: WooferTSParameters) -> Double {
        if enclosureType == .vented {
            return computedVentedPhysicalVolumeLiters(for: ts)
        }
        if isManualVolumeOverride {
            return manualNetVolumeLiters
        }
        let baseAlpha = computedBaseAlignmentAlpha(for: ts)
        guard baseAlpha > 0 else { return 10.0 }
        let acousticVb = ts.vas / baseAlpha
        return acousticVb / stuffing.volumeGainFactor
    }

    /// Required Net Acoustic Volume Vb_acoustic (in Liters) including polyfill volume gain
    public func computedAcousticVolumeLiters(for ts: WooferTSParameters) -> Double {
        if enclosureType == .vented {
            return computedVentedAcousticVolumeLiters(for: ts)
        }
        if isManualVolumeOverride {
            return manualNetVolumeLiters * stuffing.volumeGainFactor
        }
        let baseAlpha = computedBaseAlignmentAlpha(for: ts)
        guard baseAlpha > 0 else { return 10.0 }
        return ts.vas / baseAlpha
    }

    /// Vented box acoustic volume
    private func computedVentedAcousticVolumeLiters(for ts: WooferTSParameters) -> Double {
        if isManualVolumeOverride || ventedAlignment == .custom {
            return max(manualNetVolumeLiters * stuffing.volumeGainFactor, 5.0)
        }
        let effQts = ts.qts > 0 ? ts.qts : (ts.qes > 0 && ts.qms > 0 ? (ts.qes * ts.qms) / (ts.qes + ts.qms) : 0.35)
        let vas = max(ts.vas, 10.0)

        switch ventedAlignment {
        case .qb3:
            return max(3.0 * pow(effQts, 2.0) * vas, 5.0)
        case .b4:
            return max(11.0 * pow(effQts, 3.3) * vas, 5.0)
        case .sc4:
            return max(2.0 * pow(effQts, 1.5) * vas, 5.0)
        case .custom:
            return max(manualNetVolumeLiters * stuffing.volumeGainFactor, 5.0)
        }
    }

    /// Vented box physical volume
    private func computedVentedPhysicalVolumeLiters(for ts: WooferTSParameters) -> Double {
        if isManualVolumeOverride || ventedAlignment == .custom {
            return max(manualNetVolumeLiters, 5.0)
        }
        return computedVentedAcousticVolumeLiters(for: ts) / stuffing.volumeGainFactor
    }

    /// Effective Helmholtz tuning frequency Fb (Hz) for vented enclosure
    public func actualTuningFb(for ts: WooferTSParameters) -> Double {
        if enclosureType == .sealed {
            return computedResonanceFc(for: ts)
        }
        if isManualVolumeOverride || ventedAlignment == .custom {
            return max(tuningFrequencyFb, 15.0)
        }
        let effQts = ts.qts > 0 ? ts.qts : (ts.qes > 0 && ts.qms > 0 ? (ts.qes * ts.qms) / (ts.qes + ts.qms) : 0.35)
        let fs = max(ts.fs, 15.0)

        switch ventedAlignment {
        case .qb3, .b4:
            let fb = 0.42 * pow(max(effQts, 0.1), -0.9) * fs
            return min(max(fb, 18.0), 120.0)
        case .sc4:
            let fb = 0.85 * fs
            return min(max(fb, 18.0), 120.0)
        case .custom:
            return max(tuningFrequencyFb, 15.0)
        }
    }

    /// Required length of each port duct (cm) based on tuning Fb and net box volume
    public func computedPortLengthCm(for ts: WooferTSParameters) -> Double {
        let vb = max(computedPhysicalVolumeLiters(for: ts), 1.0)
        let fb = max(actualTuningFb(for: ts), 10.0)
        let dv = max(portDiameterCm, 2.0)
        let np = max(Double(numberOfPorts), 1.0)

        // Lv = (23562.5 * Dv^2 * Np) / (Fb^2 * Vb) - 0.732 * Dv
        let num = 23562.5 * pow(dv, 2.0) * np
        let denom = pow(fb, 2.0) * vb
        let lv = (num / denom) - (0.732 * dv)
        return max(lv, 0.5)
    }

    /// Minimum recommended port internal diameter (cm) to prevent audible air turbulence chuffing
    public func minRecommendedPortDiameterCm(for ts: WooferTSParameters) -> Double {
        let fb = max(actualTuningFb(for: ts), 15.0)
        let sd = max(ts.sd, 50.0)
        let xmax = max(ts.xmax, 1.0)
        let np = max(Double(numberOfPorts), 1.0)

        // D_min = 0.15 * sqrt(Fb * Sd * Xmax) / sqrt(Np)
        let dMin = 0.15 * sqrt(fb * sd * xmax) / sqrt(np)
        return max((dMin * 10.0).rounded() / 10.0, 3.0)
    }

    /// Computed Compliance Ratio Alpha = Vas / Vb_acoustic inside the enclosure
    public func computedComplianceAlpha(for ts: WooferTSParameters) -> Double {
        let acousticVb = computedAcousticVolumeLiters(for: ts)
        guard acousticVb > 0 else { return 1.0 }
        return ts.vas / max(acousticVb, 0.1)
    }

    /// Alias for physical volume in liters
    public func computedVolumeLiters(for ts: WooferTSParameters) -> Double {
        return computedPhysicalVolumeLiters(for: ts)
    }

    /// Physical Internal Box Volume in Cubic Feet
    public func computedPhysicalVolumeCubicFeet(for ts: WooferTSParameters) -> Double {
        return computedPhysicalVolumeLiters(for: ts) / 28.3168
    }

    /// System Resonant Frequency inside the sealed box Fc (Hz)
    public func computedResonanceFc(for ts: WooferTSParameters) -> Double {
        let alpha = computedComplianceAlpha(for: ts)
        return ts.fs * sqrt(1.0 + alpha)
    }

    /// Mechanical Q inside enclosure taking enclosure absorption loss Qb into account
    public func actualQmc(for ts: WooferTSParameters) -> Double {
        let alpha = computedComplianceAlpha(for: ts)
        let qmsBox = ts.qms * sqrt(1.0 + alpha)
        let qbVal = stuffing.enclosureLossQb
        return (qmsBox * qbVal) / (qmsBox + qbVal)
    }

    /// Effective Total System Q (Qtc) inside enclosure
    public func actualQtc(for ts: WooferTSParameters) -> Double {
        let alpha = computedComplianceAlpha(for: ts)
        let effectiveQts = ts.qts > 0 ? ts.qts : (ts.qes > 0 && ts.qms > 0 ? (ts.qes * ts.qms) / (ts.qes + ts.qms) : 0.35)
        return effectiveQts * sqrt(1.0 + alpha)
    }

    /// Actual lower -3dB cutoff frequency f3 (Hz) based on current configuration
    public func actualF3(for ts: WooferTSParameters) -> Double {
        if enclosureType == .vented {
            // Find frequency where |H_vented(f)| = 1/sqrt(2) ≈ 0.7071
            let targetMag = 1.0 / sqrt(2.0)
            let fs = max(ts.fs, 15.0)
            var low = 0.25 * fs
            var high = 3.5 * fs
            for _ in 0..<25 {
                let mid = (low + high) / 2.0
                let mag = ventedTransferFunction(frequency: mid, ts: ts).magnitude
                if mag < targetMag {
                    low = mid
                } else {
                    high = mid
                }
            }
            return (low + high) / 2.0
        }

        let fc = computedResonanceFc(for: ts)
        let qtc = actualQtc(for: ts)
        guard qtc > 0 else { return fc }
        let b = (1.0 / pow(qtc, 2)) - 2.0
        let x = (b + sqrt(b * b + 4.0)) / 2.0
        return fc * sqrt(x)
    }

    /// Complex transfer function transformation H_cab(s) of the driver inside the closed or vented cabinet at frequency f.
    public func transferFunction(frequency f: Double, ts: WooferTSParameters, isSyntheticFlat: Bool = true) -> ComplexNumber {
        if enclosureType == .vented {
            return ventedTransferFunction(frequency: f, ts: ts)
        }
        let fc = computedResonanceFc(for: ts)
        let qtc = actualQtc(for: ts)
        let wc = 2.0 * .pi * fc
        let w = 2.0 * .pi * f

        // Sealed box 2nd-order acoustic high-pass filter:
        // H_box(s) = s^2 / (s^2 + (wc/Qtc)*s + wc^2) where s = j*w
        let numBox = ComplexNumber(real: -pow(w, 2), imag: 0.0)
        let denomBox = ComplexNumber(real: pow(wc, 2) - pow(w, 2), imag: (w * wc) / max(qtc, 0.01))
        return numBox / denomBox
    }

    /// 4th-order Vented (Bass-Reflex) acoustic transfer function H_vented(s) (Small / Keele / Margolis filter polynomial)
    public func ventedTransferFunction(frequency f: Double, ts: WooferTSParameters) -> ComplexNumber {
        let fs = max(ts.fs, 1.0)
        let effQts = ts.qts > 0 ? ts.qts : (ts.qes > 0 && ts.qms > 0 ? (ts.qes * ts.qms) / (ts.qes + ts.qms) : 0.35)
        let qts = max(effQts, 0.05)
        let vb = max(computedAcousticVolumeLiters(for: ts), 1.0)
        let alpha = max(ts.vas / vb, 0.01)
        let fb = max(actualTuningFb(for: ts), 5.0)
        let h = fb / fs
        let ql = max(portLossQl, 5.0)

        let fn = f / fs
        let c0 = h * h
        let c1 = (h * h) / qts + h / ql
        let c2 = 1.0 + h * h + alpha + h / (qts * ql)
        let c3 = 1.0 / qts + h / ql

        let reD = pow(fn, 4) - c2 * pow(fn, 2) + c0
        let imD = -c3 * pow(fn, 3) + c1 * fn
        let denom = ComplexNumber(real: reD, imag: imD)
        let num = ComplexNumber(real: pow(fn, 4), imag: 0.0)

        return num / denom
    }

    /// Electrical input impedance of a driver loaded in a 4th-order vented enclosure (Small 1973 acoustic load equation)
    public func ventedRawImpedance(frequency f: Double, ts: WooferTSParameters) -> ComplexNumber {
        let fs = max(ts.fs, 1.0)
        let qms = max(ts.qms, 0.5)
        let qes = max(ts.qes, 0.05)
        let re = max(ts.re, 1.0)
        let leSec = max(ts.le, 0.0) / 1000.0
        let vb = max(computedAcousticVolumeLiters(for: ts), 1.0)
        let alpha = max(ts.vas / vb, 0.01)
        let fb = max(actualTuningFb(for: ts), 5.0)
        let h = fb / fs
        let ql = max(portLossQl, 5.0)

        let res = re * (qms / qes)
        let w = 2.0 * .pi * f
        let fn = max(f / fs, 1e-4)

        // Small 1973 acoustic circuit load reflected to mechanical side:
        // Zab(s) = alpha / (sn + h^2 / (sn + h/Ql)) where sn = j*fn
        let sn = ComplexNumber(real: 0.0, imag: fn)
        let denPort = sn + (h / ql)
        let zPort = ComplexNumber(real: h * h, imag: 0.0) / denPort
        let denCab = sn + zPort
        let zCab = ComplexNumber(real: alpha, imag: 0.0) / denCab

        // Total normalized mechanical impedance: z_mech = (1/Qms) + sn + 1/sn + zCab
        let invSn = ComplexNumber(real: 1.0, imag: 0.0) / sn
        let zMech = ComplexNumber(real: 1.0 / qms, imag: 0.0) + sn + invSn + zCab

        // Motional impedance: Zm = (Res / Qms) / zMech
        let zMotional = ComplexNumber(real: res / qms, imag: 0.0) / zMech

        // Total voice coil impedance: Re + j*w*Le + Zm
        return ComplexNumber(real: re, imag: w * leSec) + zMotional
    }
}
