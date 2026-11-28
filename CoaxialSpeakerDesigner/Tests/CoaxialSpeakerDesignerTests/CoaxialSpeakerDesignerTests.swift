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

        // Test Target F3 mode:
        // 1. Feasible target F3 = 140 Hz for 150CX (Fs=71, Qts=0.37, minF3=135.7 Hz)
        var ts150 = WooferTSParameters()
        ts150.fs = 71.0
        ts150.qts = 0.37
        ts150.vas = 11.2

        var cabTargetF3 = SealedCabinet(alignment: .targetF3, targetF3: 140.0)
        let actF3_140 = cabTargetF3.actualF3(for: ts150)
        XCTAssertEqual(actF3_140, 140.0, accuracy: 0.2, "Feasible target f3 must match exact target 140 Hz")
        let h140 = cabTargetF3.transferFunction(frequency: 140.0, ts: ts150)
        XCTAssertEqual(h140.magnitude, 1.0 / sqrt(2.0), accuracy: 0.02, "Magnitude at f3 must be -3 dB (0.7071)")

        // 2. Unattainable target F3 = 45 Hz (below physical closed box limit of 135.7 Hz)
        cabTargetF3.targetF3 = 45.0
        let actF3_45 = cabTargetF3.actualF3(for: ts150)
        let fc_45 = cabTargetF3.computedResonanceFc(for: ts150)
        let qtc_45 = cabTargetF3.actualQtc(for: ts150)
        let vb_45 = cabTargetF3.computedVolumeLiters(for: ts150)

        // Must align to Butterworth B2 limit (Fc = 135.7 Hz, f3 = 135.7 Hz, Qtc = 0.7071, Vb = 4.22 L)
        // NOT the unphysical Fc = 84.1 Hz and f3 = 157.2 Hz!
        XCTAssertEqual(actF3_45, 135.7, accuracy: 0.5, "Unattainable target f3 must align to minimum physical limit (Butterworth 135.7 Hz)")
        XCTAssertEqual(fc_45, 135.7, accuracy: 0.5, "Fc must equal minimum physical limit (135.7 Hz)")
        XCTAssertEqual(qtc_45, 0.7071, accuracy: 0.02, "Qtc must align to Butterworth 0.7071")
        XCTAssertEqual(vb_45, 4.22, accuracy: 0.2, "Box volume must equal Butterworth 4.22 L")
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
            invertTweeterPolarity: true,
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
            invertTweeterPolarity: true,
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

        // Optimizer should achieve optimal in-phase alignment across the split crossover zone
        XCTAssertTrue(result.isGoalAchieved, "APF optimizer should achieve goal with independent cut-off frequencies")
        XCTAssertLessThan(result.rmsErrorDeg, 8.0, "Residual RMS error should be < 8.0 deg")

        // F0 should be in the acoustic handover region
        XCTAssertGreaterThan(result.f0, 800.0)
        XCTAssertLessThan(result.f0, 8000.0)
        XCTAssertGreaterThan(result.q, 0.1)
        XCTAssertLessThan(result.q, 10.0)
    }

    func testAltec604DatasheetParserAndDigitizedCurves() {
        // 1. Verify Altec 604-8K factory specs and digitized CLIO MLS curves
        let driver = Altec604Data.createDriver()
        XCTAssertEqual(driver.name, "Altec Lansing 604-8K")
        XCTAssertEqual(driver.manufacturer, "Altec Lansing")
        XCTAssertEqual(driver.wooferTS.fs, 24.0, accuracy: 0.1)
        XCTAssertEqual(driver.wooferTS.qes, 0.299, accuracy: 0.005)
        XCTAssertEqual(driver.wooferTS.qms, 7.07, accuracy: 0.01)
        XCTAssertEqual(driver.wooferTS.qts, 0.287, accuracy: 0.01)
        XCTAssertEqual(driver.wooferTS.vas, 510.0, accuracy: 0.1)
        XCTAssertEqual(driver.wooferTS.re, 6.4, accuracy: 0.1)
        XCTAssertEqual(driver.wooferTS.le, 1.0, accuracy: 0.05)
        XCTAssertEqual(driver.wooferTS.sd, 890.0, accuracy: 1.0)
        XCTAssertEqual(driver.wooferTS.xmax, 3.81, accuracy: 0.05)
        XCTAssertEqual(driver.wooferTS.spl, 98.0, accuracy: 0.5)

        XCTAssertEqual(driver.tweeter.fs, 1200.0, accuracy: 1.0)
        XCTAssertEqual(driver.tweeter.re, 6.5, accuracy: 0.1)
        XCTAssertEqual(driver.tweeter.le, 0.12, accuracy: 0.02)
        XCTAssertEqual(driver.tweeter.spl, 105.0, accuracy: 0.5)

        // 2. Digitized CLIO curve points verification
        XCTAssertEqual(driver.wooferAcousticCurve.count, 100)
        XCTAssertEqual(driver.tweeterAcousticCurve.count, 100)

        // Woofer passband peak around 200 Hz (~98.5 dB)
        let wf200 = driver.wooferAcousticCurve.first(where: { abs($0.frequency - 200.0) < 15.0 })
        XCTAssertNotNil(wf200)
        XCTAssertGreaterThan(wf200!.magnitude, 95.0)

        // Tweeter horn boost peak around 2.5-3 kHz (~104 dB)
        let tw3k = driver.tweeterAcousticCurve.first(where: { abs($0.frequency - 2800.0) < 200.0 })
        XCTAssertNotNil(tw3k)
        XCTAssertGreaterThan(tw3k!.magnitude, 100.0)

        // 3. Full acoustic simulation with Altec 604-8K
        let cabinet = SealedCabinet(alignment: .butterworth)
        let crossover = CrossoverNetwork(
            crossoverFrequency: 1500.0,
            wooferOrder: .secondOrderLR,
            tweeterOrder: .secondOrderLR,
            enableZobelNetwork: true,
            enableLPadAttenuator: true,
            userTargetAttenuationdB: 7.0,
            acousticCenterOffsetMM: 35.0,
            enableAllpassFilter: true
        )

        let points = SimulationEngine.simulate(driver: driver, cabinet: cabinet, crossover: crossover)
        XCTAssertEqual(points.count, 201)

        for p in points {
            XCTAssertTrue(p.totalSystemSPL.isFinite)
            XCTAssertTrue(p.wooferUnwrappedPhaseDeg.isFinite)
            XCTAssertTrue(p.tweeterUnwrappedPhaseDeg.isFinite)
            XCTAssertTrue(p.wooferGroupDelayMs.isFinite)
            XCTAssertTrue(p.tweeterGroupDelayMs.isFinite)
            XCTAssertTrue(p.totalSystemGroupDelayMs.isFinite)
        }

        // Passband SPL should be realistic (85-100 dB)
        let midSPL = points[points.count / 2].totalSystemSPL
        XCTAssertGreaterThan(midSPL, 85.0)
        XCTAssertLessThan(midSPL, 105.0)

        // 4. Test DatasheetParser on Altec text
        let parser = DatasheetParser()
        let altecSample = """
        Altec Lansing 604-8K
        604-8K - THIELE-SMALL PARAMETERS Woofer
        Free Air Resonance Fs: 24 Hz
        Equivalent Volume Compliance, Vas: 510 L
        Total Q Qts = 0.9287
        Mechanical Q, Qms = 7.07
        Electrical Q Qes = 0.299
        DC Resistance Re = 6.4 Ω
        Xmax = 3.81 mm
        Inductivity at 1kHz = 1mH
        Sensitivity = 98 dB
        Cone Area Sd = 890 cm²
        Tweeter
        Tweeter Fs = 1200Hz
        DC resistance Re = 6.5 Ω
        Inductivity at 1kHz = 0.12 mH
        Sensitivity = 105 dB
        Centered at 1500 Hz
        """
        guard let sampleData = altecSample.data(using: .utf8) else {
            XCTFail("Failed to encode altec sample")
            return
        }
        let dummyURL = URL(fileURLWithPath: "/work/Altec 604-8K.pdf")
        let parsed = parser.parseDatasheetData(sampleData, sourceURL: dummyURL)
        XCTAssertEqual(parsed.name, "Altec Lansing 604-8K")
        XCTAssertEqual(parsed.ts.fs, 24.0, accuracy: 0.1)
        XCTAssertEqual(parsed.ts.re, 6.4, accuracy: 0.1)
        XCTAssertEqual(parsed.ts.qes, 0.299, accuracy: 0.005)
        XCTAssertEqual(parsed.ts.qms, 7.07, accuracy: 0.01)
        XCTAssertEqual(parsed.ts.qts, 0.287, accuracy: 0.01)
        XCTAssertEqual(parsed.ts.le, 1.0, accuracy: 0.05)
        XCTAssertEqual(parsed.tweeter.fs, 1200.0, accuracy: 1.0)
        XCTAssertEqual(parsed.tweeter.re, 6.5, accuracy: 0.1)
        XCTAssertEqual(parsed.tweeter.le, 0.12, accuracy: 0.02)
        XCTAssertEqual(parsed.tweeter.spl, 105.0, accuracy: 0.5)
        XCTAssertEqual(parsed.recommendedCrossover, 1500.0, accuracy: 1.0)

        // 5. Test dynamic PDF digitization if PDF file is present on disk
        let pdfURL = URL(fileURLWithPath: "/work/Altec 604-8K.pdf")
        if let pdfData = try? Data(contentsOf: pdfURL) {
            let parsedPDF = parser.parseDatasheetData(pdfData, sourceURL: pdfURL)
            XCTAssertEqual(parsedPDF.name, "Altec Lansing 604-8K")
            XCTAssertEqual(parsedPDF.ts.fs, 24.0, accuracy: 0.1)
            XCTAssertEqual(parsedPDF.ts.re, 6.4, accuracy: 0.1)
            XCTAssertEqual(parsedPDF.ts.qts, 0.287, accuracy: 0.01)
            #if canImport(PDFKit) && canImport(AppKit)
            XCTAssertFalse(parsedPDF.wooferCurve.isEmpty, "Should dynamically digitize woofer curve from PDF")
            XCTAssertFalse(parsedPDF.tweeterCurve.isEmpty, "Should dynamically digitize tweeter curve from PDF")
            #endif
        }
    }

    func testClosedCabinetParameterChangesReflectedInAllPlots() {
        let driver = CoaxialDriver.defaultSampleDriver
        let crossover = CrossoverNetwork(crossoverFrequency: 1800.0)

        // 1. Compare small enclosure (Vb = 6 L) vs large enclosure (Vb = 80 L)
        var smallCab = SealedCabinet()
        smallCab.isManualVolumeOverride = true
        smallCab.manualNetVolumeLiters = 6.0

        var largeCab = SealedCabinet()
        largeCab.isManualVolumeOverride = true
        largeCab.manualNetVolumeLiters = 80.0

        let fcSmall = smallCab.computedResonanceFc(for: driver.wooferTS)
        let fcLarge = largeCab.computedResonanceFc(for: driver.wooferTS)
        let qtcSmall = smallCab.actualQtc(for: driver.wooferTS)
        let qtcLarge = largeCab.actualQtc(for: driver.wooferTS)

        XCTAssertGreaterThan(fcSmall, fcLarge, "Smaller cabinet must have higher system resonance Fc")
        XCTAssertGreaterThan(qtcSmall, qtcLarge, "Smaller cabinet must have higher system Q (Qtc)")

        let simSmall = SimulationEngine.simulate(driver: driver, cabinet: smallCab, crossover: crossover)
        let simLarge = SimulationEngine.simulate(driver: driver, cabinet: largeCab, crossover: crossover)

        XCTAssertEqual(simSmall.count, 201)
        XCTAssertEqual(simLarge.count, 201)

        // 1a. Amplitude Plot Reflection:
        // At low frequencies (e.g. around 30 Hz), larger cabinet should have significantly higher bass SPL
        let idx30Hz = simSmall.firstIndex(where: { abs($0.frequency - 30.0) < 5.0 })!
        XCTAssertGreaterThan(simLarge[idx30Hz].wooferFinalSPL, simSmall[idx30Hz].wooferFinalSPL + 5.0, "Larger cabinet must deliver higher bass SPL at 30 Hz")
        XCTAssertGreaterThan(simLarge[idx30Hz].totalSystemSPL, simSmall[idx30Hz].totalSystemSPL + 5.0, "Total system SPL must reflect cabinet bass extension")

        // 1b. Phase Plot Reflection:
        // At low frequencies, cabinet acoustic transfer function phase shifts with Fc
        let phaseDiffSmallVsLarge = abs(simSmall[idx30Hz].wooferPhaseDeg - simLarge[idx30Hz].wooferPhaseDeg)
        XCTAssertGreaterThan(phaseDiffSmallVsLarge, 10.0, "Woofer acoustic phase at 30 Hz must shift with cabinet volume")

        // 1c. Group Delay Plot Reflection:
        // Group delay peak shifts with Fc
        let gdSmall = simSmall[idx30Hz].wooferGroupDelayMs
        let gdLarge = simLarge[idx30Hz].wooferGroupDelayMs
        XCTAssertNotEqual(gdSmall, gdLarge, "Woofer group delay at low frequency must reflect cabinet volume")
        XCTAssertGreaterThan(gdLarge, gdSmall + 0.5, "Large cabinet (lower Fc) produces higher group delay at 30 Hz")

        // 1d. Impedance Plot Reflection:
        // Woofer voice coil impedance resonance peak must be at fcSmall for smallCab and fcLarge for largeCab
        let zPeakSmall = simSmall.max(by: { $0.wooferImpedanceMag < $1.wooferImpedanceMag })!
        let zPeakLarge = simLarge.max(by: { $0.wooferImpedanceMag < $1.wooferImpedanceMag })!
        XCTAssertGreaterThan(zPeakSmall.frequency, zPeakLarge.frequency, "Impedance resonance peak frequency must be higher for smaller cabinet")
        XCTAssertEqual(zPeakSmall.frequency, fcSmall, accuracy: 10.0, "Small cabinet impedance peak must occur near Fc")
        XCTAssertEqual(zPeakLarge.frequency, fcLarge, accuracy: 10.0, "Large cabinet impedance peak must occur near Fc")

        // 1e. Step Response Plot Reflection:
        // Step response transient decay and settling reflect cabinet Qtc and Fc
        let stepSmall = SimulationEngine.computeStepResponse(driver: driver, cabinet: smallCab, crossover: crossover)
        let stepLarge = SimulationEngine.computeStepResponse(driver: driver, cabinet: largeCab, crossover: crossover)

        XCTAssertEqual(stepSmall.count, 201)
        XCTAssertEqual(stepLarge.count, 201)

        // Compare woofer step values around 2.0 - 4.0 ms
        let wooferStepDiff = zip(stepSmall, stepLarge).map { abs($0.0.woofer - $0.1.woofer) }.reduce(0.0, +)
        XCTAssertGreaterThan(wooferStepDiff, 0.5, "Step response woofer transient must reflect cabinet parameters")

        // 2. Stuffing Absorption Reflection:
        // Comparing no stuffing vs heavy stuffing on same volume
        var cabUnfilled = smallCab
        cabUnfilled.stuffing = .none

        var cabStuffed = smallCab
        cabStuffed.stuffing = .heavy

        let fcUnfilled = cabUnfilled.computedResonanceFc(for: driver.wooferTS)
        let fcStuffed = cabStuffed.computedResonanceFc(for: driver.wooferTS)
        XCTAssertGreaterThan(fcUnfilled, fcStuffed, "Stuffing volume gain must lower effective resonance Fc")

        let simUnfilled = SimulationEngine.simulate(driver: driver, cabinet: cabUnfilled, crossover: crossover)
        let simStuffed = SimulationEngine.simulate(driver: driver, cabinet: cabStuffed, crossover: crossover)

        // Heavy stuffing adds absorption loss Qb, reducing the motional impedance peak height
        let maxZUnfilled = simUnfilled.map { $0.wooferImpedanceMag }.max()!
        let maxZStuffed = simStuffed.map { $0.wooferImpedanceMag }.max()!
        XCTAssertGreaterThan(maxZUnfilled, maxZStuffed + 2.0, "Stuffing absorption loss Qb must reduce impedance peak height at resonance")
    }

    func testVentedBoxFourthOrderAcousticsAndImpedance() {
        let driver = Altec604Data.createDriver()
        var cabinet = SealedCabinet()
        cabinet.enclosureType = .vented
        cabinet.ventedAlignment = .qb3
        cabinet.portDiameterCm = 10.2
        cabinet.numberOfPorts = 1

        let ts = driver.wooferTS

        // 1. Check QB3 alignment volume and tuning calculations
        let vb = cabinet.computedPhysicalVolumeLiters(for: ts)
        let fb = cabinet.actualTuningFb(for: ts)
        let f3 = cabinet.actualF3(for: ts)

        // For Altec 604-8K: Fs=24, Qts=0.287, Vas=510:
        // QB3 gives Vb ~ 126 L, Fb ~ 31 Hz, f3 ~ 39 Hz
        XCTAssertGreaterThan(vb, 100.0)
        XCTAssertLessThan(vb, 160.0)
        XCTAssertEqual(fb, 31.0, accuracy: 4.0)
        XCTAssertEqual(f3, 39.0, accuracy: 4.0)

        // Compare f3 with sealed cabinet:
        var sealedCab = cabinet
        sealedCab.enclosureType = .sealed
        sealedCab.alignment = .butterworth
        let sealedF3 = sealedCab.actualF3(for: ts)
        XCTAssertGreaterThan(sealedF3, f3 + 40.0, "Vented box must provide ~50-60 Hz deeper bass extension than sealed box for low Qts driver")

        // 2. Check Port Dimensions
        let lv = cabinet.computedPortLengthCm(for: ts)
        let minDia = cabinet.minRecommendedPortDiameterCm(for: ts)
        XCTAssertGreaterThan(lv, 2.0)
        XCTAssertLessThan(lv, 30.0)
        XCTAssertGreaterThan(minDia, 4.0)

        // 3. Acoustic Transfer Function Magnitude and 4th-Order Rolloff
        let h100 = cabinet.transferFunction(frequency: 100.0, ts: ts)
        let h40 = cabinet.transferFunction(frequency: 40.0, ts: ts)
        let h20 = cabinet.transferFunction(frequency: 20.0, ts: ts)

        // Above Fb (passband): magnitude should be flat near 0 dB (1.0)
        XCTAssertEqual(h100.magnitude, 1.0, accuracy: 0.15)

        // Near f3 (~39 Hz): magnitude should be near -3 dB (~0.707)
        XCTAssertEqual(h40.magnitude, 0.707, accuracy: 0.15)

        // Below Fb (20 Hz): 4th-order roll-off (should be ~ -20 dB or lower, magnitude < 0.15)
        XCTAssertLessThan(h20.magnitude, 0.15)

        // 4. Twin-Peak Electrical Motional Impedance Curve
        // Between FL and FH, impedance must have a local minimum near Helmholtz resonance Fb
        let zAtFb = cabinet.ventedRawImpedance(frequency: fb, ts: ts).magnitude
        let zBelowFb = cabinet.ventedRawImpedance(frequency: fb * 0.5, ts: ts).magnitude
        let zAboveFb = cabinet.ventedRawImpedance(frequency: fb * 1.8, ts: ts).magnitude

        XCTAssertGreaterThan(zBelowFb, zAtFb + 5.0, "Lower impedance peak FL must be higher than the Helmholtz minimum at Fb")
        XCTAssertGreaterThan(zAboveFb, zAtFb + 10.0, "Upper impedance peak FH must be higher than the Helmholtz minimum at Fb")
        XCTAssertLessThan(zAtFb, ts.re + 5.0, "Impedance at Fb must dip close to voice coil DC resistance Re")

        // 5. Full Simulation with Vented Cabinet
        let crossover = CrossoverNetwork(crossoverFrequency: 1500.0)
        let points = SimulationEngine.simulate(driver: driver, cabinet: cabinet, crossover: crossover)
        XCTAssertEqual(points.count, 201)

        for p in points {
            XCTAssertTrue(p.totalSystemSPL.isFinite)
            XCTAssertTrue(p.wooferUnwrappedPhaseDeg.isFinite)
            XCTAssertTrue(p.wooferGroupDelayMs.isFinite)
            XCTAssertTrue(p.wooferImpedanceMag.isFinite)
            XCTAssertTrue(p.totalSystemImpedanceMag.isFinite)
        }

        let stepPoints = SimulationEngine.computeStepResponse(driver: driver, cabinet: cabinet, crossover: crossover)
        XCTAssertEqual(stepPoints.count, 201)
        for sp in stepPoints {
            XCTAssertTrue(sp.total.isFinite)
            XCTAssertTrue(sp.woofer.isFinite)
        }
    }

    func testZobelNetworkImpedancePlotReflection() {
        let driver = CoaxialDriver.defaultSampleDriver
        let cabinet = SealedCabinet(alignment: .butterworth)

        // 1. Simulation without Zobel Network
        let xoWithoutZobel = CrossoverNetwork(
            crossoverFrequency: 2200.0,
            enableZobelNetwork: false
        )
        let simNoZobel = SimulationEngine.simulate(driver: driver, cabinet: cabinet, crossover: xoWithoutZobel)

        // 2. Simulation with Zobel Network
        let xoWithZobel = CrossoverNetwork(
            crossoverFrequency: 2200.0,
            enableZobelNetwork: true
        )
        let simWithZobel = SimulationEngine.simulate(driver: driver, cabinet: cabinet, crossover: xoWithZobel)

        XCTAssertEqual(simNoZobel.count, 201)
        XCTAssertEqual(simWithZobel.count, 201)

        // Find 10 kHz and 20 kHz indices
        let idx10k = simNoZobel.firstIndex(where: { abs($0.frequency - 10000.0) < 500.0 })!
        let idx20k = simNoZobel.count - 1

        let z10kNoZobel = simNoZobel[idx10k].wooferImpedanceMag
        let z20kNoZobel = simNoZobel[idx20k].wooferImpedanceMag

        let z10kWithZobel = simWithZobel[idx10k].wooferImpedanceMag
        let z20kWithZobel = simWithZobel[idx20k].wooferImpedanceMag

        // Without Zobel: Voice coil inductance causes high-frequency impedance rise
        // Le = 0.85 mH, w*Le at 20 kHz = 106.8 Ohm -> |Z| > 100 Ohm
        XCTAssertGreaterThan(z10kNoZobel, 50.0, "Without Zobel, 10 kHz woofer impedance must show inductive rise")
        XCTAssertGreaterThan(z20kNoZobel, 100.0, "Without Zobel, 20 kHz woofer impedance must be > 100 Ohm")

        // With Zobel: Parallel RC network compensates rising inductance, flattening impedance near R_zobel = 1.25 * Re
        let expectedZobelR = 1.25 * driver.wooferTS.re
        XCTAssertLessThan(z10kWithZobel, expectedZobelR + 2.0, "With Zobel, 10 kHz woofer impedance must be flattened near R_zobel")
        XCTAssertLessThan(z20kWithZobel, expectedZobelR + 1.0, "With Zobel, 20 kHz woofer impedance must remain flat near R_zobel")
        XCTAssertGreaterThan(z20kWithZobel, driver.wooferTS.re - 1.0, "With Zobel, 20 kHz woofer impedance must not drop below Re")

        // Resonance peak at Fc must remain virtually unchanged
        let zPeakNoZobel = simNoZobel.prefix(simNoZobel.count / 2).max(by: { $0.wooferImpedanceMag < $1.wooferImpedanceMag })!
        let zPeakWithZobel = simWithZobel.max(by: { $0.wooferImpedanceMag < $1.wooferImpedanceMag })!
        XCTAssertEqual(zPeakNoZobel.frequency, zPeakWithZobel.frequency, accuracy: 5.0, "Resonance peak frequency Fc must be identical with or without Zobel")

        // 3. Verify with 150CX driver specifications (from user screenshot: Re=5.5, Le=0.42 mH, Fs=71 Hz)
        var driver150 = CoaxialDriver()
        driver150.wooferTS.fs = 71.0
        driver150.wooferTS.qes = 0.4
        driver150.wooferTS.qms = 5.17
        driver150.wooferTS.vas = 11.2
        driver150.wooferTS.re = 5.5
        driver150.wooferTS.le = 0.42

        let sim150NoZobel = SimulationEngine.simulate(driver: driver150, cabinet: cabinet, crossover: xoWithoutZobel)
        let sim150WithZobel = SimulationEngine.simulate(driver: driver150, cabinet: cabinet, crossover: xoWithZobel)

        let z150_20k_NoZobel = sim150NoZobel[idx20k].wooferImpedanceMag
        let z150_20k_WithZobel = sim150WithZobel[idx20k].wooferImpedanceMag

        // Le = 0.42 mH, w*Le at 20 kHz = 52.8 Ohm -> |Z| ≈ 53 Ohm (as seen in screenshot)
        XCTAssertGreaterThan(z150_20k_NoZobel, 50.0, "150CX without Zobel must show ~53 Ohm at 20 kHz")
        // With Zobel (R_zobel = 1.25 * 5.5 = 6.88 Ohm), 20 kHz is flattened to ~6.88 Ohm
        XCTAssertEqual(z150_20k_WithZobel, 6.88, accuracy: 0.5, "150CX with Zobel must flatten 20 kHz impedance to ~6.88 Ohm")
    }

    func testSpeakerDesignDocumentSaveAndLoadRoundtrip() throws {
        // 1. Setup customized driver, cabinet, and crossover
        var driver = CoaxialDriver()
        driver.name = "Custom Studio Monitor 8"
        driver.manufacturer = "AcousticTech"
        driver.wooferTS.fs = 38.5
        driver.wooferTS.qes = 0.32
        driver.wooferTS.qms = 4.2
        driver.wooferTS.vas = 35.0
        driver.wooferTS.re = 5.8
        driver.wooferTS.le = 0.65
        driver.tweeter.fs = 950.0
        driver.tweeter.re = 6.2
        driver.tweeter.le = 0.12
        driver.tweeter.spl = 98.0

        var cabinet = SealedCabinet()
        cabinet.enclosureType = .vented
        cabinet.ventedAlignment = .qb3
        cabinet.tuningFrequencyFb = 38.0
        cabinet.portDiameterCm = 7.5
        cabinet.numberOfPorts = 2
        cabinet.portLossQl = 12.0

        var crossover = CrossoverNetwork(
            crossoverFrequency: 1850.0,
            wooferOrder: .secondOrderLR,
            tweeterOrder: .thirdOrderBW,
            enableZobelNetwork: true,
            enableLPadAttenuator: true,
            userTargetAttenuationdB: 4.5,
            acousticCenterOffsetMM: 32.0,
            invertTweeterPolarity: true,
            enableAllpassFilter: false,
            enableIndependentFrequencies: true,
            wooferCrossoverFrequency: 1750.0,
            tweeterCrossoverFrequency: 1950.0
        )

        let originalDoc = SpeakerDesignDocument(
            version: 1,
            name: "Custom Studio Monitor 8 Project",
            driver: driver,
            cabinet: cabinet,
            crossover: crossover,
            wooferFRDText: "20.0 70.0 0.0\n1000.0 92.0 0.0\n20000.0 80.0 0.0",
            tweeterFRDText: "1000.0 90.0 0.0\n20000.0 98.0 0.0"
        )

        // 2. Encode to JSON string
        let jsonStr = try originalDoc.toJSON()
        XCTAssertFalse(jsonStr.isEmpty)
        XCTAssertTrue(jsonStr.contains("Custom Studio Monitor 8"))
        XCTAssertTrue(jsonStr.contains("AcousticTech"))
        XCTAssertTrue(jsonStr.contains("\"enclosureType\" : \"vented\""))
        XCTAssertTrue(jsonStr.contains("\"enableZobelNetwork\" : true"))

        // 3. Decode back from JSON string
        let restoredDoc = try SpeakerDesignDocument.fromJSON(jsonStr)
        XCTAssertEqual(restoredDoc.version, 1)
        XCTAssertEqual(restoredDoc.name, "Custom Studio Monitor 8 Project")
        XCTAssertEqual(restoredDoc.driver.name, "Custom Studio Monitor 8")
        XCTAssertEqual(restoredDoc.driver.manufacturer, "AcousticTech")
        XCTAssertEqual(restoredDoc.driver.wooferTS.fs, 38.5, accuracy: 1e-4)
        XCTAssertEqual(restoredDoc.driver.wooferTS.qes, 0.32, accuracy: 1e-4)
        XCTAssertEqual(restoredDoc.driver.wooferTS.re, 5.8, accuracy: 1e-4)
        XCTAssertEqual(restoredDoc.driver.wooferTS.le, 0.65, accuracy: 1e-4)

        XCTAssertEqual(restoredDoc.cabinet.enclosureType, .vented)
        XCTAssertEqual(restoredDoc.cabinet.tuningFrequencyFb, 38.0, accuracy: 1e-4)
        XCTAssertEqual(restoredDoc.cabinet.portDiameterCm, 7.5, accuracy: 1e-4)
        XCTAssertEqual(restoredDoc.cabinet.numberOfPorts, 2)

        XCTAssertEqual(restoredDoc.crossover.crossoverFrequency, 1850.0, accuracy: 1e-4)
        XCTAssertEqual(restoredDoc.crossover.wooferOrder, .secondOrderLR)
        XCTAssertEqual(restoredDoc.crossover.tweeterOrder, .thirdOrderBW)
        XCTAssertEqual(restoredDoc.crossover.enableZobelNetwork, true)
        XCTAssertEqual(restoredDoc.crossover.enableLPadAttenuator, true)
        XCTAssertEqual(restoredDoc.crossover.userTargetAttenuationdB, 4.5, accuracy: 1e-4)
        XCTAssertEqual(restoredDoc.crossover.acousticCenterOffsetMM, 32.0, accuracy: 1e-4)
        XCTAssertEqual(restoredDoc.crossover.invertTweeterPolarity, true)
        XCTAssertEqual(restoredDoc.crossover.enableIndependentFrequencies, true)
        XCTAssertEqual(restoredDoc.crossover.wooferCrossoverFrequency, 1750.0)
        XCTAssertEqual(restoredDoc.crossover.tweeterCrossoverFrequency, 1950.0)

        XCTAssertEqual(restoredDoc.wooferFRDText, "20.0 70.0 0.0\n1000.0 92.0 0.0\n20000.0 80.0 0.0")

        // 4. Test ViewModel export and import methods
        let vm = MainDesignerViewModel(driver: driver, cabinet: cabinet, crossover: crossover)
        let vmJSON = try vm.exportDesignJSON()
        XCTAssertTrue(vmJSON.contains("Custom Studio Monitor 8"))

        let newVM = MainDesignerViewModel()
        try newVM.importDesignJSON(vmJSON)
        XCTAssertEqual(newVM.driver.name, "Custom Studio Monitor 8")
        XCTAssertEqual(newVM.cabinet.enclosureType, .vented)
        XCTAssertEqual(newVM.crossover.crossoverFrequency, 1850.0, accuracy: 1e-4)
        XCTAssertEqual(newVM.simulationPoints.count, 201)

        // 5. Test error on corrupted JSON
        XCTAssertThrowsError(try SpeakerDesignDocument.fromJSON("{ invalid json }"))
    }

    func testDatasheetParsingAllThreeDrivers() {
        let parser = DatasheetParser()

        // 1. Test SN6-150CX Datasheet (P.Audio SN6-150CX)
        let sn6URL = URL(fileURLWithPath: "/work/SN6-150CX.pdf")
        if let data = try? Data(contentsOf: sn6URL) {
            let result = parser.parseDatasheetData(data, sourceURL: sn6URL)
            XCTAssertEqual(result.name, "SN6-150CX", "Driver name must be SN6-150CX, not 150CX")
            XCTAssertEqual(result.ts.fs, 71.0, accuracy: 0.5)
            XCTAssertEqual(result.ts.re, 5.5, accuracy: 0.2)
            XCTAssertEqual(result.ts.qes, 0.40, accuracy: 0.05)
            XCTAssertEqual(result.ts.qms, 5.17, accuracy: 0.1)
            XCTAssertEqual(result.ts.qts, 0.37, accuracy: 0.05)
            XCTAssertEqual(result.ts.vas, 11.2, accuracy: 0.5)
            XCTAssertEqual(result.ts.le, 0.42, accuracy: 0.02, "Woofer Le must be 0.42 mH, not 1 mH")
            XCTAssertEqual(result.ts.sd, 143.0, accuracy: 1.0)
            XCTAssertEqual(result.ts.xmax, 3.75, accuracy: 0.1)
            XCTAssertEqual(result.ts.spl, 93.0, accuracy: 0.5)
            XCTAssertEqual(result.tweeter.spl, 100.0, accuracy: 1.0, "Tweeter sensitivity must be approx 100 dB, not 93 dB")
        }

        // 2. Test B&C 6HCX51 Datasheet
        let bcURL = URL(fileURLWithPath: "/work/6HCX51.pdf")
        if let data = try? Data(contentsOf: bcURL) {
            let result = parser.parseDatasheetData(data, sourceURL: bcURL)
            XCTAssertTrue(result.name.contains("6HCX51"))
            XCTAssertEqual(result.ts.fs, 89.0, accuracy: 1.0)
            XCTAssertEqual(result.ts.re, 5.2, accuracy: 0.2)
            XCTAssertEqual(result.ts.le, 0.8, accuracy: 0.05)
            XCTAssertEqual(result.ts.spl, 92.0, accuracy: 0.5)
            XCTAssertEqual(result.tweeter.spl, 105.0, accuracy: 1.0)
            XCTAssertEqual(result.recommendedCrossover, 2200.0, accuracy: 100.0)
        }

        // 3. Test FaitalPRO 12HX500 Datasheet
        let faitalURL = URL(fileURLWithPath: "/work/12HX500_datasheet_8.pdf")
        if let data = try? Data(contentsOf: faitalURL) {
            let result = parser.parseDatasheetData(data, sourceURL: faitalURL)
            XCTAssertTrue(result.name.contains("12HX500"))
            XCTAssertEqual(result.ts.fs, 55.0, accuracy: 1.0)
            XCTAssertEqual(result.ts.re, 5.6, accuracy: 0.2)
            XCTAssertEqual(result.ts.le, 0.57, accuracy: 0.05)
            XCTAssertEqual(result.ts.spl, 95.0, accuracy: 0.5)
            XCTAssertEqual(result.tweeter.spl, 105.0, accuracy: 1.0)
            XCTAssertEqual(result.recommendedCrossover, 900.0, accuracy: 50.0)
        }
    }

    func testThreeTierPhaseAlignmentWarningLogicAndPDFReflection() {
        // 1. Green threshold (<= 10.0 deg)
        for rms in [0.0, 5.0, 8.5, 10.0] {
            let status = PhaseAlignmentStatus.from(rmsErrorDeg: rms)
            XCTAssertEqual(status, .optimal, "RMS \(rms) deg should be green (.optimal)")
            XCTAssertEqual(status.label, "Phase Aligned (Optimal)")
        }

        // 2. Yellow threshold (10.0 < rms <= 20.0 deg)
        for rms in [10.01, 12.5, 15.0, 20.0] {
            let status = PhaseAlignmentStatus.from(rmsErrorDeg: rms)
            XCTAssertEqual(status, .acceptable, "RMS \(rms) deg should be yellow (.acceptable)")
            XCTAssertEqual(status.label, "Acceptable Alignment - Minor Phase Offset")
        }

        // 3. Red threshold (> 20.0 deg)
        for rms in [20.01, 25.0, 45.0] {
            let status = PhaseAlignmentStatus.from(rmsErrorDeg: rms)
            XCTAssertEqual(status, .largeOffset, "RMS \(rms) deg should be red (.largeOffset)")
            XCTAssertEqual(status.label, "Large Phase Offset - Try Inverting Tweeter Polarity or Adjusting Fx")
        }

        // 4. Verify PDF generation across Green, Yellow, and Red phase alignment states
        let driver = CoaxialDriver.defaultSampleDriver
        let cabinet = SealedCabinet()
        for testError in [4.5, 14.2, 26.8] {
            var crossover = CrossoverNetwork(
                crossoverFrequency: 2000.0,
                enableZobelNetwork: true,
                acousticCenterOffsetMM: 35.0,
                enableAllpassFilter: true
            )
            crossover.allpassOptimizedF0 = 2000.0
            crossover.allpassOptimizedQ = 0.85
            crossover.allpassOptimizationErrorDeg = testError
            crossover.allpassOptimizationAchieved = testError <= 10.0

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
            XCTAssertEqual(String(data: pdfData.prefix(4), encoding: .ascii), "%PDF")
        }
    }

    func testE12AndE24ComponentValueSnapping() throws {
        // 1. Direct E12 vs E24 snapping accuracy tests
        // Value 1.11 -> E12 snaps to 1.2, E24 snaps to 1.1
        XCTAssertEqual(CrossoverNetwork.snapE12(1.11), 1.2, accuracy: 1e-6)
        XCTAssertEqual(CrossoverNetwork.snapE24(1.11), 1.1, accuracy: 1e-6)

        // Value 1.62 -> E12 snaps to 1.5, E24 snaps to 1.6
        XCTAssertEqual(CrossoverNetwork.snapE12(1.62), 1.5, accuracy: 1e-6)
        XCTAssertEqual(CrossoverNetwork.snapE24(1.62), 1.6, accuracy: 1e-6)

        // Value 24.1 -> E12 snaps to 22.0, E24 snaps to 24.0
        XCTAssertEqual(CrossoverNetwork.snapE12(24.1), 22.0, accuracy: 1e-6)
        XCTAssertEqual(CrossoverNetwork.snapE24(24.1), 24.0, accuracy: 1e-6)

        // Value 0.362 -> E12 snaps to 0.39, E24 snaps to 0.36
        XCTAssertEqual(CrossoverNetwork.snapE12(0.362), 0.39, accuracy: 1e-6)
        XCTAssertEqual(CrossoverNetwork.snapE24(0.362), 0.36, accuracy: 1e-6)

        // 2. Mutual exclusivity of E12 and E24 flags on CrossoverNetwork
        var xo = CrossoverNetwork(crossoverFrequency: 2100.0)
        XCTAssertFalse(xo.snapToStandardValues)
        XCTAssertFalse(xo.snapToE24Values)

        xo.snapToStandardValues = true
        XCTAssertTrue(xo.snapToStandardValues)
        XCTAssertFalse(xo.snapToE24Values)

        xo.snapToE24Values = true
        XCTAssertFalse(xo.snapToStandardValues, "Enabling E24 must automatically disable E12")
        XCTAssertTrue(xo.snapToE24Values)

        xo.snapToStandardValues = true
        XCTAssertTrue(xo.snapToStandardValues, "Enabling E12 must automatically disable E24")
        XCTAssertFalse(xo.snapToE24Values)

        // 3. Verify component calculation with E24 enabled vs Exact vs E12
        var xoExact = CrossoverNetwork(crossoverFrequency: 2150.0, enableAllpassFilter: true)
        var xoE12 = xoExact
        xoE12.snapToStandardValues = true
        var xoE24 = xoExact
        xoE24.snapToE24Values = true

        let compExact = xoExact.computeComponentValues(wooferRe: 6.2, tweeterRe: 5.8, wooferLe: 0.85)
        let compE12 = xoE12.computeComponentValues(wooferRe: 6.2, tweeterRe: 5.8, wooferLe: 0.85)
        let compE24 = xoE24.computeComponentValues(wooferRe: 6.2, tweeterRe: 5.8, wooferLe: 0.85)

        XCTAssertEqual(compE12.L1_mH!, CrossoverNetwork.snapE12(compExact.L1_mH!), accuracy: 1e-6)
        XCTAssertEqual(compE24.L1_mH!, CrossoverNetwork.snapE24(compExact.L1_mH!), accuracy: 1e-6)
        XCTAssertEqual(compE24.C1_uF!, CrossoverNetwork.snapE24(compExact.C1_uF!), accuracy: 1e-6)
        XCTAssertEqual(compE24.L_AP_mH!, CrossoverNetwork.snapE24(compExact.L_AP_mH!), accuracy: 1e-6)

        // 4. JSON Roundtrip with snapToE24Values
        let doc = SpeakerDesignDocument(
            name: "E24 Test Project",
            driver: CoaxialDriver.defaultSampleDriver,
            cabinet: SealedCabinet(),
            crossover: xoE24
        )
        let jsonStr = try doc.toJSON()
        let restored = try SpeakerDesignDocument.fromJSON(jsonStr)
        XCTAssertTrue(restored.crossover.snapToE24Values)
        XCTAssertFalse(restored.crossover.snapToStandardValues)
    }

    @MainActor
    func testDetachedChartWindowsAndLiveCrossoverReflection() {
        let vm = MainDesignerViewModel()
        XCTAssertTrue(vm.openDetachedCharts.isEmpty)

        // 1. Verify all 5 detachable chart kinds exist
        XCTAssertEqual(DetachedChartKind.allCases.count, 5)
        XCTAssertTrue(DetachedChartKind.allCases.contains(.amplitude))
        XCTAssertTrue(DetachedChartKind.allCases.contains(.phase))
        XCTAssertTrue(DetachedChartKind.allCases.contains(.groupDelay))
        XCTAssertTrue(DetachedChartKind.allCases.contains(.stepResponse))
        XCTAssertTrue(DetachedChartKind.allCases.contains(.impedance))

        // 2. Toggle individual detached chart window
        vm.toggleDetachedChart(.amplitude)
        XCTAssertTrue(vm.isChartDetached(.amplitude))
        XCTAssertFalse(vm.isChartDetached(.phase))

        // 3. Open 2x2 Live Monitor Grid
        vm.openLiveMonitorGrid(includeStepResponse: false)
        XCTAssertTrue(vm.isChartDetached(.amplitude))
        XCTAssertTrue(vm.isChartDetached(.phase))
        XCTAssertTrue(vm.isChartDetached(.groupDelay))
        XCTAssertTrue(vm.isChartDetached(.impedance))

        // 4. Verify live crossover parameter edits immediately update shared simulation curves
        let initialMidSPL = vm.simulationPoints[vm.simulationPoints.count / 2].tweeterFinalSPL
        let initialMidPhase = vm.simulationPoints[vm.simulationPoints.count / 2].tweeterPhaseDeg

        vm.crossover.userTargetAttenuationdB = 10.0
        vm.crossover.invertTweeterPolarity = true

        let updatedMidSPL = vm.simulationPoints[vm.simulationPoints.count / 2].tweeterFinalSPL
        let updatedMidPhase = vm.simulationPoints[vm.simulationPoints.count / 2].tweeterPhaseDeg

        XCTAssertNotEqual(initialMidSPL, updatedMidSPL, "Crossover L-Pad change must immediately update shared simulation points for detached Amplitude chart")
        XCTAssertNotEqual(initialMidPhase, updatedMidPhase, "Crossover polarity change must immediately update shared simulation points for detached Phase chart")

        // 5. Close all detached chart windows
        vm.closeAllDetachedCharts()
        XCTAssertTrue(vm.openDetachedCharts.isEmpty)
    }

    func testImpedanceAndGroupDelayYAxisAutoScaling() {
        let driver = CoaxialDriver.defaultSampleDriver
        let cabinet = SealedCabinet()
        let crossover = CrossoverNetwork(crossoverFrequency: 2200.0, enableZobelNetwork: true)
        let points = SimulationEngine.simulate(driver: driver, cabinet: cabinet, crossover: crossover)

        // 1. Impedance auto-scaling: Tweeter only (low peak ~11-16 Ohms) vs All curves (woofer resonance peak ~40-60 Ohms)
        let zRangeTweeterOnly = ImpedanceChartView.determineImpedanceRange(
            points: points,
            showWoofer: false,
            showTweeter: true,
            showTotalSystem: false
        )
        let zRangeAll = ImpedanceChartView.determineImpedanceRange(
            points: points,
            showWoofer: true,
            showTweeter: true,
            showTotalSystem: true
        )

        XCTAssertEqual(zRangeTweeterOnly.minZ, 0.0)
        XCTAssertLessThanOrEqual(zRangeTweeterOnly.maxZ, 25.0, "Tweeter-only impedance plot should auto-scale tightly (<= 25 Ohms) instead of 100 Ohms")
        XCTAssertLessThan(zRangeTweeterOnly.maxZ, zRangeAll.maxZ, "Tweeter-only maxZ must be smaller than full-system maxZ to maximize resolution")
        XCTAssertLessThanOrEqual(zRangeAll.maxZ, 80.0, "With Zobel enabled, full-system maxZ should fit resonance peak tightly (< 80 Ohms)")

        // 2. Group Delay auto-scaling: Tweeter only (sub-millisecond peak) vs All curves (cabinet LF group delay ~3-6 ms)
        let gdRangeTweeterOnly = GroupDelayChartView.determineGroupDelayRange(
            points: points,
            showWoofer: false,
            showTweeter: true,
            showTotalSystem: false
        )
        let gdRangeAll = GroupDelayChartView.determineGroupDelayRange(
            points: points,
            showWoofer: true,
            showTweeter: true,
            showTotalSystem: true
        )

        XCTAssertLessThanOrEqual(gdRangeTweeterOnly.maxMs, 2.0, "Tweeter-only group delay should auto-scale to fine sub-2ms ceiling instead of 6ms")
        XCTAssertLessThan(gdRangeTweeterOnly.stepMs, 1.0, "Tweeter-only group delay should use sub-millisecond grid steps (0.2 or 0.5 ms)")
        XCTAssertLessThan(gdRangeTweeterOnly.maxMs, gdRangeAll.maxMs, "Tweeter-only maxMs must be smaller than full-system maxMs")
    }

    @MainActor
    func testAltec604PresetValuesReflectInAllGraphs() {
        let vm = MainDesignerViewModel()
        let defaultPoints = vm.simulationPoints
        let defaultStep = vm.stepResponsePoints
        let defaultRevision = vm.simulationRevision

        // Load Altec 604-8K Preset via ViewModel action
        vm.loadAltec604Preset()

        XCTAssertGreaterThan(vm.simulationRevision, defaultRevision)
        XCTAssertEqual(vm.driver.name, "Altec Lansing 604-8K")
        XCTAssertEqual(vm.driver.manufacturer, "Altec Lansing")
        XCTAssertEqual(vm.crossover.crossoverFrequency, 1500.0)
        XCTAssertEqual(vm.targetReferenceSPL, 98.0)

        // Must preserve the 100-point digitized CLIO curves (NOT overwrite with 201-point synthetic curve)
        XCTAssertTrue(vm.driver.hasCustomWooferCurve)
        XCTAssertTrue(vm.driver.hasCustomTweeterCurve)
        XCTAssertEqual(vm.driver.wooferAcousticCurve.count, 100)
        XCTAssertEqual(vm.driver.tweeterAcousticCurve.count, 100)
        XCTAssertFalse(vm.wooferFRDText.isEmpty)
        XCTAssertFalse(vm.tweeterFRDText.isEmpty)

        // Verify reflection across all 5 graphs (Amplitude, Phase, Group Delay, Step Response, Impedance)
        let altecPoints = vm.simulationPoints
        let altecStep = vm.stepResponsePoints
        XCTAssertEqual(altecPoints.count, 201)
        XCTAssertEqual(altecStep.count, 201)

        // 1. Amplitude plot reflection (Altec ~98-105 dB vs default ~89-94 dB)
        let idx1k = altecPoints.firstIndex(where: { abs($0.frequency - 1000.0) < 50.0 })!
        let idx2600 = altecPoints.firstIndex(where: { abs($0.frequency - 2640.0) < 100.0 })!
        XCTAssertNotEqual(altecPoints[idx1k].wooferFinalSPL, defaultPoints[idx1k].wooferFinalSPL)
        XCTAssertNotEqual(altecPoints[idx2600].tweeterFinalSPL, defaultPoints[idx2600].tweeterFinalSPL)
        XCTAssertNotEqual(altecPoints[idx1k].totalSystemSPL, defaultPoints[idx1k].totalSystemSPL)

        // 2. Phase & Group Delay reflection (includes Hilbert minimum phase of CLIO curves)
        XCTAssertNotEqual(altecPoints[idx1k].wooferUnwrappedPhaseDeg, defaultPoints[idx1k].wooferUnwrappedPhaseDeg)
        XCTAssertNotEqual(altecPoints[idx2600].tweeterUnwrappedPhaseDeg, defaultPoints[idx2600].tweeterUnwrappedPhaseDeg)
        XCTAssertNotEqual(altecPoints[idx1k].totalSystemGroupDelayMs, defaultPoints[idx1k].totalSystemGroupDelayMs)

        // 3. System Impedance reflection
        let idx100 = altecPoints.firstIndex(where: { abs($0.frequency - 100.0) < 10.0 })!
        XCTAssertNotEqual(altecPoints[idx100].wooferImpedanceMag, defaultPoints[idx100].wooferImpedanceMag)
        XCTAssertNotEqual(altecPoints[idx1k].totalSystemImpedanceMag, defaultPoints[idx1k].totalSystemImpedanceMag)

        // 4. Step Response reflection
        let stepDiff = zip(altecStep, defaultStep).map { abs($0.0.total - $0.1.total) }.reduce(0.0, +)
        XCTAssertGreaterThan(stepDiff, 0.5, "Step response must reflect Altec 604-8K preset curves and T/S parameters")

        // 5. Verify manual SPL edit after loading Altec preset shifts curve in graphs
        let splBefore = vm.simulationPoints[idx1k].wooferFinalSPL
        vm.driver.wooferTS.spl = 95.0 // -3 dB from 98.0 dB preset
        let splAfter = vm.simulationPoints[idx1k].wooferFinalSPL
        XCTAssertEqual(splAfter, splBefore - 3.0, accuracy: 0.1, "Manual sensitivity edit on Altec preset must shift graph curve")
    }

    @MainActor
    func testFRDImportExportDialogActions() {
        let vm = MainDesignerViewModel()

        // 1. Import custom Woofer FRD text (3-column)
        let customWooferFRD = """
        * Custom Woofer Measurement
        20.0\t82.0\t15.0
        100.0\t91.5\t5.0
        1000.0\t93.0\t-10.0
        5000.0\t75.0\t-85.0
        20000.0\t60.0\t-140.0
        """
        vm.importWooferFRDText(customWooferFRD)
        XCTAssertTrue(vm.driver.hasCustomWooferCurve)
        XCTAssertEqual(vm.driver.wooferAcousticCurve.count, 5)
        XCTAssertEqual(vm.wooferFRDText, customWooferFRD)
        XCTAssertNil(vm.errorMessage)

        // 2. Import custom Tweeter FRD text with European comma decimals & semicolon delimiter
        let customTweeterFRD = """
        1000,0; 88,0; 40,0
        3000,0; 99,5; 0,0
        10000,0; 97,0; -15,0
        20000,0; 94,0; -35,0
        """
        vm.importTweeterFRDText(customTweeterFRD)
        XCTAssertTrue(vm.driver.hasCustomTweeterCurve)
        XCTAssertEqual(vm.driver.tweeterAcousticCurve.count, 4)
        XCTAssertEqual(vm.driver.tweeterAcousticCurve[1].magnitude, 99.5, accuracy: 0.01)
        XCTAssertNil(vm.errorMessage)

        // 3. Export simulated system FRD and verify roundtrip parsing
        let exportedFRD = vm.exportSystemFRD()
        XCTAssertTrue(exportedFRD.contains("* Freq(Hz)\tMag(dB)\tPhase(Deg)"))
        let parsedExport = DatasheetParser.parseFRDText(exportedFRD)
        XCTAssertEqual(parsedExport.count, vm.simulationPoints.count)

        // 4. Reset Woofer and Tweeter back to synthetic T/S curves
        vm.resetWooferToSyntheticCurve()
        XCTAssertFalse(vm.driver.hasCustomWooferCurve)
        XCTAssertTrue(vm.wooferFRDText.isEmpty)
        XCTAssertEqual(vm.driver.wooferAcousticCurve.count, 201)

        vm.resetTweeterToSyntheticCurve()
        XCTAssertFalse(vm.driver.hasCustomTweeterCurve)
        XCTAssertTrue(vm.tweeterFRDText.isEmpty)
        XCTAssertEqual(vm.driver.tweeterAcousticCurve.count, 201)
    }

    func testCDHornMassRollOffCompensationAndAltec604HFExtension() throws {
        let driver = Altec604Data.createDriver()
        let cabinet = SealedCabinet()

        // 1. Without CD Horn Compensation (standard 7 dB L-Pad on Altec 604-8K)
        let xoNoCD = CrossoverNetwork(
            crossoverFrequency: 1500.0,
            enableLPadAttenuator: true,
            userTargetAttenuationdB: 7.0,
            enableCDHornCompensation: false
        )
        let compNoCD = xoNoCD.computeComponentValues(wooferRe: driver.wooferTS.re, tweeterRe: driver.tweeter.re, wooferLe: driver.wooferTS.le)
        XCTAssertNil(compNoCD.C_cd_uF)
        XCTAssertNil(compNoCD.R_cd_ohms)

        // 2. With CD Horn Compensation (damped +5 dB HF shelf at 3500 Hz with 7 dB L-Pad)
        let xoDampedCD = CrossoverNetwork(
            crossoverFrequency: 1500.0,
            enableLPadAttenuator: true,
            userTargetAttenuationdB: 7.0,
            enableCDHornCompensation: true,
            cdHornCornerFrequency: 3500.0,
            cdHornBoostdB: 5.0
        )
        let compDamped = xoDampedCD.computeComponentValues(wooferRe: driver.wooferTS.re, tweeterRe: driver.tweeter.re, wooferLe: driver.wooferTS.le)
        XCTAssertNotNil(compDamped.C_cd_uF)
        XCTAssertNotNil(compDamped.R_cd_ohms, "When boost < L-Pad attenuation, series damping resistor R_eq must be computed")
        XCTAssertGreaterThan(compDamped.C_cd_uF!, 1.0)
        XCTAssertGreaterThan(compDamped.R_cd_ohms!, 0.5)

        // 3. With CD Horn Compensation at +7 dB boost matching 7 dB L-Pad at 3500 Hz
        let xoFullCD = CrossoverNetwork(
            crossoverFrequency: 1500.0,
            enableLPadAttenuator: true,
            userTargetAttenuationdB: 7.0,
            enableCDHornCompensation: true,
            cdHornCornerFrequency: 3500.0,
            cdHornBoostdB: 7.0
        )
        let compFull = xoFullCD.computeComponentValues(wooferRe: driver.wooferTS.re, tweeterRe: driver.tweeter.re, wooferLe: driver.wooferTS.le)
        XCTAssertNotNil(compFull.C_cd_uF)
        XCTAssertNotNil(compFull.R_cd_ohms, "Series damping resistor R_eq must be computed and present in BOM and schematic")
        XCTAssertGreaterThan(compFull.R_cd_ohms!, 0.1)

        // 4. Verify simulation shows significantly higher 10-20 kHz SPL with CD Horn Compensation enabled
        let simNoCD = SimulationEngine.simulate(driver: driver, cabinet: cabinet, crossover: xoNoCD)
        let simWithCD = SimulationEngine.simulate(driver: driver, cabinet: cabinet, crossover: xoFullCD)

        let idx15k = simNoCD.firstIndex(where: { abs($0.frequency - 15000.0) < 800.0 })!
        let idx20k = simNoCD.count - 1
        XCTAssertGreaterThan(simWithCD[idx15k].tweeterFinalSPL, simNoCD[idx15k].tweeterFinalSPL + 4.0, "CD Horn EQ must boost 15 kHz SPL to compensate mass roll-off")
        XCTAssertGreaterThan(simWithCD[idx20k].totalSystemSPL, simNoCD[idx20k].totalSystemSPL + 4.5, "CD Horn EQ must restore 20 kHz total system SPL")

        // 5. Verify PDF generation and JSON roundtrip with CD Horn Compensation including R_eq & C_eq reflection
        let pdfData = PDFExporter.generateSchematicPDF(driver: driver, cabinet: cabinet, crossover: xoDampedCD, components: compDamped)
        XCTAssertFalse(pdfData.isEmpty)
        XCTAssertEqual(String(data: pdfData.prefix(4), encoding: .ascii), "%PDF")

        let doc = SpeakerDesignDocument(name: "Altec 604-8K CD EQ", driver: driver, cabinet: cabinet, crossover: xoDampedCD)
        let jsonStr = try doc.toJSON()
        let restored = try SpeakerDesignDocument.fromJSON(jsonStr)
        XCTAssertTrue(restored.crossover.enableCDHornCompensation)
        XCTAssertEqual(restored.crossover.cdHornCornerFrequency, 3500.0)
        XCTAssertEqual(restored.crossover.cdHornBoostdB, 5.0)
    }

    @MainActor
    func testTweeterPolarityInversionReflectsInRMSErrorValue() {
        // 1. Default driver with All-Pass Filter enabled (2200 Hz, 35 mm delay)
        let vm = MainDesignerViewModel()
        vm.crossover.enableAllpassFilter = true
        vm.crossover.acousticCenterOffsetMM = 35.0
        vm.crossover.invertTweeterPolarity = false

        let rmsNormal = vm.crossover.allpassOptimizationErrorDeg!
        let f0Normal = vm.crossover.allpassOptimizedF0!
        let qNormal = vm.crossover.allpassOptimizedQ!
        let statusNormal = vm.crossover.allpassAlignmentStatus
        let pointsNormal = vm.simulationPoints
        let lapNormal = vm.calculatedComponents.L_AP_mH
        let capNormal = vm.calculatedComponents.C_AP_uF

        // Invert tweeter polarity (+180 deg)
        vm.crossover.invertTweeterPolarity = true

        let rmsInverted = vm.crossover.allpassOptimizationErrorDeg!
        let f0Inverted = vm.crossover.allpassOptimizedF0!
        let qInverted = vm.crossover.allpassOptimizedQ!
        let statusInverted = vm.crossover.allpassAlignmentStatus
        let pointsInverted = vm.simulationPoints
        let lapInverted = vm.calculatedComponents.L_AP_mH
        let capInverted = vm.calculatedComponents.C_AP_uF

        // Woofer APF network and woofer phase response must remain 100% unchanged when tweeter polarity is inverted
        XCTAssertEqual(f0Normal, f0Inverted, accuracy: 1e-9, "Woofer All-Pass F0 must NOT change when tweeter polarity is inverted")
        XCTAssertEqual(qNormal, qInverted, accuracy: 1e-9, "Woofer All-Pass Q must NOT change when tweeter polarity is inverted")
        XCTAssertEqual(lapNormal!, lapInverted!, accuracy: 1e-9, "Woofer L_AP must NOT change when tweeter polarity is inverted")
        XCTAssertEqual(capNormal!, capInverted!, accuracy: 1e-9, "Woofer C_AP must NOT change when tweeter polarity is inverted")
        for i in 0..<pointsNormal.count {
            XCTAssertEqual(pointsNormal[i].wooferPhaseDeg, pointsInverted[i].wooferPhaseDeg, accuracy: 1e-12, "Woofer wrapped phase must be invariant to tweeter polarity")
            XCTAssertEqual(pointsNormal[i].wooferUnwrappedPhaseDeg, pointsInverted[i].wooferUnwrappedPhaseDeg, accuracy: 1e-12, "Woofer unwrapped phase must be invariant to tweeter polarity")
            XCTAssertEqual(pointsNormal[i].wooferGroupDelayMs, pointsInverted[i].wooferGroupDelayMs, accuracy: 1e-12, "Woofer group delay must be invariant to tweeter polarity")
        }

        // Phase chart Y-axis bounds must also remain strictly identical so woofer curve never jumps visually
        let rangeNormal = PhaseBodeChartView.determinePhaseRange(
            points: pointsNormal,
            unwrapPhase: true,
            showWoofer: true,
            showTweeter: true,
            showTotalSystem: true,
            compensateTweeterDelay: false
        )
        let rangeInverted = PhaseBodeChartView.determinePhaseRange(
            points: pointsInverted,
            unwrapPhase: true,
            showWoofer: true,
            showTweeter: true,
            showTotalSystem: true,
            compensateTweeterDelay: false
        )
        XCTAssertEqual(rangeNormal.minDeg, rangeInverted.minDeg, accuracy: 1e-9, "Phase chart minDeg must not shift when tweeter polarity is inverted")
        XCTAssertEqual(rangeNormal.maxDeg, rangeInverted.maxDeg, accuracy: 1e-9, "Phase chart maxDeg must not shift when tweeter polarity is inverted")
        XCTAssertEqual(rangeNormal.stepDeg, rangeInverted.stepDeg, accuracy: 1e-9)

        XCTAssertNotEqual(rmsNormal, rmsInverted, "Inverting tweeter polarity must reflect in the RMS phase error value")
        XCTAssertGreaterThan(abs(rmsNormal - rmsInverted), 150.0, "2nd-order LR must transition from ~178° out-of-phase to ~2.1° in-phase")
        XCTAssertEqual(statusNormal, .largeOffset, "Normal polarity at 35mm 2nd-order LR is out of phase (Red tier)")
        XCTAssertEqual(statusInverted, .optimal, "Inverted polarity at 35mm 2nd-order LR achieves Green optimal alignment (~2.1°)")

        // 2. Altec 604-8K Preset with All-Pass Filter enabled (1500 Hz, 35 mm delay)
        vm.loadAltec604Preset()
        vm.crossover.enableAllpassFilter = true
        vm.crossover.acousticCenterOffsetMM = 35.0
        vm.crossover.invertTweeterPolarity = false

        let altecRmsNormal = vm.crossover.allpassOptimizationErrorDeg!
        let altecF0Normal = vm.crossover.allpassOptimizedF0!
        let altecQNormal = vm.crossover.allpassOptimizedQ!
        let altecStatusNormal = vm.crossover.allpassAlignmentStatus
        let altecPointsNormal = vm.simulationPoints
        XCTAssertEqual(altecStatusNormal, .largeOffset, "Altec 604-8K with normal polarity should indicate Large Phase Offset (> 20°)")

        // Follow the warning recommendation: "Try Inverting Tweeter Polarity"
        vm.crossover.invertTweeterPolarity = true
        let altecRmsInverted = vm.crossover.allpassOptimizationErrorDeg!
        let altecF0Inverted = vm.crossover.allpassOptimizedF0!
        let altecQInverted = vm.crossover.allpassOptimizedQ!
        let altecStatusInverted = vm.crossover.allpassAlignmentStatus
        let altecPointsInverted = vm.simulationPoints

        XCTAssertEqual(altecF0Normal, altecF0Inverted, accuracy: 1e-9, "Altec 604-8K woofer APF F0 must not change when tweeter polarity is inverted")
        XCTAssertEqual(altecQNormal, altecQInverted, accuracy: 1e-9, "Altec 604-8K woofer APF Q must not change when tweeter polarity is inverted")
        for i in 0..<altecPointsNormal.count {
            XCTAssertEqual(altecPointsNormal[i].wooferPhaseDeg, altecPointsInverted[i].wooferPhaseDeg, accuracy: 1e-12)
            XCTAssertEqual(altecPointsNormal[i].wooferUnwrappedPhaseDeg, altecPointsInverted[i].wooferUnwrappedPhaseDeg, accuracy: 1e-12)
        }
        XCTAssertLessThan(altecRmsInverted, altecRmsNormal - 20.0, "Inverting tweeter polarity on Altec 604-8K must substantially reduce RMS phase error")
        XCTAssertEqual(altecStatusInverted, .acceptable, "Inverting tweeter polarity on Altec 604-8K must improve status from Red to Yellow (< 20°)")

        // 3. With All-Pass Filter disabled (uncompensated crossover RMS phase error & chart range invariance)
        vm.crossover.enableAllpassFilter = false
        vm.crossover.invertTweeterPolarity = false
        let uncompNormal = vm.crossover.allpassOptimizationErrorDeg!
        let uncompPtsNormal = vm.simulationPoints

        vm.crossover.invertTweeterPolarity = true
        let uncompInverted = vm.crossover.allpassOptimizationErrorDeg!
        let uncompPtsInverted = vm.simulationPoints

        XCTAssertNotEqual(uncompNormal, uncompInverted, "Inverting tweeter polarity must also reflect in uncompensated RMS error when APF is disabled")
        let altecRangeN = PhaseBodeChartView.determinePhaseRange(points: uncompPtsNormal, unwrapPhase: true, showWoofer: true, showTweeter: true, showTotalSystem: true, compensateTweeterDelay: false)
        let altecRangeI = PhaseBodeChartView.determinePhaseRange(points: uncompPtsInverted, unwrapPhase: true, showWoofer: true, showTweeter: true, showTotalSystem: true, compensateTweeterDelay: false)
        XCTAssertEqual(altecRangeN.minDeg, altecRangeI.minDeg, accuracy: 1e-9)
        XCTAssertEqual(altecRangeN.maxDeg, altecRangeI.maxDeg, accuracy: 1e-9)
    }
}
