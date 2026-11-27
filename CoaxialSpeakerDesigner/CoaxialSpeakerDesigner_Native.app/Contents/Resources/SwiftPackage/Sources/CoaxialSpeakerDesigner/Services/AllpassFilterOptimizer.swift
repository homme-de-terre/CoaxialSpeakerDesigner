import Foundation

/// 3-Tier RMS Phase Alignment Warning & Status Logic.
public enum PhaseAlignmentStatus: String, Codable, Sendable {
    case optimal = "green"
    case acceptable = "yellow"
    case largeOffset = "red"

    public static func from(rmsErrorDeg: Double) -> PhaseAlignmentStatus {
        if rmsErrorDeg <= 10.0 {
            return .optimal
        } else if rmsErrorDeg <= 20.0 {
            return .acceptable
        } else {
            return .largeOffset
        }
    }

    public var label: String {
        switch self {
        case .optimal:
            return "Phase Aligned (Optimal)"
        case .acceptable:
            return "Acceptable Alignment - Minor Phase Offset"
        case .largeOffset:
            return "Large Phase Offset - Try Inverting Tweeter Polarity or Adjusting Fx"
        }
    }
}

/// Result of Nelder-Mead All-Pass Filter Phase Alignment Optimization.
public struct AllpassOptimizationResult: Codable, Sendable {
    public let f0: Double
    public let q: Double
    public let rmsErrorDeg: Double
    public let maxDeltaErrorDeg: Double
    public let isGoalAchieved: Bool
    public let alignmentStatus: PhaseAlignmentStatus
    public let warnings: [String]

    public init(
        f0: Double,
        q: Double,
        rmsErrorDeg: Double,
        maxDeltaErrorDeg: Double,
        isGoalAchieved: Bool,
        alignmentStatus: PhaseAlignmentStatus? = nil,
        warnings: [String] = []
    ) {
        self.f0 = f0
        self.q = q
        self.rmsErrorDeg = rmsErrorDeg
        self.maxDeltaErrorDeg = maxDeltaErrorDeg
        self.isGoalAchieved = isGoalAchieved
        self.alignmentStatus = alignmentStatus ?? PhaseAlignmentStatus.from(rmsErrorDeg: rmsErrorDeg)
        self.warnings = warnings
    }
}

/// Iterative 2D Nelder-Mead Simplex Optimizer for woofer All-Pass Filter (APF).
///
/// Goal: Keep the tweeter phase curve fixed (including datasheet curve & acoustic delay).
/// Tweak F0 and Q of the woofer's 2nd-order APF transfer function until phase traces run
/// parallel through the crossover zone [fx/2, 2*fx], minimizing the sum of squared errors
/// around the mean unwrapped phase difference.
public enum AllpassFilterOptimizer {

