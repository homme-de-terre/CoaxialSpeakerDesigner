import Foundation

/// Core Audio Physics Simulation Engine for Coaxial Drivers in Sealed Enclosures with Passive Crossover Networks.
public enum SimulationEngine {
    
    /// Run complete acoustic & electrical simulation across 20 Hz to 20,000 Hz (logarithmic steps).
    public static func simulate(
        driver: CoaxialDriver,
        cabinet: SealedCabinet,
        crossover: CrossoverNetwork,
        stepCount: Int = 200
    ) -> [SimulationPoint] {
        var points: [SimulationPoint] = []
        
        let minFreq = 20.0
        let maxFreq = 20000.0
        let logMin = log10(minFreq)
        let logMax = log10(maxFreq)
        let logStep = (logMax - logMin) / Double(stepCount)
        
        // Ensure Hilbert minimum phase is present for raw driver acoustic curves
        let baseWooferCurve = (driver.hasCustomWooferCurve && !driver.wooferAcousticCurve.isEmpty)
            ? driver.wooferAcousticCurve
            : (driver.wooferAcousticCurve.isEmpty ? CoaxialDriver.generateSyntheticWooferCurve(ts: driver.wooferTS) : driver.wooferAcousticCurve)
        let baseTweeterCurve = (driver.hasCustomTweeterCurve && !driver.tweeterAcousticCurve.isEmpty)
            ? driver.tweeterAcousticCurve
            : (driver.tweeterAcousticCurve.isEmpty ? CoaxialDriver.generateSyntheticTweeterCurve(tw: driver.tweeter) : driver.tweeterAcousticCurve)

        let wooferSPLShift: Double = {
            if driver.hasCustomWooferCurve, let refSPL = driver.customWooferReferenceSPL, refSPL > 0, driver.wooferTS.spl > 0 {
                return driver.wooferTS.spl - refSPL
            }
            return 0.0
        }()
        let tweeterSPLShift: Double = {
            if driver.hasCustomTweeterCurve, let refSPL = driver.customTweeterReferenceSPL, refSPL > 0, driver.tweeter.spl > 0 {
                return driver.tweeter.spl - refSPL
            }
            return 0.0
        }()

        let rawWooferCurve = abs(wooferSPLShift) > 1e-4
            ? baseWooferCurve.map { ResponseDataPoint(id: $0.id, frequency: $0.frequency, magnitude: $0.magnitude + wooferSPLShift, phase: $0.phase) }
            : baseWooferCurve
        let rawTweeterCurve = abs(tweeterSPLShift) > 1e-4
            ? baseTweeterCurve.map { ResponseDataPoint(id: $0.id, frequency: $0.frequency, magnitude: $0.magnitude + tweeterSPLShift, phase: $0.phase) }
            : baseTweeterCurve

        let wooferAcousticP = driver.hasCustomWooferCurve ? ensurePhase(curve: rawWooferCurve) : rawWooferCurve
        let tweeterAcousticP = driver.hasCustomTweeterCurve ? ensurePhase(curve: rawTweeterCurve) : rawTweeterCurve
        
        for i in 0...stepCount {
            let logF = logMin + Double(i) * logStep
            let f = pow(10.0, logF)
            
            // 1. Raw Driver Acoustic Pressure Interpolation (Complex)
            let pWooferRaw = interpolateAcousticPressure(freq: f, curve: wooferAcousticP)
            let pTweeterRaw = interpolateAcousticPressure(freq: f, curve: tweeterAcousticP)
            
            // 2. Sealed Cabinet Acoustic Transfer Function H_cab(s)
            let hCab = cabinet.transferFunction(frequency: f, ts: driver.wooferTS)
            
            // 3. Crossover Electrical Filter Transfer Functions H_LP(s), H_HP(s), H_AP(s)
            let hLP = crossover.wooferFilterTransferFunction(frequency: f)
            let hHP = crossover.tweeterFilterTransferFunction(frequency: f)
            let hAP = crossover.allpassFilterTransferFunction(frequency: f)
            
            // 4. Acoustic Delay & Polarity & L-Pad / CD Horn EQ Transfer Function
            let hDelay = crossover.tweeterAcousticDelayFactor(frequency: f)
            let hLpadCD = crossover.tweeterLPadAndCDHornTransferFunction(frequency: f, tweeterRe: driver.tweeter.re)
            let polarityMultiplier = crossover.invertTweeterPolarity ? -1.0 : 1.0

            // 5. Compute Woofer Final Acoustic Pressure
            let pWooferCab = pWooferRaw * hCab
            let pWooferFinal = pWooferCab * hLP * hAP

            // 6. Compute Tweeter Final Acoustic Pressure (and pure delay-compensated pressure)
            let pTweeterFinal = pTweeterRaw * hHP * hLpadCD * hDelay
            let pTweeterDelayComp = pTweeterRaw * hHP * hLpadCD * polarityMultiplier

            // 7. Summed Complex Acoustic Pressure Vector
            let pTotal = pWooferFinal + pTweeterFinal

            // 8. Magnitudes and Phase Angles
            let wooferRawSPL = 20.0 * log10(max(pWooferRaw.magnitude, 1e-6))
            let wooferCabSPL = 20.0 * log10(max(pWooferCab.magnitude, 1e-6))
            let wooferFinalSPL = 20.0 * log10(max(pWooferFinal.magnitude, 1e-6))
            let wooferPhaseDeg = pWooferFinal.phaseDegrees

            let tweeterRawSPL = 20.0 * log10(max(pTweeterRaw.magnitude, 1e-6))
            let tweeterFinalSPL = 20.0 * log10(max(pTweeterFinal.magnitude, 1e-6))
            let tweeterPhaseDeg = pTweeterFinal.phaseDegrees
            let tweeterDelayCompPhaseDeg = pTweeterDelayComp.phaseDegrees

            let totalSPL = 20.0 * log10(max(pTotal.magnitude, 1e-6))
            let totalPhaseDeg = pTotal.phaseDegrees

            // Inter-driver phase difference delta phi
            var deltaPhase = abs(wooferPhaseDeg - tweeterPhaseDeg).truncatingRemainder(dividingBy: 360.0)
            if deltaPhase > 180.0 { deltaPhase = 360.0 - deltaPhase }

            // 9. Raw Driver & System Impedance Calculations
            let zWooferRaw = computeWooferRawImpedance(freq: f, ts: driver.wooferTS, cabinet: cabinet)
            let zTweeterRaw = computeTweeterRawImpedance(freq: f, tw: driver.tweeter)

            let zWooferCompensated = computeWooferCompensatedImpedance(freq: f, zVoiceCoilRaw: zWooferRaw, crossover: crossover, ts: driver.wooferTS)
            let zWooferInput = computeWooferCrossoverInputImpedance(freq: f, zVoiceCoilRaw: zWooferRaw, crossover: crossover, ts: driver.wooferTS)
            let zTweeterInput = computeTweeterCrossoverInputImpedance(freq: f, zVoiceCoilRaw: zTweeterRaw, crossover: crossover, tw: driver.tweeter)

            // Total parallel load impedance seen by amplifier
            let zTotalSystem = (zWooferInput * zTweeterInput) / (zWooferInput + zTweeterInput)

            points.append(
                SimulationPoint(
                    frequency: f,
                    wooferRawSPL: wooferRawSPL,
                    wooferCabinetSPL: wooferCabSPL,
                    wooferFinalSPL: wooferFinalSPL,
                    wooferPhaseDeg: wooferPhaseDeg,
                    tweeterRawSPL: tweeterRawSPL,
                    tweeterFinalSPL: tweeterFinalSPL,
                    tweeterPhaseDeg: tweeterPhaseDeg,
                    totalSystemSPL: totalSPL,
                    totalSystemPhaseDeg: totalPhaseDeg,
                    phaseDifferenceDeg: deltaPhase,
                    wooferImpedanceMag: zWooferCompensated.magnitude,
                    tweeterImpedanceMag: zTweeterRaw.magnitude,
                    totalSystemImpedanceMag: zTotalSystem.magnitude,
                    totalSystemImpedancePhaseDeg: zTotalSystem.phaseDegrees,
                    tweeterDelayCompensatedPhaseDeg: tweeterDelayCompPhaseDeg
                )
            )
        }

        // 10. Compute Unwrapped Phase & Acoustic Group Delay
        let freqs = points.map { $0.frequency }
        let wooferUnwrapped = unwrapPhase(phases: points.map { $0.wooferPhaseDeg })
        let tweeterUnwrapped = unwrapPhase(phases: points.map { $0.tweeterPhaseDeg })
        let totalUnwrapped = unwrapPhase(phases: points.map { $0.totalSystemPhaseDeg })

        let wooferGD = computeGroupDelay(frequencies: freqs, unwrappedPhases: wooferUnwrapped)
        let tweeterGD = computeGroupDelay(frequencies: freqs, unwrappedPhases: tweeterUnwrapped)
        let totalGD = computeGroupDelay(frequencies: freqs, unwrappedPhases: totalUnwrapped)

        for i in 0..<points.count {
            points[i].wooferUnwrappedPhaseDeg = wooferUnwrapped[i]
            points[i].tweeterUnwrappedPhaseDeg = tweeterUnwrapped[i]
            points[i].totalSystemUnwrappedPhaseDeg = totalUnwrapped[i]
            points[i].wooferGroupDelayMs = wooferGD[i]
            points[i].tweeterGroupDelayMs = tweeterGD[i]
            points[i].totalSystemGroupDelayMs = totalGD[i]
        }

        return points
    }

