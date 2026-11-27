import Foundation
import Combine
import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Enumerates the simulation chart views that can be detached into live floating windows.
public enum DetachedChartKind: String, CaseIterable, Identifiable, Codable, Sendable {
    case amplitude = "Amplitude Response"
    case phase = "Phase & Delay"
    case groupDelay = "Group Delay"
    case stepResponse = "Step Response"
    case impedance = "System Impedance"

    public var id: String { rawValue }

    public var shortTitle: String {
        switch self {
        case .amplitude: return "Amplitude"
        case .phase: return "Phase & Delay"
        case .groupDelay: return "Group Delay"
        case .stepResponse: return "Step Response"
        case .impedance: return "Impedance"
        }
    }

    public var systemImage: String {
        switch self {
        case .amplitude: return "chart.xyaxis.line"
        case .phase: return "waveform"
        case .groupDelay: return "clock"
        case .stepResponse: return "waveform.path.ecg"
        case .impedance: return "bolt.horizontal"
        }
    }
}

@MainActor
public class MainDesignerViewModel: ObservableObject {
    // MARK: - Published State
    @Published public var driver: CoaxialDriver {
        didSet { recalculateSimulation() }
    }
    @Published public var cabinet: SealedCabinet {
        didSet { recalculateSimulation() }
    }
    @Published public var crossover: CrossoverNetwork {
        didSet { recalculateSimulation() }
    }

    @Published public var simulationPoints: [SimulationPoint] = []
    @Published public var stepResponsePoints: [StepResponsePoint] = []
    @Published public var calculatedComponents: CalculatedComponents = CalculatedComponents()

    // UI State
    @Published public var datasheetURLString: String = ""
    @Published public var isLoadingDatasheet: Bool = false
    @Published public var statusMessage: String? = nil
    @Published public var errorMessage: String? = nil
    @Published public var missingParameters: [String] = []
    @Published public var plausibilityWarnings: [String] = []
    @Published public var isEuropeanDecimal: Bool = false

    @Published public var selectedTab: Int = 0 // 0: Amplitude, 1: Phase, 8: Group Delay, 7: Step, 2: Impedance, 3: Cabinet, 4: Crossover, 5: BOM, 6: FRD
    @Published public var wooferFRDText: String = ""
    @Published public var tweeterFRDText: String = ""
    @Published public var digitizerActiveTab: Int = 0
    @Published public var showWoofer: Bool = true
    @Published public var showTweeter: Bool = true
    @Published public var showTotalSystem: Bool = true
    @Published public var showPhaseDiff: Bool = true
    @Published public var unwrapPhase: Bool = true
    @Published public var compensateTweeterDelay: Bool = false
    @Published public var showAboutDialog: Bool = false
    @Published public var showHelpDialog: Bool = false
    @Published public var showWooferRaw: Bool = true
    @Published public var showWooferFinal: Bool = true
    @Published public var showTweeterRaw: Bool = true
    @Published public var showTweeterFinal: Bool = true
    @Published public var showTargetReference: Bool = true
    @Published public var targetReferenceSPL: Double = 89.0
    @Published public var simulationRevision: Int = 0
    @Published public var openDetachedCharts: Set<DetachedChartKind> = []

    #if canImport(AppKit)
    private var detachedWindows: [DetachedChartKind: NSWindow] = [:]
    private var windowCloseObservers: [DetachedChartKind: NSObjectProtocol] = [:]
    #endif

    public init(
        driver: CoaxialDriver = .defaultSampleDriver,
        cabinet: SealedCabinet = SealedCabinet(),
        crossover: CrossoverNetwork = CrossoverNetwork()
    ) {
        self.driver = driver
        self.cabinet = cabinet
        self.crossover = crossover
        if driver.wooferTS.spl > 0 {
            self.targetReferenceSPL = driver.wooferTS.spl
        }

        recalculateSimulation()
    }

    private var isRecalculating: Bool = false

