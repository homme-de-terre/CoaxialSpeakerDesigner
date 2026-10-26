import XCTest
@testable import CoaxialSpeakerDesigner

final class CoaxialSpeakerDesignerTests: XCTestCase {

    func testComplexNumberArithmetic() {
        let z1 = ComplexNumber(real: 3.0, imag: 4.0)
        XCTAssertEqual(z1.magnitude, 5.0, accuracy: 1e-6)
        XCTAssertEqual(z1.phaseDegrees, 53.130102, accuracy: 1e-4)

        let z2 = ComplexNumber(real: 1.0, imag: -2.0)
        let sum = z1 + z2
        XCTAssertEqual(sum.real, 4.0)
        XCTAssertEqual(sum.imag, 2.0)

        let prod = z1 * z2 // (3+4j)(1-2j) = 3 - 6j + 4j - 8j^2 = 11 - 2j
        XCTAssertEqual(prod.real, 11.0)
        XCTAssertEqual(prod.imag, -2.0)
    }

    func testSealedCabinetCalculations() {
        var ts = WooferTSParameters()
        ts.fs = 40.0
        ts.qts = 0.25
        ts.vas = 178.0

        let cabinet = SealedCabinet(alignment: .butterworth)
        let fc = cabinet.computedResonanceFc(for: ts)
        let alpha = cabinet.computedComplianceAlpha(for: ts)
        let vb = cabinet.computedVolumeLiters(for: ts)
        let f3 = cabinet.actualF3(for: ts)
        let qtc = cabinet.actualQtc(for: ts)

        XCTAssertEqual(qtc, 0.7071, accuracy: 0.01)
        XCTAssertEqual(fc, 113.14, accuracy: 0.5)
        XCTAssertEqual(f3, 113.14, accuracy: 0.5)
        XCTAssertEqual(alpha, 7.0, accuracy: 0.1)
        XCTAssertEqual(vb, 25.43, accuracy: 0.5)

        // Transfer function at resonance frequency Fc should have magnitude ~ Qtc = 0.707
        let hFc = cabinet.transferFunction(frequency: fc, ts: ts)
        XCTAssertEqual(hFc.magnitude, cabinet.actualQtc(for: ts), accuracy: 0.1)
    }

    func testCrossoverComponents() {
        let crossover = CrossoverNetwork(
            crossoverFrequency: 2000.0,
            wooferOrder: .secondOrderLR,
            tweeterOrder: .secondOrderLR,
            enableZobelNetwork: true,
            enableLPadAttenuator: true,
            userTargetAttenuationdB: 6.0
        )

        let comp = crossover.computeComponentValues(wooferRe: 6.0, tweeterRe: 6.0, wooferLe: 0.8)

        XCTAssertNotNil(comp.L1_mH)
        XCTAssertNotNil(comp.C1_uF)
        XCTAssertNotNil(comp.C_HP1_uF)
        XCTAssertNotNil(comp.L_HP1_mH)
        XCTAssertNotNil(comp.R_zobel_ohms)
        XCTAssertNotNil(comp.C_zobel_uF)
        XCTAssertNotNil(comp.R1_lpad_ohms)
        XCTAssertNotNil(comp.R2_lpad_ohms)

        // 6 dB attenuation L-Pad on 6 Ohm driver => R1 ~ 3 Ohms, R2 ~ 6 Ohms
        XCTAssertEqual(comp.R1_lpad_ohms!, 3.0, accuracy: 0.2)
        XCTAssertEqual(comp.R2_lpad_ohms!, 6.0, accuracy: 0.3)
    }

    func testSimulationEngine() {
        let driver = CoaxialDriver.defaultSampleDriver
        let cabinet = SealedCabinet()
        let crossover = CrossoverNetwork()

        let points = SimulationEngine.simulate(
            driver: driver,
            cabinet: cabinet,
            crossover: crossover,
            stepCount: 50
        )

        XCTAssertEqual(points.count, 51)
        XCTAssertEqual(points.first?.frequency, 20.0, accuracy: 0.1)
        XCTAssertEqual(points.last?.frequency, 20000.0, accuracy: 1.0)

        // Total system SPL should be reasonable in passband (70 dB to 100 dB)
        let midPoint = points[points.count / 2]
        XCTAssertGreaterThan(midPoint.totalSystemSPL, 70.0)
        XCTAssertLessThan(midPoint.totalSystemSPL, 105.0)
    }

