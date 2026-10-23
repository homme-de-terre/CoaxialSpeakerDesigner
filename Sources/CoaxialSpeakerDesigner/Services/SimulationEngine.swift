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
        let wooferAcousticP = ensurePhase(curve: driver.wooferAcousticCurve)
        let tweeterAcousticP = ensurePhase(curve: driver.tweeterAcousticCurve)
        
        for i in 0...stepCount {
            let logF = logMin + Double(i) * logStep
            let f = pow(10.0, logF)
            
            // 1. Raw Driver Acoustic Pressure Interpolation (Complex)
            let pWooferRaw = interpolateAcousticPressure(freq: f, curve: wooferAcousticP)
            let pTweeterRaw = interpolateAcousticPressure(freq: f, curve: tweeterAcousticP)
            
            // 2. Sealed Cabinet Acoustic Transfer Function H_cab(s)
            let hCab = cabinet.transferFunction(frequency: f, ts: driver.wooferTS)
            
            // 3. Crossover Electrical Filter Transfer Functions H_LP(s), H_HP(s)
            let hLP = crossover.wooferFilterTransferFunction(frequency: f)
            let hHP = crossover.tweeterFilterTransferFunction(frequency: f)
            
            // 4. Acoustic Delay & Polarity & L-Pad Gain Factor
            let hDelay = crossover.tweeterAcousticDelayFactor(frequency: f)
            let gLpad = crossover.lpadVoltageGain
            
            // 5. Compute Woofer Final Acoustic Pressure
            let pWooferCab = pWooferRaw * hCab
            let pWooferFinal = pWooferCab * hLP
            
            // 6. Compute Tweeter Final Acoustic Pressure
            let pTweeterFinal = pTweeterRaw * hHP * gLpad * hDelay
            
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
            
            let totalSPL = 20.0 * log10(max(pTotal.magnitude, 1e-6))
            let totalPhaseDeg = pTotal.phaseDegrees
            
            // Inter-driver phase difference delta phi
            var deltaPhase = abs(wooferPhaseDeg - tweeterPhaseDeg).truncatingRemainder(dividingBy: 360.0)
            if deltaPhase > 180.0 { deltaPhase = 360.0 - deltaPhase }
            
            // 9. Raw Driver & System Impedance Calculations
            let zWooferRaw = computeWooferRawImpedance(freq: f, ts: driver.wooferTS, cabinet: cabinet)
            let zTweeterRaw = computeTweeterRawImpedance(freq: f, tw: driver.tweeter)

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
                    wooferImpedanceMag: zWooferRaw.magnitude,
                    tweeterImpedanceMag: zTweeterRaw.magnitude,
                    totalSystemImpedanceMag: zTotalSystem.magnitude,
                    totalSystemImpedancePhaseDeg: zTotalSystem.phaseDegrees
                )
            )
        }
        
        return points
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
                let phaseDeg = p1.phase + t * (p2.phase - p1.phase)
                
                let magLinear = pow(10.0, spl / 20.0)
                let phaseRad = phaseDeg * (.pi / 180.0)
                return ComplexNumber(r: magLinear, theta: phaseRad)
            }
        }
        
        let magLinear = pow(10.0, curve.first!.magnitude / 20.0)
        return ComplexNumber(real: magLinear, imag: 0)
    }
    
    /// Compute Woofer raw voice coil and sealed cabinet motional impedance Z_woofer,raw(f)
    private static func computeWooferRawImpedance(
        freq: Double,
        ts: WooferTSParameters,
        cabinet: SealedCabinet
    ) -> ComplexNumber {
        let fc = cabinet.computedResonanceFc(for: ts)
        let qmc = cabinet.actualQmc(for: ts)
        let w = 2.0 * .pi * freq
        let re = ts.re
        let leSec = ts.le / 1000.0
        let res = re * (ts.qms / max(ts.qes, 0.01))
        
        // Motional impedance peak at Fc inside closed box
        let deltaF = (freq / fc) - (fc / freq)
        let denom = 1.0 + pow(qmc * deltaF, 2)
        let rMotional = res / denom
        let xMotional = -res * (qmc * deltaF) / denom
        
        let zMotional = ComplexNumber(real: rMotional, imag: xMotional)
        return ComplexNumber(real: re, imag: w * leSec) + zMotional
    }

    /// Compute Low-Pass Crossover Branch Input Impedance seen by Amplifier
    private static func computeWooferCrossoverInputImpedance(
        freq: Double,
        zVoiceCoilRaw: ComplexNumber,
        crossover: CrossoverNetwork,
        ts: WooferTSParameters
    ) -> ComplexNumber {
        let w = 2.0 * .pi * freq
        var zVC = zVoiceCoilRaw

        // Apply Zobel Network in parallel across woofer terminals if enabled
        if crossover.enableZobelNetwork {
            let rz = 1.25 * ts.re
            let czFarads = (ts.le / 1000.0) / (rz * rz)
            let zZobel = ComplexNumber(real: rz, imag: -1.0 / (w * czFarads))
            zVC = (zVC * zZobel) / (zVC + zZobel)
        }

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

        // Apply L-Pad Attenuator if enabled
        if crossover.enableLPadAttenuator && crossover.userTargetAttenuationdB > 0 {
            let k = pow(10.0, -crossover.userTargetAttenuationdB / 20.0)
            if k < 1.0 {
                let r1 = tw.nominalImpedance * (1.0 - k)
                let r2 = tw.nominalImpedance * (k / (1.0 - k))
                let zR2 = ComplexNumber(real: r2, imag: 0.0)
                let zParallel = (zVC * zR2) / (zVC + zR2)
                zVC = ComplexNumber(real: r1, imag: 0.0) + zParallel
            }
        }

        let comp = crossover.computeComponentValues(wooferRe: 6.0, tweeterRe: tw.re, wooferLe: 0.8)

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
}