    /// Canonical 1D phase unwrapping algorithm removing +/- 360 degree discontinuities.
    public static func unwrapPhase(phases: [Double]) -> [Double] {
        guard !phases.isEmpty else { return [] }
        var unwrapped = phases
        for i in 1..<phases.count {
            var diff = unwrapped[i] - unwrapped[i - 1]
            while diff > 180.0 { diff -= 360.0 }
            while diff < -180.0 { diff += 360.0 }
            unwrapped[i] = unwrapped[i - 1] + diff
        }
        return unwrapped
    }

    /// Numerical group delay calculation in milliseconds: tau_g(f) = -dPhi/dOmega = -(1000/360) * dPhi_deg/df.
    public static func computeGroupDelay(frequencies: [Double], unwrappedPhases: [Double]) -> [Double] {
        let n = frequencies.count
        guard n > 0, unwrappedPhases.count == n else { return [] }
        if n == 1 { return [0.0] }

        var gd = [Double](repeating: 0.0, count: n)
        let scale = -1000.0 / 360.0

        for i in 0..<n {
            let dPhiDf: Double
            if i == 0 {
                let df = frequencies[1] - frequencies[0]
                dPhiDf = df != 0 ? (unwrappedPhases[1] - unwrappedPhases[0]) / df : 0.0
            } else if i == n - 1 {
                let df = frequencies[n - 1] - frequencies[n - 2]
                dPhiDf = df != 0 ? (unwrappedPhases[n - 1] - unwrappedPhases[n - 2]) / df : 0.0
            } else {
                let df = frequencies[i + 1] - frequencies[i - 1]
                dPhiDf = df != 0 ? (unwrappedPhases[i + 1] - unwrappedPhases[i - 1]) / df : 0.0
            }
            gd[i] = scale * dPhiDf
        }
        return gd
    }
    