    func testDatasheetRegexParser() {
        let parser = DatasheetParser()
        let sampleText = """
        8CX21 COAXIAL LOUDSPEAKER
        Fs = 48.5 Hz
        Qes = 0.38
        Qms = 5.2
        Vas = 26.4 L
        Re = 6.1 Ohm
        Le = 0.75 mH
        Sensitivity = 91 dB
        """

        let ts = parser.parseTSFromText(sampleText)
        XCTAssertEqual(ts.fs, 48.5, accuracy: 0.1)
        XCTAssertEqual(ts.qes, 0.38, accuracy: 0.01)
        XCTAssertEqual(ts.qms, 5.2, accuracy: 0.1)
        XCTAssertEqual(ts.vas, 26.4, accuracy: 0.1)
        XCTAssertEqual(ts.re, 6.1, accuracy: 0.1)
        XCTAssertEqual(ts.le, 0.75, accuracy: 0.05)
        XCTAssertEqual(ts.spl, 91.0, accuracy: 0.1)
    }

    func testBCDatasheetTableParser() {
        let parser = DatasheetParser()
        let bcSampleText = """
        15CXN88
        100.0 dB
        106.0 dB
        40 Hz
        5.0 Ω
        0.26
        10.3
        0.25
        178.0 dm3
        855.0 cm2
        8.5 mm
        1.05 mH
        PARAMETERS
        Resonance Frequency
        Re
        Qes
        Qms
        Qts
        Vas
        Sd
        Xmax
        Le
        """

        let ts = parser.parseTSFromText(bcSampleText)
        XCTAssertEqual(ts.fs, 40.0, accuracy: 0.1)
        XCTAssertEqual(ts.qes, 0.26, accuracy: 0.01)
        XCTAssertEqual(ts.qms, 10.3, accuracy: 0.1)
        XCTAssertEqual(ts.qts, 0.25, accuracy: 0.01)
        XCTAssertEqual(ts.vas, 178.0, accuracy: 0.1)
        XCTAssertEqual(ts.re, 5.0, accuracy: 0.1)
        XCTAssertEqual(ts.le, 1.05, accuracy: 0.05)
        XCTAssertEqual(ts.spl, 100.0, accuracy: 0.1)

        let tw = parser.parseTweeterFromText(bcSampleText)
        XCTAssertEqual(tw.spl, 106.0, accuracy: 0.1)
    }

    func testParseDatasheetData() {
        let parser = DatasheetParser()
        let sampleText = """
        8CX21 COAXIAL LOUDSPEAKER
        Fs = 48.5 Hz
        Qes = 0.38
        Qms = 5.2
        Vas = 26.4 L
        Re = 6.1 Ohm
        Le = 0.75 mH
        Sensitivity = 91 dB
        """
        guard let data = sampleText.data(using: .utf8) else {
            XCTFail("Failed to encode sample text to data")
            return
        }
        let dummyURL = URL(fileURLWithPath: "/Users/test/Documents/8CX21_datasheet.pdf")
        let result = parser.parseDatasheetData(data, sourceURL: dummyURL)
        XCTAssertEqual(result.name, "8CX21")
        XCTAssertEqual(result.ts.fs, 48.5, accuracy: 0.1)
        XCTAssertEqual(result.ts.qes, 0.38, accuracy: 0.01)
        XCTAssertEqual(result.ts.qms, 5.2, accuracy: 0.1)
        XCTAssertEqual(result.ts.vas, 26.4, accuracy: 0.1)
        XCTAssertEqual(result.ts.re, 6.1, accuracy: 0.1)
        XCTAssertEqual(result.ts.le, 0.75, accuracy: 0.05)
        XCTAssertEqual(result.ts.spl, 91.0, accuracy: 0.1)
    }

