import Foundation
import Combine
import AppKit
import UniformTypeIdentifiers

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
    @Published public var showWooferRaw: Bool = true
    @Published public var showWooferFinal: Bool = true
    @Published public var showTweeterRaw: Bool = true
    @Published public var showTweeterFinal: Bool = true
    @Published public var showTargetReference: Bool = true
    @Published public var targetReferenceSPL: Double = 89.0

    public init(
        driver: CoaxialDriver = .defaultSampleDriver,
        cabinet: SealedCabinet = SealedCabinet(),
        crossover: CrossoverNetwork = CrossoverNetwork()
    ) {
        self.driver = driver
        self.cabinet = cabinet
        self.crossover = crossover

        recalculateSimulation()
    }

    private var isRecalculating: Bool = false

    /// Re-runs the physics simulation and recalculates passive filter component values.
    public func recalculateSimulation() {
        guard !isRecalculating else { return }
        isRecalculating = true
        defer { isRecalculating = false }
        
        // If curves are synthetic (no custom FRD imported), keep them in sync with current manual/parsed T/S parameters
        if self.wooferFRDText.isEmpty {
            driver.wooferAcousticCurve = CoaxialDriver.generateSyntheticWooferCurve(ts: driver.wooferTS)
        }
        if self.tweeterFRDText.isEmpty {
            driver.tweeterAcousticCurve = CoaxialDriver.generateSyntheticTweeterCurve(tw: driver.tweeter)
        }
        driver.wooferImpedanceCurve = CoaxialDriver.generateSyntheticWooferImpedance(ts: driver.wooferTS)
        driver.tweeterImpedanceCurve = CoaxialDriver.generateSyntheticTweeterImpedance(tw: driver.tweeter)

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

        // Include All-Pass Filter optimization and setup warnings
        if crossover.enableAllpassFilter {
            warns.append(contentsOf: crossover.allpassWarnings)
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
        self.driver.name = result.name
        self.driver.datasheetURL = sourceName
        self.driver.wooferTS = result.ts
        self.driver.tweeter = result.tweeter

        if result.recommendedCrossover >= 500.0 && result.recommendedCrossover <= 8000.0 {
            self.crossover.crossoverFrequency = result.recommendedCrossover
        }

        self.missingParameters = result.missingParams
        self.plausibilityWarnings = result.warnings

        if !result.wooferCurve.isEmpty {
            self.driver.wooferAcousticCurve = result.wooferCurve
        } else if self.wooferFRDText.isEmpty {
            self.driver.wooferAcousticCurve = CoaxialDriver.generateSyntheticWooferCurve(ts: result.ts)
        }

        if !result.tweeterCurve.isEmpty {
            self.driver.tweeterAcousticCurve = result.tweeterCurve
        } else if self.tweeterFRDText.isEmpty {
            self.driver.tweeterAcousticCurve = CoaxialDriver.generateSyntheticTweeterCurve(tw: result.tweeter)
        }
        self.driver.wooferImpedanceCurve = CoaxialDriver.generateSyntheticWooferImpedance(ts: result.ts)
        self.driver.tweeterImpedanceCurve = CoaxialDriver.generateSyntheticTweeterImpedance(tw: result.tweeter)

        self.isLoadingDatasheet = false
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
        self.driver = Altec604Data.createDriver()
        self.crossover.crossoverFrequency = Altec604Data.recommendedCrossover
        self.statusMessage = "Loaded Altec Lansing 604-8K factory specs & digitized CLIO frequency response curves."
        self.recalculateSimulation()
    }

    /// Ingest raw text as FRD data for Woofer acoustic curve.
    public func importWooferFRDText(_ text: String) {
        let points = DatasheetParser.parseFRDText(text)
        if !points.isEmpty {
            self.driver.wooferAcousticCurve = points
            self.recalculateSimulation()
            self.statusMessage = "Imported \(points.count) woofer acoustic points."
        }
    }

    /// Ingest raw text as FRD data for Tweeter acoustic curve.
    public func importTweeterFRDText(_ text: String) {
        let points = DatasheetParser.parseFRDText(text)
        if !points.isEmpty {
            self.driver.tweeterAcousticCurve = points
            self.recalculateSimulation()
            self.statusMessage = "Imported \(points.count) tweeter acoustic points."
        }
    }

    /// Export simulated system curve as FRD text file.
    public func exportSystemFRD() -> String {
        let exportPoints = simulationPoints.map {
            ResponseDataPoint(frequency: $0.frequency, magnitude: $0.totalSystemSPL, phase: $0.totalSystemPhaseDeg)
        }
        return DatasheetParser.exportToFRD(points: exportPoints, comment: "\(driver.name) - Sealed Cabinet \(String(format: "%.1f", cabinet.computedVolumeLiters(for: driver.wooferTS)))L - Combined Response")
    }

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
        let doc = try SpeakerDesignDocument.fromJSON(jsonString)
        self.driver = doc.driver
        self.cabinet = doc.cabinet
        self.crossover = doc.crossover
        self.wooferFRDText = doc.wooferFRDText ?? ""
        self.tweeterFRDText = doc.tweeterFRDText ?? ""
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
}