    /// Re-runs the physics simulation and recalculates passive filter component values.
    public func recalculateSimulation() {
        guard !isRecalculating else { return }
        isRecalculating = true
        defer { isRecalculating = false }
        
        // If curves are synthetic (no custom/preset/digitized FRD active), keep them in sync with current manual/parsed T/S parameters
        if !driver.hasCustomWooferCurve && self.wooferFRDText.isEmpty {
            driver.wooferAcousticCurve = CoaxialDriver.generateSyntheticWooferCurve(ts: driver.wooferTS)
        }
        if !driver.hasCustomTweeterCurve && self.tweeterFRDText.isEmpty {
            driver.tweeterAcousticCurve = CoaxialDriver.generateSyntheticTweeterCurve(tw: driver.tweeter)
        }
        driver.wooferImpedanceCurve = CoaxialDriver.generateSyntheticWooferImpedance(ts: driver.wooferTS)
        driver.tweeterImpedanceCurve = CoaxialDriver.generateSyntheticTweeterImpedance(tw: driver.tweeter)
        if driver.wooferTS.spl > 0 {
            self.targetReferenceSPL = driver.wooferTS.spl
        }

        // Run Nelder-Mead All-Pass Filter Phase Alignment Optimization if APF is enabled
        if crossover.enableAllpassFilter {
            let opt = AllpassFilterOptimizer.optimize(
                driver: driver,
                cabinet: cabinet,
                crossover: crossover
            )
            crossover.allpassOptimizedF0 = opt.f0
            crossover.allpassOptimizedQ = opt.q
            crossover.allpassOptimizationErrorDeg = opt.rmsErrorDeg
            crossover.allpassOptimizationAchieved = opt.isGoalAchieved
            crossover.allpassWarnings = opt.warnings
        } else {
            crossover.allpassOptimizedF0 = nil
            crossover.allpassOptimizedQ = nil
            crossover.allpassOptimizationErrorDeg = nil
            crossover.allpassOptimizationAchieved = true
            crossover.allpassWarnings = []
        }

        let newPoints = SimulationEngine.simulate(
            driver: driver,
            cabinet: cabinet,
            crossover: crossover
        )

        let newComponents = crossover.computeComponentValues(
            wooferRe: driver.wooferTS.re,
            tweeterRe: driver.tweeter.re,
            wooferLe: driver.wooferTS.le
        )

        let newStepPoints = SimulationEngine.computeStepResponse(
            driver: driver,
            cabinet: cabinet,
            crossover: crossover
        )

        self.simulationPoints = newPoints
        self.calculatedComponents = newComponents
        self.stepResponsePoints = newStepPoints
        self.simulationRevision &+= 1
        self.validateParameters()
    }

    /// Dynamically validates active driver parameters against physical bounds.
    public func validateParameters() {
        var missing: [String] = []
        var warns: [String] = []

        if driver.wooferTS.fs == 0 { missing.append("Fs") }
        else if driver.wooferTS.fs < 15.0 || driver.wooferTS.fs > 250.0 { warns.append("Fs (\(driver.wooferTS.fs) Hz) outside typical range (15–200 Hz).") }

        if driver.wooferTS.qes == 0 { missing.append("Qes") }
        else if driver.wooferTS.qes < 0.08 || driver.wooferTS.qes > 2.5 { warns.append("Qes (\(driver.wooferTS.qes)) outside typical range (0.1–2.0).") }

        if driver.wooferTS.qms == 0 { missing.append("Qms") }
        else if driver.wooferTS.qms < 0.8 || driver.wooferTS.qms > 30.0 { warns.append("Qms (\(driver.wooferTS.qms)) outside typical range (1.0–25.0).") }

        if driver.wooferTS.qts == 0 { missing.append("Qts") }
        else if driver.wooferTS.qts < 0.08 || driver.wooferTS.qts > 2.0 { warns.append("Qts (\(driver.wooferTS.qts)) outside typical range (0.1–1.5).") }

        if driver.wooferTS.vas == 0 { missing.append("Vas") }
        else if driver.wooferTS.vas < 1.0 || driver.wooferTS.vas > 900.0 { warns.append("Vas (\(driver.wooferTS.vas) L) outside typical range (2–800 L).") }

        if driver.wooferTS.re == 0 { missing.append("Re") }
        else if driver.wooferTS.re < 1.0 || driver.wooferTS.re > 25.0 { warns.append("Woofer Re (\(driver.wooferTS.re) Ω) outside typical range (1.5–20 Ω).") }

        if driver.wooferTS.spl == 0 { missing.append("Sensitivity") }
        else if driver.wooferTS.spl < 75.0 || driver.wooferTS.spl > 115.0 { warns.append("Woofer Sensitivity (\(driver.wooferTS.spl) dB) seems implausible.") }

        if driver.tweeter.spl < 85.0 || driver.tweeter.spl > 125.0 {
            warns.append("Tweeter Sensitivity (\(driver.tweeter.spl) dB) seems implausible.")
        }

        if crossover.crossoverFrequency < 500.0 || crossover.crossoverFrequency > 8000.0 {
            warns.append("Crossover Frequency (\(Int(crossover.crossoverFrequency)) Hz) outside typical coaxial range.")
        }

        // Include All-Pass Filter setup warnings (and severe >20° phase offset warnings)
        if crossover.enableAllpassFilter {
            warns.append(contentsOf: crossover.allpassWarnings)
            if crossover.allpassAlignmentStatus == .largeOffset {
                warns.append(crossover.allpassAlignmentStatus.label)
            }
        }

        self.missingParameters = missing
        self.plausibilityWarnings = warns
    }