    func testBeymaDatasheetTableParser() {
        let parser = DatasheetParser()
        let beymaSampleText = """
        TECHNICAL SPECIFICATIONS
        Sensitivity (LF/HF) 99 dB / 105 dB
        Recom. HF crossover 1,5 kHz or higher (12 dB/oct min slope)
        DIMENSION DRAWINGS
        Resonant frequency, fs 38 Hz
        D.C. Voice coil resistance, Re 6,7 Ω
        Mechanical Quality Factor, Qms 6,4
        Electrical Quality Factor, Qes 0,31
        Total Quality Factor, Qts 0,30
        Equivalent Air Volume to Cms, Vas 238 l
        Effective Surface Area, Sd 0,088 m 2
        Maximum Displacement, Xmax 6 mm
        Voice Coil Inductance, Le @ 1 kHz 1 mH
        15XA38Nd COAXIAL TRANSDUCER
        """
        guard let data = beymaSampleText.data(using: .utf8) else {
            XCTFail("Failed to encode beyma sample text")
            return
        }
        let dummyURL = URL(fileURLWithPath: "/tmp/beyma-speakers-data-sheet-coaxial-15XA38Nd.pdf")
        let result = parser.parseDatasheetData(data, sourceURL: dummyURL)
        XCTAssertEqual(result.name, "15XA38Nd")
        XCTAssertEqual(result.ts.fs, 38.0, accuracy: 0.1)
        XCTAssertEqual(result.ts.qes, 0.31, accuracy: 0.01)
        XCTAssertEqual(result.ts.qms, 6.4, accuracy: 0.1)
        XCTAssertEqual(result.ts.qts, 0.30, accuracy: 0.01)
        XCTAssertEqual(result.ts.vas, 238.0, accuracy: 0.1)
        XCTAssertEqual(result.ts.re, 6.7, accuracy: 0.1)
        XCTAssertEqual(result.ts.sd, 880.0, accuracy: 5.0)
        XCTAssertEqual(result.ts.xmax, 6.0, accuracy: 0.1)
        XCTAssertEqual(result.ts.spl, 99.0, accuracy: 0.1)
        XCTAssertEqual(result.tweeter.spl, 105.0, accuracy: 0.1)
        XCTAssertEqual(result.recommendedCrossover, 1500.0, accuracy: 1.0)
        XCTAssertTrue(result.missingParams.isEmpty)
        XCTAssertTrue(result.warnings.isEmpty)
    }

    func testStepResponseComputation() {
        let driver = CoaxialDriver.defaultSampleDriver
        let cabinet = SealedCabinet()
        let crossover = CrossoverNetwork(crossoverFrequency: 1500.0, acousticCenterOffsetMM: 35.0)

        let stepPoints = SimulationEngine.computeStepResponse(driver: driver, cabinet: cabinet, crossover: crossover)
        XCTAssertFalse(stepPoints.isEmpty)
        XCTAssertEqual(stepPoints.count, 201)

        if let first = stepPoints.first {
            XCTAssertEqual(first.timeMs, 0.0, accuracy: 0.001)
            XCTAssertLessThan(abs(first.total), 0.25)
        }

        let maxTotal = stepPoints.map { abs($0.total) }.max() ?? 0.0
        XCTAssertGreaterThan(maxTotal, 0.5)

        var invertedCrossover = crossover
        invertedCrossover.invertTweeterPolarity = true
        let invertedStep = SimulationEngine.computeStepResponse(driver: driver, cabinet: cabinet, crossover: invertedCrossover)
        XCTAssertFalse(invertedStep.isEmpty)
    }

    func testAllpassFilterPhaseAndDelay() {
        var crossover = CrossoverNetwork(crossoverFrequency: 1500.0, acousticCenterOffsetMM: 35.0)
        crossover.enableAllpassFilter = true

        // Magnitude must be strictly 1.0 (0 dB) across all frequencies
        for f in [100.0, 500.0, 1000.0, 1500.0, 3000.0, 10000.0] {
            let hAP = crossover.allpassFilterTransferFunction(frequency: f)
            XCTAssertEqual(hAP.magnitude, 1.0, accuracy: 1e-6, "All-pass magnitude must be 1.0 at \(f) Hz")
        }

        // At crossover frequency (1500 Hz), phase shift must be -180 deg
        let hAtXo = crossover.allpassFilterTransferFunction(frequency: 1500.0)
        XCTAssertEqual(abs(hAtXo.phaseDegrees), 180.0, accuracy: 2.0)

        // Check component values
        let comp = crossover.computeComponentValues(wooferRe: 6.0, tweeterRe: 6.0, wooferLe: 0.8)
        XCTAssertNotNil(comp.L_AP_mH)
        XCTAssertNotNil(comp.C_AP_uF)
        XCTAssertGreaterThan(comp.L_AP_mH ?? 0, 0)
        XCTAssertGreaterThan(comp.C_AP_uF ?? 0, 0)
    }