    private static func ensurePhase(curve: [ResponseDataPoint]) -> [ResponseDataPoint] {
        if curve.isEmpty { return [] }
        let hasNonZeroPhase = curve.contains(where: { abs($0.phase) > 0.01 })
        if hasNonZeroPhase {
            return curve
        }
        // Synthesize minimum phase via Hilbert Transform
        return HilbertTransform.computeMinimumPhase(points: curve)
    }
    
    private static func interpolateAcousticPressure(freq: Double, curve: [ResponseDataPoint]) -> ComplexNumber {
        guard !curve.isEmpty else { return ComplexNumber(real: 0, imag: 0) }
        
        if freq <= curve.first!.frequency {
            let spl = curve.first!.magnitude
            let magLinear = pow(10.0, spl / 20.0)
            let phaseRad = curve.first!.phase * (.pi / 180.0)
            return ComplexNumber(r: magLinear, theta: phaseRad)
        }
        
        if freq >= curve.last!.frequency {
            let spl = curve.last!.magnitude
            let magLinear = pow(10.0, spl / 20.0)
            let phaseRad = curve.last!.phase * (.pi / 180.0)
            return ComplexNumber(r: magLinear, theta: phaseRad)
        }
        
        for i in 0..<(curve.count - 1) {
            let p1 = curve[i]
            let p2 = curve[i+1]
            if freq >= p1.frequency && freq <= p2.frequency {
                let logF = log10(freq)
                let logF1 = log10(p1.frequency)
                let logF2 = log10(p2.frequency)
                let t = (logF - logF1) / (logF2 - logF1)
                
                let spl = p1.magnitude + t * (p2.magnitude - p1.magnitude)
                var dPhase = p2.phase - p1.phase
                while dPhase > 180.0 { dPhase -= 360.0 }
                while dPhase < -180.0 { dPhase += 360.0 }
                var phaseDeg = p1.phase + t * dPhase
                while phaseDeg > 180.0 { phaseDeg -= 360.0 }
                while phaseDeg < -180.0 { phaseDeg += 360.0 }
                
                let magLinear = pow(10.0, spl / 20.0)
                let phaseRad = phaseDeg * (.pi / 180.0)
                return ComplexNumber(r: magLinear, theta: phaseRad)
            }
        }
        
        let magLinear = pow(10.0, curve.first!.magnitude / 20.0)
        return ComplexNumber(real: magLinear, imag: 0)
    }
    