    /// Downloads driver datasheet from URL and ingests parameters and text.
    public func loadDatasheetFromURL() {
        guard let url = URL(string: datasheetURLString), url.scheme == "http" || url.scheme == "https" else {
            self.errorMessage = "Please enter a valid HTTP or HTTPS datasheet URL."
            return
        }

        self.isLoadingDatasheet = true
        self.errorMessage = nil
        self.statusMessage = "Downloading datasheet from URL..."

        let currentParser = DatasheetParser()

        Task {
            do {
                let result = try await currentParser.fetchAndParseDatasheet(url: url)
                await MainActor.run {
                    self.applyParsedDatasheet(result: result, sourceName: url.lastPathComponent.isEmpty ? url.absoluteString : url.lastPathComponent)
                }
            } catch {
                await MainActor.run {
                    self.isLoadingDatasheet = false
                    self.errorMessage = "Error downloading datasheet: \(error.localizedDescription)"
                }
            }
        }
    }

    /// Ingests driver datasheet from a local file URL.
    public func loadDatasheet(from fileURL: URL) {
        self.isLoadingDatasheet = true
        self.errorMessage = nil
        self.statusMessage = "Reading local datasheet..."

        let currentParser = DatasheetParser()
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let result = try currentParser.parseDatasheet(from: fileURL)
                DispatchQueue.main.async {
                    self.applyParsedDatasheet(result: result, sourceName: fileURL.lastPathComponent)
                }
            } catch {
                DispatchQueue.main.async {
                    self.isLoadingDatasheet = false
                    self.errorMessage = "Error reading local datasheet: \(error.localizedDescription)"
                }
            }
        }
    }

#if canImport(AppKit)
    /// Prompts user with native macOS Open Panel to select a local PDF datasheet.
    public func chooseLocalDatasheetFile() {
        let openPanel = NSOpenPanel()
        openPanel.title = "Select Loudspeaker Datasheet (PDF)"
        openPanel.message = "Choose a PDF or text datasheet to import driver parameters"
        openPanel.allowedContentTypes = [UTType.pdf, UTType.plainText]
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = false
        openPanel.canChooseFiles = true

        if openPanel.runModal() == .OK, let url = openPanel.url {
            self.loadDatasheet(from: url)
        }
    }
