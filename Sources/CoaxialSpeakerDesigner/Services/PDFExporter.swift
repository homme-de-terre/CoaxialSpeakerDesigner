import Foundation
import AppKit

/// High-precision, vector PDF Exporter for Crossover Schematic and Bill of Materials using AppKit NSBezierPath & NSString.
public enum PDFExporter {

    /// Generates a vector PDF Data object containing the header, schematic, and BOM table.
    public static func generateSchematicPDF(
        driver: CoaxialDriver,
        cabinet: SealedCabinet,
        crossover: CrossoverNetwork,
        components: CalculatedComponents
    ) -> Data {
        let pageRect = CGRect(x: 0, y: 0, width: 842.0, height: 595.0) // A4 Landscape
        let reportView = SchematicReportNSView(
            frame: pageRect,
            driver: driver,
            cabinet: cabinet,
            crossover: crossover,
            components: components
        )

        // Generate vector PDF directly using AppKit's native NSView PDF recording
        let pdfData = reportView.dataWithPDF(inside: reportView.bounds)
        return pdfData
    }
}

// MARK: - AppKit Native Report Drawing View (Flipped Top-Down Coordinates)

public class SchematicReportNSView: NSView {
    let driver: CoaxialDriver
    let cabinet: SealedCabinet
    let crossover: CrossoverNetwork
    let components: CalculatedComponents

    public init(
        frame: CGRect,
        driver: CoaxialDriver,
        cabinet: SealedCabinet,
        crossover: CrossoverNetwork,
        components: CalculatedComponents
    ) {
        self.driver = driver
        self.cabinet = cabinet
        self.crossover = crossover
        self.components = components
        super.init(frame: frame)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override var isFlipped: Bool {
        return true // Top-Left origin (0,0 at top-left), Y increases DOWNWARDS
    }

    public override func draw(_ decoderRect: NSRect) {
        let bounds = self.bounds

        // 1. Fill White Background
        NSColor.white.setFill()
        NSBezierPath(rect: bounds).fill()

        // 2. Draw Header Banner
        drawHeaderBanner(bounds: bounds)

        // 3. Draw Vector Circuit Schematic Diagram
        drawSchematicDiagram(bounds: bounds)

        // 4. Draw Bill of Materials (BOM) Table
        drawBOMTable(bounds: bounds)
    }

    // MARK: - 1. Header Banner
    private func drawHeaderBanner(bounds: CGRect) {
        let margin: CGFloat = 36.0
        let bannerY: CGFloat = 20.0
        let bannerH: CGFloat = 52.0
        let bannerW = bounds.width - (margin * 2)

        // Banner Background
        let bannerRect = CGRect(x: margin, y: bannerY, width: bannerW, height: bannerH)
        let path = NSBezierPath(roundedRect: bannerRect, xRadius: 5, yRadius: 5)
        NSColor(calibratedRed: 0.08, green: 0.12, blue: 0.22, alpha: 1.0).setFill()
        path.fill()

        // Document Title
        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 13.5),
            .foregroundColor: NSColor.white
        ]
        "COAXIAL SPEAKER CROSSOVER & CABINET SCHEMATIC REPORT".draw(
            at: CGPoint(x: margin + 14, y: bannerY + 8),
            withAttributes: titleAttrs
        )

