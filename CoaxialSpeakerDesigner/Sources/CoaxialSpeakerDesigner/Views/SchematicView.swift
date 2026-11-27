import SwiftUI

public struct SchematicView: View {
    @ObservedObject var viewModel: MainDesignerViewModel

    public init(viewModel: MainDesignerViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "cpu.fill")
                    .font(.title2)
                    .foregroundColor(.accentColor)
                Text("Crossover Schematic & Bill of Materials (BOM)")
                    .font(.title2)
                    .bold()
                Spacer()
                Button(action: {
                    viewModel.exportSchematicPDF()
                }) {
                    Label("Export Schematic to PDF", systemImage: "doc.richtext")
                }
                .buttonStyle(.borderedProminent)

                Button(action: {
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.setString(generateBOMText(), forType: .string)
                }) {
                    Label("Copy BOM to Clipboard", systemImage: "doc.on.doc")
                }
                .buttonStyle(.bordered)
            }

            Divider()

            if viewModel.crossover.enableAllpassFilter {
                let status = viewModel.crossover.allpassAlignmentStatus
                let statusColor: Color = status == .optimal ? .green : (status == .acceptable ? .yellow : .red)
                let statusIcon = status == .optimal ? "checkmark.circle.fill" : (status == .acceptable ? "exclamationmark.triangle.fill" : "exclamationmark.octagon.fill")
                let errVal = String(format: "%.2f°", viewModel.crossover.allpassOptimizationErrorDeg ?? 0.0)

                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .center, spacing: 6) {
                        Image(systemName: statusIcon)
                            .foregroundColor(statusColor)
                        Text("RMS Phase Error (\(errVal)): \(status.label)")
                            .font(.caption.bold())
                            .foregroundColor(statusColor)
                    }

                    ForEach(viewModel.crossover.allpassWarnings, id: \.self) { warn in
                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text(warn)
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(statusColor.opacity(0.12))
                .cornerRadius(8)
            }

            let comp = viewModel.calculatedComponents

            // Schematic Graphical Diagram Placeholder / Layout
            GroupBox(label: Label("Electrical Crossover Circuit Schematic", systemImage: "point.3.connected.trianglepath.dotted")) {
                VStack(spacing: 12) {
                    Text("Amplifier Input (＋ / －)")
                        .font(.caption)
                        .bold()
                        .padding(4)
                        .background(Color.accentColor.opacity(0.15))
                        .cornerRadius(6)

                    HStack(spacing: 30) {
                        // Woofer Branch
                        VStack(spacing: 8) {
                            Text("Woofer Branch (Low-Pass)")
                                .font(.subheadline)
                                .bold()
                                .foregroundColor(.blue)

                            CircuitBranchBox(title: "Topology", value: viewModel.crossover.wooferOrder.rawValue)
                            if let l1 = comp.L1_mH { CircuitBranchBox(title: "Series Inductor L1", value: "\(String(format: "%.2f", l1)) mH") }
                            if let c1 = comp.C1_uF { CircuitBranchBox(title: "Shunt Capacitor C1", value: "\(String(format: "%.2f", c1)) µF") }
                            if let l2 = comp.L2_mH { CircuitBranchBox(title: "Series Inductor L2", value: "\(String(format: "%.2f", l2)) mH") }
                            if let c2 = comp.C2_uF { CircuitBranchBox(title: "Shunt Capacitor C2", value: "\(String(format: "%.2f", c2)) µF") }
                            if viewModel.crossover.enableAllpassFilter {
                                if let lap = comp.L_AP_mH { CircuitBranchBox(title: "All-Pass Inductor L_AP", value: "\(String(format: "%.2f", lap)) mH", color: .teal) }
                                if let cap = comp.C_AP_uF { CircuitBranchBox(title: "All-Pass Capacitor C_AP", value: "\(String(format: "%.2f", cap)) µF", color: .teal) }
                            }
                            if viewModel.crossover.enableZobelNetwork, let rz = comp.R_zobel_ohms, let cz = comp.C_zobel_uF {
                                CircuitBranchBox(title: "Zobel Network", value: "Rz = \(String(format: "%.2f", rz)) Ω, Cz = \(String(format: "%.2f", cz)) µF", color: .orange)
                            }
                            Text("Woofer Voice Coil (Re = \(String(format: "%.1f", viewModel.driver.wooferTS.re)) Ω)")
                                .font(.caption)
                                .bold()
                        }
                        .padding()
                        .background(Color.blue.opacity(0.05))
                        .cornerRadius(8)

                        // Tweeter Branch
                        VStack(spacing: 8) {
                            Text("Tweeter Branch (High-Pass)")
                                .font(.subheadline)
                                .bold()
                                .foregroundColor(.red)

                            CircuitBranchBox(title: "Topology", value: viewModel.crossover.tweeterOrder.rawValue)
                            if let c1 = comp.C_HP1_uF { CircuitBranchBox(title: "Series Capacitor C_HP1", value: "\(String(format: "%.2f", c1)) µF") }
                            if let l1 = comp.L_HP1_mH { CircuitBranchBox(title: "Shunt Inductor L_HP1", value: "\(String(format: "%.2f", l1)) mH") }
                            if let c2 = comp.C_HP2_uF { CircuitBranchBox(title: "Series Capacitor C_HP2", value: "\(String(format: "%.2f", c2)) µF") }
                            if (viewModel.crossover.enableLPadAttenuator || viewModel.crossover.enableCDHornCompensation), let r1 = comp.R1_lpad_ohms, let r2 = comp.R2_lpad_ohms {
                                CircuitBranchBox(title: "L-Pad Attenuator", value: "R1 (Series) = \(String(format: "%.2f", r1)) Ω, R2 (Shunt) = \(String(format: "%.2f", r2)) Ω", color: .purple)
                            }
                            if viewModel.crossover.enableCDHornCompensation, let ccd = comp.C_cd_uF {
                                let rcdStr = comp.R_cd_ohms != nil ? ", R_eq (Series w/ C_eq) = \(String(format: "%.2f", comp.R_cd_ohms!)) Ω" : " (Full R1 Bypass)"
                                CircuitBranchBox(title: "CD Horn Mass Roll-Off EQ (|| R1)", value: "C_eq = \(String(format: "%.2f", ccd)) µF\(rcdStr) @ \(Int(viewModel.crossover.cdHornCornerFrequency)) Hz", color: .purple)
                            }
                            Text(viewModel.crossover.invertTweeterPolarity ? "Tweeter Voice Coil (Inverted Polarity -180°: \(String(format: "%.1f", viewModel.driver.tweeter.re)) Ω)" : "Tweeter Voice Coil (Re = \(String(format: "%.1f", viewModel.driver.tweeter.re)) Ω)")
                                .font(.caption)
                                .bold()
                                .foregroundColor(viewModel.crossover.invertTweeterPolarity ? .orange : .primary)
                        }
                        .padding()
                        .background(Color.red.opacity(0.05))
                        .cornerRadius(8)
                    }
                }
                .padding(8)
            }

            // Bill of Materials Table
            GroupBox(label: Label("Component Bill of Materials (BOM)", systemImage: "tablecells")) {
                Table(of: BOMRow.self) {
                    TableColumn("Designator", value: \.designator)
                        .width(min: 80, max: 120)
                    TableColumn("Component Type", value: \.type)
                        .width(min: 120, max: 180)
                    TableColumn("Value", value: \.value)
                        .width(min: 100, max: 150)
                    TableColumn("Rating / Specification", value: \.spec)
                } rows: {
                    ForEach(generateBOMRows()) { row in
                        TableRow(row)
                    }
                }
                .frame(minHeight: 200)
            }
        }
        .padding()
    }

    private func generateBOMRows() -> [BOMRow] {
        var rows: [BOMRow] = []
        let comp = viewModel.calculatedComponents

        if let l1 = comp.L1_mH {
            rows.append(BOMRow(designator: "L1", type: "Air-Core Inductor", value: "\(String(format: "%.2f", l1)) mH", spec: "1.2mm OFC Wire, Low DCR"))
        }
        if let c1 = comp.C1_uF {
            rows.append(BOMRow(designator: "C1", type: "Metalized Polypropylene Film Capacitor", value: "\(String(format: "%.2f", c1)) µF", spec: "400V DC, ±5% Tolerance"))
        }
        if let l2 = comp.L2_mH {
            rows.append(BOMRow(designator: "L2", type: "Air-Core Inductor", value: "\(String(format: "%.2f", l2)) mH", spec: "1.0mm OFC Wire"))
        }
        if let c2 = comp.C2_uF {
            rows.append(BOMRow(designator: "C2", type: "Metalized Polypropylene Film Cap", value: "\(String(format: "%.2f", c2)) µF", spec: "250V DC"))
        }
        if viewModel.crossover.enableAllpassFilter {
            if let lap = comp.L_AP_mH {
                rows.append(BOMRow(designator: "L_AP", type: "All-Pass Delay Inductor", value: "\(String(format: "%.2f", lap)) mH", spec: "OFC Wire, Low DCR"))
            }
            if let cap = comp.C_AP_uF {
                rows.append(BOMRow(designator: "C_AP", type: "All-Pass Polypropylene Film Cap", value: "\(String(format: "%.2f", cap)) µF", spec: "400V DC, ±5% Tolerance"))
            }
        }
        if let c1 = comp.C_HP1_uF {
            rows.append(BOMRow(designator: "C_HP1", type: "Polypropylene Audio Cap", value: "\(String(format: "%.2f", c1)) µF", spec: "250V DC High Precision"))
        }
        if let l1 = comp.L_HP1_mH {
            rows.append(BOMRow(designator: "L_HP1", type: "Air-Core Inductor", value: "\(String(format: "%.2f", l1)) mH", spec: "0.8mm Wire"))
        }
        if let c2 = comp.C_HP2_uF {
            rows.append(BOMRow(designator: "C_HP2", type: "Polypropylene Cap", value: "\(String(format: "%.2f", c2)) µF", spec: "250V DC"))
        }
        if let rz = comp.R_zobel_ohms {
            rows.append(BOMRow(designator: "R_zobel", type: "Non-Inductive Ceramic Resistor", value: "\(String(format: "%.2f", rz)) Ω", spec: "10W Power Rating"))
        }
        if let cz = comp.C_zobel_uF {
            rows.append(BOMRow(designator: "C_zobel", type: "Bipolar Electrolytic / Film Cap", value: "\(String(format: "%.2f", cz)) µF", spec: "100V DC"))
        }
        if let r1 = comp.R1_lpad_ohms {
            rows.append(BOMRow(designator: "R1 (L-Pad)", type: "Wirewound / Metal Oxide Resistor", value: "\(String(format: "%.2f", r1)) Ω", spec: "10W Non-Inductive Series Element"))
        }
        if let r2 = comp.R2_lpad_ohms {
            rows.append(BOMRow(designator: "R2 (L-Pad)", type: "Wirewound / Metal Oxide Resistor", value: "\(String(format: "%.2f", r2)) Ω", spec: "10W Non-Inductive Shunt Element"))
        }
        if viewModel.crossover.enableCDHornCompensation {
            if let ccd = comp.C_cd_uF {
                rows.append(BOMRow(designator: "C_eq (CD Horn)", type: "Polypropylene HF Bypass Capacitor", value: "\(String(format: "%.2f", ccd)) µF", spec: "250V DC Film Cap, Parallel across R1 (f_eq = \(Int(viewModel.crossover.cdHornCornerFrequency)) Hz)"))
            }
            if let rcd = comp.R_cd_ohms {
                rows.append(BOMRow(designator: "R_eq (CD Horn)", type: "Metal Oxide HF Shelf Damping Resistor", value: "\(String(format: "%.2f", rcd)) Ω", spec: "5W Non-Inductive, Series with C_eq across R1"))
            }
        }

        if viewModel.cabinet.enclosureType == .vented {
            let lv = viewModel.cabinet.computedPortLengthCm(for: viewModel.driver.wooferTS)
            let np = viewModel.cabinet.numberOfPorts
            let dia = viewModel.cabinet.portDiameterCm
            rows.append(BOMRow(designator: "Port Duct", type: "Bass-Reflex Helmholtz Port", value: "\(np)x Ø\(String(format: "%.1f", dia)) cm × \(String(format: "%.1f", lv)) cm", spec: "Rigid Port Duct, Flared Ends"))
        }

        return rows
    }

    private func generateBOMText() -> String {
        var text = "COAXIAL SPEAKER CROSSOVER BILL OF MATERIALS (BOM)\n"
        text += "Driver: \(viewModel.driver.name)\n"
        if viewModel.crossover.enableIndependentFrequencies {
            text += "Crossover Frequencies: Woofer LP = \(Int(viewModel.crossover.actualWooferFrequency)) Hz, Tweeter HP = \(Int(viewModel.crossover.actualTweeterFrequency)) Hz (Center = \(Int(round(viewModel.crossover.acousticCenterFrequency))) Hz)\n\n"
        } else {
            text += "Crossover Frequency: \(Int(viewModel.crossover.crossoverFrequency)) Hz\n\n"
        }
        text += "Designator\tType\tValue\tSpecification\n"
        for row in generateBOMRows() {
            text += "\(row.designator)\t\(row.type)\t\(row.value)\t\(row.spec)\n"
        }
        return text
    }
}

public struct CircuitBranchBox: View {
    let title: String
    let value: String
    var color: Color = .primary

    public var body: some View {
        HStack {
            Text(title + ":").font(.caption).foregroundColor(.secondary)
            Spacer()
            Text(value).font(.caption).bold().foregroundColor(color)
        }
        .padding(6)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(6)
    }
}

public struct BOMRow: Identifiable {
    public var id = UUID()
    public var designator: String
    public var type: String
    public var value: String
    public var spec: String
}
