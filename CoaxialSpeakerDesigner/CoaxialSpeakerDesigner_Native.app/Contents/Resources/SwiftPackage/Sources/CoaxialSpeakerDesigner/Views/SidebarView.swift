import SwiftUI
import AppKit

public struct SidebarView: View {
    @ObservedObject var viewModel: MainDesignerViewModel

    public init(viewModel: MainDesignerViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                // MARK: - Section 1: Design Project File
                GroupBox(label: Label("Design Project File", systemImage: "folder.badge.gearshape")) {
                    VStack(spacing: 8) {
                        Button(action: {
                            viewModel.saveDesignToFile()
                        }) {
                            HStack {
                                Image(systemName: "square.and.arrow.down")
                                Text("Save Design...")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .help("Save entire design to .json file (⌘S)")

                        Button(action: {
                            viewModel.loadDesignFromFile()
                        }) {
                            HStack {
                                Image(systemName: "folder")
                                Text("Load Design...")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .help("Load design from .json file (⌘O)")
                    }
                    .padding(.vertical, 4)
                }

                // MARK: - Section 2: Datasheet Ingestion
                GroupBox(label: Label("Datasheet Ingestion", systemImage: "doc.text.magnifyingglass")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Button(action: {
                            viewModel.chooseLocalDatasheetFile()
                        }) {
                            HStack {
                                Image(systemName: "doc.badge.plus")
                                Text("Choose Local PDF Datasheet...")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .disabled(viewModel.isLoadingDatasheet)

                        Button(action: {
                            viewModel.loadAltec604Preset()
                        }) {
                            HStack {
                                Image(systemName: "speaker.wave.3")
                                Text("Load Altec 604-8K Preset (CLIO)")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)

                        Button(action: {
                            viewModel.selectedTab = 6
                        }) {
                            HStack {
                                Image(systemName: "doc.text")
                                Text("FRD Import/Export...")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .help("Open FRD Response Curve Import & Export Dialog (⇧⌘I)")

                        HStack {
                            VStack { Divider() }
                            Text("or from web URL")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            VStack { Divider() }
                        }

                        HStack(spacing: 6) {
                            TextField("https://example.com/driver_datasheet.pdf", text: $viewModel.datasheetURLString)
                                .textFieldStyle(.roundedBorder)

                            Button(action: {
                                if let clipboardStr = NSPasteboard.general.string(forType: .string) {
                                    viewModel.datasheetURLString = clipboardStr.trimmingCharacters(in: .whitespacesAndNewlines)
                                }
                            }) {
                                Image(systemName: "doc.on.clipboard")
                            }
                            .buttonStyle(.bordered)
                            .help("Paste URL from Clipboard")
                        }

                        Button(action: {
                            viewModel.loadDatasheetFromURL()
                        }) {
                            HStack {
                                if viewModel.isLoadingDatasheet {
                                    ProgressView()
                                        .controlSize(.small)
                                } else {
                                    Image(systemName: "square.and.arrow.down")
                                }
                                Text("Fetch & Parse URL")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(viewModel.isLoadingDatasheet || viewModel.datasheetURLString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                        if !viewModel.missingParameters.isEmpty {
                            HStack(alignment: .top, spacing: 6) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Missing from datasheet:")
                                        .font(.caption.bold())
                                        .foregroundColor(.orange)
                                    Text(viewModel.missingParameters.joined(separator: ", "))
                                        .font(.caption2)
                                        .foregroundColor(.orange)
                                    Text("Please enter manually below.")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(6)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.orange.opacity(0.12))
                            .cornerRadius(6)
                        }

                        if !viewModel.plausibilityWarnings.isEmpty {
                            HStack(alignment: .top, spacing: 6) {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .foregroundColor(.red)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Implausible parameter warning:")
                                        .font(.caption.bold())
                                        .foregroundColor(.red)
                                    ForEach(viewModel.plausibilityWarnings, id: \.self) { warn in
                                        Text("• \(warn)")
                                            .font(.caption2)
                                            .foregroundColor(.red)
                                    }
                                }
                            }
                            .padding(6)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.red.opacity(0.12))
                            .cornerRadius(6)
                        }

                        if let msg = viewModel.statusMessage {
                            Text(msg)
                                .font(.caption)
                                .foregroundColor(viewModel.missingParameters.isEmpty && viewModel.plausibilityWarnings.isEmpty ? .green : .orange)
                        }
                        if let err = viewModel.errorMessage {
                            Text(err)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                    .padding(.vertical, 4)
                }

                // MARK: - Section 3: Driver Identity & Target Crossover
                GroupBox(label: Label("Driver Identity & Target Crossover", systemImage: "speaker.wave.2")) {
                    VStack(alignment: .leading, spacing: 8) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Model Name:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            TextField("Driver Model Name", text: $viewModel.driver.name)
                                .textFieldStyle(.roundedBorder)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Manufacturer:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            TextField("Manufacturer", text: $viewModel.driver.manufacturer)
                                .textFieldStyle(.roundedBorder)
                        }

                        HStack {
                            Text("Decimal Separator:")
                                .font(.caption)
                            Spacer()
                            Picker("Decimal Separator", selection: $viewModel.isEuropeanDecimal) {
                                Text("US ( . )").tag(false)
                                Text("EU ( , )").tag(true)
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 140)
                        }

                        if viewModel.crossover.enableIndependentFrequencies {
                            HStack(spacing: 6) {
                                Text("Woofer LP fx:")
                                    .lineLimit(1)
                                    .foregroundColor(.blue)
                                Spacer(minLength: 8)
                                HStack(spacing: 4) {
                                    TextField("", text: Binding(
                                        get: { String(format: "%.0f", viewModel.crossover.actualWooferFrequency) },
                                        set: { if let v = Double($0) { viewModel.crossover.wooferCrossoverFrequency = v } }
                                    ))
                                    .labelsHidden()
                                    .frame(width: 65)
                                    .textFieldStyle(.roundedBorder)
                                    .multilineTextAlignment(.trailing)
                                    Text("Hz")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .frame(width: 28, alignment: .leading)
                                }
                            }

                            HStack(spacing: 6) {
                                Text("Tweeter HP fx:")
                                    .lineLimit(1)
                                    .foregroundColor(.red)
                                Spacer(minLength: 8)
                                HStack(spacing: 4) {
                                    TextField("", text: Binding(
                                        get: { String(format: "%.0f", viewModel.crossover.actualTweeterFrequency) },
                                        set: { if let v = Double($0) { viewModel.crossover.tweeterCrossoverFrequency = v } }
                                    ))
                                    .labelsHidden()
                                    .frame(width: 65)
                                    .textFieldStyle(.roundedBorder)
                                    .multilineTextAlignment(.trailing)
                                    Text("Hz")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .frame(width: 28, alignment: .leading)
                                }
                            }
                        } else {
                            HStack(spacing: 6) {
                                Text("Crossover Freq:")
                                    .lineLimit(1)
                                Spacer(minLength: 8)
                                HStack(spacing: 4) {
                                    TextField("", text: decimalBinding(for: $viewModel.crossover.crossoverFrequency))
                                        .labelsHidden()
                                        .frame(width: 65)
                                        .textFieldStyle(.roundedBorder)
                                        .multilineTextAlignment(.trailing)
                                    Text("Hz")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .frame(width: 28, alignment: .leading)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }

                // MARK: - Section 4: Woofer Thiele-Small Specs
                GroupBox(label: Label("Woofer Thiele-Small Specs", systemImage: "waveform")) {
                    VStack(spacing: 8) {
                        decimalRow("Fs:", value: $viewModel.driver.wooferTS.fs, unit: "Hz")
                        decimalRow("Qes:", value: $viewModel.driver.wooferTS.qes)
                        decimalRow("Qms:", value: $viewModel.driver.wooferTS.qms)
                        decimalRow("Qts:", value: $viewModel.driver.wooferTS.qts)
                        decimalRow("Vas:", value: $viewModel.driver.wooferTS.vas, unit: "L")
                        decimalRow("Re:", value: $viewModel.driver.wooferTS.re, unit: "Ω")
                        decimalRow("Le:", value: $viewModel.driver.wooferTS.le, unit: "mH")
                        decimalRow("Sd:", value: $viewModel.driver.wooferTS.sd, unit: "cm²")
                        decimalRow("Xmax:", value: $viewModel.driver.wooferTS.xmax, unit: "mm")
                        decimalRow("Sensitivity:", value: $viewModel.driver.wooferTS.spl, unit: "dB")
                    }
                    .padding(.vertical, 4)
                }

                // MARK: - Section 5: Tweeter Specifications
                GroupBox(label: Label("Tweeter Specifications", systemImage: "bolt.horizontal")) {
                    VStack(spacing: 8) {
                        decimalRow("Tweeter Fs:", value: $viewModel.driver.tweeter.fs, unit: "Hz")
                        decimalRow("Tweeter Re:", value: $viewModel.driver.tweeter.re, unit: "Ω")
                        decimalRow("Tweeter Le:", value: $viewModel.driver.tweeter.le, unit: "mH")
                        decimalRow("Sensitivity:", value: $viewModel.driver.tweeter.spl, unit: "dB")
                    }
                    .padding(.vertical, 4)
                }
            }
            .padding(12)
        }
    }

    private func decimalBinding(for valueBinding: Binding<Double>) -> Binding<String> {
        Binding<String>(
            get: {
                let val = valueBinding.wrappedValue
                guard val != 0 else { return "0" }
                let str = String(format: "%g", val)
                return viewModel.isEuropeanDecimal ? str.replacingOccurrences(of: ".", with: ",") : str
            },
            set: { newStr in
                let clean = newStr.trimmingCharacters(in: .whitespacesAndNewlines)
                    .replacingOccurrences(of: ",", with: ".")
                if let num = Double(clean) {
                    if valueBinding.wrappedValue != num {
                        valueBinding.wrappedValue = num
                    }
                }
            }
        )
    }

    @ViewBuilder
    private func decimalRow(_ title: String, value: Binding<Double>, unit: String = "") -> some View {
        HStack(alignment: .center, spacing: 6) {
            Text(title)
                .font(.body)
                .lineLimit(1)
            Spacer(minLength: 8)
            HStack(spacing: 4) {
                TextField("", text: decimalBinding(for: value))
                    .labelsHidden()
                    .frame(width: 65)
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.trailing)
                if !unit.isEmpty {
                    Text(unit)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 28, alignment: .leading)
                } else {
                    Spacer().frame(width: 28)
                }
            }
        }
    }
}
