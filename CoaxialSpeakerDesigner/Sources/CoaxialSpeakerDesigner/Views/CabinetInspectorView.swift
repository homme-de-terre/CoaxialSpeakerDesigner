import SwiftUI

public struct CabinetInspectorView: View {
    @ObservedObject var viewModel: MainDesignerViewModel

    public init(viewModel: MainDesignerViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "cube.box.fill")
                    .font(.title2)
                    .foregroundColor(.accentColor)
                Text("Closed (Sealed) Cabinet Designer")
                    .font(.title2)
                    .bold()

                Spacer()

                Button(action: {
                    viewModel.recalculateSimulation()
                    viewModel.statusMessage = "Simulation restarted with updated cabinet parameters."
                }) {
                    Label("Restart Simulation", systemImage: "arrow.clockwise.circle.fill")
                }
                .buttonStyle(.borderedProminent)
            }

            Divider()

            // Enclosure Architecture Selector (Sealed 2nd-Order vs Vented 4th-Order)
            Picker("Enclosure Architecture:", selection: $viewModel.cabinet.enclosureType) {
                ForEach(EnclosureType.allCases) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .pickerStyle(.segmented)
            .padding(.bottom, 4)

            let effQts = viewModel.driver.wooferTS.qts > 0 ? viewModel.driver.wooferTS.qts : (viewModel.driver.wooferTS.qes > 0 && viewModel.driver.wooferTS.qms > 0 ? (viewModel.driver.wooferTS.qes * viewModel.driver.wooferTS.qms) / (viewModel.driver.wooferTS.qes + viewModel.driver.wooferTS.qms) : 0.35)
            let minF3 = viewModel.driver.wooferTS.fs * (0.70710678 / max(effQts, 0.01))

            if viewModel.cabinet.enclosureType == .sealed {
                if viewModel.cabinet.alignment == .targetF3 && viewModel.cabinet.targetF3 < minF3 {
                    HStack(spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("Target f3 (\(Int(viewModel.cabinet.targetF3)) Hz) is below the physical sealed-box limit (\(String(format: "%.1f", minF3)) Hz) for Qts = \(String(format: "%.3f", effQts)). Enclosure is aligned to Butterworth B2 (minimum achievable sealed cutoff f3 = \(String(format: "%.1f", minF3)) Hz). Switch to Vented (Bass-Reflex) mode to extend bass down to 35–45 Hz.")
                            .font(.caption)
                            .foregroundColor(.primary)
                    }
                    .padding(10)
                    .background(Color.orange.opacity(0.15))
                    .cornerRadius(8)
                } else if viewModel.cabinet.alignment == .customQtc && viewModel.cabinet.targetQtc <= effQts {
                    HStack(spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("Target Qtc (\(String(format: "%.3f", viewModel.cabinet.targetQtc))) is ≤ driver Qts (\(String(format: "%.3f", effQts))). A sealed enclosure cannot reduce driver Q.")
                            .font(.caption)
                            .foregroundColor(.primary)
                    }
                    .padding(10)
                    .background(Color.orange.opacity(0.15))
                    .cornerRadius(8)
                }
            } else {
                HStack(spacing: 10) {
                    Image(systemName: "wind")
                        .foregroundColor(.teal)
                    Text("4th-Order Bass-Reflex Architecture: Uses Helmholtz acoustic resonance to dramatically extend low-frequency cutoff with steep 24 dB/oct roll-off below Fb.")
                        .font(.caption)
                        .foregroundColor(.teal)
                }
                .padding(10)
                .background(Color.teal.opacity(0.12))
                .cornerRadius(8)
            }

            GroupBox(label: Label(viewModel.cabinet.enclosureType == .sealed ? "Sealed Cabinet Parameters" : "4th-Order Vented Enclosure Tuning", systemImage: viewModel.cabinet.enclosureType == .sealed ? "slider.horizontal.3" : "wind")) {
                VStack(alignment: .leading, spacing: 14) {
                    if viewModel.cabinet.enclosureType == .sealed {
                        Picker("Alignment Design Mode:", selection: $viewModel.cabinet.alignment) {
                            ForEach(AlignmentType.allCases) { alignment in
                                Text(alignment.rawValue).tag(alignment)
                            }
                        }
                        .pickerStyle(.menu)

                        // Target f3 Slider (if Target f3 mode active)
                        if viewModel.cabinet.alignment == .targetF3 {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text("Target Lower -3 dB Cutoff (f3):")
                                    Spacer()
                                    if viewModel.cabinet.targetF3 < minF3 {
                                        Text("\(Int(viewModel.cabinet.targetF3)) Hz (Sealed Min: \(String(format: "%.1f", minF3)) Hz)")
                                            .bold()
                                            .foregroundColor(.orange)
                                    } else {
                                        Text("\(Int(viewModel.cabinet.targetF3)) Hz")
                                            .bold()
                                            .foregroundColor(.accentColor)
                                    }
                                }
                                Slider(value: $viewModel.cabinet.targetF3, in: 25.0...250.0, step: 1.0)
                            }
                        }

                        // System Qtc Slider (if Custom Qtc mode active)
                        if viewModel.cabinet.alignment == .customQtc {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text("Target Total System Q (Qtc):")
                                    Spacer()
                                    Text(String(format: "%.3f", viewModel.cabinet.targetQtc))
                                        .bold()
                                        .foregroundColor(.accentColor)
                                }
                                Slider(value: $viewModel.cabinet.targetQtc, in: 0.35...1.20, step: 0.01)
                            }
                        }
                    } else {
                        // Vented Alignment Mode Picker
                        Picker("Vented Alignment Preset:", selection: $viewModel.cabinet.ventedAlignment) {
                            ForEach(VentedAlignmentType.allCases) { vAlign in
                                Text(vAlign.rawValue).tag(vAlign)
                            }
                        }
                        .pickerStyle(.menu)

                        // Tuning Frequency Fb Slider
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Port Helmholtz Tuning Frequency (Fb):")
                                Spacer()
                                Text("\(String(format: "%.1f", viewModel.cabinet.actualTuningFb(for: viewModel.driver.wooferTS))) Hz")
                                    .bold()
                                    .foregroundColor(.teal)
                            }
                            Slider(value: $viewModel.cabinet.tuningFrequencyFb, in: 18.0...80.0, step: 0.5)
                        }

                        // Port Diameter & Length Controls
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 20) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Port Duct Diameter:")
                                        .font(.caption).foregroundColor(.secondary)
                                    HStack {
                                        Text(String(format: "%.1f cm (%.1f in)", viewModel.cabinet.portDiameterCm, viewModel.cabinet.portDiameterCm / 2.54))
                                            .font(.caption).bold()
                                    }
                                }
                                Slider(value: $viewModel.cabinet.portDiameterCm, in: 5.0...20.0, step: 0.5)

                                Picker("Number of Ports:", selection: $viewModel.cabinet.numberOfPorts) {
                                    Text("1 Vent").tag(1)
                                    Text("2 Vents").tag(2)
                                    Text("3 Vents").tag(3)
                                }
                                .pickerStyle(.menu)
                                .frame(width: 120)
                            }

                            let lv = viewModel.cabinet.computedPortLengthCm(for: viewModel.driver.wooferTS)
                            let minDia = viewModel.cabinet.minRecommendedPortDiameterCm(for: viewModel.driver.wooferTS)
                            let isChuffingRisk = viewModel.cabinet.portDiameterCm < minDia

                            HStack {
                                Text("Calculated Port Length:")
                                    .font(.caption).foregroundColor(.secondary)
                                Text(String(format: "%.1f cm (%.2f inches)", lv, lv / 2.54))
                                    .font(.caption).bold().foregroundColor(.teal)
                                Spacer()
                                Text("Min Recommended Port Dia: \(String(format: "%.1f cm", minDia))")
                                    .font(.caption2)
                                    .foregroundColor(isChuffingRisk ? .orange : .secondary)
                            }
                        }
                    }

                    // Stuffing / Filling Absorption Selector
                    Picker("Acoustic Lining / Stuffing:", selection: $viewModel.cabinet.stuffing) {
                        ForEach(StuffingLevel.allCases) { stuffing in
                            Text(stuffing.rawValue).tag(stuffing)
                        }
                    }
                    .pickerStyle(.menu)

                    // Volume Override
                    Toggle("Manual Enclosure Volume Override (Vb)", isOn: $viewModel.cabinet.isManualVolumeOverride)

                    if viewModel.cabinet.isManualVolumeOverride {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("Manual Net Internal Volume (Vb):")
                                Spacer()
                                TextField("Vb Liters", value: $viewModel.cabinet.manualNetVolumeLiters, format: .number)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 80)
                                Text("Liters (\(String(format: "%.2f", viewModel.cabinet.manualNetVolumeLiters / 28.3168)) ft³)")
                            }
                            Slider(value: $viewModel.cabinet.manualNetVolumeLiters, in: 5.0...300.0, step: 0.5)
                        }
                    }

                    Divider()

                    // Restart Simulation Trigger Button inside Box
                    HStack {
                        Button(action: {
                            viewModel.recalculateSimulation()
                            viewModel.statusMessage = "Simulation recalculated and updated with new cabinet parameters."
                        }) {
                            HStack {
                                Image(systemName: "play.circle.fill")
                                Text("Restart Simulation with Updated Parameters")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                    }
                }
                .padding(8)
            }
            .onChange(of: viewModel.cabinet) { _ in
                viewModel.recalculateSimulation()
            }

            // Real-time Calculated Cabinet Output Metrics
            let physicalVb = viewModel.cabinet.computedPhysicalVolumeLiters(for: viewModel.driver.wooferTS)
            let physicalCuFt = viewModel.cabinet.computedPhysicalVolumeCubicFeet(for: viewModel.driver.wooferTS)
            let acousticVb = viewModel.cabinet.computedAcousticVolumeLiters(for: viewModel.driver.wooferTS)
            let fc = viewModel.cabinet.computedResonanceFc(for: viewModel.driver.wooferTS)
            let qtc = viewModel.cabinet.actualQtc(for: viewModel.driver.wooferTS)
            let actualF3 = viewModel.cabinet.actualF3(for: viewModel.driver.wooferTS)
            let alpha = viewModel.cabinet.computedComplianceAlpha(for: viewModel.driver.wooferTS)
            let fb = viewModel.cabinet.actualTuningFb(for: viewModel.driver.wooferTS)

            GroupBox(label: Label(viewModel.cabinet.enclosureType == .sealed ? "Calculated Sealed Enclosure Sizing" : "Calculated 4th-Order Vented Enclosure Sizing", systemImage: "function")) {
                Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 10) {
                    GridRow {
                        MetricCard(title: "Physical Internal Box Volume", value: String(format: "%.2f L (%.2f ft³)", physicalVb, physicalCuFt), icon: "cube.fill", color: .blue)
                        MetricCard(title: "Effective Acoustic Volume", value: String(format: "%.2f L", acousticVb), icon: "waveform", color: .teal)
                    }
                    GridRow {
                        if viewModel.cabinet.enclosureType == .sealed {
                            MetricCard(title: "System Resonance (Fc)", value: String(format: "%.1f Hz", fc), icon: "waveform.path", color: .orange)
                            MetricCard(title: "System Total Q (Qtc)", value: String(format: "%.3f", qtc), icon: "gauge.medium", color: .purple)
                        } else {
                            MetricCard(title: "Port Helmholtz Resonance (Fb)", value: String(format: "%.1f Hz", fb), icon: "wind", color: .teal)
                            let portLen = viewModel.cabinet.computedPortLengthCm(for: viewModel.driver.wooferTS)
                            MetricCard(title: "Required Port Duct Length", value: String(format: "%.1f cm (%.1f in)", portLen, portLen / 2.54), icon: "ruler", color: .indigo)
                        }
                    }
                    GridRow {
                        MetricCard(title: "Actual Lower -3dB Cutoff (f3)", value: String(format: "%.1f Hz", actualF3), icon: "chart.line.downtrend.xyaxis", color: .green)
                        MetricCard(title: "Compliance Ratio (α = Vas/Vb)", value: String(format: "%.2f", alpha), icon: "arrow.up.and.down.square", color: .purple)
                    }
                }
                .padding(8)
            }

            // Alignment Comparison Matrix
            GroupBox(label: Label("Qtc vs Box Volume (Vb) Sizing Matrix for \(viewModel.driver.name)", systemImage: "tablecells")) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Comparison of required box volumes and resulting cutoff frequencies for different Qtc targets:")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    ScrollView(.horizontal, showsIndicators: false) {
                        Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 8) {
                            GridRow {
                                Text("Target Alignment").bold()
                                Text("Target Qtc").bold()
                                Text("Box Volume (Vb)").bold()
                                Text("Resonance (Fc)").bold()
                                Text("Cutoff (f3)").bold()
                            }
                            .font(.caption)

                            Divider()

                            let targets: [(String, Double)] = [
                                ("Butterworth B2", 0.7071),
                                ("Bessel Alignment", 0.5774),
                                ("Critically Damped", 0.5000),
                                ("Extended Low Q", 0.4500),
                                ("Large Box Low Q", 0.4000)
                            ]

                            ForEach(targets, id: \.0) { target in
                                if target.1 <= viewModel.driver.wooferTS.qts {
                                    GridRow {
                                        Text(target.0).bold().foregroundColor(.secondary)
                                        Text(String(format: "%.3f", target.1))
                                        Text("N/A (Qtc ≤ Qts)").italic().foregroundColor(.secondary)
                                        Text("-").foregroundColor(.secondary)
                                        Text("-").foregroundColor(.secondary)
                                    }
                                    .font(.caption)
                                    .lineLimit(1)
                                } else {
                                    let ratio = target.1 / max(viewModel.driver.wooferTS.qts, 0.01)
                                    let a = pow(ratio, 2) - 1.0
                                    let acVb = viewModel.driver.wooferTS.vas / a
                                    let physVb = acVb / viewModel.cabinet.stuffing.volumeGainFactor
                                    let physFt = physVb / 28.3168
                                    let f_c = viewModel.driver.wooferTS.fs * sqrt(1.0 + a)
                                    let b_val = (1.0 / pow(target.1, 2)) - 2.0
                                    let x_val = (b_val + sqrt(pow(b_val, 2) + 4.0)) / 2.0
                                    let f3_val = f_c * sqrt(x_val)

                                    GridRow {
                                        Text(target.0).bold().foregroundColor(.blue)
                                        Text(String(format: "%.3f", target.1))
                                        Text(String(format: "%.2f L (%.2f ft³)", physVb, physFt)).bold()
                                        Text(String(format: "%.1f Hz", f_c))
                                        Text(String(format: "%.1f Hz", f3_val)).bold().foregroundColor(.green)
                                    }
                                    .font(.caption)
                                    .lineLimit(1)
                                }
                            }
                        }
                        .padding(6)
                    }
                }
            }
        }
        .padding()
    }
}

public struct MetricCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    public var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
                .frame(width: 32, height: 32)
                .background(color.opacity(0.15))
                .cornerRadius(8)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.headline)
                    .bold()
            }
            Spacer()
        }
        .padding(8)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
}
