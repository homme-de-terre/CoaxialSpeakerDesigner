import SwiftUI

public struct SidebarView: View {
    @ObservedObject var viewModel: MainDesignerViewModel

    public init(viewModel: MainDesignerViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
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
                    Text("Crossover Freq:")
                    Spacer()
                    HStack(spacing: 4) {
                        TextField("fx", value: $viewModel.crossover.crossoverFrequency, format: .number)
                            .frame(width: 70)
                        Text("Hz")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(width: 28, alignment: .leading)
                    }
                }
            }

            Section(header: Label("Woofer Thiele-Small Specs", systemImage: "waveform")) {
                Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
                    GridRow {
                        Text("Fs:")
                        Spacer()
                        HStack(spacing: 4) {
                            TextField("Fs", value: $viewModel.driver.wooferTS.fs, format: .number)
                                .frame(width: 70)
                            Text("Hz")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(width: 28, alignment: .leading)
                        }
                    }
                    GridRow {
                        Text("Qes:")
                        Spacer()
                        HStack(spacing: 4) {
                            TextField("Qes", value: $viewModel.driver.wooferTS.qes, format: .number)
                                .frame(width: 70)
                            Text("")
                                .frame(width: 28)
                        }
                    }
                    GridRow {
                        Text("Qms:")
                        Spacer()
                        HStack(spacing: 4) {
                            TextField("Qms", value: $viewModel.driver.wooferTS.qms, format: .number)
                                .frame(width: 70)
                            Text("")
                                .frame(width: 28)
                        }
                    }
                    GridRow {
                        Text("Qts:")
                        Spacer()
                        HStack(spacing: 4) {
                            TextField("Qts", value: $viewModel.driver.wooferTS.qts, format: .number)
                                .frame(width: 70)
                            Text("")
                                .frame(width: 28)
                        }
                    }
                    GridRow {
                        Text("Vas:")
                        Spacer()
                        HStack(spacing: 4) {
                            TextField("Vas", value: $viewModel.driver.wooferTS.vas, format: .number)
                                .frame(width: 70)
                            Text("L")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(width: 28, alignment: .leading)
                        }
                    }
                    GridRow {
                        Text("Re:")
                        Spacer()
                        HStack(spacing: 4) {
                            TextField("Re", value: $viewModel.driver.wooferTS.re, format: .number)
                                .frame(width: 70)
                            Text("Ω")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(width: 28, alignment: .leading)
                        }
                    }
                    GridRow {
                        Text("Le:")
                        Spacer()
                        HStack(spacing: 4) {
                            TextField("Le", value: $viewModel.driver.wooferTS.le, format: .number)
                                .frame(width: 70)
                            Text("mH")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(width: 28, alignment: .leading)
                        }
                    }
                    GridRow {
                        Text("Sd:")
                        Spacer()
                        HStack(spacing: 4) {
                            TextField("Sd", value: $viewModel.driver.wooferTS.sd, format: .number)
                                .frame(width: 70)
                            Text("cm²")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(width: 28, alignment: .leading)
                        }
                    }
                    GridRow {
                        Text("Xmax:")
                        Spacer()
                        HStack(spacing: 4) {
                            TextField("Xmax", value: $viewModel.driver.wooferTS.xmax, format: .number)
                                .frame(width: 70)
                            Text("mm")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(width: 28, alignment: .leading)
                        }
                    }
                    GridRow {
                        Text("Sensitivity:")
                        Spacer()
                        HStack(spacing: 4) {
                            TextField("SPL", value: $viewModel.driver.wooferTS.spl, format: .number)
                                .frame(width: 70)
                            Text("dB")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(width: 28, alignment: .leading)
                        }
                    }
                }
                .padding(.vertical, 8)
            }

            Section(header: Label("Tweeter Specifications", systemImage: "bolt.horizontal")) {
                Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 6) {
                    GridRow {
                        Text("Tweeter Fs:")
                        Spacer()
                        HStack(spacing: 4) {
                            TextField("Fs", value: $viewModel.driver.tweeter.fs, format: .number)
                                .frame(width: 70)
                            Text("Hz")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(width: 28, alignment: .leading)
                        }
                    }
                    GridRow {
                        Text("Tweeter Re:")
                        Spacer()
                        HStack(spacing: 4) {
                            TextField("Re", value: $viewModel.driver.tweeter.re, format: .number)
                                .frame(width: 70)
                            Text("Ω")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(width: 28, alignment: .leading)
                        }
                    }
                    GridRow {
                        Text("Tweeter Le:")
                        Spacer()
                        HStack(spacing: 4) {
                            TextField("Le", value: $viewModel.driver.tweeter.le, format: .number)
                                .frame(width: 70)
                            Text("mH")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(width: 28, alignment: .leading)
                        }
                    }
                    GridRow {
                        Text("Sensitivity:")
                        Spacer()
                        HStack(spacing: 4) {
                            TextField("SPL", value: $viewModel.driver.tweeter.spl, format: .number)
                                .frame(width: 70)
                            Text("dB")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(width: 28, alignment: .leading)
                        }
                    }
                }
            }
                        Text("Sensitivity (dB):")
                        Spacer()
                        TextField("SPL", value: $viewModel.driver.tweeter.spl, format: .number)
                            .frame(width: 70)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
}
