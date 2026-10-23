import SwiftUI

public struct CurveDigitizerEditorView: View {
    @ObservedObject var viewModel: MainDesignerViewModel

    public init(viewModel: MainDesignerViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "pencil.and.outline")
                    .font(.title2)
                    .foregroundColor(.accentColor)
                Text("FRD Response Curve Import & Digitizer")
                    .font(.title2)
                    .bold()
            }

            Divider()

            Picker("Select Driver Section", selection: $viewModel.digitizerActiveTab) {
                Text("Woofer Acoustic Response FRD").tag(0)
                Text("Tweeter Acoustic Response FRD").tag(1)
            }
            .pickerStyle(.segmented)

            if viewModel.digitizerActiveTab == 0 {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Paste Woofer FRD Text Data (Freq, SPL, Phase):")
                        .font(.headline)

                    TextEditor(text: $viewModel.wooferFRDText)
                        .font(.monospaced(.body)())
                        .frame(minHeight: 180)
                        .border(Color.gray.opacity(0.3))

                    HStack {
                        Button(action: {
                            viewModel.importWooferFRDText(viewModel.wooferFRDText)
                        }) {
                            Label("Import Woofer FRD", systemImage: "square.and.arrow.down")
                        }
                        .buttonStyle(.borderedProminent)

                        Spacer()

                        Text("Current points loaded: \(viewModel.driver.wooferAcousticCurve.count)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Paste Tweeter FRD Text Data (Freq, SPL, Phase):")
                        .font(.headline)

                    TextEditor(text: $viewModel.tweeterFRDText)
                        .font(.monospaced(.body)())
                        .frame(minHeight: 180)
                        .border(Color.gray.opacity(0.3))

                    HStack {
                        Button(action: {
                            viewModel.importTweeterFRDText(viewModel.tweeterFRDText)
                        }) {
                            Label("Import Tweeter FRD", systemImage: "square.and.arrow.down")
                        }
                        .buttonStyle(.borderedProminent)

                        Spacer()

                        Text("Current points loaded: \(viewModel.driver.tweeterAcousticCurve.count)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Divider()

            GroupBox(label: Label("Export Simulated FRD File", systemImage: "square.and.arrow.up")) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Generates a standard 3-column FRD text file containing the total combined amplitude and phase response suitable for CAD speaker simulation software (VituixCAD, BoxSim, LOUDSOFT).")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Button(action: {
                        let frdText = viewModel.exportSystemFRD()
                        let pasteboard = NSPasteboard.general
                        pasteboard.clearContents()
                        pasteboard.setString(frdText, forType: .string)
                    }) {
                        Label("Copy System Simulated FRD to Clipboard", systemImage: "doc.on.doc")
                    }
                    .buttonStyle(.bordered)
                }
                .padding(6)
            }
        }
        .padding()
    }
}
