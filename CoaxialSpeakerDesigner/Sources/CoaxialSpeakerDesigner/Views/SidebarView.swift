import SwiftUI

public struct SidebarView: View {
    @ObservedObject var viewModel: MainDesignerViewModel

    public init(viewModel: MainDesignerViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        ScrollView {
            Form {
            Section(header: Label("Datasheet Ingestion", systemImage: "doc.text.magnifyingglass")) {
                Button(action: {
                    #if canImport(AppKit)
                    viewModel.chooseLocalDatasheetFile()
                    #endif
                }) {
                    HStack {
                        Image(systemName: "doc.badge.plus")
                        Text("Choose Local PDF Datasheet...")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.isLoadingDatasheet)

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
                        #if canImport(AppKit)
                        if let clipboardStr = NSPasteboard.general.string(forType: .string) {
                            viewModel.datasheetURLString = clipboardStr.trimmingCharacters(in: .whitespacesAndNewlines)
                        }
                        #endif
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

            Section(header: Label("Driver Identity & Target Crossover", systemImage: "speaker.wave.2")) {
                TextField("Driver Model Name", text: $viewModel.driver.name)
                TextField("Manufacturer", text: $viewModel.driver.manufacturer)
                
                HStack {
                    Text("Decimal Separator:")
                    Spacer()
                    Picker("Decimal Separator", selection: $viewModel.isEuropeanDecimal) {
                        Text("US ( . )").tag(false)
                        Text("EU ( , )").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 140)
                }

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

            Section(header: Label("Woofer Thiele-Small Specs", systemImage: "waveform")) {
                ScrollView {
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
                .frame(maxHeight: 280)
            }

            Section(header: Label("Tweeter Specifications", systemImage: "bolt.horizontal")) {
                ScrollView {
                    VStack(spacing: 8) {
                        decimalRow("Tweeter Fs:", value: $viewModel.driver.tweeter.fs, unit: "Hz")
                        decimalRow("Tweeter Re:", value: $viewModel.driver.tweeter.re, unit: "Ω")
                        decimalRow("Tweeter Le:", value: $viewModel.driver.tweeter.le, unit: "mH")
                        decimalRow("Sensitivity:", value: $viewModel.driver.tweeter.spl, unit: "dB")
                    }
                    .padding(.vertical, 4)
                }
                .frame(maxHeight: 180)
            }
        }
        .formStyle(.grouped)
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
