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
    @Published public var calculatedComponents: CalculatedComponents = CalculatedComponents()

    // UI State
    @Published public var datasheetURLString: String = ""
    @Published public var isLoadingDatasheet: Bool = false
    @Published public var statusMessage: String? = nil
    @Published public var errorMessage: String? = nil

    @Published public var selectedTab: Int = 0 // 0: Amplitude, 1: Phase, 2: Impedance, 3: Cabinet, 4: Crossover, 5: BOM, 6: FRD
    @Published public var wooferFRDText: String = ""
    @Published public var tweeterFRDText: String = ""
    @Published public var digitizerActiveTab: Int = 0
    @Published public var showWooferRaw: Bool = true
    @Published public var showWooferFinal: Bool = true
    @Published public var showTweeterRaw: Bool = true
    @Published public var showTweeterFinal: Bool = true
    @Published public var showTotalSystem: Bool = true
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

    /// Re-runs the physics simulation and recalculates passive filter component values.
    public func recalculateSimulation() {
        objectWillChange.send()
        
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

        self.simulationPoints = newPoints
        self.calculatedComponents = newComponents
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

                self.driver.name = result.name
                self.driver.datasheetURL = url.absoluteString
                self.driver.wooferTS = result.ts
                self.driver.tweeter = result.tweeter

                self.isLoadingDatasheet = false
                self.statusMessage = "Successfully parsed driver parameters from datasheet."
                self.recalculateSimulation()
            } catch {
                self.isLoadingDatasheet = false
                self.errorMessage = "Error downloading datasheet: \(error.localizedDescription)"
            }
        }
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

        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                do {
                    try pdfData.write(to: url)
                    Task { @MainActor in
                        self.statusMessage = "Successfully exported PDF schematic to \(url.lastPathComponent)"
                    }
                } catch {
                    Task { @MainActor in
                        self.errorMessage = "Failed to save PDF file: \(error.localizedDescription)"
                    }
                }
            }
        }
    }
}