    public static func optimize(
        driver: CoaxialDriver,
        cabinet: SealedCabinet,
        crossover: CrossoverNetwork,
        sampleCount: Int = 31,
        maxIterations: Int = 150
    ) -> AllpassOptimizationResult {
        let fx = crossover.acousticCenterFrequency
        let fLow = max(20.0, min(crossover.actualWooferFrequency, crossover.actualTweeterFrequency) / 2.0)
        let fHigh = min(20000.0, max(crossover.actualWooferFrequency, crossover.actualTweeterFrequency) * 2.0)

        // Ensure phase is available for custom/digitized driver curves
        let rawWooferCurve = (driver.hasCustomWooferCurve && !driver.wooferAcousticCurve.isEmpty)
            ? driver.wooferAcousticCurve
            : (driver.wooferAcousticCurve.isEmpty ? CoaxialDriver.generateSyntheticWooferCurve(ts: driver.wooferTS) : driver.wooferAcousticCurve)
        let rawTweeterCurve = (driver.hasCustomTweeterCurve && !driver.tweeterAcousticCurve.isEmpty)
            ? driver.tweeterAcousticCurve
            : (driver.tweeterAcousticCurve.isEmpty ? CoaxialDriver.generateSyntheticTweeterCurve(tw: driver.tweeter) : driver.tweeterAcousticCurve)

        let wooferAcousticP = driver.hasCustomWooferCurve ? ensurePhase(curve: rawWooferCurve) : rawWooferCurve
        let tweeterAcousticP = driver.hasCustomTweeterCurve ? ensurePhase(curve: rawTweeterCurve) : rawTweeterCurve

        // Generate logarithmic frequency test grid in [fLow, fHigh]
        var freqs: [Double] = []
        freqs.reserveCapacity(sampleCount)
        let logLow = log(fLow)
        let logHigh = log(fHigh)
        let logStep = (logHigh - logLow) / Double(max(sampleCount - 1, 1))

        for i in 0..<sampleCount {
            freqs.append(exp(logLow + Double(i) * logStep))
        }

        // Precompute fixed Tweeter complex pressure and fixed Woofer base pressure (before APF)
        var pTweeterFixed: [ComplexNumber] = []
        var pWooferBase: [ComplexNumber] = []
        pTweeterFixed.reserveCapacity(sampleCount)
        pWooferBase.reserveCapacity(sampleCount)

        for f in freqs {
            let pTwRaw = interpolateAcousticPressure(freq: f, curve: tweeterAcousticP)
            let hHP = crossover.tweeterFilterTransferFunction(frequency: f)
            let hLpadCD = crossover.tweeterLPadAndCDHornTransferFunction(frequency: f, tweeterRe: driver.tweeter.re)
            let hDelay = crossover.tweeterAcousticDelayFactor(frequency: f)
            pTweeterFixed.append(pTwRaw * hHP * hLpadCD * hDelay)

            let pWfRaw = interpolateAcousticPressure(freq: f, curve: wooferAcousticP)
            let hCab = cabinet.transferFunction(frequency: f, ts: driver.wooferTS)
            let hLP = crossover.wooferFilterTransferFunction(frequency: f)
            pWooferBase.append(pWfRaw * hCab * hLP)
        }

        // Cost function: sum of squared in-phase alignment errors (wrapped to [-180°, +180°] around 0° coherent target)
        // Directly reflects tweeter polarity (+180° inversion) as well as acoustic delay and filter phase slopes.
        func evaluateCost(f0: Double, q: Double) -> Double {
            if f0 < 0.1 * fx || f0 > 10.0 * fx || q < 0.05 || q > 25.0 {
                return 1e8
            }

            var sse = 0.0

            for i in 0..<sampleCount {
                let f = freqs[i]
                let x = f / f0
                let num = ComplexNumber(real: 1.0 - x * x, imag: -x / q)
                let denom = ComplexNumber(real: 1.0 - x * x, imag: x / q)
                let hAP = num / denom

                let pWooferFinal = pWooferBase[i] * hAP
                let wPhase = pWooferFinal.phaseDegrees
                let tPhase = pTweeterFixed[i].phaseDegrees
                var delta = wPhase - tPhase
                while delta > 180.0 { delta -= 360.0 }
                while delta < -180.0 { delta += 360.0 }
                sse += delta * delta
            }

            return sse
        }

        // Initial guesses for F0 and Q (multi-start Nelder-Mead simplex across crossover region)
        let tau = (crossover.acousticCenterOffsetMM / 1000.0) / 343.0
        let qInit = max(0.5, min(2.5, 2.0 / (2.0 * .pi * fx * max(tau, 1e-6))))
        let f0Init = fx

        // Nelder-Mead 2D Simplex Initialization
        struct SimplexPoint {
            var f0: Double
            var q: Double
            var cost: Double
        }

        let seedCandidates: [(f0: Double, q: Double)] = [
            (fx * 0.4, 0.35),
            (fx * 0.7, qInit),
            (f0Init, qInit),
            (fx * 1.5, qInit),
            (fx * 2.4, 0.6)
        ]

        let alpha = 1.0  // Reflection
        let gamma = 2.0  // Expansion
        let rho = 0.5    // Contraction
        let sigma = 0.5  // Shrink

        var globalOptimal = SimplexPoint(f0: f0Init, q: qInit, cost: evaluateCost(f0: f0Init, q: qInit))

        for seed in seedCandidates {
            var s: [SimplexPoint] = [
                SimplexPoint(f0: seed.f0, q: seed.q, cost: evaluateCost(f0: seed.f0, q: seed.q)),
                SimplexPoint(f0: seed.f0 * 1.2, q: seed.q, cost: evaluateCost(f0: seed.f0 * 1.2, q: seed.q)),
                SimplexPoint(f0: seed.f0, q: seed.q * 1.25, cost: evaluateCost(f0: seed.f0, q: seed.q * 1.25))
            ]

            for _ in 0..<maxIterations {
                s.sort { $0.cost < $1.cost }

                let best = s[0]
                let worst = s[2]

                // Check convergence
                let costDiff = abs(worst.cost - best.cost)
                let f0Span = abs(worst.f0 - best.f0) / max(best.f0, 1.0)
                let qSpan = abs(worst.q - best.q) / max(best.q, 0.1)

                if costDiff < 1e-5 && f0Span < 1e-4 && qSpan < 1e-4 {
                    break
                }

                // Centroid of best two points
                let cF0 = (s[0].f0 + s[1].f0) / 2.0
                let cQ = (s[0].q + s[1].q) / 2.0

                // 1. Reflection
                let xrF0 = cF0 + alpha * (cF0 - worst.f0)
                let xrQ = cQ + alpha * (cQ - worst.q)
                let xrCost = evaluateCost(f0: xrF0, q: xrQ)

                if xrCost < s[1].cost && xrCost >= s[0].cost {
                    s[2] = SimplexPoint(f0: xrF0, q: xrQ, cost: xrCost)
                    continue
                }

                // 2. Expansion
                if xrCost < s[0].cost {
                    let xeF0 = cF0 + gamma * (xrF0 - cF0)
                    let xeQ = cQ + gamma * (xrQ - cQ)
                    let xeCost = evaluateCost(f0: xeF0, q: xeQ)

                    if xeCost < xrCost {
                        s[2] = SimplexPoint(f0: xeF0, q: xeQ, cost: xeCost)
                    } else {
                        s[2] = SimplexPoint(f0: xrF0, q: xrQ, cost: xrCost)
                    }
                    continue
                }

                // 3. Contraction
                if xrCost < worst.cost {
                    // Outside contraction
                    let xcF0 = cF0 + rho * (xrF0 - cF0)
                    let xcQ = cQ + rho * (xrQ - cQ)
                    let xcCost = evaluateCost(f0: xcF0, q: xcQ)
                    if xcCost < xrCost {
                        s[2] = SimplexPoint(f0: xcF0, q: xcQ, cost: xcCost)
                        continue
                    }
                } else {
                    // Inside contraction
                    let xcF0 = cF0 - rho * (cF0 - worst.f0)
                    let xcQ = cQ - rho * (cQ - worst.q)
                    let xcCost = evaluateCost(f0: xcF0, q: xcQ)
                    if xcCost < worst.cost {
                        s[2] = SimplexPoint(f0: xcF0, q: xcQ, cost: xcCost)
                        continue
                    }
                }

                // 4. Shrink
                for i in 1...2 {
                    let sf0 = s[0].f0 + sigma * (s[i].f0 - s[0].f0)
                    let sq = s[0].q + sigma * (s[i].q - s[0].q)
                    s[i] = SimplexPoint(f0: sf0, q: sq, cost: evaluateCost(f0: sf0, q: sq))
                }
            }

            s.sort { $0.cost < $1.cost }
            if s[0].cost < globalOptimal.cost {
                globalOptimal = s[0]
            }
        }

        let optimal = globalOptimal

        // Compute final statistics across window (if acoustic delay is 0, no all-pass delay filter is applied)
        let finalSSE: Double
        if crossover.acousticCenterOffsetMM <= 0 {
            var uncompSSE = 0.0
            for i in 0..<sampleCount {
                var d = pWooferBase[i].phaseDegrees - pTweeterFixed[i].phaseDegrees
                while d > 180.0 { d -= 360.0 }
                while d < -180.0 { d += 360.0 }
                uncompSSE += d * d
            }
            finalSSE = uncompSSE
        } else {
            finalSSE = optimal.cost
        }
        let rmsErrorDeg = sqrt(finalSSE / Double(sampleCount))

        // Compute peak-to-peak phase delta error across window
        var deltas: [Double] = []
        for i in 0..<sampleCount {
            let f = freqs[i]
            let x = f / optimal.f0
            let num = ComplexNumber(real: 1.0 - x * x, imag: -x / optimal.q)
            let denom = ComplexNumber(real: 1.0 - x * x, imag: x / optimal.q)
            let hAP = num / denom
            let pWooferFinal = pWooferBase[i] * hAP
            deltas.append(pWooferFinal.phaseDegrees - pTweeterFixed[i].phaseDegrees)
        }
        for i in 1..<sampleCount {
            while deltas[i] - deltas[i - 1] > 180.0 { deltas[i] -= 360.0 }
            while deltas[i] - deltas[i - 1] < -180.0 { deltas[i] += 360.0 }
        }
        let maxDelta = deltas.max() ?? 0.0
        let minDelta = deltas.min() ?? 0.0
        let peakToPeakError = maxDelta - minDelta

        var warnings: [String] = []

        // 3-Tier RMS Phase Alignment logic:
        // Green (<= 10.0°): "Phase Aligned (Optimal)"
        // Yellow (10.0° - 20.0°): "Acceptable Alignment - Minor Phase Offset"
        // Red (> 20.0°): "Large Phase Offset - Try Inverting Tweeter Polarity or Adjusting Fx"
        let alignmentStatus = PhaseAlignmentStatus.from(rmsErrorDeg: rmsErrorDeg)
        let isGoalAchieved = rmsErrorDeg <= 10.0

        if crossover.enableAllpassFilter && !crossover.enableZobelNetwork {
            warnings.append("All-Pass Filter Warning: Zobel impedance compensation network is disabled. All-pass delay compensation requires resistive woofer voice-coil termination to prevent inductive filter detuning.")
        }

        return AllpassOptimizationResult(
            f0: optimal.f0,
            q: optimal.q,
            rmsErrorDeg: rmsErrorDeg,
            maxDeltaErrorDeg: peakToPeakError,
            isGoalAchieved: isGoalAchieved,
            alignmentStatus: alignmentStatus,
            warnings: warnings
        )
    }