    /// Compute Woofer raw voice coil and sealed/vented cabinet motional impedance Z_woofer,raw(f)
    private static func computeWooferRawImpedance(
        freq: Double,
        ts: WooferTSParameters,
        cabinet: SealedCabinet
    ) -> ComplexNumber {
        if cabinet.enclosureType == .vented {
            return cabinet.ventedRawImpedance(frequency: freq, ts: ts)
        }
        let fc = cabinet.computedResonanceFc(for: ts)
        let qmc = cabinet.actualQmc(for: ts)
        let alpha = cabinet.computedComplianceAlpha(for: ts)
        let qmsBox = ts.qms * sqrt(1.0 + alpha)
        let qb = cabinet.stuffing.enclosureLossQb
        
        let w = 2.0 * .pi * freq
        let re = ts.re
        let leSec = ts.le / 1000.0
        
        // Motional impedance peak at Fc scaled by absorption loss Qb
        let res = re * (ts.qms / max(ts.qes, 0.01)) * (qb / (qmsBox + qb))
        
        // Motional impedance peak at Fc inside closed box
        let deltaF = (freq / fc) - (fc / freq)
        let denom = 1.0 + pow(qmc * deltaF, 2)
        let rMotional = res / denom
        let xMotional = -res * (qmc * deltaF) / denom
        
        let zMotional = ComplexNumber(real: rMotional, imag: xMotional)
        return ComplexNumber(real: re, imag: w * leSec) + zMotional
    }

    /// Compute Woofer terminal load impedance, applying parallel Zobel network across terminals if enabled
    public static func computeWooferCompensatedImpedance(
        freq: Double,
        zVoiceCoilRaw: ComplexNumber,
        crossover: CrossoverNetwork,
        ts: WooferTSParameters
    ) -> ComplexNumber {
        guard crossover.enableZobelNetwork && ts.le > 0 && ts.re > 0 else {
            return zVoiceCoilRaw
        }
        let w = 2.0 * .pi * freq
        let rz = 1.25 * ts.re
        let czFarads = (ts.le / 1000.0) / (rz * rz)
        let zZobel = ComplexNumber(real: rz, imag: -1.0 / (w * czFarads))
        return (zVoiceCoilRaw * zZobel) / (zVoiceCoilRaw + zZobel)
    }

