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
}

/// Parameters and computed physics metrics for a closed/sealed loudspeaker enclosure.
public struct SealedCabinet: Codable, Sendable {
    public var alignment: AlignmentType = .targetF3
    public var targetF3: Double = 55.0   // Target lower -3 dB cutoff frequency (Hz)
    public var targetQtc: Double = 0.707 // Target total system Q (Qtc)
    public var stuffing: StuffingLevel = .medium
    public var enclosureLossQb: Double = 7.0 // Enclosure absorption loss Q (typically 5.0 - 10.0, default 7.0)
    public var isManualVolumeOverride: Bool = false
    public var manualNetVolumeLiters: Double = 25.0

    public init(
        alignment: AlignmentType = .targetF3,
        targetF3: Double = 55.0,
        targetQtc: Double = 0.7071,
        stuffing: StuffingLevel = .medium,
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

    /// Computed Compliance Ratio Alpha = Vas / Vb_acoustic
    public func computedComplianceAlpha(for ts: WooferTSParameters) -> Double {
        if isManualVolumeOverride {
            guard manualNetVolumeLiters > 0 else { return 1.0 }
            let acousticVb = manualNetVolumeLiters * stuffing.volumeGainFactor
            return ts.vas / max(acousticVb, 0.1)
        }

        switch alignment {
        case .targetF3:
            let r = pow(targetF3 / max(ts.fs, 1.0), 2)
            let q2 = pow(ts.qts, 2)
            guard q2 > 0 else { return 1.0 }
            let term = 2.0 * r * r + (r / q2)
            let x = sqrt(term) - r
            let alpha = x - 1.0
            return max(alpha, 0.05)

        case .butterworth, .bessel, .criticallyDamped:
            if let targetQ = alignment.targetQtc {
                let ratio = targetQ / max(ts.qts, 0.01)
                let alpha = pow(ratio, 2) - 1.0
                return max(alpha, 0.05)
            }
            return 1.0

        case .customQtc:
            let ratio = targetQtc / max(ts.qts, 0.01)
            let alpha = pow(ratio, 2) - 1.0
            return max(alpha, 0.05)
        }
    }

    /// Required Net Acoustic Volume Vb_acoustic (in Liters)
    public func computedAcousticVolumeLiters(for ts: WooferTSParameters) -> Double {
        if isManualVolumeOverride {
            return manualNetVolumeLiters * stuffing.volumeGainFactor
        }
        let alpha = computedComplianceAlpha(for: ts)
        guard alpha > 0 else { return 10.0 }
        return ts.vas / alpha
    }

    /// Physical Internal Box Volume required taking stuffing volume gain into account
    public func computedPhysicalVolumeLiters(for ts: WooferTSParameters) -> Double {
        if isManualVolumeOverride {
            return manualNetVolumeLiters
        }
        let acousticVb = computedAcousticVolumeLiters(for: ts)
        return acousticVb / stuffing.volumeGainFactor
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

    /// Effective Total System Q (Qtc) inside enclosure
    public func actualQtc(for ts: WooferTSParameters) -> Double {
        let alpha = computedComplianceAlpha(for: ts)
        return ts.qts * sqrt(1.0 + alpha)
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
        let b = 1.0 - (1.0 / (2.0 * pow(qtc, 2)))
        let factor = sqrt(b + sqrt(pow(b, 2) + 1.0))
        return fc * factor
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
