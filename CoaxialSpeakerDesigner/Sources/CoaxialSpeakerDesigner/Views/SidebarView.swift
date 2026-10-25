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
                    Text("Decimal Separator:")
                    Spacer()
                    Picker("Decimal Separator", selection: $viewModel.isEuropeanDecimal) {
                        Text("US ( . )").tag(false)
                        Text("EU ( , )").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 140)
                }

                HStack {
                    Text("Crossover Freq:")
                    Spacer()
                    DecimalInputField("fx", value: $viewModel.crossover.crossoverFrequency, isEuropean: viewModel.isEuropeanDecimal, unit: "Hz")
                }
            }

            Section(header: Label("Woofer Thiele-Small Specs", systemImage: "waveform")) {
                Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
                    GridRow {
                        Text("Fs:")
                        Spacer()
                        DecimalInputField("Fs", value: $viewModel.driver.wooferTS.fs, isEuropean: viewModel.isEuropeanDecimal, unit: "Hz")
                    }
                    GridRow {
                        Text("Qes:")
                        Spacer()
                        DecimalInputField("Qes", value: $viewModel.driver.wooferTS.qes, isEuropean: viewModel.isEuropeanDecimal)
                    }
                    GridRow {
                        Text("Qms:")
                        Spacer()
                        DecimalInputField("Qms", value: $viewModel.driver.wooferTS.qms, isEuropean: viewModel.isEuropeanDecimal)
                    }
                    GridRow {
                        Text("Qts:")
                        Spacer()
                        DecimalInputField("Qts", value: $viewModel.driver.wooferTS.qts, isEuropean: viewModel.isEuropeanDecimal)
                    }
                    GridRow {
                        Text("Vas:")
                        Spacer()
                        DecimalInputField("Vas", value: $viewModel.driver.wooferTS.vas, isEuropean: viewModel.isEuropeanDecimal, unit: "L")
                    }
                    GridRow {
                        Text("Re:")
                        Spacer()
                        DecimalInputField("Re", value: $viewModel.driver.wooferTS.re, isEuropean: viewModel.isEuropeanDecimal, unit: "Ω")
                    }
                    GridRow {
                        Text("Le:")
                        Spacer()
                        DecimalInputField("Le", value: $viewModel.driver.wooferTS.le, isEuropean: viewModel.isEuropeanDecimal, unit: "mH")
                    }
                    GridRow {
                        Text("Sd:")
                        Spacer()
                        DecimalInputField("Sd", value: $viewModel.driver.wooferTS.sd, isEuropean: viewModel.isEuropeanDecimal, unit: "cm²")
                    }
                    GridRow {
                        Text("Xmax:")
                        Spacer()
                        DecimalInputField("Xmax", value: $viewModel.driver.wooferTS.xmax, isEuropean: viewModel.isEuropeanDecimal, unit: "mm")
                    }
                    GridRow {
                        Text("Sensitivity:")
                        Spacer()
                        DecimalInputField("SPL", value: $viewModel.driver.wooferTS.spl, isEuropean: viewModel.isEuropeanDecimal, unit: "dB")
                    }
                }
                .padding(.vertical, 8)
            }

            Section(header: Label("Tweeter Specifications", systemImage: "bolt.horizontal")) {
                Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 6) {
                    GridRow {
                        Text("Tweeter Fs:")
                        Spacer()
                        DecimalInputField("Fs", value: $viewModel.driver.tweeter.fs, isEuropean: viewModel.isEuropeanDecimal, unit: "Hz")
                    }
                    GridRow {
                        Text("Tweeter Re:")
                        Spacer()
                        DecimalInputField("Re", value: $viewModel.driver.tweeter.re, isEuropean: viewModel.isEuropeanDecimal, unit: "Ω")
                    }
                    GridRow {
                        Text("Tweeter Le:")
                        Spacer()
                        DecimalInputField("Le", value: $viewModel.driver.tweeter.le, isEuropean: viewModel.isEuropeanDecimal, unit: "mH")
                    }
                    GridRow {
                        Text("Sensitivity:")
                        Spacer()
                        DecimalInputField("SPL", value: $viewModel.driver.tweeter.spl, isEuropean: viewModel.isEuropeanDecimal, unit: "dB")
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
}

/// A resilient decimal input text field that accepts both '.' and ',' as separators,
/// and dynamically formats the value according to the chosen US/European style.
public struct DecimalInputField: View {
    let title: String
    @Binding var value: Double
    var isEuropean: Bool
    var width: CGFloat = 70
    var unit: String = ""
    var onCommit: (() -> Void)? = nil

    @State private var text: String = ""
    @FocusState private var isFocused: Bool

    public init(
        _ title: String,
        value: Binding<Double>,
        isEuropean: Bool,
        width: CGFloat = 70,
        unit: String = "",
        onCommit: (() -> Void)? = nil
    ) {
        self.title = title
        self._value = value
        self.isEuropean = isEuropean
        self.width = width
        self.unit = unit
        self.onCommit = onCommit
    }

    private func formatValue(_ v: Double) -> String {
        guard v != 0 else { return "0" }
        let str = String(format: "%g", v)
        return isEuropean ? str.replacingOccurrences(of: ".", with: ",") : str
    }

    private func parseText(_ str: String) -> Double? {
        let clean = str.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
        return Double(clean)
    }

    public var body: some View {
        HStack(spacing: 4) {
            TextField(title, text: $text)
                .focused($isFocused)
                .frame(width: width)
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.trailing)
                .onChange(of: text) { newText in
                    if let parsed = parseText(newText) {
                        if parsed != value {
                            value = parsed
                            onCommit?()
                        }
                    }
                }
                .onChange(of: isFocused) { focused in
                    if !focused {
                        text = formatValue(value)
                    }
                }
                .onChange(of: value) { newValue in
                    if !isFocused {
                        text = formatValue(newValue)
                    }
                }
                .onChange(of: isEuropean) { _ in
                    if !isFocused {
                        text = formatValue(value)
                    }
                }
                .onAppear {
                    text = formatValue(value)
                }

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