    func testNelderMeadAllpassOptimizerConvergence() {
        let driver = CoaxialDriver.defaultSampleDriver
        let cabinet = SealedCabinet()
        var crossover = CrossoverNetwork(
            crossoverFrequency: 2200.0,
            wooferOrder: .secondOrderLR,
            tweeterOrder: .secondOrderLR,
            enableZobelNetwork: true,
            acousticCenterOffsetMM: 30.0,
            enableAllpassFilter: true
        )

        let result = AllpassFilterOptimizer.optimize(
            driver: driver,
            cabinet: cabinet,
            crossover: crossover,
            sampleCount: 31,
            maxIterations: 150
        )

        // F0 should be in the vicinity of the crossover region
        XCTAssertGreaterThan(result.f0, 500.0)
        XCTAssertLessThan(result.f0, 8000.0)

        // Q should be well-behaved
        XCTAssertGreaterThan(result.q, 0.1)
        XCTAssertLessThan(result.q, 10.0)

        // Residual RMS phase deviation across the 2-octave crossover window should be low
        XCTAssertLessThan(result.rmsErrorDeg, 8.0, "Optimizer should converge to parallel phase traces (RMS < 8 deg)")
        XCTAssertTrue(result.isGoalAchieved)

        // Component values generated from optimized parameters
        crossover.allpassOptimizedF0 = result.f0
        crossover.allpassOptimizedQ = result.q
        let comp = crossover.computeComponentValues(wooferRe: driver.wooferTS.re, tweeterRe: driver.tweeter.re, wooferLe: driver.wooferTS.le)
        XCTAssertNotNil(comp.L_AP_mH)
        XCTAssertNotNil(comp.C_AP_uF)
        XCTAssertGreaterThan(comp.L_AP_mH!, 0.05)
        XCTAssertGreaterThan(comp.C_AP_uF!, 0.1)
    }

    func testAllpassWarnings() {
        let driver = CoaxialDriver.defaultSampleDriver
        let cabinet = SealedCabinet()

        // 1. Warning when APF is enabled but Zobel is disabled
        var noZobelCrossover = CrossoverNetwork(
            crossoverFrequency: 2000.0,
            enableZobelNetwork: false,
            acousticCenterOffsetMM: 25.0,
            enableAllpassFilter: true
        )
        let optResultNoZobel = AllpassFilterOptimizer.optimize(
            driver: driver,
            cabinet: cabinet,
            crossover: noZobelCrossover
        )
        let hasZobelWarning = optResultNoZobel.warnings.contains(where: { $0.contains("Zobel") })
        XCTAssertTrue(hasZobelWarning, "Should issue warning if APF is enabled without Zobel network")

        // 2. Warning in MainDesignerViewModel validateParameters
        noZobelCrossover.allpassWarnings = optResultNoZobel.warnings
        let vm = MainDesignerViewModel(driver: driver, cabinet: cabinet, crossover: noZobelCrossover)
        XCTAssertTrue(vm.plausibilityWarnings.contains(where: { $0.contains("Zobel") }))
    }

    func testTwoPagePDFExportData() {
        let driver = CoaxialDriver.defaultSampleDriver
        let cabinet = SealedCabinet()
        var crossover = CrossoverNetwork(
            crossoverFrequency: 1800.0,
            enableZobelNetwork: true,
            acousticCenterOffsetMM: 35.0,
            enableAllpassFilter: true
        )
        let opt = AllpassFilterOptimizer.optimize(driver: driver, cabinet: cabinet, crossover: crossover)
        crossover.allpassOptimizedF0 = opt.f0
        crossover.allpassOptimizedQ = opt.q
        crossover.allpassOptimizationErrorDeg = opt.rmsErrorDeg
        crossover.allpassOptimizationAchieved = opt.isGoalAchieved
        crossover.allpassWarnings = opt.warnings

        let components = crossover.computeComponentValues(
            wooferRe: driver.wooferTS.re,
            tweeterRe: driver.tweeter.re,
            wooferLe: driver.wooferTS.le
        )

        let pdfData = PDFExporter.generateSchematicPDF(
            driver: driver,
            cabinet: cabinet,
            crossover: crossover,
            components: components
        )

        XCTAssertFalse(pdfData.isEmpty)
        // Check standard PDF header signature "%PDF"
        let headerPrefix = String(data: pdfData.prefix(4), encoding: .ascii)
        XCTAssertEqual(headerPrefix, "%PDF")
    }

