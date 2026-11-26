import SwiftUI

public struct CrossoverInspectorView: View {
    @ObservedObject var viewModel: MainDesignerViewModel

    public init(viewModel: MainDesignerViewModel) {
        self.viewModel = viewModel
    }

    private var wooferFrequencyBinding: Binding<Double> {
        Binding(
            get: { self.viewModel.crossover.actualWooferFrequency },
            set: { self.viewModel.crossover.wooferCrossoverFrequency = $0 }
        )
    }

    private var tweeterFrequencyBinding: Binding<Double> {
        Binding(
            get: { self.viewModel.crossover.actualTweeterFrequency },
            set: { self.viewModel.crossover.tweeterCrossoverFrequency = $0 }
        )
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
                    // Independent Target Cut-Off Frequencies Toggle
                    Toggle("Specify Independent Cut-off Frequencies (Woofer & Tweeter)", isOn: $viewModel.crossover.enableIndependentFrequencies)
                        .font(.subheadline)
                        .padding(.bottom, 2)

                    if !viewModel.crossover.enableIndependentFrequencies {
                        // Single Crossover Frequency Slider
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
                    } else {
                        // Two Split Frequency Sliders
                        VStack(alignment: .leading, spacing: 10) {
                            // Woofer Low-Pass Cut-off
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text("Woofer Low-Pass Cut-off (fx,woofer):")
                                        .foregroundColor(.blue)
                                    Spacer()
                                    Text("\(Int(viewModel.crossover.actualWooferFrequency)) Hz")
                                        .bold()
                                        .foregroundColor(.blue)
                                }
                                Slider(value: wooferFrequencyBinding, in: 800.0...6000.0, step: 25.0)
                            }

                            // Tweeter High-Pass Cut-off
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text("Tweeter High-Pass Cut-off (fx,tweeter):")
                                        .foregroundColor(.red)
                                    Spacer()
                                    Text("\(Int(viewModel.crossover.actualTweeterFrequency)) Hz")
                                        .bold()
                                        .foregroundColor(.red)
                                }
                                Slider(value: tweeterFrequencyBinding, in: 800.0...6000.0, step: 25.0)
                            }

                            // Handover Band Info
                            let fW = viewModel.crossover.actualWooferFrequency
                            let fT = viewModel.crossover.actualTweeterFrequency
                            let centerFx = Int(round(viewModel.crossover.acousticCenterFrequency))
                            let gap = Int(round(fT - fW))
                            let gapText = gap > 0 ? "+\(gap) Hz Underlap (Gap)" : (gap < 0 ? "\(abs(gap)) Hz Overlap" : "Synchronous (0 Hz Gap)")
                            HStack {
                                Text("Acoustic Handover Center: \(centerFx) Hz • Handover: \(gapText)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
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
                        Spacer()
                        Toggle("Snap Components to Commercial E24 Series", isOn: $viewModel.crossover.snapToE24Values)
                    }

                    Toggle("Enable All-Pass Woofer Delay Compensation Network", isOn: $viewModel.crossover.enableAllpassFilter)

                    if viewModel.crossover.enableAllpassFilter {
                        let status = viewModel.crossover.allpassAlignmentStatus
                        let statusColor: Color = status == .optimal ? .green : (status == .acceptable ? .yellow : .red)
                        let statusIcon = status == .optimal ? "checkmark.circle.fill" : (status == .acceptable ? "exclamationmark.triangle.fill" : "exclamationmark.octagon.fill")

                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Image(systemName: "wand.and.stars")
                                    .foregroundColor(.teal)
                                Text("Nelder-Mead Phase Optimization:")
                                    .font(.caption)
                                    .bold()
                                    .foregroundColor(.teal)
                                Spacer()
                                if let err = viewModel.crossover.allpassOptimizationErrorDeg {
                                    Text("RMS Error: \(String(format: "%.2f°", err))")
                                        .font(.caption)
                                        .bold()
                                        .foregroundColor(statusColor)
                                }
                            }

                            if let f0 = viewModel.crossover.allpassOptimizedF0, let q = viewModel.crossover.allpassOptimizedQ {
                                Text("Optimal Resonance (F0): \(Int(f0)) Hz  •  Damping (Q): \(String(format: "%.2f", q))")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }

                            // 3-Tier Phase Alignment Status Banner (Green / Yellow / Red)
                            HStack(alignment: .center, spacing: 6) {
                                Image(systemName: statusIcon)
                                    .foregroundColor(statusColor)
                                    .font(.caption)
                                Text(status.label)
                                    .font(.caption2)
                                    .bold()
                                    .foregroundColor(statusColor)
                            }
                            .padding(6)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(statusColor.opacity(0.12))
                            .cornerRadius(6)

                            // Show additional APF setup warnings (e.g., Zobel disabled)
                            ForEach(viewModel.crossover.allpassWarnings, id: \.self) { warn in
                                HStack(alignment: .top, spacing: 6) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.orange)
                                        .font(.caption)
                                    Text(warn)
                                        .font(.caption2)
                                        .foregroundColor(.orange)
                                }
                                .padding(6)
                                .background(Color.orange.opacity(0.1))
                                .cornerRadius(6)
                            }
                        }
                        .padding(8)
                        .background(Color.teal.opacity(0.06))
                        .cornerRadius(8)
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
                    if viewModel.crossover.enableAllpassFilter {
                        GridRow {
                            Text("All-Pass Delay Comp:").bold().foregroundColor(.teal)
                            if let lap = comp.L_AP_mH { Text("L_AP = \(String(format: "%.2f", lap)) mH") }
                            if let cap = comp.C_AP_uF { Text("C_AP = \(String(format: "%.2f", cap)) µF") }
                        }
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
