import SwiftUI
#if canImport(AppKit)
import AppKit
#endif

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

            if let err = viewModel.errorMessage {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    Text(err)
                        .font(.caption)
                        .foregroundColor(.red)
                    Spacer()
                }
                .padding(8)
                .background(Color.red.opacity(0.12))
                .cornerRadius(6)
            } else if let msg = viewModel.statusMessage {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text(msg)
                        .font(.caption)
                        .foregroundColor(.green)
                    Spacer()
                }
                .padding(8)
                .background(Color.green.opacity(0.12))
                .cornerRadius(6)
            }

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
                        .frame(minHeight: 180, maxHeight: 240)
                        .border(Color.gray.opacity(0.3))

                    HStack(spacing: 10) {
                        Button(action: {
                            viewModel.importWooferFRDText(viewModel.wooferFRDText)
                        }) {
                            Label("Import Woofer FRD", systemImage: "square.and.arrow.down")
                        }
                        .buttonStyle(.borderedProminent)

                        #if canImport(AppKit)
                        Button(action: {
                            viewModel.chooseWooferFRDFile()
                        }) {
                            Label("Choose FRD File...", systemImage: "folder")
                        }
                        .buttonStyle(.bordered)

                        Button(action: {
                            if let clip = NSPasteboard.general.string(forType: .string),
                               !clip.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                viewModel.wooferFRDText = clip
                                viewModel.importWooferFRDText(clip)
                            } else {
                                viewModel.errorMessage = "Clipboard does not contain text data."
                            }
                        }) {
                            Label("Paste & Import", systemImage: "doc.on.clipboard")
                        }
                        .buttonStyle(.bordered)
                        #endif

                        Button(action: {
                            viewModel.resetWooferToSyntheticCurve()
                        }) {
                            Label("Reset to Synthetic", systemImage: "arrow.counterclockwise")
                        }
                        .buttonStyle(.bordered)

                        Spacer()

                        Text("Current points loaded: \(viewModel.driver.wooferAcousticCurve.count) (\(viewModel.driver.hasCustomWooferCurve ? "Custom/Measured" : "Synthetic T/S"))")
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
                        .frame(minHeight: 180, maxHeight: 240)
                        .border(Color.gray.opacity(0.3))

                    HStack(spacing: 10) {
                        Button(action: {
                            viewModel.importTweeterFRDText(viewModel.tweeterFRDText)
                        }) {
                            Label("Import Tweeter FRD", systemImage: "square.and.arrow.down")
                        }
                        .buttonStyle(.borderedProminent)

                        #if canImport(AppKit)
                        Button(action: {
                            viewModel.chooseTweeterFRDFile()
                        }) {
                            Label("Choose FRD File...", systemImage: "folder")
                        }
                        .buttonStyle(.bordered)

                        Button(action: {
                            if let clip = NSPasteboard.general.string(forType: .string),
                               !clip.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                viewModel.tweeterFRDText = clip
                                viewModel.importTweeterFRDText(clip)
                            } else {
                                viewModel.errorMessage = "Clipboard does not contain text data."
                            }
                        }) {
                            Label("Paste & Import", systemImage: "doc.on.clipboard")
                        }
                        .buttonStyle(.bordered)
                        #endif

                        Button(action: {
                            viewModel.resetTweeterToSyntheticCurve()
                        }) {
                            Label("Reset to Synthetic", systemImage: "arrow.counterclockwise")
                        }
                        .buttonStyle(.bordered)

                        Spacer()

                        Text("Current points loaded: \(viewModel.driver.tweeterAcousticCurve.count) (\(viewModel.driver.hasCustomTweeterCurve ? "Custom/Measured" : "Synthetic T/S"))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Divider()

            GroupBox(label: Label("Export Simulated FRD File", systemImage: "square.and.arrow.up")) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Generates a standard 3-column FRD text file containing the total combined amplitude and phase response suitable for CAD speaker simulation software (VituixCAD, BoxSim, LOUDSOFT).")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    HStack(spacing: 10) {
                        #if canImport(AppKit)
                        Button(action: {
                            viewModel.exportSystemFRDToFile()
                        }) {
                            Label("Export System Simulated FRD File...", systemImage: "square.and.arrow.up")
                        }
                        .buttonStyle(.borderedProminent)

                        Button(action: {
                            viewModel.copySystemFRDToClipboard()
                        }) {
                            Label("Copy System Simulated FRD to Clipboard", systemImage: "doc.on.doc")
                        }
                        .buttonStyle(.bordered)
                        #endif
                    }
                }
                .padding(6)
            }
        }
        .padding()
    }
}