    /// Compute Low-Pass Crossover Branch Input Impedance seen by Amplifier
    private static func computeWooferCrossoverInputImpedance(
        freq: Double,
        zVoiceCoilRaw: ComplexNumber,
        crossover: CrossoverNetwork,
        ts: WooferTSParameters
    ) -> ComplexNumber {
        let w = 2.0 * .pi * freq
        let zVC = computeWooferCompensatedImpedance(freq: freq, zVoiceCoilRaw: zVoiceCoilRaw, crossover: crossover, ts: ts)

        let comp = crossover.computeComponentValues(wooferRe: ts.re, tweeterRe: 8.0, wooferLe: ts.le)

        switch crossover.wooferOrder {
        case .firstOrder:
            if let l1 = comp.L1_mH {
                let zL1 = ComplexNumber(real: 0.05, imag: w * (l1 / 1000.0))
                return zL1 + zVC
            }
            return zVC

        case .secondOrderLR, .secondOrderBW:
            if let l1 = comp.L1_mH, let c1 = comp.C1_uF {
                let zL1 = ComplexNumber(real: 0.05, imag: w * (l1 / 1000.0))
                let zC1 = ComplexNumber(real: 0.0, imag: -1.0 / (w * (c1 / 1e6)))
                let zParallel = (zVC * zC1) / (zVC + zC1)
                return zL1 + zParallel
            }
            return zVC

        case .thirdOrderBW, .fourthOrderLR:
            if let l1 = comp.L1_mH, let c1 = comp.C1_uF {
                let zL1 = ComplexNumber(real: 0.05, imag: w * (l1 / 1000.0))
                let zC1 = ComplexNumber(real: 0.0, imag: -1.0 / (w * (c1 / 1e6)))
                let zParallel = (zVC * zC1) / (zVC + zC1)
                return zL1 + zParallel
            }
            return zVC
        }
    }
    
    /// Compute Tweeter raw voice coil impedance Z_tweeter,raw(f)
    private static func computeTweeterRawImpedance(
        freq: Double,
        tw: TweeterParameters
    ) -> ComplexNumber {
        let w = 2.0 * .pi * freq
        let leSec = tw.le / 1000.0
        
        // Tweeter motional peak at Fs_tweeter
        let fsTw = tw.fs
        let qmsTw = 3.5
        let resTw = tw.re * 1.8
        let deltaF = (freq / fsTw) - (fsTw / freq)
        let denom = 1.0 + pow(qmsTw * deltaF, 2)
        let rMotional = resTw / denom
        let xMotional = -resTw * (qmsTw * deltaF) / denom
        
        return ComplexNumber(real: tw.re + rMotional, imag: w * leSec + xMotional)
    }

    /// Compute High-Pass Crossover Branch Input Impedance seen by Amplifier
    private static func computeTweeterCrossoverInputImpedance(
        freq: Double,
        zVoiceCoilRaw: ComplexNumber,
        crossover: CrossoverNetwork,
        tw: TweeterParameters
    ) -> ComplexNumber {
        let w = 2.0 * .pi * freq
        var zVC = zVoiceCoilRaw

        let comp = crossover.computeComponentValues(wooferRe: 6.0, tweeterRe: tw.re, wooferLe: 0.8)

        // Apply L-Pad Attenuator & optional CD Horn Mass Roll-Off Bypass across R1
        if let r1 = comp.R1_lpad_ohms, let r2 = comp.R2_lpad_ohms {
            let zR2 = ComplexNumber(real: r2, imag: 0.0)
            let zParallel = (zVC * zR2) / (zVC + zR2)
            var zSeries = ComplexNumber(real: r1, imag: 0.0)
            if crossover.enableCDHornCompensation, let cCD = comp.C_cd_uF, cCD > 0 {
                let rCD = comp.R_cd_ohms ?? 0.0
                let zBypass = ComplexNumber(real: rCD, imag: -1.0 / (w * (cCD / 1e6)))
                zSeries = (zSeries * zBypass) / (zSeries + zBypass)
            }
            zVC = zSeries + zParallel
        }

        switch crossover.tweeterOrder {
        case .firstOrder:
            if let c1 = comp.C_HP1_uF {
                let zC1 = ComplexNumber(real: 0.0, imag: -1.0 / (w * (c1 / 1e6)))
                return zC1 + zVC
            }
            return zVC

        case .secondOrderLR, .secondOrderBW:
            if let c1 = comp.C_HP1_uF, let l1 = comp.L_HP1_mH {
                let zC1 = ComplexNumber(real: 0.0, imag: -1.0 / (w * (c1 / 1e6)))
                let zL1 = ComplexNumber(real: 0.05, imag: w * (l1 / 1000.0))
                let zParallel = (zVC * zL1) / (zVC + zL1)
                return zC1 + zParallel
            }
            return zVC

        case .thirdOrderBW, .fourthOrderLR:
            if let c1 = comp.C_HP1_uF, let l1 = comp.L_HP1_mH {
                let zC1 = ComplexNumber(real: 0.0, imag: -1.0 / (w * (c1 / 1e6)))
                let zL1 = ComplexNumber(real: 0.05, imag: w * (l1 / 1000.0))
                let zParallel = (zVC * zL1) / (zVC + zL1)
                return zC1 + zParallel
            }
            return zVC
        }
    }

