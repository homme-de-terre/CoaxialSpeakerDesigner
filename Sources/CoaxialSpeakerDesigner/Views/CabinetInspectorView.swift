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

            GroupBox(label: Label("Cabinet Alignment & Parameters", systemImage: "slider.horizontal.3")) {
                VStack(alignment: .leading, spacing: 14) {
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
                                Text("\(Int(viewModel.cabinet.targetF3)) Hz")
                                    .bold()
                                    .foregroundColor(.accentColor)
                            }
                            Slider(value: $viewModel.cabinet.targetF3, in: 30.0...120.0, step: 1.0)
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

                    // Stuffing / Filling Absorption Selector
                    Picker("Acoustic Polyfill Stuffing Level:", selection: $viewModel.cabinet.stuffing) {
                        ForEach(StuffingLevel.allCases) { stuffing in
                            Text(stuffing.rawValue).tag(stuffing)
                        }
                    }
                    .pickerStyle(.menu)

                    // Volume Override
                    Toggle("Manual Enclosure Volume Override", isOn: $viewModel.cabinet.isManualVolumeOverride)

                    if viewModel.cabinet.isManualVolumeOverride {
                        HStack {
                            Text("Manual Net Internal Volume (Vb):")
                            Spacer()
                            TextField("Vb Liters", value: $viewModel.cabinet.manualNetVolumeLiters, format: .number)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 80)
                            Text("Liters (\(String(format: "%.2f", viewModel.cabinet.manualNetVolumeLiters / 28.3168)) ft³)")
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

            // Real-time Calculated Cabinet Output Metrics
            let physicalVb = viewModel.cabinet.computedPhysicalVolumeLiters(for: viewModel.driver.wooferTS)
            let physicalCuFt = viewModel.cabinet.computedPhysicalVolumeCubicFeet(for: viewModel.driver.wooferTS)
            let acousticVb = viewModel.cabinet.computedAcousticVolumeLiters(for: viewModel.driver.wooferTS)
            let fc = viewModel.cabinet.computedResonanceFc(for: viewModel.driver.wooferTS)
            let qtc = viewModel.cabinet.actualQtc(for: viewModel.driver.wooferTS)
            let actualF3 = viewModel.cabinet.actualF3(for: viewModel.driver.wooferTS)
            let alpha = viewModel.cabinet.computedComplianceAlpha(for: viewModel.driver.wooferTS)

            GroupBox(label: Label("Calculated Sealed Cabinet Enclosure Sizing", systemImage: "function")) {
                Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 10) {
                    GridRow {
                        MetricCard(title: "Physical Internal Box Volume", value: String(format: "%.2f L (%.2f ft³)", physicalVb, physicalCuFt), icon: "cube.fill", color: .blue)
                        MetricCard(title: "Effective Acoustic Volume", value: String(format: "%.2f L", acousticVb), icon: "waveform", color: .teal)
                    }
                    GridRow {
                        MetricCard(title: "System Resonance (Fc)", value: String(format: "%.1f Hz", fc), icon: "waveform.path", color: .orange)
                        MetricCard(title: "System Total Q (Qtc)", value: String(format: "%.3f", qtc), icon: "gauge.medium", color: .purple)
                    }
                    GridRow {
                        MetricCard(title: "Actual Cutoff Frequency (f3)", value: String(format: "%.1f Hz", actualF3), icon: "chart.line.downtrend.xyaxis", color: .green)
                        MetricCard(title: "Compliance Ratio (α = Vas/Vb)", value: String(format: "%.2f", alpha), icon: "arrow.up.and.down.square", color: .indigo)
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

                    Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 6) {
                        GridRow {
                            Text("Target Alignment").bold()
                            Text("Target Qtc").bold()
                            Text("Physical Vb (Liters)").bold()
                            Text("Physical Vb (cu ft)").bold()
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
                            let ratio = target.1 / max(viewModel.driver.wooferTS.qts, 0.01)
                            let a = max(pow(ratio, 2) - 1.0, 0.05)
                            let acVb = viewModel.driver.wooferTS.vas / a
                            let physVb = acVb / viewModel.cabinet.stuffing.volumeGainFactor
                            let physFt = physVb / 28.3168
                            let f_c = viewModel.driver.wooferTS.fs * sqrt(1.0 + a)
                            let k_val = 1.0 - (1.0 / (2.0 * pow(target.1, 2)))
                            let f3_val = f_c * sqrt(k_val + sqrt(pow(k_val, 2) + 1.0))

                            GridRow {
                                Text(target.0).bold().foregroundColor(.blue)
                                Text(String(format: "%.3f", target.1))
                                Text(String(format: "%.2f L", physVb)).bold()
                                Text(String(format: "%.2f ft³", physFt))
                                Text(String(format: "%.1f Hz", f_c))
                                Text(String(format: "%.1f Hz", f3_val)).bold().foregroundColor(.green)
                            }
                            .font(.caption)
                        }
                    }
                    .padding(6)
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