    func testStepResponseProperties() {
        let driver = CoaxialDriver.defaultSampleDriver
        let cabinet = SealedCabinet()
        let crossover = CrossoverNetwork(crossoverFrequency: 2000.0, acousticCenterOffsetMM: 25.0)

        let points = SimulationEngine.computeStepResponse(driver: driver, cabinet: cabinet, crossover: crossover, durationMs: 6.0)
        XCTAssertEqual(points.count, 201)

        // At t=0 ms, response should start near 0
        XCTAssertEqual(points[0].timeMs, 0.0)
        XCTAssertLessThan(abs(points[0].total), 0.2)

        // Peak normalized to 1.0 (or within normal acoustic overshoot bounds)
        let maxAbs = points.map { abs($0.total) }.max() ?? 0.0
        XCTAssertGreaterThanOrEqual(maxAbs, 0.8)
        XCTAssertLessThanOrEqual(maxAbs, 1.25)
    }

    func testPhaseUnwrappingAlgorithm() {
        // 1. Synthetic phase wrap jump test
        let wrappedInput = [160.0, 175.0, -170.0, -155.0]
        let unwrapped = SimulationEngine.unwrapPhase(phases: wrappedInput)
        XCTAssertEqual(unwrapped[0], 160.0, accuracy: 1e-4)
        XCTAssertEqual(unwrapped[1], 175.0, accuracy: 1e-4)
        XCTAssertEqual(unwrapped[2], 190.0, accuracy: 1e-4)
        XCTAssertEqual(unwrapped[3], 205.0, accuracy: 1e-4)

        // 2. Full simulation unwrapped tweeter phase test
        let driver = CoaxialDriver.defaultSampleDriver
        let cabinet = SealedCabinet()
        let crossover = CrossoverNetwork(crossoverFrequency: 2200.0, acousticCenterOffsetMM: 35.0)

        let points = SimulationEngine.simulate(driver: driver, cabinet: cabinet, crossover: crossover)
        XCTAssertEqual(points.count, 201)

        // At low frequencies (20 Hz), tweeter unwrapped phase starts near +180 deg
        XCTAssertGreaterThan(points[0].tweeterUnwrappedPhaseDeg, 150.0)

        // At 20 kHz, due to 35mm acoustic center delay, unwrapped phase reaches ~ -720 deg
        let lastPt = points.last!
        XCTAssertLessThan(lastPt.tweeterUnwrappedPhaseDeg, -600.0)

        // Check continuity: adjacent unwrapped points must never jump by more than 45 degrees
        for i in 1..<points.count {
            let step = abs(points[i].tweeterUnwrappedPhaseDeg - points[i - 1].tweeterUnwrappedPhaseDeg)
            XCTAssertLessThan(step, 45.0, "Unwrapped phase must be smooth and continuous at point \(i)")
        }
    }

    func testDelayCompensatedPhase() {
        let driver = CoaxialDriver.defaultSampleDriver
        let cabinet = SealedCabinet()
        let crossover = CrossoverNetwork(crossoverFrequency: 2200.0, acousticCenterOffsetMM: 35.0)

        let points = SimulationEngine.simulate(driver: driver, cabinet: cabinet, crossover: crossover)

        // High frequency (20 kHz) delay-compensated phase should be near 0° in passband (not -720°)
        let hfPoint = points.last!
        XCTAssertEqual(hfPoint.tweeterDelayCompensatedPhaseDeg, 0.0, accuracy: 25.0, "HF delay-compensated phase should be near 0 deg")
        XCTAssertLessThan(abs(hfPoint.tweeterDelayCompensatedPhaseDeg), 45.0)

        // Low frequency (20 Hz) delay-compensated phase should approach 180° for 2nd order HP filter
        let lfPoint = points.first!
        XCTAssertEqual(abs(lfPoint.tweeterDelayCompensatedPhaseDeg), 180.0, accuracy: 10.0)
    }