    /// Computes transient step response across a time window (0 to durationMs).
    public static func computeStepResponse(
        driver: CoaxialDriver,
        cabinet: SealedCabinet,
        crossover: CrossoverNetwork,
        durationMs: Double = 6.0,
        sampleRate: Double = 48000.0,
        fftSize: Int = 1024
    ) -> [StepResponsePoint] {
        let n = fftSize
        let fs = sampleRate

        var rw = [Double](repeating: 0.0, count: n)
        var iw = [Double](repeating: 0.0, count: n)
        var rt = [Double](repeating: 0.0, count: n)
        var it = [Double](repeating: 0.0, count: n)
        var rTot = [Double](repeating: 0.0, count: n)
        var iTot = [Double](repeating: 0.0, count: n)

        let baseWooferCurve = (driver.hasCustomWooferCurve && !driver.wooferAcousticCurve.isEmpty)
            ? driver.wooferAcousticCurve
            : (driver.wooferAcousticCurve.isEmpty ? CoaxialDriver.generateSyntheticWooferCurve(ts: driver.wooferTS) : driver.wooferAcousticCurve)
        let baseTweeterCurve = (driver.hasCustomTweeterCurve && !driver.tweeterAcousticCurve.isEmpty)
            ? driver.tweeterAcousticCurve
            : (driver.tweeterAcousticCurve.isEmpty ? CoaxialDriver.generateSyntheticTweeterCurve(tw: driver.tweeter) : driver.tweeterAcousticCurve)

        let wooferSPLShift: Double = {
            if driver.hasCustomWooferCurve, let refSPL = driver.customWooferReferenceSPL, refSPL > 0, driver.wooferTS.spl > 0 {
                return driver.wooferTS.spl - refSPL
            }
            return 0.0
        }()
        let tweeterSPLShift: Double = {
            if driver.hasCustomTweeterCurve, let refSPL = driver.customTweeterReferenceSPL, refSPL > 0, driver.tweeter.spl > 0 {
                return driver.tweeter.spl - refSPL
            }
            return 0.0
        }()

        let rawWooferCurve = abs(wooferSPLShift) > 1e-4
            ? baseWooferCurve.map { ResponseDataPoint(id: $0.id, frequency: $0.frequency, magnitude: $0.magnitude + wooferSPLShift, phase: $0.phase) }
            : baseWooferCurve
        let rawTweeterCurve = abs(tweeterSPLShift) > 1e-4
            ? baseTweeterCurve.map { ResponseDataPoint(id: $0.id, frequency: $0.frequency, magnitude: $0.magnitude + tweeterSPLShift, phase: $0.phase) }
            : baseTweeterCurve

        let wooferAcousticP = driver.hasCustomWooferCurve ? ensurePhase(curve: rawWooferCurve) : rawWooferCurve
        let tweeterAcousticP = driver.hasCustomTweeterCurve ? ensurePhase(curve: rawTweeterCurve) : rawTweeterCurve

        for k in 1..<(n / 2) {
            let f = Double(k) * fs / Double(n)

            let pWooferRaw = interpolateAcousticPressure(freq: f, curve: wooferAcousticP)
            let pTweeterRaw = interpolateAcousticPressure(freq: f, curve: tweeterAcousticP)

            let hCab = cabinet.transferFunction(frequency: f, ts: driver.wooferTS)
            let hLP = crossover.wooferFilterTransferFunction(frequency: f)
            let hHP = crossover.tweeterFilterTransferFunction(frequency: f)
            let hLpadCD = crossover.tweeterLPadAndCDHornTransferFunction(frequency: f, tweeterRe: driver.tweeter.re)
            let hDelay = crossover.tweeterAcousticDelayFactor(frequency: f)
            let hAP = crossover.allpassFilterTransferFunction(frequency: f)

            let pWooferFinal = pWooferRaw * hCab * hLP * hAP
            let pTweeterFinal = pTweeterRaw * hHP * hLpadCD * hDelay
            let pTotal = pWooferFinal + pTweeterFinal

            // Anti-aliasing smooth rolloff near Nyquist to eliminate sinc ringing
            let rollOff = exp(-pow(f / 21000.0, 4.0))

            let wR = pWooferFinal.real * rollOff
            let wI = pWooferFinal.imag * rollOff
            let tR = pTweeterFinal.real * rollOff
            let tI = pTweeterFinal.imag * rollOff
            let totR = pTotal.real * rollOff
            let totI = pTotal.imag * rollOff

            rw[k] = wR
            iw[k] = wI
            rw[n - k] = wR
            iw[n - k] = -wI

            rt[k] = tR
            it[k] = tI
            rt[n - k] = tR
            it[n - k] = -tI

            rTot[k] = totR
            iTot[k] = totI
            rTot[n - k] = totR
            iTot[n - k] = -totI
        }

        // Perform Inverse FFT
        ifft(&rw, &iw)
        ifft(&rt, &it)
        ifft(&rTot, &iTot)

        // Integrate impulse response to obtain step response (cumulative sum)
        var stepW = [Double](repeating: 0.0, count: n)
        var stepT = [Double](repeating: 0.0, count: n)
        var stepTot = [Double](repeating: 0.0, count: n)

        stepW[0] = rw[0]
        stepT[0] = rt[0]
        stepTot[0] = rTot[0]

        for i in 1..<n {
            stepW[i] = stepW[i - 1] + rw[i]
            stepT[i] = stepT[i - 1] + rt[i]
            stepTot[i] = stepTot[i - 1] + rTot[i]
        }

        // Peak normalization
        var maxPeak = 0.001
        for i in 0..<n {
            let p = abs(stepTot[i])
            if p > maxPeak { maxPeak = p }
        }
        let normFactor = 1.0 / maxPeak

        // Sample points across time window
        let stepCount = 200
        var points: [StepResponsePoint] = []
        points.reserveCapacity(stepCount + 1)

        for i in 0...stepCount {
            let tMs = Double(i) * durationMs / Double(stepCount)
            let sampleIdx = min(n - 1, max(0, Int(round((tMs / 1000.0) * fs))))
            points.append(
                StepResponsePoint(
                    timeMs: tMs,
                    woofer: stepW[sampleIdx] * normFactor,
                    tweeter: stepT[sampleIdx] * normFactor,
                    total: stepTot[sampleIdx] * normFactor
                )
            )
        }

        return points
    }

