import SwiftUI

public struct SidebarView: View {
    @ObservedObject var viewModel: MainDesignerViewModel

    public init(viewModel: MainDesignerViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        Form {
            Section(header: Label("Datasheet URL Ingestion", systemImage: "link")) {
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
                        Text("Fetch & Parse Datasheet")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isLoadingDatasheet)

                if let msg = viewModel.statusMessage {
                    Text(msg)
                        .font(.caption)
                        .foregroundColor(.green)
                }
                if let err = viewModel.errorMessage {
                    Text(err)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }

            Section(header: Label("Driver Identity", systemImage: "speaker.wave.2")) {
                TextField("Driver Model Name", text: $viewModel.driver.name)
                TextField("Manufacturer", text: $viewModel.driver.manufacturer)
            }

            Section(header: Label("Woofer Thiele-Small Specs", systemImage: "waveform")) {
                Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 6) {
                    GridRow {
                        Text("Fs (Hz):")
                        Spacer()
                        TextField("Fs", value: $viewModel.driver.wooferTS.fs, format: .number)
                            .frame(width: 70)
                    }
                    GridRow {
                        Text("Qes:")
                        Spacer()
                        TextField("Qes", value: $viewModel.driver.wooferTS.qes, format: .number)
                            .frame(width: 70)
                    }
                    GridRow {
                        Text("Qms:")
                        Spacer()
                        TextField("Qms", value: $viewModel.driver.wooferTS.qms, format: .number)
                            .frame(width: 70)
                    }
                    GridRow {
                        Text("Qts:")
                        Spacer()
                        Text(String(format: "%.3f", viewModel.driver.wooferTS.qts))
                            .bold()
                            .foregroundColor(.secondary)
                    }
                    GridRow {
                        Text("Vas (Liters):")
                        Spacer()
                        TextField("Vas", value: $viewModel.driver.wooferTS.vas, format: .number)
                            .frame(width: 70)
                    }
                    GridRow {
                        Text("Re (Ohms):")
                        Spacer()
                        TextField("Re", value: $viewModel.driver.wooferTS.re, format: .number)
                            .frame(width: 70)
                    }
                    GridRow {
                        Text("Le (mH):")
                        Spacer()
                        TextField("Le", value: $viewModel.driver.wooferTS.le, format: .number)
                            .frame(width: 70)
                    }
                    GridRow {
                        Text("Sd (cm²):")
                        Spacer()
                        TextField("Sd", value: $viewModel.driver.wooferTS.sd, format: .number)
                            .frame(width: 70)
                    }
                    GridRow {
                        Text("Xmax (mm):")
                        Spacer()
                        TextField("Xmax", value: $viewModel.driver.wooferTS.xmax, format: .number)
                            .frame(width: 70)
                    }
                    GridRow {
                        Text("Sensitivity (dB):")
                        Spacer()
                        TextField("SPL", value: $viewModel.driver.wooferTS.spl, format: .number)
                            .frame(width: 70)
                    }
                }
            }

            Section(header: Label("Tweeter Specifications", systemImage: "bolt.horizontal")) {
                Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 6) {
                    GridRow {
                        Text("Tweeter Fs (Hz):")
                        Spacer()
                        TextField("Fs", value: $viewModel.driver.tweeter.fs, format: .number)
                            .frame(width: 70)
                    }
                    GridRow {
                        Text("Re (Ohms):")
                        Spacer()
                        TextField("Re", value: $viewModel.driver.tweeter.re, format: .number)
                            .frame(width: 70)
                    }
                    GridRow {
                        Text("Le (mH):")
                        Spacer()
                        TextField("Le", value: $viewModel.driver.tweeter.le, format: .number)
                            .frame(width: 70)
                    }
                    GridRow {
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
