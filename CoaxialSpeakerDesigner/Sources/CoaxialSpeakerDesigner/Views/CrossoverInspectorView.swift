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
                Spacer()
                Button(action: { viewModel.openLiveMonitorGrid(includeStepResponse: false) }) {
                    Label("Open 2×2 Live Monitor Grid", systemImage: "square.grid.2x2")
                        .font(.caption.bold())
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .help("Open Amplitude, Phase & Delay, Group Delay, and System Impedance in a 2×2 screen grid")

                if !viewModel.openDetachedCharts.isEmpty {
                    Button(action: { viewModel.closeAllDetachedCharts() }) {
                        Label("Close All Windows", systemImage: "xmark.circle")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }

            Divider()

            GroupBox(label: Label("Detached Live Curve Windows (Real-Time Crossover Monitor)", systemImage: "macwindow.on.rectangle")) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Detach any curve view into a live floating window to observe real-time acoustic and electrical response changes while adjusting crossover parameters.")
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(DetachedChartKind.allCases) { kind in
                                let isOpen = viewModel.isChartDetached(kind)
                                Button(action: {
                                    viewModel.toggleDetachedChart(kind)
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: isOpen ? "checkmark.rectangle.stack.fill" : "arrow.up.forward.square")
                                        Text(kind.shortTitle)
                                    }
                                    .font(.caption.bold())
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                }
                                .buttonStyle(.bordered)
                                .tint(isOpen ? .accentColor : .secondary)
                                .help(isOpen ? "Close detached \(kind.rawValue) window" : "Open \(kind.rawValue) in a floating live window")
                            }
                        }
                    }
                }
                .padding(6)
            }

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

                    Toggle("Enable CD Horn Mass Roll-Off Compensation (+6 dB/oct HF Boost across R1)", isOn: Binding(
                        get: { viewModel.crossover.enableCDHornCompensation },
                        set: { enabled in
                            viewModel.crossover.enableCDHornCompensation = enabled
                            if enabled && !viewModel.crossover.enableLPadAttenuator {
                                viewModel.crossover.enableLPadAttenuator = true
                            }
                        }
                    ))

                    if viewModel.crossover.enableCDHornCompensation {
                        VStack(alignment: .leading, spacing: 8) {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text("CD Horn Mass Break Corner Frequency (f_eq):")
                                    Spacer()
                                    Text("\(Int(viewModel.crossover.cdHornCornerFrequency)) Hz")
                                        .bold()
                                        .foregroundColor(.purple)
                                }
                                Slider(value: $viewModel.crossover.cdHornCornerFrequency, in: 2000.0...8000.0, step: 100.0)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text("Target High-Frequency Shelf Boost (ΔG_eq):")
                                    Spacer()
                                    Text(String(format: "+%.1f dB", viewModel.crossover.cdHornBoostdB))
                                        .bold()
                                        .foregroundColor(.purple)
                                }
                                Slider(value: $viewModel.crossover.cdHornBoostdB, in: 1.0...12.0, step: 0.5)
                            }

                            Text("Places a bypass capacitor C_eq (and damping resistor R_eq when ΔG_eq < L-Pad attenuation) in parallel with L-Pad series resistor R1 to compensate for Constant Directivity horn 6 dB/oct mass roll-off above \(Int(viewModel.crossover.cdHornCornerFrequency)) Hz.")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .padding(8)
                        .background(Color.purple.opacity(0.08))
                        .cornerRadius(8)
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

                    VStack(alignment: .leading, spacing: 8) {
                        Toggle("Invert Tweeter Polarity (+180°)", isOn: $viewModel.crossover.invertTweeterPolarity)
                        HStack(spacing: 16) {
                            Toggle("Snap Components to Commercial E12 Series", isOn: $viewModel.crossover.snapToStandardValues)
                            Toggle("Snap Components to Commercial E24 Series", isOn: $viewModel.crossover.snapToE24Values)
                            Spacer()
                        }
                    }

                    Toggle("Enable All-Pass Woofer Delay Compensation Network", isOn: $viewModel.crossover.enableAllpassFilter)

                    let status = viewModel.crossover.allpassAlignmentStatus
                    let statusColor: Color = status == .optimal ? .green : (status == .acceptable ? .yellow : .red)
                    let statusIcon = status == .optimal ? "checkmark.circle.fill" : (status == .acceptable ? "exclamationmark.triangle.fill" : "exclamationmark.octagon.fill")

                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Image(systemName: viewModel.crossover.enableAllpassFilter ? "wand.and.stars" : "waveform")
                                .foregroundColor(.teal)
                            Text(viewModel.crossover.enableAllpassFilter ? "Nelder-Mead Phase Optimization:" : "Crossover Phase Alignment:")
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

                        if viewModel.crossover.enableAllpassFilter,
                           let f0 = viewModel.crossover.allpassOptimizedF0,
                           let q = viewModel.crossover.allpassOptimizedQ {
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
                        if viewModel.crossover.enableAllpassFilter {
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
                    }
                    .id(viewModel.simulationRevision)
                    .padding(8)
                    .background(Color.teal.opacity(0.06))
                    .cornerRadius(8)
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
                    if viewModel.crossover.enableLPadAttenuator || viewModel.crossover.enableCDHornCompensation {
                        GridRow {
                            Text("L-Pad Attenuator:").bold().foregroundColor(.purple)
                            if let r1 = comp.R1_lpad_ohms { Text("R1 (Series) = \(String(format: "%.2f", r1)) Ω") }
                            if let r2 = comp.R2_lpad_ohms { Text("R2 (Parallel) = \(String(format: "%.2f", r2)) Ω") }
                        }
                    }
                    if viewModel.crossover.enableCDHornCompensation {
                        GridRow {
                            Text("CD Horn Mass EQ:").bold().foregroundColor(.purple)
                            if let ccd = comp.C_cd_uF { Text("C_eq (Bypass || R1) = \(String(format: "%.2f", ccd)) µF") }
                            if let rcd = comp.R_cd_ohms { Text("R_eq (Shelf Damping) = \(String(format: "%.2f", rcd)) Ω") }
                        }
                    }
                }
                .padding(8)
            }
        }
        .padding()
    }
}