    /// Fast Radix-2 Cooley-Tukey Inverse FFT (in-place)
    private static func ifft(_ real: inout [Double], _ imag: inout [Double]) {
        let n = real.count
        for i in 0..<n { imag[i] = -imag[i] }
        fft(&real, &imag)
        let scale = 1.0 / Double(n)
        for i in 0..<n {
            real[i] *= scale
            imag[i] = -imag[i] * scale
        }
    }

    /// Fast Radix-2 Cooley-Tukey Forward FFT (in-place)
    private static func fft(_ real: inout [Double], _ imag: inout [Double]) {
        let n = real.count
        var j = 0
        for i in 0..<(n - 1) {
            if i < j {
                real.swapAt(i, j)
                imag.swapAt(i, j)
            }
            var k = n >> 1
            while k <= j {
                j -= k
                k >>= 1
            }
            j += k
        }

        var len = 2
        while len <= n {
            let half = len >> 1
            let angle = -2.0 * .pi / Double(len)
            let wStepR = cos(angle)
            let wStepI = sin(angle)

            var i = 0
            while i < n {
                var wr = 1.0
                var wi = 0.0
                for m in 0..<half {
                    let idx1 = i + m
                    let idx2 = i + m + half
                    let tr = wr * real[idx2] - wi * imag[idx2]
                    let ti = wr * imag[idx2] + wi * real[idx2]
                    real[idx2] = real[idx1] - tr
                    imag[idx2] = imag[idx1] - ti
                    real[idx1] += tr
                    imag[idx1] += ti

                    let nextWr = wr * wStepR - wi * wStepI
                    wi = wr * wStepI + wi * wStepR
                    wr = nextWr
                }
                i += len
            }
            len <<= 1
        }
    }
}