        // Metadata Subtitle Lines
        let subAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 8.5),
            .foregroundColor: NSColor(calibratedRed: 0.78, green: 0.84, blue: 0.95, alpha: 1.0)
        ]

        let vb = cabinet.computedVolumeLiters(for: driver.wooferTS)
        let fc = cabinet.computedResonanceFc(for: driver.wooferTS)
        let f3 = cabinet.actualF3(for: driver.wooferTS)
        let qtc = cabinet.actualQtc(for: driver.wooferTS)

        let line1 = "Driver: \(driver.name) (\(driver.manufacturer))  |  Crossover: \(Int(crossover.crossoverFrequency)) Hz (\(crossover.wooferOrder.rawValue) / \(crossover.tweeterOrder.rawValue))"
        let line2 = "Sealed Enclosure: Vb = \(String(format: "%.2f", vb)) L  |  Fc = \(String(format: "%.1f", fc)) Hz  |  f3 = \(String(format: "%.1f", f3)) Hz  |  Qtc = \(String(format: "%.3f", qtc))"

        line1.draw(at: CGPoint(x: margin + 14, y: bannerY + 25), withAttributes: subAttrs)
        line2.draw(at: CGPoint(x: margin + 14, y: bannerY + 37), withAttributes: subAttrs)
    }

    // MARK: - 2. Vector Circuit Schematic Diagram
    private func drawSchematicDiagram(bounds: CGRect) {
        let margin: CGFloat = 36.0
        let sectionY: CGFloat = 80.0
        let boxY: CGFloat = 94.0
        let boxH: CGFloat = 260.0
        let boxW = bounds.width - (margin * 2)

        // Section Title
        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 11),
            .foregroundColor: NSColor(calibratedRed: 0.1, green: 0.25, blue: 0.5, alpha: 1.0)
        ]
        "ELECTRICAL CIRCUIT SCHEMATIC".draw(at: CGPoint(x: margin, y: sectionY), withAttributes: titleAttrs)

        // Box Frame Background
        let boxRect = CGRect(x: margin, y: boxY, width: boxW, height: boxH)
        let boxPath = NSBezierPath(roundedRect: boxRect, xRadius: 4, yRadius: 4)
        NSColor(calibratedRed: 0.98, green: 0.98, blue: 0.99, alpha: 1.0).setFill()
        boxPath.fill()
        NSColor(calibratedRed: 0.8, green: 0.82, blue: 0.86, alpha: 1.0).setStroke()
        boxPath.lineWidth = 1.0
        boxPath.stroke()

        // 20pt Background Grid
        let gridPath = NSBezierPath()
        for gx in stride(from: boxRect.minX + 20, to: boxRect.maxX, by: 20) {
            gridPath.move(to: CGPoint(x: gx, y: boxRect.minY))
            gridPath.line(to: CGPoint(x: gx, y: boxRect.maxY))
        }
        for gy in stride(from: boxRect.minY + 20, to: boxRect.maxY, by: 20) {
            gridPath.move(to: CGPoint(x: boxRect.minX, y: gy))
            gridPath.line(to: CGPoint(x: boxRect.maxX, y: gy))
        }
        NSColor(calibratedRed: 0.93, green: 0.94, blue: 0.96, alpha: 1.0).setStroke()
        gridPath.lineWidth = 0.5
        gridPath.stroke()

        // Wiring Rails
        let ampX = boxRect.minX + 35.0
        let wooferY = boxRect.minY + 50.0
        let tweeterY = boxRect.minY + 135.0
        let groundY = boxRect.minY + 220.0

        // Terminals
        drawTerminalDot(point: CGPoint(x: ampX, y: wooferY), text: "AMP (+)", isPositive: true)
        drawTerminalDot(point: CGPoint(x: ampX, y: groundY), text: "AMP (-)", isPositive: false)

        // Vertical Input Bus Line
        let vBus = NSBezierPath()
        vBus.move(to: CGPoint(x: ampX, y: wooferY))
        vBus.line(to: CGPoint(x: ampX, y: tweeterY))
        NSColor.black.setStroke()
        vBus.lineWidth = 1.5
        vBus.stroke()
        drawJunctionDot(point: CGPoint(x: ampX, y: tweeterY))

        // Ground Rail
        let gRail = NSBezierPath()
        gRail.move(to: CGPoint(x: ampX, y: groundY))
        gRail.line(to: CGPoint(x: boxRect.maxX - 40, y: groundY))
        gRail.lineWidth = 1.5
        gRail.stroke()

        // ==========================================
        // WOOFER LOW-PASS BRANCH (TOP)
        // ==========================================
        var curX = ampX
        let wooferTagAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 9),
            .foregroundColor: NSColor(calibratedRed: 0.1, green: 0.35, blue: 0.75, alpha: 1.0)
        ]
        "WOOFER LOW-PASS (\(crossover.wooferOrder.rawValue))".draw(
            at: CGPoint(x: curX + 15, y: wooferY - 20),
            withAttributes: wooferTagAttrs
        )

        // Series Inductor L1
        if let l1 = components.L1_mH {
            drawWire(from: CGPoint(x: curX, y: wooferY), to: CGPoint(x: curX + 35, y: wooferY))
            curX += 35
            drawInductorSymbol(startX: curX, endX: curX + 60, y: wooferY, name: "L1", valueStr: "\(String(format: "%.2f", l1)) mH", color: .systemBlue)
            curX += 60
        }

        // Shunt Capacitor C1
        if let c1 = components.C1_uF {
            drawWire(from: CGPoint(x: curX, y: wooferY), to: CGPoint(x: curX + 50, y: wooferY))
            curX += 50
            drawJunctionDot(point: CGPoint(x: curX, y: wooferY))

            drawShuntCapacitor(topX: curX, topY: wooferY, groundY: groundY, name: "C1", valueStr: "\(String(format: "%.2f", c1)) µF", color: .systemBlue)
            drawJunctionDot(point: CGPoint(x: curX, y: groundY))
        }

        // Series Inductor L2 (3rd/4th order)
        if let l2 = components.L2_mH {
            drawWire(from: CGPoint(x: curX, y: wooferY), to: CGPoint(x: curX + 30, y: wooferY))
            curX += 30
            drawInductorSymbol(startX: curX, endX: curX + 60, y: wooferY, name: "L2", valueStr: "\(String(format: "%.2f", l2)) mH", color: .systemBlue)
            curX += 60
        }

        // Shunt Capacitor C2 (4th order)
        if let c2 = components.C2_uF {
            drawWire(from: CGPoint(x: curX, y: wooferY), to: CGPoint(x: curX + 50, y: wooferY))
            curX += 50
            drawJunctionDot(point: CGPoint(x: curX, y: wooferY))

            drawShuntCapacitor(topX: curX, topY: wooferY, groundY: groundY, name: "C2", valueStr: "\(String(format: "%.2f", c2)) µF", color: .systemBlue)
            drawJunctionDot(point: CGPoint(x: curX, y: groundY))
        }

        // Zobel Network (Shunt Rz + Cz)
        if crossover.enableZobelNetwork, let rz = components.R_zobel_ohms, let cz = components.C_zobel_uF {
            drawWire(from: CGPoint(x: curX, y: wooferY), to: CGPoint(x: curX + 50, y: wooferY))
            curX += 50
            drawJunctionDot(point: CGPoint(x: curX, y: wooferY))

            drawShuntZobelBranch(
                topX: curX,
                topY: wooferY,
                groundY: groundY,
                rzStr: "\(String(format: "%.2f", rz)) Ω",
                czStr: "\(String(format: "%.2f", cz)) µF"
            )
            drawJunctionDot(point: CGPoint(x: curX, y: groundY))
        }

        // Wire to Woofer
        drawWire(from: CGPoint(x: curX, y: wooferY), to: CGPoint(x: boxRect.maxX - 110, y: wooferY))
        curX = boxRect.maxX - 110

        drawSpeakerSymbol(
            topX: curX,
            topY: wooferY,
            groundY: groundY,
            title: "WOOFER",
            subTitle: "Re = \(String(format: "%.1f", driver.wooferTS.re)) Ω"
        )
        drawJunctionDot(point: CGPoint(x: curX, y: groundY))

        // ==========================================
        // TWEETER HIGH-PASS BRANCH (MIDDLE)
        // ==========================================
        var tCurX = ampX
        let tweeterTagAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 9),
            .foregroundColor: NSColor(calibratedRed: 0.8, green: 0.15, blue: 0.15, alpha: 1.0)
        ]
        "TWEETER HIGH-PASS (\(crossover.tweeterOrder.rawValue))".draw(
            at: CGPoint(x: tCurX + 15, y: tweeterY - 20),
            withAttributes: tweeterTagAttrs
        )

        // Series Capacitor C_HP1
        if let c1 = components.C_HP1_uF {
            drawWire(from: CGPoint(x: tCurX, y: tweeterY), to: CGPoint(x: tCurX + 35, y: tweeterY))
            tCurX += 35
            drawCapacitorSymbol(startX: tCurX, endX: tCurX + 55, y: tweeterY, name: "C_HP1", valueStr: "\(String(format: "%.2f", c1)) µF", color: .systemRed)
            tCurX += 55
        }

        // Shunt Inductor L_HP1
        if let l1 = components.L_HP1_mH {
            drawWire(from: CGPoint(x: tCurX, y: tweeterY), to: CGPoint(x: tCurX + 50, y: tweeterY))
            tCurX += 50
            drawJunctionDot(point: CGPoint(x: tCurX, y: tweeterY))

            drawShuntInductor(topX: tCurX, topY: tweeterY, groundY: groundY, name: "L_HP1", valueStr: "\(String(format: "%.2f", l1)) mH", color: .systemRed)
            drawJunctionDot(point: CGPoint(x: tCurX, y: groundY))
        }

        // Series Capacitor C_HP2 (3rd/4th order)
        if let c2 = components.C_HP2_uF {
            drawWire(from: CGPoint(x: tCurX, y: tweeterY), to: CGPoint(x: tCurX + 30, y: tweeterY))
            tCurX += 30
            drawCapacitorSymbol(startX: tCurX, endX: tCurX + 55, y: tweeterY, name: "C_HP2", valueStr: "\(String(format: "%.2f", c2)) µF", color: .systemRed)
            tCurX += 55
        }

        // Shunt Inductor L_HP2 (4th order)
        if let l2 = components.L_HP2_mH {
            drawWire(from: CGPoint(x: tCurX, y: tweeterY), to: CGPoint(x: tCurX + 50, y: tweeterY))
            tCurX += 50
            drawJunctionDot(point: CGPoint(x: tCurX, y: tweeterY))

            drawShuntInductor(topX: tCurX, topY: tweeterY, groundY: groundY, name: "L_HP2", valueStr: "\(String(format: "%.2f", l2)) mH", color: .systemRed)
            drawJunctionDot(point: CGPoint(x: tCurX, y: groundY))
        }

        // L-Pad Attenuator (Series R1 + Shunt R2)
        if crossover.enableLPadAttenuator, let r1 = components.R1_lpad_ohms, let r2 = components.R2_lpad_ohms {
            drawWire(from: CGPoint(x: tCurX, y: tweeterY), to: CGPoint(x: tCurX + 30, y: tweeterY))
            tCurX += 30
            drawResistorSymbol(startX: tCurX, endX: tCurX + 55, y: tweeterY, name: "R1 (L-Pad)", valueStr: "\(String(format: "%.2f", r1)) Ω", color: .systemOrange)
            tCurX += 55

            drawWire(from: CGPoint(x: tCurX, y: tweeterY), to: CGPoint(x: tCurX + 45, y: tweeterY))
            tCurX += 45
            drawJunctionDot(point: CGPoint(x: tCurX, y: tweeterY))

            drawShuntResistor(topX: tCurX, topY: tweeterY, groundY: groundY, name: "R2 (L-Pad)", valueStr: "\(String(format: "%.2f", r2)) Ω", color: .systemOrange)
            drawJunctionDot(point: CGPoint(x: tCurX, y: groundY))
        }

        // Wire to Tweeter
        drawWire(from: CGPoint(x: tCurX, y: tweeterY), to: CGPoint(x: boxRect.maxX - 110, y: tweeterY))
        tCurX = boxRect.maxX - 110

        let tweeterTitle = crossover.invertTweeterPolarity ? "TWEETER (-180°)" : "TWEETER (+)"
        drawSpeakerSymbol(
            topX: tCurX,
            topY: tweeterY,
            groundY: groundY,
            title: tweeterTitle,
            subTitle: "Re = \(String(format: "%.1f", driver.tweeter.re)) Ω"
        )
        drawJunctionDot(point: CGPoint(x: tCurX, y: groundY))
    }

    // MARK: - 3. Bill of Materials (BOM) Table
    private func drawBOMTable(bounds: CGRect) {
        let margin: CGFloat = 36.0
        let sectionY: CGFloat = 368.0
        let tableY: CGFloat = 382.0
        let width = bounds.width - (margin * 2)

        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 11),
            .foregroundColor: NSColor(calibratedRed: 0.1, green: 0.25, blue: 0.5, alpha: 1.0)
        ]
        "BILL OF MATERIALS (BOM) COMPONENT TABLE".draw(at: CGPoint(x: margin, y: sectionY), withAttributes: titleAttrs)

        let headerAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 8.5),
            .foregroundColor: NSColor.white
        ]
        let cellTitleAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 8.5),
            .foregroundColor: NSColor.black
        ]
        let cellAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 8.5),
            .foregroundColor: NSColor.darkGray
        ]

        let colWidths: [CGFloat] = [75.0, 180.0, 120.0, width - 375.0]
        let rowHeight: CGFloat = 16.0

        // Table Header
        let headerRect = CGRect(x: margin, y: tableY, width: width, height: rowHeight)
        NSColor(calibratedRed: 0.15, green: 0.22, blue: 0.35, alpha: 1.0).setFill()
        NSBezierPath(rect: headerRect).fill()

        let headers = ["Designator", "Component Type", "Calculated Value", "Recommended Specification"]
        var currentX = margin
        for (i, h) in headers.enumerated() {
            h.draw(at: CGPoint(x: currentX + 6, y: tableY + 2), withAttributes: headerAttrs)
            currentX += colWidths[i]
        }

        // Table Rows Data
        var rows: [(String, String, String, String)] = []
        if let l1 = components.L1_mH { rows.append(("L1", "Air-Core Inductor", "\(String(format: "%.2f", l1)) mH", "1.2mm OFC Wire, Low DCR")) }
        if let c1 = components.C1_uF { rows.append(("C1", "Metalized Polypropylene Film Cap", "\(String(format: "%.2f", c1)) µF", "400V DC, ±5% Tolerance")) }
        if let l2 = components.L2_mH { rows.append(("L2", "Air-Core Inductor", "\(String(format: "%.2f", l2)) mH", "1.0mm OFC Wire")) }
        if let c2 = components.C2_uF { rows.append(("C2", "Metalized Polypropylene Film Cap", "\(String(format: "%.2f", c2)) µF", "250V DC")) }

        if let c1 = components.C_HP1_uF { rows.append(("C_HP1", "Polypropylene Audio Cap", "\(String(format: "%.2f", c1)) µF", "250V DC High Precision")) }
        if let l1 = components.L_HP1_mH { rows.append(("L_HP1", "Air-Core Inductor", "\(String(format: "%.2f", l1)) mH", "0.8mm Wire")) }
        if let c2 = components.C_HP2_uF { rows.append(("C_HP2", "Polypropylene Audio Cap", "\(String(format: "%.2f", c2)) µF", "250V DC")) }
        if let l2 = components.L_HP2_mH { rows.append(("L_HP2", "Air-Core Inductor", "\(String(format: "%.2f", l2)) mH", "0.8mm Wire")) }

        if let rz = components.R_zobel_ohms { rows.append(("R_zobel", "Non-Inductive Ceramic Resistor", "\(String(format: "%.2f", rz)) Ω", "10W Power Rating")) }
        if let cz = components.C_zobel_uF { rows.append(("C_zobel", "Bipolar / Film Cap", "\(String(format: "%.2f", cz)) µF", "100V DC")) }
        if let r1 = components.R1_lpad_ohms { rows.append(("R1 (L-Pad)", "Metal Oxide Resistor", "\(String(format: "%.2f", r1)) Ω", "10W Power Rating")) }
        if let r2 = components.R2_lpad_ohms { rows.append(("R2 (L-Pad)", "Metal Oxide Resistor", "\(String(format: "%.2f", r2)) Ω", "10W Power Rating")) }

        var curRowY = tableY + rowHeight

        for (idx, row) in rows.enumerated() {
            // Alternating Row Background
            if idx % 2 == 1 {
                let rowBg = CGRect(x: margin, y: curRowY, width: width, height: rowHeight)
                NSColor(calibratedRed: 0.96, green: 0.97, blue: 0.98, alpha: 1.0).setFill()
                NSBezierPath(rect: rowBg).fill()
            }

            currentX = margin
            let vals = [(row.0, cellTitleAttrs), (row.1, cellAttrs), (row.2, cellTitleAttrs), (row.3, cellAttrs)]
            for (i, v) in vals.enumerated() {
                v.0.draw(at: CGPoint(x: currentX + 6, y: curRowY + 2), withAttributes: v.1)
                currentX += colWidths[i]
            }

            let divider = NSBezierPath()
            divider.move(to: CGPoint(x: margin, y: curRowY + rowHeight))
            divider.line(to: CGPoint(x: margin + width, y: curRowY + rowHeight))
            NSColor(calibratedRed: 0.88, green: 0.90, blue: 0.92, alpha: 1.0).setStroke()
            divider.lineWidth = 0.5
            divider.stroke()

            curRowY += rowHeight
        }

        // Table Border
        let tableRect = CGRect(x: margin, y: tableY, width: width, height: curRowY - tableY)
        NSColor(calibratedRed: 0.7, green: 0.75, blue: 0.8, alpha: 1.0).setStroke()
        NSBezierPath(rect: tableRect).stroke()
    }

    // MARK: - NSBezierPath Vector Drawing Helpers

    private func drawTerminalDot(point: CGPoint, text: String, isPositive: Bool) {
        let r: CGFloat = 3.5
        let p = NSBezierPath(ovalIn: CGRect(x: point.x - r, y: point.y - r, width: r*2, height: r*2))
        (isPositive ? NSColor.systemRed : NSColor.black).setFill()
        p.fill()

        let attr: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 8),
            .foregroundColor: isPositive ? NSColor.systemRed : NSColor.black
        ]
        text.draw(at: CGPoint(x: point.x - 34, y: point.y - 4), withAttributes: attr)
    }

    private func drawJunctionDot(point: CGPoint) {
        let r: CGFloat = 2.5
        let p = NSBezierPath(ovalIn: CGRect(x: point.x - r, y: point.y - r, width: r*2, height: r*2))
        NSColor.black.setFill()
        p.fill()
    }

    private func drawWire(from p1: CGPoint, to p2: CGPoint) {
        let p = NSBezierPath()
        p.move(to: p1)
        p.line(to: p2)
        NSColor.black.setStroke()
        p.lineWidth = 1.5
        p.stroke()
    }

    private func drawBadge(point: CGPoint, text: String, textColor: NSColor) {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 7.5),
            .foregroundColor: textColor
        ]
        let textSize = text.size(withAttributes: attrs)
        let bgRect = CGRect(x: point.x - 4, y: point.y - 2, width: textSize.width + 8, height: textSize.height + 4)

        let path = NSBezierPath(roundedRect: bgRect, xRadius: 3, yRadius: 3)
        NSColor.white.withAlphaComponent(0.95).setFill()
        path.fill()
        NSColor.lightGray.withAlphaComponent(0.6).setStroke()
        path.lineWidth = 0.5
        path.stroke()

        text.draw(at: point, withAttributes: attrs)
    }

    private func drawInductorSymbol(startX: CGFloat, endX: CGFloat, y: CGFloat, name: String, valueStr: String, color: NSColor) {
        let len = endX - startX
        let numLoops = 4
        let loopR = len / CGFloat(numLoops * 2)

        let path = NSBezierPath()
        for i in 0..<numLoops {
            let cx = startX + loopR + CGFloat(i * 2) * loopR
            path.appendArc(withCenter: CGPoint(x: cx, y: y), radius: loopR, startAngle: 180, endAngle: 0, clockwise: true)
        }
        NSColor.black.setStroke()
        path.lineWidth = 1.5
        path.stroke()

        drawBadge(point: CGPoint(x: startX + 2, y: y - 18), text: "\(name): \(valueStr)", textColor: color)
    }

    private func drawCapacitorSymbol(startX: CGFloat, endX: CGFloat, y: CGFloat, name: String, valueStr: String, color: NSColor) {
        let midX = (startX + endX) / 2.0
        let capGap: CGFloat = 6.0
        let capH: CGFloat = 16.0

        let path = NSBezierPath()
        // Plate 1
        path.move(to: CGPoint(x: startX, y: y))
        path.line(to: CGPoint(x: midX - capGap/2, y: y))
        path.move(to: CGPoint(x: midX - capGap/2, y: y - capH/2))
        path.line(to: CGPoint(x: midX - capGap/2, y: y + capH/2))

        // Plate 2
        path.move(to: CGPoint(x: midX + capGap/2, y: y - capH/2))
        path.line(to: CGPoint(x: midX + capGap/2, y: y + capH/2))
        path.move(to: CGPoint(x: midX + capGap/2, y: y))
        path.line(to: CGPoint(x: endX, y: y))

        NSColor.black.setStroke()
        path.lineWidth = 1.5
        path.stroke()

        drawBadge(point: CGPoint(x: startX, y: y - 18), text: "\(name): \(valueStr)", textColor: color)
    }

    private func drawResistorSymbol(startX: CGFloat, endX: CGFloat, y: CGFloat, name: String, valueStr: String, color: NSColor) {
        let midX = (startX + endX) / 2.0
        let resW: CGFloat = 24.0
        let resH: CGFloat = 10.0

        let path = NSBezierPath()
        path.move(to: CGPoint(x: startX, y: y))
        path.line(to: CGPoint(x: midX - resW/2, y: y))

        let rect = CGRect(x: midX - resW/2, y: y - resH/2, width: resW, height: resH)
        path.appendRect(rect)

        path.move(to: CGPoint(x: midX + resW/2, y: y))
        path.line(to: CGPoint(x: endX, y: y))

        NSColor.black.setStroke()
        path.lineWidth = 1.5
        path.stroke()

        drawBadge(point: CGPoint(x: startX, y: y - 18), text: "\(name): \(valueStr)", textColor: color)
    }

    private func drawShuntCapacitor(topX: CGFloat, topY: CGFloat, groundY: CGFloat, name: String, valueStr: String, color: NSColor) {
        let midY = (topY + groundY) / 2.0
        let capGap: CGFloat = 6.0
        let capW: CGFloat = 16.0

        let path = NSBezierPath()
        path.move(to: CGPoint(x: topX, y: topY))
        path.line(to: CGPoint(x: topX, y: midY - capGap/2))

        path.move(to: CGPoint(x: topX - capW/2, y: midY - capGap/2))
        path.line(to: CGPoint(x: topX + capW/2, y: midY - capGap/2))

        path.move(to: CGPoint(x: topX - capW/2, y: midY + capGap/2))
        path.line(to: CGPoint(x: topX + capW/2, y: midY + capGap/2))

        path.move(to: CGPoint(x: topX, y: midY + capGap/2))
        path.line(to: CGPoint(x: topX, y: groundY))

        NSColor.black.setStroke()
        path.lineWidth = 1.5
        path.stroke()

        drawBadge(point: CGPoint(x: topX + 12, y: midY - 6), text: "\(name): \(valueStr)", textColor: color)
    }

    private func drawShuntInductor(topX: CGFloat, topY: CGFloat, groundY: CGFloat, name: String, valueStr: String, color: NSColor) {
        let midY = (topY + groundY) / 2.0
        let len: CGFloat = 36.0
        let numLoops = 4
        let loopR = len / CGFloat(numLoops * 2)

        let path = NSBezierPath()
        path.move(to: CGPoint(x: topX, y: topY))
        path.line(to: CGPoint(x: topX, y: midY - len/2))

        for i in 0..<numLoops {
            let cy = midY - len/2 + loopR + CGFloat(i * 2) * loopR
            path.appendArc(withCenter: CGPoint(x: topX, y: cy), radius: loopR, startAngle: 270, endAngle: 90, clockwise: true)
        }

        path.move(to: CGPoint(x: topX, y: midY + len/2))
        path.line(to: CGPoint(x: topX, y: groundY))

        NSColor.black.setStroke()
        path.lineWidth = 1.5
        path.stroke()

        drawBadge(point: CGPoint(x: topX + 12, y: midY - 6), text: "\(name): \(valueStr)", textColor: color)
    }

    private func drawShuntResistor(topX: CGFloat, topY: CGFloat, groundY: CGFloat, name: String, valueStr: String, color: NSColor) {
        let midY = (topY + groundY) / 2.0
        let resW: CGFloat = 10.0
        let resH: CGFloat = 24.0

        let path = NSBezierPath()
        path.move(to: CGPoint(x: topX, y: topY))
        path.line(to: CGPoint(x: topX, y: midY - resH/2))

        let rect = CGRect(x: topX - resW/2, y: midY - resH/2, width: resW, height: resH)
        path.appendRect(rect)

        path.move(to: CGPoint(x: topX, y: midY + resH/2))
        path.line(to: CGPoint(x: topX, y: groundY))

        NSColor.black.setStroke()
        path.lineWidth = 1.5
        path.stroke()

        drawBadge(point: CGPoint(x: topX + 12, y: midY - 6), text: "\(name): \(valueStr)", textColor: color)
    }

    private func drawShuntZobelBranch(
        topX: CGFloat,
        topY: CGFloat,
        groundY: CGFloat,
        rzStr: String,
        czStr: String
    ) {
        let midY = (topY + groundY) / 2.0
        let rH: CGFloat = 16.0
        let rW: CGFloat = 10.0
        let capGap: CGFloat = 5.0
        let capW: CGFloat = 16.0

        let path = NSBezierPath()
        // Top wire to Rz
        path.move(to: CGPoint(x: topX, y: topY))
        path.line(to: CGPoint(x: topX, y: midY - 20.0))

        // Rz Resistor Box
        let rRect = CGRect(x: topX - rW/2, y: midY - 20.0, width: rW, height: rH)
        path.appendRect(rRect)

        // Wire Rz to Cz
        path.move(to: CGPoint(x: topX, y: midY - 4.0))
        path.line(to: CGPoint(x: topX, y: midY + 10.0 - capGap/2))

        // Cz Capacitor Plates
        path.move(to: CGPoint(x: topX - capW/2, y: midY + 10.0 - capGap/2))
        path.line(to: CGPoint(x: topX + capW/2, y: midY + 10.0 - capGap/2))

        path.move(to: CGPoint(x: topX - capW/2, y: midY + 10.0 + capGap/2))
        path.line(to: CGPoint(x: topX + capW/2, y: midY + 10.0 + capGap/2))

        // Wire Cz to Ground
        path.move(to: CGPoint(x: topX, y: midY + 10.0 + capGap/2))
        path.line(to: CGPoint(x: topX, y: groundY))

        NSColor.black.setStroke()
        path.lineWidth = 1.5
        path.stroke()

        drawBadge(point: CGPoint(x: topX + 12, y: midY - 16), text: "Rz: \(rzStr)", textColor: .systemOrange)
        drawBadge(point: CGPoint(x: topX + 12, y: midY + 6), text: "Cz: \(czStr)", textColor: .systemOrange)
    }

    private func drawSpeakerSymbol(
        topX: CGFloat,
        topY: CGFloat,
        groundY: CGFloat,
        title: String,
        subTitle: String
    ) {
        let midY = (topY + groundY) / 2.0
        let spkW: CGFloat = 14.0
        let spkH: CGFloat = 30.0
        let coneDepth: CGFloat = 14.0

        let path = NSBezierPath()
        // Wire in from top
        path.move(to: CGPoint(x: topX, y: topY))
        path.line(to: CGPoint(x: topX, y: midY - spkH/2))

        // Wire down to ground
        path.move(to: CGPoint(x: topX, y: midY + spkH/2))
        path.line(to: CGPoint(x: topX, y: groundY))

        // Voice Coil Box
        let boxRect = CGRect(x: topX, y: midY - spkH/2, width: spkW, height: spkH)
        path.appendRect(boxRect)

        // Cone Flared Trapezoid
        path.move(to: CGPoint(x: topX + spkW, y: midY - spkH/2))
        path.line(to: CGPoint(x: topX + spkW + coneDepth, y: midY - spkH/2 - 10))
        path.line(to: CGPoint(x: topX + spkW + coneDepth, y: midY + spkH/2 + 10))
        path.line(to: CGPoint(x: topX + spkW, y: midY + spkH/2))

        NSColor.black.setStroke()
        path.lineWidth = 1.5
        path.stroke()

        let plusAttrs: [NSAttributedString.Key: Any] = [.font: NSFont.boldSystemFont(ofSize: 8), .foregroundColor: NSColor.systemRed]
        let minusAttrs: [NSAttributedString.Key: Any] = [.font: NSFont.boldSystemFont(ofSize: 8), .foregroundColor: NSColor.black]
        "+".draw(at: CGPoint(x: topX + 3, y: midY - spkH/2 + 2), withAttributes: plusAttrs)
        "-".draw(at: CGPoint(x: topX + 3, y: midY + spkH/2 - 10), withAttributes: minusAttrs)

        let titleAttrs: [NSAttributedString.Key: Any] = [.font: NSFont.boldSystemFont(ofSize: 8.5), .foregroundColor: NSColor.black]
        let subAttrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 8), .foregroundColor: NSColor.darkGray]

        title.draw(at: CGPoint(x: topX + spkW + coneDepth + 6, y: midY - 8), withAttributes: titleAttrs)
        subTitle.draw(at: CGPoint(x: topX + spkW + coneDepth + 6, y: midY + 4), withAttributes: subAttrs)
    }
}