#endif

    /// Applies extracted datasheet parameters and synthesizes driver response curves.
    private func applyParsedDatasheet(result: (ts: WooferTSParameters, tweeter: TweeterParameters, name: String, recommendedCrossover: Double, missingParams: [String], warnings: [String], rawText: String, wooferCurve: [ResponseDataPoint], tweeterCurve: [ResponseDataPoint]), sourceName: String) {
        #if canImport(AppKit)
        NSApp.keyWindow?.makeFirstResponder(nil)
        #endif
        self.driver.name = result.name
        self.driver.datasheetURL = sourceName
        self.driver.wooferTS = result.ts
        self.driver.tweeter = result.tweeter

        if result.recommendedCrossover >= 500.0 && result.recommendedCrossover <= 8000.0 {
            self.crossover.crossoverFrequency = result.recommendedCrossover
            self.crossover.wooferCrossoverFrequency = result.recommendedCrossover
            self.crossover.tweeterCrossoverFrequency = result.recommendedCrossover
        }

        self.missingParameters = result.missingParams
        self.plausibilityWarnings = result.warnings

        if !result.wooferCurve.isEmpty {
            self.driver.hasCustomWooferCurve = true
            self.driver.customWooferReferenceSPL = result.ts.spl
            self.driver.wooferAcousticCurve = result.wooferCurve
            self.wooferFRDText = DatasheetParser.exportToFRD(points: result.wooferCurve, comment: "\(result.name) - Digitized Woofer Response")
        } else {
            self.driver.hasCustomWooferCurve = false
            self.driver.customWooferReferenceSPL = nil
            self.wooferFRDText = ""
            self.driver.wooferAcousticCurve = CoaxialDriver.generateSyntheticWooferCurve(ts: result.ts)
        }

        if !result.tweeterCurve.isEmpty {
            self.driver.hasCustomTweeterCurve = true
            self.driver.customTweeterReferenceSPL = result.tweeter.spl
            self.driver.tweeterAcousticCurve = result.tweeterCurve
            self.tweeterFRDText = DatasheetParser.exportToFRD(points: result.tweeterCurve, comment: "\(result.name) - Digitized Tweeter Response")
        } else {
            self.driver.hasCustomTweeterCurve = false
            self.driver.customTweeterReferenceSPL = nil
            self.tweeterFRDText = ""
            self.driver.tweeterAcousticCurve = CoaxialDriver.generateSyntheticTweeterCurve(tw: result.tweeter)
        }
        self.driver.wooferImpedanceCurve = CoaxialDriver.generateSyntheticWooferImpedance(ts: result.ts)
        self.driver.tweeterImpedanceCurve = CoaxialDriver.generateSyntheticTweeterImpedance(tw: result.tweeter)

        self.isLoadingDatasheet = false
        self.errorMessage = nil
        if !result.warnings.isEmpty {
            self.statusMessage = "Warning: \(result.warnings.joined(separator: " | "))"
        } else if !result.missingParams.isEmpty {
            self.statusMessage = "Missing from datasheet: \(result.missingParams.joined(separator: ", ")) — please enter manually."
        } else {
            let xoStr = result.recommendedCrossover > 0 ? " (fx: \(Int(result.recommendedCrossover)) Hz)" : ""
            self.statusMessage = "Successfully parsed driver parameters from \(sourceName)\(xoStr)."
        }
        self.recalculateSimulation()
    }

    /// Loads factory preset specifications and digitized CLIO response curves for Altec Lansing 604-8K.
    public func loadAltec604Preset() {
        #if canImport(AppKit)
        NSApp.keyWindow?.makeFirstResponder(nil)
        #endif
        self.wooferFRDText = DatasheetParser.exportToFRD(
            points: Altec604Data.wooferCurve,
            comment: "Altec Lansing 604-8K - Digitized CLIO Woofer Response"
        )
        self.tweeterFRDText = DatasheetParser.exportToFRD(
            points: Altec604Data.tweeterCurve,
            comment: "Altec Lansing 604-8K - Digitized CLIO Tweeter Response"
        )
        self.driver = Altec604Data.createDriver()
        self.crossover.crossoverFrequency = Altec604Data.recommendedCrossover
        self.crossover.wooferCrossoverFrequency = Altec604Data.recommendedCrossover
        self.crossover.tweeterCrossoverFrequency = Altec604Data.recommendedCrossover
        self.targetReferenceSPL = Altec604Data.wooferTS.spl
        self.missingParameters = []
        self.plausibilityWarnings = []
        self.errorMessage = nil
        self.statusMessage = "Loaded Altec Lansing 604-8K factory specs & digitized CLIO frequency response curves."
        self.recalculateSimulation()
    }

    /// Ingest raw text as FRD data for Woofer acoustic curve.
    public func importWooferFRDText(_ text: String) {
        #if canImport(AppKit)
        NSApp.keyWindow?.makeFirstResponder(nil)
        #endif
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            #if canImport(AppKit)
            chooseWooferFRDFile()
            return
            #else
            self.errorMessage = "Please paste Woofer FRD data (Freq, SPL, Phase) or select an FRD file."
            return
            #endif
        }
        let points = DatasheetParser.parseFRDText(trimmed)
        if !points.isEmpty {
            self.wooferFRDText = text
            self.driver.hasCustomWooferCurve = true
            self.driver.customWooferReferenceSPL = self.driver.wooferTS.spl
            self.driver.wooferAcousticCurve = points
            self.errorMessage = nil
            self.statusMessage = "Imported \(points.count) woofer acoustic FRD points."
            self.recalculateSimulation()
        } else {
            self.errorMessage = "Could not parse Woofer FRD data. Expected 2 or 3 numeric columns per line: Frequency(Hz) SPL(dB) [Phase(Deg)]."
        }
    }

    /// Ingest raw text as FRD data for Tweeter acoustic curve.
    public func importTweeterFRDText(_ text: String) {
        #if canImport(AppKit)
        NSApp.keyWindow?.makeFirstResponder(nil)
        #endif
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            #if canImport(AppKit)
            chooseTweeterFRDFile()
            return
            #else
            self.errorMessage = "Please paste Tweeter FRD data (Freq, SPL, Phase) or select an FRD file."
            return
            #endif
        }
        let points = DatasheetParser.parseFRDText(trimmed)
        if !points.isEmpty {
            self.tweeterFRDText = text
            self.driver.hasCustomTweeterCurve = true
            self.driver.customTweeterReferenceSPL = self.driver.tweeter.spl
            self.driver.tweeterAcousticCurve = points
            self.errorMessage = nil
            self.statusMessage = "Imported \(points.count) tweeter acoustic FRD points."
            self.recalculateSimulation()
        } else {
            self.errorMessage = "Could not parse Tweeter FRD data. Expected 2 or 3 numeric columns per line: Frequency(Hz) SPL(dB) [Phase(Deg)]."
        }
    }

    /// Resets Woofer acoustic curve back to T/S synthetic model.
    public func resetWooferToSyntheticCurve() {
        #if canImport(AppKit)
        NSApp.keyWindow?.makeFirstResponder(nil)
        #endif
        self.wooferFRDText = ""
        self.driver.hasCustomWooferCurve = false
        self.driver.customWooferReferenceSPL = nil
        self.driver.wooferAcousticCurve = CoaxialDriver.generateSyntheticWooferCurve(ts: self.driver.wooferTS)
        self.errorMessage = nil
        self.statusMessage = "Reset woofer response to synthetic T/S curve."
        self.recalculateSimulation()
    }

    /// Resets Tweeter acoustic curve back to synthetic model.
    public func resetTweeterToSyntheticCurve() {
        #if canImport(AppKit)
        NSApp.keyWindow?.makeFirstResponder(nil)
        #endif
        self.tweeterFRDText = ""
        self.driver.hasCustomTweeterCurve = false
        self.driver.customTweeterReferenceSPL = nil
        self.driver.tweeterAcousticCurve = CoaxialDriver.generateSyntheticTweeterCurve(tw: self.driver.tweeter)
        self.errorMessage = nil
        self.statusMessage = "Reset tweeter response to synthetic HF curve."
        self.recalculateSimulation()
    }

    #if canImport(AppKit)
    /// Opens macOS file picker to load a local .frd or .txt file into the Woofer FRD curve.
    public func chooseWooferFRDFile() {
        let openPanel = NSOpenPanel()
        openPanel.title = "Select Woofer Acoustic Response File (FRD / TXT)"
        openPanel.message = "Choose a 2- or 3-column frequency response data file (.frd, .txt, .csv)"
        openPanel.allowedContentTypes = [UTType.plainText, UTType.commaSeparatedText, UTType.data, UTType.item]
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = false
        openPanel.canChooseFiles = true

        NSApp.activate(ignoringOtherApps: true)
        if openPanel.runModal() == .OK, let url = openPanel.url {
            do {
                let content = try String(contentsOf: url, encoding: .utf8)
                let points = DatasheetParser.parseFRDText(content)
                if !points.isEmpty {
                    self.wooferFRDText = content
                    self.driver.hasCustomWooferCurve = true
                    self.driver.customWooferReferenceSPL = self.driver.wooferTS.spl
                    self.driver.wooferAcousticCurve = points
                    self.errorMessage = nil
                    self.statusMessage = "Imported \(points.count) woofer FRD points from \(url.lastPathComponent)."
                    self.recalculateSimulation()
                } else {
                    self.errorMessage = "No valid FRD points found in \(url.lastPathComponent)."
                }
            } catch {
                self.errorMessage = "Failed to read Woofer FRD file: \(error.localizedDescription)"
            }
        }
    }

    /// Opens macOS file picker to load a local .frd or .txt file into the Tweeter FRD curve.
    public func chooseTweeterFRDFile() {
        let openPanel = NSOpenPanel()
        openPanel.title = "Select Tweeter Acoustic Response File (FRD / TXT)"
        openPanel.message = "Choose a 2- or 3-column frequency response data file (.frd, .txt, .csv)"
        openPanel.allowedContentTypes = [UTType.plainText, UTType.commaSeparatedText, UTType.data, UTType.item]
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = false
        openPanel.canChooseFiles = true

        NSApp.activate(ignoringOtherApps: true)
        if openPanel.runModal() == .OK, let url = openPanel.url {
            do {
                let content = try String(contentsOf: url, encoding: .utf8)
                let points = DatasheetParser.parseFRDText(content)
                if !points.isEmpty {
                    self.tweeterFRDText = content
                    self.driver.hasCustomTweeterCurve = true
                    self.driver.customTweeterReferenceSPL = self.driver.tweeter.spl
                    self.driver.tweeterAcousticCurve = points
                    self.errorMessage = nil
                    self.statusMessage = "Imported \(points.count) tweeter FRD points from \(url.lastPathComponent)."
                    self.recalculateSimulation()
                } else {
                    self.errorMessage = "No valid FRD points found in \(url.lastPathComponent)."
                }
            } catch {
                self.errorMessage = "Failed to read Tweeter FRD file: \(error.localizedDescription)"
            }
        }
    }
    #endif

    /// Export simulated system curve as FRD text file.
    public func exportSystemFRD() -> String {
        let exportPoints = simulationPoints.map {
            ResponseDataPoint(frequency: $0.frequency, magnitude: $0.totalSystemSPL, phase: $0.totalSystemPhaseDeg)
        }
        let cabLabel = cabinet.enclosureType == .vented ? "Ported Cabinet" : "Closed Cabinet"
        return DatasheetParser.exportToFRD(points: exportPoints, comment: "\(driver.name) - \(cabLabel) \(String(format: "%.1f", cabinet.computedVolumeLiters(for: driver.wooferTS)))L - Combined Response")
    }

    #if canImport(AppKit)
    /// Copies simulated system FRD text to the macOS clipboard and updates status message.
    public func copySystemFRDToClipboard() {
        let frdText = exportSystemFRD()
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(frdText, forType: .string)
        self.errorMessage = nil
        self.statusMessage = "Copied \(simulationPoints.count)-point simulated system FRD to clipboard."
    }

    /// Exports simulated system FRD text to a local .frd file via macOS Save Panel.
    public func exportSystemFRDToFile() {
        let frdText = exportSystemFRD()
        let savePanel = NSSavePanel()
        if let frdType = UTType(filenameExtension: "frd") {
            savePanel.allowedContentTypes = [frdType, UTType.plainText]
        } else {
            savePanel.allowedContentTypes = [UTType.plainText]
        }
        savePanel.allowsOtherFileTypes = true
        let sanitizedName = driver.name.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: " ", with: "_")
        savePanel.nameFieldStringValue = "\(sanitizedName.isEmpty ? "Speaker" : sanitizedName)_System_Simulated.frd"
        savePanel.title = "Export Simulated System FRD File"
        savePanel.message = "Save 3-column simulated amplitude and phase response as a standard .frd file"

        NSApp.activate(ignoringOtherApps: true)
        if savePanel.runModal() == .OK, let url = savePanel.url {
            do {
                try frdText.write(to: url, atomically: true, encoding: .utf8)
                self.errorMessage = nil
                self.statusMessage = "Successfully exported simulated FRD to \(url.lastPathComponent)."
            } catch {
                self.errorMessage = "Failed to save FRD file: \(error.localizedDescription)"
            }
        }
    }
    #endif

    /// Generates vector PDF schematic & BOM document and opens macOS Save Panel dialog.
    public func exportSchematicPDF() {
        let pdfData = PDFExporter.generateSchematicPDF(
            driver: driver,
            cabinet: cabinet,
            crossover: crossover,
            components: calculatedComponents
        )

        guard !pdfData.isEmpty else {
            self.errorMessage = "Failed to generate PDF document."
            return
        }

        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [UTType.pdf]
        savePanel.nameFieldStringValue = "Crossover_Schematic_\(driver.name.replacingOccurrences(of: " ", with: "_")).pdf"
        savePanel.title = "Export Crossover Schematic & BOM to PDF"

        NSApp.activate(ignoringOtherApps: true)
        if savePanel.runModal() == .OK, let url = savePanel.url {
            do {
                try pdfData.write(to: url)
                self.statusMessage = "Successfully exported PDF schematic to \(url.lastPathComponent)"
                self.errorMessage = nil
            } catch {
                self.errorMessage = "Failed to save PDF file: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Save / Load Complete Design File

    /// Creates a complete SpeakerDesignDocument from current state and returns formatted JSON string.
    public func exportDesignJSON() throws -> String {
        let doc = SpeakerDesignDocument(
            name: driver.name,
            driver: driver,
            cabinet: cabinet,
            crossover: crossover,
            wooferFRDText: wooferFRDText.isEmpty ? nil : wooferFRDText,
            tweeterFRDText: tweeterFRDText.isEmpty ? nil : tweeterFRDText
        )
        return try doc.toJSON()
    }

    /// Ingests a JSON design string and restores all parameters and simulations.
    public func importDesignJSON(_ jsonString: String) throws {
        #if canImport(AppKit)
        NSApp.keyWindow?.makeFirstResponder(nil)
        #endif
        let doc = try SpeakerDesignDocument.fromJSON(jsonString)
        self.wooferFRDText = doc.wooferFRDText ?? ""
        self.tweeterFRDText = doc.tweeterFRDText ?? ""
        var loadedDriver = doc.driver
        if !self.wooferFRDText.isEmpty {
            let wPts = DatasheetParser.parseFRDText(self.wooferFRDText)
            if !wPts.isEmpty {
                loadedDriver.wooferAcousticCurve = wPts
                loadedDriver.hasCustomWooferCurve = true
            }
        }
        if !self.tweeterFRDText.isEmpty {
            let tPts = DatasheetParser.parseFRDText(self.tweeterFRDText)
            if !tPts.isEmpty {
                loadedDriver.tweeterAcousticCurve = tPts
                loadedDriver.hasCustomTweeterCurve = true
            }
        }
        self.driver = loadedDriver
        self.cabinet = doc.cabinet
        self.crossover = doc.crossover
        self.statusMessage = "Successfully loaded design '\(doc.name)'"
        self.errorMessage = nil
        self.recalculateSimulation()
    }

    #if canImport(AppKit)
    /// Opens native macOS Save Panel to save the entire design as a .json file.
    public func saveDesignToFile() {
        do {
            let jsonString = try exportDesignJSON()
            let savePanel = NSSavePanel()
            savePanel.allowedContentTypes = [UTType.json]
            let sanitizedName = driver.name.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: " ", with: "_")
            savePanel.nameFieldStringValue = "\(sanitizedName.isEmpty ? "Speaker" : sanitizedName)_Design.json"
            savePanel.title = "Save Loudspeaker Design File"
            savePanel.message = "Save all driver, cabinet, crossover, and curve parameters into a project file"

            NSApp.activate(ignoringOtherApps: true)
            if savePanel.runModal() == .OK, let url = savePanel.url {
                do {
                    try jsonString.write(to: url, atomically: true, encoding: .utf8)
                    self.statusMessage = "Successfully saved design to \(url.lastPathComponent)"
                    self.errorMessage = nil
                } catch {
                    self.errorMessage = "Failed to save design file: \(error.localizedDescription)"
                }
            }
        } catch {
            self.errorMessage = "Failed to encode design JSON: \(error.localizedDescription)"
        }
    }

    /// Opens native macOS Open Panel to select and load a .json loudspeaker design file.
    public func loadDesignFromFile() {
        let openPanel = NSOpenPanel()
        openPanel.title = "Open Loudspeaker Design File"
        openPanel.message = "Choose a JSON design file to load all project parameters"
        openPanel.allowedContentTypes = [UTType.json]
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = false
        openPanel.canChooseFiles = true

        NSApp.activate(ignoringOtherApps: true)
        if openPanel.runModal() == .OK, let url = openPanel.url {
            self.loadDesign(from: url)
        }
    }

    /// Loads design from local file URL.
    public func loadDesign(from fileURL: URL) {
        do {
            let jsonString = try String(contentsOf: fileURL, encoding: .utf8)
            try importDesignJSON(jsonString)
            self.statusMessage = "Loaded design from \(fileURL.lastPathComponent)"
        } catch {
            self.errorMessage = "Failed to load design file: \(error.localizedDescription)"
        }
    }
    #endif

    // MARK: - Detached Live Curve Windows Manager

    /// Checks whether a specific chart is currently open in a detached window.
    public func isChartDetached(_ kind: DetachedChartKind) -> Bool {
        return openDetachedCharts.contains(kind)
    }

    /// Toggles a detached chart window open or closed.
    public func toggleDetachedChart(_ kind: DetachedChartKind) {
        if openDetachedCharts.contains(kind) {
            closeDetachedChart(kind)
        } else {
            openDetachedChart(kind)
        }
    }

    /// Opens (or brings to front) a detached live window for the requested simulation chart.
    public func openDetachedChart(_ kind: DetachedChartKind, frame: NSRect? = nil) {
        openDetachedCharts.insert(kind)

        #if canImport(AppKit)
        if let existingWindow = detachedWindows[kind] {
            if let targetFrame = frame {
                existingWindow.setFrame(targetFrame, display: true, animate: false)
            }
            existingWindow.makeKeyAndOrderFront(nil)
            return
        }

        let hostingView: NSView
        switch kind {
        case .amplitude:
            hostingView = NSHostingView(rootView: AmplitudeBodeChartView(viewModel: self, isDetachedWindow: true).frame(minWidth: 480, minHeight: 340))
        case .phase:
            hostingView = NSHostingView(rootView: PhaseBodeChartView(viewModel: self, isDetachedWindow: true).frame(minWidth: 480, minHeight: 340))
        case .groupDelay:
            hostingView = NSHostingView(rootView: GroupDelayChartView(viewModel: self, isDetachedWindow: true).frame(minWidth: 480, minHeight: 340))
        case .stepResponse:
            hostingView = NSHostingView(rootView: StepResponseChartView(viewModel: self, isDetachedWindow: true).frame(minWidth: 480, minHeight: 340))
        case .impedance:
            hostingView = NSHostingView(rootView: ImpedanceChartView(viewModel: self, isDetachedWindow: true).frame(minWidth: 480, minHeight: 340))
        }

        let indexOffset = CGFloat((DetachedChartKind.allCases.firstIndex(of: kind) ?? 0) * 28)
        let defaultRect = frame ?? NSRect(x: 140.0 + indexOffset, y: 140.0 + indexOffset, width: 680.0, height: 440.0)

        let window = NSWindow(
            contentRect: defaultRect,
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Coaxial Speaker Designer — \(kind.rawValue) (Live)"
        window.isReleasedWhenClosed = false
        window.contentView = hostingView
        if let targetFrame = frame {
            window.setFrame(targetFrame, display: true, animate: false)
        }

        let observer = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.openDetachedCharts.remove(kind)
                self.detachedWindows.removeValue(forKey: kind)
                if let obs = self.windowCloseObservers.removeValue(forKey: kind) {
                    NotificationCenter.default.removeObserver(obs)
                }
            }
        }

        windowCloseObservers[kind] = observer
        detachedWindows[kind] = window
        window.makeKeyAndOrderFront(nil)
        #endif
    }

    /// Closes a specific detached chart window if open.
    public func closeDetachedChart(_ kind: DetachedChartKind) {
        openDetachedCharts.remove(kind)
        #if canImport(AppKit)
        if let obs = windowCloseObservers.removeValue(forKey: kind) {
            NotificationCenter.default.removeObserver(obs)
        }
        if let window = detachedWindows.removeValue(forKey: kind) {
            window.close()
        }
        #endif
    }

    /// Opens the 4 primary frequency-domain plots (Amplitude, Phase & Delay, Group Delay, System Impedance)
    /// arranged in a 2×2 live monitor grid on screen, with optional 5th Step Response window.
    public func openLiveMonitorGrid(includeStepResponse: Bool = false) {
        let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 40, y: 40, width: 1440, height: 900)
        let gap: CGFloat = 12.0
        let cellW = max(480.0, (screenFrame.width - gap * 3.0) / 2.0)
        let cellH = max(340.0, (screenFrame.height - gap * 3.0) / 2.0)

        let leftX = screenFrame.minX + gap
        let rightX = leftX + cellW + gap
        let bottomY = screenFrame.minY + gap
        let topY = bottomY + cellH + gap

        openDetachedChart(.amplitude, frame: NSRect(x: leftX, y: topY, width: cellW, height: cellH))
        openDetachedChart(.phase, frame: NSRect(x: rightX, y: topY, width: cellW, height: cellH))
        openDetachedChart(.groupDelay, frame: NSRect(x: leftX, y: bottomY, width: cellW, height: cellH))
        openDetachedChart(.impedance, frame: NSRect(x: rightX, y: bottomY, width: cellW, height: cellH))

        if includeStepResponse {
            let centerRect = NSRect(
                x: screenFrame.midX - cellW / 2.0,
                y: screenFrame.midY - cellH / 2.0,
                width: cellW,
                height: cellH
            )
            openDetachedChart(.stepResponse, frame: centerRect)
        }
    }

    /// Closes all currently open detached chart windows.
    public func closeAllDetachedCharts() {
        let activeKinds = Array(openDetachedCharts)
        for kind in activeKinds {
            closeDetachedChart(kind)
        }
    }
}
