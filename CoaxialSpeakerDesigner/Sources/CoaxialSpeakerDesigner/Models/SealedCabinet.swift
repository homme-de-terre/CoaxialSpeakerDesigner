import Foundation

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

/// Parameters and computed physics metrics for a closed/sealed loudspeaker enclosure.
public struct SealedCabinet: Codable, Sendable {
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
        manualNetVolumeLiters: Double = 25.0
    ) {
        self.alignment = alignment
        self.targetF3 = targetF3
        self.targetQtc = targetQtc
        self.stuffing = stuffing
        self.enclosureLossQb = enclosureLossQb
        self.isManualVolumeOverride = isManualVolumeOverride
        self.manualNetVolumeLiters = manualNetVolumeLiters
    }

    /// Baseline alignment alpha (unfilled) for target Q or target f3
    public func computedBaseAlignmentAlpha(for ts: WooferTSParameters) -> Double {
        let effectiveQts = ts.qts > 0 ? ts.qts : (ts.qes > 0 && ts.qms > 0 ? (ts.qes * ts.qms) / (ts.qes + ts.qms) : 0.35)

        switch alignment {
        case .targetF3:
            let r = pow(targetF3 / max(ts.fs, 1.0), 2)
            let q2 = pow(effectiveQts, 2)
            let disc = 2.0 * r * r - (r / max(q2, 1e-4))
            if disc <= 0 {
                // If requested f3 is below the physical limit for a closed box,
                // fall back to Butterworth B2 (Qtc = 0.7071) which produces the lowest
                // cutoff without resonance peaking, avoiding thousands of liters of box volume.
                let ratio = 0.70710678 / max(effectiveQts, 0.01)
                return max(pow(ratio, 2) - 1.0, 0.05)
            }
            let y = r + sqrt(disc)
            if y <= 1.0 {
                let ratio = 0.70710678 / max(effectiveQts, 0.01)
                return max(pow(ratio, 2) - 1.0, 0.05)
            }
            let alpha = y - 1.0
            return max(alpha, 0.05)

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
        if isManualVolumeOverride {
            return manualNetVolumeLiters
        }
        let baseAlpha = computedBaseAlignmentAlpha(for: ts)
        guard baseAlpha > 0 else { return 10.0 }
        return ts.vas / baseAlpha
    }

    /// Required Net Acoustic Volume Vb_acoustic (in Liters) including polyfill volume gain
    public func computedAcousticVolumeLiters(for ts: WooferTSParameters) -> Double {
        return computedPhysicalVolumeLiters(for: ts) * stuffing.volumeGainFactor
    }

    /// Computed Compliance Ratio Alpha = Vas / Vb_acoustic inside the stuffed enclosure
    public func computedComplianceAlpha(for ts: WooferTSParameters) -> Double {
        let acousticVb = computedAcousticVolumeLiters(for: ts)
        guard acousticVb > 0 else { return 1.0 }
        return ts.vas / acousticVb
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

    /// Effective Total System Q (Qtc) inside enclosure including electrical and mechanical damping
    public func actualQtc(for ts: WooferTSParameters) -> Double {
        let alpha = computedComplianceAlpha(for: ts)
        let effectiveQes = ts.qes > 0 ? ts.qes : 0.35
        let qec = effectiveQes * sqrt(1.0 + alpha)
        let qmc = actualQmc(for: ts)
        return (qec * qmc) / (qec + qmc)
    }

    /// Mechanical Q inside enclosure taking enclosure absorption loss Qb into account
    public func actualQmc(for ts: WooferTSParameters) -> Double {
        let alpha = computedComplianceAlpha(for: ts)
        let qmsBox = ts.qms * sqrt(1.0 + alpha)
        let qbVal = max(enclosureLossQb, 1.0)
        return (qmsBox * qbVal) / (qmsBox + qbVal)
    }

    /// Actual lower -3dB cutoff frequency f3 (Hz) based on current configuration
    public func actualF3(for ts: WooferTSParameters) -> Double {
        let fc = computedResonanceFc(for: ts)
        let qtc = actualQtc(for: ts)
        guard qtc > 0 else { return fc }
        let b = (1.0 / pow(qtc, 2)) - 2.0
        let x = (b + sqrt(b * b + 4.0)) / 2.0
        return fc * sqrt(x)
    }

    /// Complex transfer function transformation H_cab(s) of the driver inside the closed cabinet at frequency f.
    /// If transforming a measured free-air response curve, applies the enclosure ratio H_box(s) / H_free_air(s).
    public func transferFunction(frequency f: Double, ts: WooferTSParameters, isSyntheticFlat: Bool = false) -> ComplexNumber {
        let fc = computedResonanceFc(for: ts)
        let qtc = actualQtc(for: ts)
        let wc = 2.0 * .pi * fc
        let ws = 2.0 * .pi * max(ts.fs, 1.0)
        let w = 2.0 * .pi * f

        // H_box(s) = s^2 / (s^2 + (wc/Qtc)*s + wc^2) where s = j*w
        let numBox = ComplexNumber(real: -pow(w, 2), imag: 0.0)
        let denomBox = ComplexNumber(real: pow(wc, 2) - pow(w, 2), imag: (w * wc) / max(qtc, 0.01))
        let hBox = numBox / denomBox

        if isSyntheticFlat {
            return hBox
        } else {
            // Enclosure response transformation ratio H_box(s) / H_free_air(s)
            let denomFreeAir = ComplexNumber(real: pow(ws, 2) - pow(w, 2), imag: (w * ws) / max(ts.qts, 0.01))
            return denomFreeAir / denomBox
        }
    }
}
