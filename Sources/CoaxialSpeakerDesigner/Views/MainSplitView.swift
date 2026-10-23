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
                // Top Tab Switcher
                Picker("View Mode", selection: $viewModel.selectedTab) {
                    Label("Amplitude Response", systemImage: "chart.xyaxis.line").tag(0)
                    Label("Phase & Delay", systemImage: "waveform").tag(1)
                    Label("System Impedance", systemImage: "bolt.horizontal").tag(2)
                    Label("Closed Cabinet", systemImage: "cube.box").tag(3)
                    Label("Crossover Network", systemImage: "line.horizontal.3.decrease.circle").tag(4)
                    Label("Schematic & BOM", systemImage: "cpu").tag(5)
                    Label("FRD Import/Export", systemImage: "pencil.and.outline").tag(6)
                }
                .pickerStyle(.segmented)
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
    }
}