    func testGroupDelayCalculations() {
        let driver = CoaxialDriver.defaultSampleDriver
        let cabinet = SealedCabinet()
        let crossover = CrossoverNetwork(crossoverFrequency: 2000.0, acousticCenterOffsetMM: 35.0)

        let points = SimulationEngine.simulate(driver: driver, cabinet: cabinet, crossover: crossover)
        XCTAssertEqual(points.count, 201)

        // 1. All group delay values must be finite numbers
        for (i, p) in points.enumerated() {
            XCTAssertTrue(p.wooferGroupDelayMs.isFinite, "Woofer GD must be finite at point \(i)")
            XCTAssertTrue(p.tweeterGroupDelayMs.isFinite, "Tweeter GD must be finite at point \(i)")
            XCTAssertTrue(p.totalSystemGroupDelayMs.isFinite, "Total GD must be finite at point \(i)")
        }

        // 2. High frequency tweeter group delay converges to acoustic delay tau = d / c
        // d = 35mm => tau = 0.035 / 343 = 0.102 ms
        let expectedDelayMs = (35.0 / 1000.0) / 343.0 * 1000.0
        let hfPoint = points.last!
        XCTAssertEqual(hfPoint.tweeterGroupDelayMs, expectedDelayMs, accuracy: 0.02, "HF Tweeter GD must approach physical delay (0.102 ms)")

        // 3. Low frequency woofer group delay reflects closed box resonance (typically 3-10 ms)
        let lfPoint = points.first!
        XCTAssertGreaterThan(lfPoint.wooferGroupDelayMs, 2.5, "LF Woofer GD should reflect cabinet resonance delay")

        // 4. All-Pass Filter adds peak group delay on woofer branch around F0
        var apfCrossover = crossover
        apfCrossover.enableAllpassFilter = true
        let apfPoints = SimulationEngine.simulate(driver: driver, cabinet: cabinet, crossover: apfCrossover)

        // At crossover frequency 2000 Hz, APF woofer GD should be significantly higher than without APF
        let midIdx = apfPoints.count / 2
        XCTAssertGreaterThan(apfPoints[midIdx].wooferGroupDelayMs, points[midIdx].wooferGroupDelayMs)
    }

    func testIndependentCrossoverFrequencies() {
        var xo = CrossoverNetwork(crossoverFrequency: 2200.0)
        XCTAssertFalse(xo.enableIndependentFrequencies)
        XCTAssertEqual(xo.actualWooferFrequency, 2200.0)
        XCTAssertEqual(xo.actualTweeterFrequency, 2200.0)
        XCTAssertEqual(xo.acousticCenterFrequency, 2200.0, accuracy: 1e-4)

        // Enable independent cut-off frequencies: 1800 Hz (woofer LP) and 2400 Hz (tweeter HP)
        xo.enableIndependentFrequencies = true
        xo.wooferCrossoverFrequency = 1800.0
        xo.tweeterCrossoverFrequency = 2400.0

        XCTAssertEqual(xo.actualWooferFrequency, 1800.0)
        XCTAssertEqual(xo.actualTweeterFrequency, 2400.0)
        let expectedCenter = sqrt(1800.0 * 2400.0)
        XCTAssertEqual(xo.acousticCenterFrequency, expectedCenter, accuracy: 0.1)

        // Compute components with split cut-offs
        let compSplit = xo.computeComponentValues(wooferRe: 6.0, tweeterRe: 6.0, wooferLe: 0.8)

        // Compute components with unified 2200 Hz crossover
        var xoUnified = xo
        xoUnified.enableIndependentFrequencies = false
        let compUnified = xoUnified.computeComponentValues(wooferRe: 6.0, tweeterRe: 6.0, wooferLe: 0.8)

        // Lower woofer cut-off (1800 Hz vs 2200 Hz) -> larger series inductance L1 (L ~ 1/f)
        XCTAssertGreaterThan(compSplit.L1_mH!, compUnified.L1_mH!)

        // Higher tweeter cut-off (2400 Hz vs 2200 Hz) -> smaller series capacitance C_HP1 (C ~ 1/f)
        XCTAssertLessThan(compSplit.C_HP1_uF!, compUnified.C_HP1_uF!)
    }

    func testAPFOptimizerWithIndependentFrequencies() {
        let driver = CoaxialDriver.defaultSampleDriver
        let cabinet = SealedCabinet()
        var crossover = CrossoverNetwork(
            crossoverFrequency: 2200.0,
            acousticCenterOffsetMM: 35.0,
            enableAllpassFilter: true,
            enableIndependentFrequencies: true,
            wooferCrossoverFrequency: 1800.0,
            tweeterCrossoverFrequency: 2400.0
        )

        let result = AllpassFilterOptimizer.optimize(
            driver: driver,
            cabinet: cabinet,
            crossover: crossover,
            sampleCount: 31,
            maxIterations: 150
        )

        // Optimizer should achieve parallel phase alignment across the split crossover zone
        XCTAssertTrue(result.isGoalAchieved, "APF optimizer should achieve goal with independent cut-off frequencies")
        XCTAssertLessThan(result.rmsErrorDeg, 8.0, "Residual RMS error should be < 8.0 deg")

        // F0 should be in the acoustic handover region
        XCTAssertGreaterThan(result.f0, 800.0)
        XCTAssertLessThan(result.f0, 8000.0)
        XCTAssertGreaterThan(result.q, 0.1)
        XCTAssertLessThan(result.q, 10.0)
    }
}
