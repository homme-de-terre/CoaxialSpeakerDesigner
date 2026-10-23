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
        ts.fs = 45.0
        ts.qts = 0.35
        ts.vas = 30.0

        let cabinet = SealedCabinet(alignment: .butterworth, targetF3: 60.0)
        let fc = cabinet.computedResonanceFc(for: ts)
        let alpha = cabinet.computedComplianceAlpha(for: ts)
        let vb = cabinet.computedVolumeLiters(for: ts)

        XCTAssertGreaterThan(fc, ts.fs)
        XCTAssertGreaterThan(alpha, 0.0)
        XCTAssertGreaterThan(vb, 0.0)

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
}
