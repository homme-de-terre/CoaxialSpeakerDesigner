import SwiftUI

public struct CrossoverInspectorView: View {
    @ObservedObject var viewModel: MainDesignerViewModel

    public init(viewModel: MainDesignerViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "line.horizontal.3.decrease.circle.fill")
                    .font(.title2)
                    .foregroundColor(.accentColor)
                Text("Coaxial Crossover Network Designer")
                    .font(.title2)
                    .bold()
            }

            Divider()

            GroupBox(label: Label("Frequency & Topology Settings", systemImage: "slider.horizontal.2.square.on.square")) {
                VStack(alignment: .leading, spacing: 12) {
                    // Crossover Frequency Slider
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Crossover Frequency (fx):")
                            Spacer()
                            Text("\(Int(viewModel.crossover.crossoverFrequency)) Hz")
                                .bold()
                                .foregroundColor(.accentColor)
                        }
                        Slider(value: $viewModel.crossover.crossoverFrequency, in: 800.0...6000.0, step: 25.0)
                    }

                    HStack(spacing: 20) {
                        VStack(alignment: .leading) {
                            Text("Woofer Low-Pass Filter:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Picker("Woofer Filter Order", selection: $viewModel.crossover.wooferOrder) {
                                ForEach(FilterOrder.allCases) { order in
                                    Text(order.rawValue).tag(order)
                                }
                            }
                            .pickerStyle(.menu)
                        }

                        VStack(alignment: .leading) {
                            Text("Tweeter High-Pass Filter:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Picker("Tweeter Filter Order", selection: $viewModel.crossover.tweeterOrder) {
                                ForEach(FilterOrder.allCases) { order in
                                    Text(order.rawValue).tag(order)
                                }
                            }
                            .pickerStyle(.menu)
                        }
                    }
                }
                .padding(8)
            }

            GroupBox(label: Label("Compensation & Alignment Circuits", systemImage: "bolt.shield")) {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Enable Zobel Network (Inductance Compensation)", isOn: $viewModel.crossover.enableZobelNetwork)

                    Toggle("Enable Tweeter L-Pad Attenuator", isOn: $viewModel.crossover.enableLPadAttenuator)

                    if viewModel.crossover.enableLPadAttenuator {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Tweeter Attenuation:")
                                Spacer()
                                Text(String(format: "%.1f dB", viewModel.crossover.userTargetAttenuationdB))
                                    .bold()
                            }
                            Slider(value: $viewModel.crossover.userTargetAttenuationdB, in: 0.0...15.0, step: 0.5)
                        }
                    }

                    Divider()

                    // Acoustic Center Offset
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Coaxial Tweeter Acoustic Center Delay Offset (Δd):")
                            Spacer()
                            Text(String(format: "%.1f mm (%.2f ms)", viewModel.crossover.acousticCenterOffsetMM, (viewModel.crossover.acousticCenterOffsetMM/1000.0)/343.0 * 1000.0))
                                .bold()
                                .foregroundColor(.blue)
                        }
                        Slider(value: $viewModel.crossover.acousticCenterOffsetMM, in: 0.0...100.0, step: 1.0)
                    }

                    HStack {
                        Toggle("Invert Tweeter Polarity (+180°)", isOn: $viewModel.crossover.invertTweeterPolarity)
                        Spacer()
                        Toggle("Snap Components to Commercial E12 Series", isOn: $viewModel.crossover.snapToStandardValues)
                    }
                }
                .padding(8)
            }

            // Calculated Component Readouts
            let comp = viewModel.calculatedComponents

            GroupBox(label: Label("Passive Crossover Network Component Values", systemImage: "cpu")) {
                Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 8) {
                    GridRow {
                        Text("Woofer LP:").bold()
                        if let l1 = comp.L1_mH { Text("L1 = \(String(format: "%.2f", l1)) mH") }
                        if let c1 = comp.C1_uF { Text("C1 = \(String(format: "%.2f", c1)) µF") }
                        if let l2 = comp.L2_mH { Text("L2 = \(String(format: "%.2f", l2)) mH") }
                    }
                    GridRow {
                        Text("Tweeter HP:").bold()
                        if let c1 = comp.C_HP1_uF { Text("C_HP1 = \(String(format: "%.2f", c1)) µF") }
                        if let l1 = comp.L_HP1_mH { Text("L_HP1 = \(String(format: "%.2f", l1)) mH") }
                        if let c2 = comp.C_HP2_uF { Text("C_HP2 = \(String(format: "%.2f", c2)) µF") }
                    }
                    if viewModel.crossover.enableZobelNetwork {
                        GridRow {
                            Text("Zobel Network:").bold().foregroundColor(.orange)
                            if let rz = comp.R_zobel_ohms { Text("R_zobel = \(String(format: "%.2f", rz)) Ω") }
                            if let cz = comp.C_zobel_uF { Text("C_zobel = \(String(format: "%.2f", cz)) µF") }
                        }
                    }
                    if viewModel.crossover.enableLPadAttenuator {
                        GridRow {
                            Text("L-Pad Attenuator:").bold().foregroundColor(.purple)
                            if let r1 = comp.R1_lpad_ohms { Text("R1 (Series) = \(String(format: "%.2f", r1)) Ω") }
                            if let r2 = comp.R2_lpad_ohms { Text("R2 (Parallel) = \(String(format: "%.2f", r2)) Ω") }
                        }
                    }
                }
                .padding(8)
            }
        }
        .padding()
    }
}
