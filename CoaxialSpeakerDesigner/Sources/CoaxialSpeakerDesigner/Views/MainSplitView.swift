import SwiftUI

public struct MainSplitView: View {
    @StateObject var viewModel = MainDesignerViewModel()

    public init() {}

    public var body: some View {
        NavigationSplitView {
            SidebarView(viewModel: viewModel)
                .navigationSplitViewColumnWidth(min: 300, ideal: 350, max: 400)
        } detail: {
            VStack(spacing: 0) {
                // Top Tab Switcher & About Info
                HStack(spacing: 12) {
                    Picker("View Mode", selection: $viewModel.selectedTab) {
                        Label("Amplitude Response", systemImage: "chart.xyaxis.line").tag(0)
                        Label("Phase & Delay", systemImage: "waveform").tag(1)
                        Label("Group Delay", systemImage: "clock").tag(8)
                        Label("Step Response", systemImage: "waveform.path.ecg").tag(7)
                        Label("System Impedance", systemImage: "bolt.horizontal").tag(2)
                        Label("Closed Cabinet", systemImage: "cube.box").tag(3)
                        Label("Crossover Network", systemImage: "line.horizontal.3.decrease.circle").tag(4)
                        Label("Schematic & BOM", systemImage: "cpu").tag(5)
                        Label("FRD Import/Export", systemImage: "pencil.and.outline").tag(6)
                    }
                    .pickerStyle(.segmented)

                    Button(action: { viewModel.showAboutDialog = true }) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 15))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("About Coaxial Speaker Designer")
                }
                .padding()
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