    private static func ensurePhase(curve: [ResponseDataPoint]) -> [ResponseDataPoint] {
        if curve.isEmpty { return [] }
        let hasNonZeroPhase = curve.contains(where: { abs($0.phase) > 0.01 })
        if hasNonZeroPhase { return curve }
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
            let p2 = curve[i + 1]
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

    /// Evaluates the uncompensated RMS phase alignment error (in degrees) across the 2-octave crossover handover band
    /// when the All-Pass filter is disabled (`H_AP(f) = 1.0`).
    public static func evaluateUncompensatedRMSError(
        driver: CoaxialDriver,
        cabinet: SealedCabinet,
        crossover: CrossoverNetwork,
        sampleCount: Int = 31
    ) -> Double {
        let fLow = max(20.0, min(crossover.actualWooferFrequency, crossover.actualTweeterFrequency) / 2.0)
        let fHigh = min(20000.0, max(crossover.actualWooferFrequency, crossover.actualTweeterFrequency) * 2.0)

        let rawWooferCurve = (driver.hasCustomWooferCurve && !driver.wooferAcousticCurve.isEmpty)
            ? driver.wooferAcousticCurve
            : (driver.wooferAcousticCurve.isEmpty ? CoaxialDriver.generateSyntheticWooferCurve(ts: driver.wooferTS) : driver.wooferAcousticCurve)
        let rawTweeterCurve = (driver.hasCustomTweeterCurve && !driver.tweeterAcousticCurve.isEmpty)
            ? driver.tweeterAcousticCurve
            : (driver.tweeterAcousticCurve.isEmpty ? CoaxialDriver.generateSyntheticTweeterCurve(tw: driver.tweeter) : driver.tweeterAcousticCurve)

        let wooferAcousticP = driver.hasCustomWooferCurve ? ensurePhase(curve: rawWooferCurve) : rawWooferCurve
        let tweeterAcousticP = driver.hasCustomTweeterCurve ? ensurePhase(curve: rawTweeterCurve) : rawTweeterCurve

        let logLow = log(fLow)
        let logHigh = log(fHigh)
        let logStep = (logHigh - logLow) / Double(max(sampleCount - 1, 1))

        var sse = 0.0
        for i in 0..<sampleCount {
            let f = exp(logLow + Double(i) * logStep)
            let pTwRaw = interpolateAcousticPressure(freq: f, curve: tweeterAcousticP)
            let hHP = crossover.tweeterFilterTransferFunction(frequency: f)
            let hLpadCD = crossover.tweeterLPadAndCDHornTransferFunction(frequency: f, tweeterRe: driver.tweeter.re)
            let hDelay = crossover.tweeterAcousticDelayFactor(frequency: f)
            let pTweeter = pTwRaw * hHP * hLpadCD * hDelay

            let pWfRaw = interpolateAcousticPressure(freq: f, curve: wooferAcousticP)
            let hCab = cabinet.transferFunction(frequency: f, ts: driver.wooferTS)
            let hLP = crossover.wooferFilterTransferFunction(frequency: f)
            let pWoofer = pWfRaw * hCab * hLP

            var delta = pWoofer.phaseDegrees - pTweeter.phaseDegrees
            while delta > 180.0 { delta -= 360.0 }
            while delta < -180.0 { delta += 360.0 }
            sse += delta * delta
        }

        return sqrt(sse / Double(max(sampleCount, 1)))
    }
}
