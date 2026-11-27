import SwiftUI

public struct MainSplitView: View {
    @StateObject var viewModel = MainDesignerViewModel()

    public init() {}

    public var body: some View {
        NavigationSplitView {
            SidebarView(viewModel: viewModel)
                .navigationSplitViewColumnWidth(min: 250, ideal: 290, max: 340)
        } detail: {
            VStack(spacing: 0) {
                // Top Tab Switcher & About Info (Horizontally scrollable & compact so it never pushes window beyond screen bounds)
                HStack(spacing: 8) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        Picker("View Mode", selection: $viewModel.selectedTab) {
                            Label("Amplitude Response", systemImage: "chart.xyaxis.line").tag(0)
                            Label("Phase & Delay", systemImage: "waveform").tag(1)
                            Label("Group Delay", systemImage: "clock").tag(8)
                            Label("Step Response", systemImage: "waveform.path.ecg").tag(7)
                            Label("System Impedance", systemImage: "bolt.horizontal").tag(2)
                            Label("Cabinet Closed/Ported", systemImage: "cube.box").tag(3)
                            Label("Crossover Network", systemImage: "line.horizontal.3.decrease.circle").tag(4)
                            Label("Schematic & BOM", systemImage: "cpu").tag(5)
                            Label("FRD Import/Export", systemImage: "pencil.and.outline").tag(6)
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .controlSize(.small)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    HStack(spacing: 10) {
                        Button(action: { viewModel.saveDesignToFile() }) {
                            Image(systemName: "square.and.arrow.down")
                                .font(.system(size: 15))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("Save Design to File (⌘S)")

                        Button(action: { viewModel.loadDesignFromFile() }) {
                            Image(systemName: "folder")
                                .font(.system(size: 15))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("Open Design File (⌘O)")

                        Button(action: { viewModel.showHelpDialog = true }) {
                            Image(systemName: "questionmark.circle")
                                .font(.system(size: 15))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("Quick User & Engineering Help Guide")

                        Button(action: { viewModel.showAboutDialog = true }) {
                            Image(systemName: "info.circle")
                                .font(.system(size: 15))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("About Coaxial Speaker Designer")
                    }
                    .fixedSize(horizontal: true, vertical: false)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(NSColor.windowBackgroundColor))

                Divider()

                // Content View for active tab
                Group {
                    switch viewModel.selectedTab {
                    case 0:
                        AmplitudeBodeChartView(viewModel: viewModel)
                    case 1:
                        PhaseBodeChartView(viewModel: viewModel)
                    case 8:
                        GroupDelayChartView(viewModel: viewModel)
                    case 7:
                        StepResponseChartView(viewModel: viewModel)
                    case 2:
                        ImpedanceChartView(viewModel: viewModel)
                    case 3:
                        ScrollView { CabinetInspectorView(viewModel: viewModel) }
                    case 4:
                        ScrollView { CrossoverInspectorView(viewModel: viewModel) }
                    case 5:
                        ScrollView { SchematicView(viewModel: viewModel) }
                    case 6:
                        ScrollView { CurveDigitizerEditorView(viewModel: viewModel) }
                    default:
                        AmplitudeBodeChartView(viewModel: viewModel)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .sheet(isPresented: Binding<Bool>(
            get: { viewModel.showAboutDialog },
            set: { viewModel.showAboutDialog = $0 }
        )) {
            AboutDialogView(viewModel: viewModel)
        }
        .sheet(isPresented: Binding<Bool>(
            get: { viewModel.showHelpDialog },
            set: { viewModel.showHelpDialog = $0 }
        )) {
            HelpDialogView(viewModel: viewModel)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("CSD_SaveDesign"))) { _ in
            #if canImport(AppKit)
            viewModel.saveDesignToFile()
            #endif
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("CSD_LoadDesign"))) { _ in
            #if canImport(AppKit)
            viewModel.loadDesignFromFile()
            #endif
        }
    }
}

public struct AboutDialogView: View {
    @ObservedObject var viewModel: MainDesignerViewModel

    public var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "speaker.wave.3.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 54, height: 54)
                .foregroundColor(.accentColor)

            VStack(spacing: 4) {
                Text("Coaxial Speaker Designer")
                    .font(.title2)
                    .bold()

                Text("Version 1.3.0 (Build 2026.10)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Professional Loudspeaker Engineering & Simulation System")
                    .font(.caption)
                    .bold()

                VStack(alignment: .leading, spacing: 4) {
                    Label("Independent Target Cut-off Frequencies (Woofer & Tweeter)", systemImage: "slider.horizontal.2.square.on.square")
                    Label("Nelder-Mead All-Pass Filter Phase Optimizer", systemImage: "waveform.badge.magnifyingglass")
                    Label("Phase Unwrapping & Delay Compensation", systemImage: "waveform")
                    Label("Acoustic & Electrical Group Delay Analysis", systemImage: "clock")
                    Label("Time-Domain Transient Step Response Engine", systemImage: "waveform.path.ecg")
                    Label("Vector 2-Page Schematic & BOM PDF Exporter", systemImage: "doc.richtext")
                }
                .font(.caption2)
                .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)

            HStack {
                Spacer()
                Button("Close") {
                    viewModel.showAboutDialog = false
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 440)
    }
}

public struct HelpDialogView: View {
    @ObservedObject var viewModel: MainDesignerViewModel

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "questionmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.accentColor)
                Text("Coaxial Speaker Designer — Quick Help Guide")
                    .font(.headline)
                Spacer()
            }

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    helpSection(
                        title: "1. Driver Setup & Datasheet Ingestion",
                        bullets: [
                            "Import local PDF datasheets or paste a URL to auto-extract Thiele-Small specs (Fs, Qes, Qms, Qts, Vas, Re, Le, Sd, Xmax, SPL) and digitize response curves.",
                            "Or click 'Load Altec 604-8K Preset (CLIO)' to load factory specs and 100-point measured curves."
                        ]
                    )

                    helpSection(
                        title: "2. Enclosure Design (Sealed 2nd-Order & Vented 4th-Order)",
                        bullets: [
                            "Sealed Box (12 dB/oct): Choose Butterworth B2 (Qtc = 0.707), Bessel (0.577), Critically Damped (0.500), or Target f3.",
                            "Vented Bass-Reflex (24 dB/oct): Recommended for low-Qts pro coaxial woofers (0.25–0.38). Select QB3, B4, or SC4 and keep port diameter above Min Recommended Dia to avoid chuffing."
                        ]
                    )

                    helpSection(
                        title: "3. Crossover Tuning, Phase Alignment & Live Windows",
                        bullets: [
                            "Live Curve Windows: In the Crossover tab, click 'Open 2×2 Live Monitor Grid' (or detach individual plots) so changes reflect immediately in the curves.",
                            "All-Pass Phase Optimizer: Enter tweeter physical depth offset (mm) and enable the All-Pass Network. Green (≤ 10° RMS) = Optimal, Yellow (10°–20°) = Acceptable, Red (> 20°) = Try inverting polarity or adjusting fx.",
                            "E12 / E24 Snapping: Snap ideal components to standard commercial E12 (±10%) or E24 (±5%) values."
                        ]
                    )

                    helpSection(
                        title: "4. Auto-Scaled Plots, Project Save & CAD PDF Export",
                        bullets: [
                            "Group Delay and System Impedance automatically scale their vertical Y-axis to maximize resolution for visible traces.",
                            "Use Save/Load Design (⌘S / ⌘O) for JSON project files, or export a 2-page vector schematic & BOM report from the Schematic & BOM tab."
                        ]
                    )
                }
            }
            .frame(maxHeight: 340)

            Divider()

            HStack {
                Text("Full guide available in HELP.md")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
                Button("Close") {
                    viewModel.showHelpDialog = false
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
        .frame(width: 540)
    }

    @ViewBuilder
    private func helpSection(title: String, bullets: [String]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.bold())
                .foregroundColor(.primary)
            ForEach(bullets, id: \.self) { b in
                Text("• \(b)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(6)
    }
}
