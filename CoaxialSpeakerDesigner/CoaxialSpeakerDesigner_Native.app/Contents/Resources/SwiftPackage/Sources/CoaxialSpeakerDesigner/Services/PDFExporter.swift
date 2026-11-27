import Foundation
import AppKit

/// High-precision, vector multi-page PDF Exporter for Crossover Schematic and Bill of Materials using AppKit & CoreGraphics.
public enum PDFExporter {

    /// Generates a vector 2-page PDF Data object containing:
    /// Page 1: Full-resolution circuit schematic diagram with APF circuitry.
    /// Page 2: Comprehensive Bill of Materials (BOM) table, alignment parameters & APF optimizer report.
    public static func generateSchematicPDF(
        driver: CoaxialDriver,
        cabinet: SealedCabinet,
        crossover: CrossoverNetwork,
        components: CalculatedComponents
    ) -> Data {
        let pageRect = CGRect(x: 0, y: 0, width: 842.0, height: 595.0) // A4 Landscape
        let pdfData = NSMutableData()
        guard let consumer = CGDataConsumer(data: pdfData as CFMutableData) else {
            // Fallback to single page NSView rendering if CGDataConsumer fails
            let reportView = SchematicReportNSView(
                frame: pageRect,
                driver: driver,
                cabinet: cabinet,
                crossover: crossover,
                components: components
            )
            return reportView.dataWithPDF(inside: reportView.bounds)
        }

        var mediaBox = pageRect
        guard let cgContext = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            let reportView = SchematicReportNSView(
                frame: pageRect,
                driver: driver,
                cabinet: cabinet,
                crossover: crossover,
                components: components
            )
            return reportView.dataWithPDF(inside: reportView.bounds)
        }

        let drawer = SchematicReportRenderer(
            driver: driver,
            cabinet: cabinet,
            crossover: crossover,
            components: components
        )

        // ================= PAGE 1: Circuit Schematic Diagram =================
        cgContext.beginPDFPage(nil)
        cgContext.saveGState()
        cgContext.translateBy(x: 0, y: pageRect.height)
        cgContext.scaleBy(x: 1.0, y: -1.0)
        let nsContext1 = NSGraphicsContext(cgContext: cgContext, flipped: true)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = nsContext1
        drawer.drawPage1(bounds: pageRect)
        NSGraphicsContext.restoreGraphicsState()
        cgContext.restoreGState()
        cgContext.endPDFPage()

        // ================= PAGE 2: BOM Table & Technical Summary =============
        cgContext.beginPDFPage(nil)
        cgContext.saveGState()
        cgContext.translateBy(x: 0, y: pageRect.height)
        cgContext.scaleBy(x: 1.0, y: -1.0)
        let nsContext2 = NSGraphicsContext(cgContext: cgContext, flipped: true)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = nsContext2
        drawer.drawPage2(bounds: pageRect)
        NSGraphicsContext.restoreGraphicsState()
        cgContext.restoreGState()
        cgContext.endPDFPage()

        cgContext.closePDF()
        return pdfData as Data
    }
}

// MARK: - Legacy View Wrapper

public class SchematicReportNSView: NSView {
    let renderer: SchematicReportRenderer

    public init(
        frame: CGRect,
        driver: CoaxialDriver,
        cabinet: SealedCabinet,
        crossover: CrossoverNetwork,
        components: CalculatedComponents
    ) {
        self.renderer = SchematicReportRenderer(
            driver: driver,
            cabinet: cabinet,
            crossover: crossover,
            components: components
        )
        super.init(frame: frame)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override var isFlipped: Bool { true }

    public override func draw(_ decoderRect: NSRect) {
        renderer.drawPage1(bounds: self.bounds)
    }
}

// MARK: - Vector Report Renderer

public class SchematicReportRenderer {
    let driver: CoaxialDriver
    let cabinet: SealedCabinet
    let crossover: CrossoverNetwork
    let components: CalculatedComponents

    public init(
        driver: CoaxialDriver,
        cabinet: SealedCabinet,
        crossover: CrossoverNetwork,
        components: CalculatedComponents
    ) {
        self.driver = driver
        self.cabinet = cabinet
        self.crossover = crossover
        self.components = components
    }

    // =========================================================================
    // MARK: - PAGE 1: Full-Resolution Circuit Schematic Diagram
    // =========================================================================
    public func drawPage1(bounds: CGRect) {
        // 1. Fill White Page Background
        NSColor.white.setFill()
        NSBezierPath(rect: bounds).fill()

        // 2. Header Banner
        drawHeaderBanner(bounds: bounds, pageNumber: 1, totalPages: 2, subtitle: "ELECTRICAL CIRCUIT SCHEMATIC")

        // 3. Full Height Vector Circuit Schematic
        drawSchematicDiagram(bounds: bounds)

        // 4. Page Footer
        drawPageFooter(bounds: bounds, pageNumber: 1, totalPages: 2)
    }

    // =========================================================================
    // MARK: - PAGE 2: Bill of Materials & Technical Specifications
    // =========================================================================
    public func drawPage2(bounds: CGRect) {
        // 1. Fill White Page Background
        NSColor.white.setFill()
        NSBezierPath(rect: bounds).fill()

        // 2. Header Banner
        drawHeaderBanner(bounds: bounds, pageNumber: 2, totalPages: 2, subtitle: "BILL OF MATERIALS & TECHNICAL SPECIFICATIONS")

        var startY: CGFloat = 82.0

        // 3. Phase Alignment Status & Warning Alert Box (when APF is enabled)
        if crossover.enableAllpassFilter {
            startY = drawWarningBanner(bounds: bounds, startY: startY)
        }

        // 4. Bill of Materials Table
        let tableEndY = drawBOMTable(bounds: bounds, startY: startY)

        // 5. Technical Specification Cards
        drawTechnicalSpecCards(bounds: bounds, startY: tableEndY + 16.0)

        // 6. Page Footer
        drawPageFooter(bounds: bounds, pageNumber: 2, totalPages: 2)
    }

    // MARK: - Common Header Banner
    private func drawHeaderBanner(bounds: CGRect, pageNumber: Int, totalPages: Int, subtitle: String) {
        let margin: CGFloat = 36.0
        let bannerY: CGFloat = 18.0
        let bannerH: CGFloat = 52.0
        let bannerW = bounds.width - (margin * 2)

        let bannerRect = CGRect(x: margin, y: bannerY, width: bannerW, height: bannerH)
        let path = NSBezierPath(roundedRect: bannerRect, xRadius: 5, yRadius: 5)
        NSColor(calibratedRed: 0.08, green: 0.12, blue: 0.22, alpha: 1.0).setFill()
        path.fill()

        // Document Title
        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 13.0),
            .foregroundColor: NSColor.white
        ]
        "COAXIAL SPEAKER CROSSOVER & CABINET REPORT".draw(
            at: CGPoint(x: margin + 14, y: bannerY + 7),
            withAttributes: titleAttrs
        )

        // Page Badge
        let pageBadge = "PAGE \(pageNumber) OF \(totalPages)"
        let badgeAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 8.5),
            .foregroundColor: NSColor(calibratedRed: 0.5, green: 0.75, blue: 1.0, alpha: 1.0)
        ]
        let badgeSize = pageBadge.size(withAttributes: badgeAttrs)
        pageBadge.draw(at: CGPoint(x: bannerRect.maxX - badgeSize.width - 14, y: bannerY + 8), withAttributes: badgeAttrs)

        // Metadata Subtitle Lines
        let subAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 8.5),
            .foregroundColor: NSColor(calibratedRed: 0.78, green: 0.84, blue: 0.95, alpha: 1.0)
        ]

        let vb = cabinet.computedVolumeLiters(for: driver.wooferTS)
        let fc = cabinet.computedResonanceFc(for: driver.wooferTS)
        let f3 = cabinet.actualF3(for: driver.wooferTS)
        let qtc = cabinet.actualQtc(for: driver.wooferTS)
        let fb = cabinet.actualTuningFb(for: driver.wooferTS)

        let f0Display = Int(crossover.allpassOptimizedF0 ?? crossover.acousticCenterFrequency)
        let apfStatus = crossover.enableAllpassFilter
            ? " | APF Delay: Active (F0 = \(f0Display) Hz, Q = \(String(format: "%.2f", crossover.allpassOptimizedQ ?? 0.70)))"
            : ""
        let cdStatus = crossover.enableCDHornCompensation
            ? " | CD Horn EQ: C_eq + R_eq || R1 (f_eq = \(Int(crossover.cdHornCornerFrequency)) Hz, +\(String(format: "%.1f", crossover.cdHornBoostdB)) dB)"
            : ""

        let xoInfo = crossover.enableIndependentFrequencies
            ? "Crossover: Woofer \(Int(crossover.actualWooferFrequency)) Hz (\(crossover.wooferOrder.rawValue)) / Tweeter \(Int(crossover.actualTweeterFrequency)) Hz (\(crossover.tweeterOrder.rawValue))"
            : "Crossover: \(Int(crossover.crossoverFrequency)) Hz (\(crossover.wooferOrder.rawValue) / \(crossover.tweeterOrder.rawValue))"
        let line1 = "Driver: \(driver.name) (\(driver.manufacturer))  |  \(xoInfo)\(apfStatus)\(cdStatus)"
        let line2: String
        if cabinet.enclosureType == .vented {
            line2 = "Vented Enclosure (4th-Order): Vb = \(String(format: "%.1f", vb)) L  |  Fb = \(String(format: "%.1f", fb)) Hz  |  f3 = \(String(format: "%.1f", f3)) Hz  |  Port: \(cabinet.numberOfPorts)x Ø\(String(format: "%.1f", cabinet.portDiameterCm))cm  |  \(subtitle)"
        } else {
            line2 = "Sealed Enclosure: Vb = \(String(format: "%.2f", vb)) L  |  Fc = \(String(format: "%.1f", fc)) Hz  |  f3 = \(String(format: "%.1f", f3)) Hz  |  Qtc = \(String(format: "%.3f", qtc))  |  \(subtitle)"
        }

        line1.draw(at: CGPoint(x: margin + 14, y: bannerY + 24), withAttributes: subAttrs)
        line2.draw(at: CGPoint(x: margin + 14, y: bannerY + 36), withAttributes: subAttrs)
    }

    // MARK: - Page Footer
    private func drawPageFooter(bounds: CGRect, pageNumber: Int, totalPages: Int) {
        let margin: CGFloat = 36.0
        let footerY = bounds.height - 22.0
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 7.5),
            .foregroundColor: NSColor.gray
        ]
        let leftText = "Generated by Coaxial Speaker Designer • Nelder-Mead Phase Aligned Crossover & Sealed Enclosure"
        let rightText = "Page \(pageNumber) of \(totalPages)"
        leftText.draw(at: CGPoint(x: margin, y: footerY), withAttributes: attrs)

        let rightSize = rightText.size(withAttributes: attrs)
        rightText.draw(at: CGPoint(x: bounds.width - margin - rightSize.width, y: footerY), withAttributes: attrs)
    }

    // MARK: - Page 1 Schematic Drawing
    private func drawSchematicDiagram(bounds: CGRect) {
        let margin: CGFloat = 36.0
        let sectionY: CGFloat = 78.0
        let boxY: CGFloat = 92.0
        let boxH: CGFloat = bounds.height - boxY - 32.0 // Spans to 563 pt (generous 471 pt height!)
        let boxW = bounds.width - (margin * 2)

        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 11),
            .foregroundColor: NSColor(calibratedRed: 0.1, green: 0.25, blue: 0.5, alpha: 1.0)
        ]
        "FULL ELECTRICAL CIRCUIT SCHEMATIC (CROSSOVER & APF DELAY COMPENSATION)".draw(
            at: CGPoint(x: margin, y: sectionY),
            withAttributes: titleAttrs
        )

        // Box Frame
        let boxRect = CGRect(x: margin, y: boxY, width: boxW, height: boxH)
        let boxPath = NSBezierPath(roundedRect: boxRect, xRadius: 4, yRadius: 4)
        NSColor(calibratedRed: 0.98, green: 0.98, blue: 0.99, alpha: 1.0).setFill()
        boxPath.fill()
        NSColor(calibratedRed: 0.8, green: 0.82, blue: 0.86, alpha: 1.0).setStroke()
        boxPath.lineWidth = 1.0
        boxPath.stroke()

        // Background Grid
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

        // Geometry Levels with Generous Vertical Clearance
        let ampX = boxRect.minX + 45.0
        let signalDropX = ampX + 32.0
        let speakerX = boxRect.maxX - 125.0

        // Woofer Branch Levels (Top Tier)
        let wooferHeaderY = boxRect.minY + 16.0
        let wooferY = boxRect.minY + 65.0
        let wooferGroundY = boxRect.minY + 195.0

        // Branch Separator Level
        let branchSeparatorY = boxRect.minY + 225.0

        // Tweeter Branch Levels (Bottom Tier)
        let tweeterHeaderY = boxRect.minY + 242.0
        let tweeterY = boxRect.minY + 305.0
        let tweeterGroundY = boxRect.minY + 435.0

        // Input Terminals (Aligned on the X-axis: AMP (+) at woofer level, AMP (-) at ground level)
        drawTerminalDot(point: CGPoint(x: ampX, y: wooferY), text: "AMP (+)", isPositive: true)
        drawTerminalDot(point: CGPoint(x: ampX, y: tweeterGroundY), text: "AMP (-)", isPositive: false)

        // Top Positive Rail from AMP (+) to signalDropX
        drawWire(from: CGPoint(x: ampX, y: wooferY), to: CGPoint(x: signalDropX, y: wooferY))

        // Signal Drop Wire to Tweeter (+) at signalDropX: from wooferY down to tweeterY
        // Jumps over the woofer ground rail at wooferGroundY with a bridge jumper arc (NO SHORT CIRCUIT!)
        let vSignalDrop = NSBezierPath()
        vSignalDrop.move(to: CGPoint(x: signalDropX, y: wooferY))
        vSignalDrop.line(to: CGPoint(x: signalDropX, y: wooferGroundY - 6.0))
        vSignalDrop.move(to: CGPoint(x: signalDropX, y: wooferGroundY + 6.0))
        vSignalDrop.line(to: CGPoint(x: signalDropX, y: tweeterY))
        NSColor.black.setStroke()
        vSignalDrop.lineWidth = 1.5
        vSignalDrop.stroke()

        // Jumper bridge arc at (signalDropX, wooferGroundY)
        let jumperArc = NSBezierPath()
        jumperArc.appendArc(withCenter: CGPoint(x: signalDropX, y: wooferGroundY), radius: 6.0, startAngle: 90, endAngle: 270, clockwise: false)
        jumperArc.lineWidth = 1.5
        jumperArc.stroke()

        drawJunctionDot(point: CGPoint(x: signalDropX, y: wooferY))
        drawJunctionDot(point: CGPoint(x: signalDropX, y: tweeterY))

        // Vertical Ground Return Line at ampX: from AMP (-) at (ampX, tweeterGroundY) UP to (ampX, wooferGroundY)
        let vGroundBus = NSBezierPath()
        vGroundBus.move(to: CGPoint(x: ampX, y: tweeterGroundY))
        vGroundBus.line(to: CGPoint(x: ampX, y: wooferGroundY))
        vGroundBus.lineWidth = 1.5
        vGroundBus.stroke()
        drawJunctionDot(point: CGPoint(x: ampX, y: tweeterGroundY))
        drawJunctionDot(point: CGPoint(x: ampX, y: wooferGroundY))

        // Dedicated Ground Rails
        let wGroundRail = NSBezierPath()
        wGroundRail.move(to: CGPoint(x: ampX, y: wooferGroundY))
        wGroundRail.line(to: CGPoint(x: speakerX, y: wooferGroundY))
        wGroundRail.lineWidth = 1.5
        wGroundRail.stroke()

        let tGroundRail = NSBezierPath()
        tGroundRail.move(to: CGPoint(x: ampX, y: tweeterGroundY))
        tGroundRail.line(to: CGPoint(x: speakerX, y: tweeterGroundY))
        tGroundRail.lineWidth = 1.5
        tGroundRail.stroke()

        // Horizontal dashed branch separator line
        let sepPath = NSBezierPath()
        sepPath.move(to: CGPoint(x: boxRect.minX + 15, y: branchSeparatorY))
        sepPath.line(to: CGPoint(x: boxRect.maxX - 15, y: branchSeparatorY))
        NSColor(calibratedRed: 0.88, green: 0.90, blue: 0.93, alpha: 1.0).setStroke()
        let dashes: [CGFloat] = [4.0, 4.0]
        sepPath.setLineDash(dashes, count: 2, phase: 0.0)
        sepPath.lineWidth = 0.8
        sepPath.stroke()

        // ==========================================
        // WOOFER LOW-PASS BRANCH (TOP TIER)
        // ==========================================
        var curX = signalDropX
        let wooferTagAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 9.5),
            .foregroundColor: NSColor(calibratedRed: 0.1, green: 0.35, blue: 0.75, alpha: 1.0)
        ]
        let allpassTag = crossover.enableAllpassFilter
            ? " + ALL-PASS DELAY (F0 = \(Int(crossover.allpassOptimizedF0 ?? crossover.crossoverFrequency)) Hz, Q = \(String(format: "%.2f", crossover.allpassOptimizedQ ?? 0.70)))"
            : ""
        "WOOFER LOW-PASS (\(crossover.wooferOrder.rawValue))\(allpassTag)".draw(
            at: CGPoint(x: signalDropX + 15, y: wooferHeaderY),
            withAttributes: wooferTagAttrs
        )

        // Series Inductor L1
        if let l1 = components.L1_mH {
            drawWire(from: CGPoint(x: curX, y: wooferY), to: CGPoint(x: curX + 30, y: wooferY))
            curX += 30
            drawInductorSymbol(startX: curX, endX: curX + 54, y: wooferY, name: "L1", valueStr: "\(String(format: "%.2f", l1)) mH", color: .systemBlue)
            curX += 54
        }

        // Shunt Capacitor C1
        if let c1 = components.C1_uF {
            drawWire(from: CGPoint(x: curX, y: wooferY), to: CGPoint(x: curX + 48, y: wooferY))
            curX += 48
            drawJunctionDot(point: CGPoint(x: curX, y: wooferY))

            drawShuntCapacitor(topX: curX, topY: wooferY, groundY: wooferGroundY, name: "C1", valueStr: "\(String(format: "%.2f", c1)) µF", color: .systemBlue)
            drawJunctionDot(point: CGPoint(x: curX, y: wooferGroundY))
        }

        // Series Inductor L2 (3rd/4th order)
        if let l2 = components.L2_mH {
            drawWire(from: CGPoint(x: curX, y: wooferY), to: CGPoint(x: curX + 30, y: wooferY))
            curX += 30
            drawInductorSymbol(startX: curX, endX: curX + 54, y: wooferY, name: "L2", valueStr: "\(String(format: "%.2f", l2)) mH", color: .systemBlue)
            curX += 54
        }

        // Shunt Capacitor C2 (4th order)
        if let c2 = components.C2_uF {
            drawWire(from: CGPoint(x: curX, y: wooferY), to: CGPoint(x: curX + 48, y: wooferY))
            curX += 48
            drawJunctionDot(point: CGPoint(x: curX, y: wooferY))

            drawShuntCapacitor(topX: curX, topY: wooferY, groundY: wooferGroundY, name: "C2", valueStr: "\(String(format: "%.2f", c2)) µF", color: .systemBlue)
            drawJunctionDot(point: CGPoint(x: curX, y: wooferGroundY))
        }

        // All-Pass Delay Compensation Network (Series L_AP + Shunt C_AP)
        if crossover.enableAllpassFilter, let lap = components.L_AP_mH, let cap = components.C_AP_uF {
            drawWire(from: CGPoint(x: curX, y: wooferY), to: CGPoint(x: curX + 30, y: wooferY))
            curX += 30
            drawInductorSymbol(startX: curX, endX: curX + 54, y: wooferY, name: "L_AP (Delay)", valueStr: "\(String(format: "%.2f", lap)) mH", color: .systemTeal)
            curX += 54

            drawWire(from: CGPoint(x: curX, y: wooferY), to: CGPoint(x: curX + 48, y: wooferY))
            curX += 48
            drawJunctionDot(point: CGPoint(x: curX, y: wooferY))

            drawShuntCapacitor(topX: curX, topY: wooferY, groundY: wooferGroundY, name: "C_AP (Delay)", valueStr: "\(String(format: "%.2f", cap)) µF", color: .systemTeal)
            drawJunctionDot(point: CGPoint(x: curX, y: wooferGroundY))
        }

        // Zobel Network (Shunt Rz + Cz)
        if crossover.enableZobelNetwork, let rz = components.R_zobel_ohms, let cz = components.C_zobel_uF {
            drawWire(from: CGPoint(x: curX, y: wooferY), to: CGPoint(x: curX + 54, y: wooferY))
            curX += 54
            drawJunctionDot(point: CGPoint(x: curX, y: wooferY))

            drawShuntZobelBranch(
                topX: curX,
                topY: wooferY,
                groundY: wooferGroundY,
                rzStr: "\(String(format: "%.2f", rz)) Ω",
                czStr: "\(String(format: "%.2f", cz)) µF"
            )
            drawJunctionDot(point: CGPoint(x: curX, y: wooferGroundY))
        }

        // Wire to Woofer
        drawWire(from: CGPoint(x: curX, y: wooferY), to: CGPoint(x: speakerX, y: wooferY))

        drawSpeakerSymbol(
            topX: speakerX,
            topY: wooferY,
            groundY: wooferGroundY,
            title: "WOOFER",
            subTitle: "Re = \(String(format: "%.1f", driver.wooferTS.re)) Ω",
            invertPolarity: false
        )
        drawJunctionDot(point: CGPoint(x: speakerX, y: wooferGroundY))

        // ==========================================
        // TWEETER HIGH-PASS BRANCH (BOTTOM TIER)
        // ==========================================
        var tCurX = signalDropX
        let tweeterTagAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 9.5),
            .foregroundColor: NSColor(calibratedRed: 0.8, green: 0.15, blue: 0.15, alpha: 1.0)
        ]
        let cdHornTag = crossover.enableCDHornCompensation
            ? " + CD HORN EQ (C_eq + R_eq || R1 @ f_eq = \(Int(crossover.cdHornCornerFrequency)) Hz, +\(String(format: "%.1f", crossover.cdHornBoostdB)) dB)"
            : ""
        "TWEETER HIGH-PASS (\(crossover.tweeterOrder.rawValue))\(cdHornTag)".draw(
            at: CGPoint(x: signalDropX + 15, y: tweeterHeaderY),
            withAttributes: tweeterTagAttrs
        )

        let hpWireLead: CGFloat = crossover.enableCDHornCompensation ? 26.0 : 35.0
        let hpSymW: CGFloat = crossover.enableCDHornCompensation ? 48.0 : 55.0
        let hpShuntStep: CGFloat = crossover.enableCDHornCompensation ? 44.0 : 55.0

        // Series Capacitor C_HP1
        if let c1 = components.C_HP1_uF {
            drawWire(from: CGPoint(x: tCurX, y: tweeterY), to: CGPoint(x: tCurX + hpWireLead, y: tweeterY))
            tCurX += hpWireLead
            drawCapacitorSymbol(startX: tCurX, endX: tCurX + hpSymW, y: tweeterY, name: "C_HP1", valueStr: "\(String(format: "%.2f", c1)) µF", color: .systemRed)
            tCurX += hpSymW
        }

        // Shunt Inductor L_HP1
        if let l1 = components.L_HP1_mH {
            drawWire(from: CGPoint(x: tCurX, y: tweeterY), to: CGPoint(x: tCurX + hpShuntStep, y: tweeterY))
            tCurX += hpShuntStep
            drawJunctionDot(point: CGPoint(x: tCurX, y: tweeterY))

            drawShuntInductor(topX: tCurX, topY: tweeterY, groundY: tweeterGroundY, name: "L_HP1", valueStr: "\(String(format: "%.2f", l1)) mH", color: .systemRed)
            drawJunctionDot(point: CGPoint(x: tCurX, y: tweeterGroundY))
        }

        // Series Capacitor C_HP2 (3rd/4th order)
        if let c2 = components.C_HP2_uF {
            drawWire(from: CGPoint(x: tCurX, y: tweeterY), to: CGPoint(x: tCurX + hpWireLead, y: tweeterY))
            tCurX += hpWireLead
            drawCapacitorSymbol(startX: tCurX, endX: tCurX + hpSymW, y: tweeterY, name: "C_HP2", valueStr: "\(String(format: "%.2f", c2)) µF", color: .systemRed)
            tCurX += hpSymW
        }

        // Shunt Inductor L_HP2 (4th order)
        if let l2 = components.L_HP2_mH {
            drawWire(from: CGPoint(x: tCurX, y: tweeterY), to: CGPoint(x: tCurX + hpShuntStep, y: tweeterY))
            tCurX += hpShuntStep
            drawJunctionDot(point: CGPoint(x: tCurX, y: tweeterY))

            drawShuntInductor(topX: tCurX, topY: tweeterY, groundY: tweeterGroundY, name: "L_HP2", valueStr: "\(String(format: "%.2f", l2)) mH", color: .systemRed)
            drawJunctionDot(point: CGPoint(x: tCurX, y: tweeterGroundY))
        }

        // L-Pad Attenuator (Series R1 + Shunt R2) & Optional CD Horn Mass Roll-Off Bypass (Series C_eq + R_eq || R1)
        if (crossover.enableLPadAttenuator || crossover.enableCDHornCompensation), let r1 = components.R1_lpad_ohms, let r2 = components.R2_lpad_ohms {
            if crossover.enableCDHornCompensation, let ccd = components.C_cd_uF {
                let rcd = components.R_cd_ohms ?? 0.39
                drawWire(from: CGPoint(x: tCurX, y: tweeterY), to: CGPoint(x: tCurX + 26, y: tweeterY))
                tCurX += 26

                let loopStartX = tCurX
                let loopWidth: CGFloat = 136.0
                let loopEndX = loopStartX + loopWidth
                let bypassY = tweeterY - 40.0

                // Parallel loop junction dots on main tweeter rail
                drawJunctionDot(point: CGPoint(x: loopStartX, y: tweeterY))
                drawJunctionDot(point: CGPoint(x: loopEndX, y: tweeterY))

                // Lower branch: R1 (L-Pad) centered along tweeterY with badge below so it doesn't collide with bypass branch
                let r1SymStart = loopStartX + 36.0
                let r1SymEnd = loopEndX - 36.0
                drawWire(from: CGPoint(x: loopStartX, y: tweeterY), to: CGPoint(x: r1SymStart, y: tweeterY))
                drawResistorSymbol(
                    startX: r1SymStart,
                    endX: r1SymEnd,
                    y: tweeterY,
                    name: "R1 (L-Pad)",
                    valueStr: "\(String(format: "%.2f", r1)) Ω",
                    color: .systemOrange,
                    badgeBelow: true
                )
                drawWire(from: CGPoint(x: r1SymEnd, y: tweeterY), to: CGPoint(x: loopEndX, y: tweeterY))

                // Upper parallel bypass branch: vertical risers + series C_eq capacitor and R_eq damping resistor
                drawWire(from: CGPoint(x: loopStartX, y: tweeterY), to: CGPoint(x: loopStartX, y: bypassY))
                drawWire(from: CGPoint(x: loopEndX, y: tweeterY), to: CGPoint(x: loopEndX, y: bypassY))

                let capEndX = loopStartX + 64.0
                let resStartX = capEndX + 8.0
                drawCapacitorSymbol(
                    startX: loopStartX,
                    endX: capEndX,
                    y: bypassY,
                    name: "C_eq",
                    valueStr: "\(String(format: "%.2f", ccd)) µF",
                    color: .systemPurple
                )
                drawWire(from: CGPoint(x: capEndX, y: bypassY), to: CGPoint(x: resStartX, y: bypassY))
                drawResistorSymbol(
                    startX: resStartX,
                    endX: loopEndX,
                    y: bypassY,
                    name: "R_eq",
                    valueStr: "\(String(format: "%.2f", rcd)) Ω",
                    color: .systemPurple
                )

                tCurX = loopEndX
            } else {
                drawWire(from: CGPoint(x: tCurX, y: tweeterY), to: CGPoint(x: tCurX + 35, y: tweeterY))
                tCurX += 35
                drawResistorSymbol(startX: tCurX, endX: tCurX + 55, y: tweeterY, name: "R1 (L-Pad)", valueStr: "\(String(format: "%.2f", r1)) Ω", color: .systemOrange)
                tCurX += 55
            }

            drawWire(from: CGPoint(x: tCurX, y: tweeterY), to: CGPoint(x: tCurX + hpShuntStep, y: tweeterY))
            tCurX += hpShuntStep
            drawJunctionDot(point: CGPoint(x: tCurX, y: tweeterY))

            drawShuntResistor(topX: tCurX, topY: tweeterY, groundY: tweeterGroundY, name: "R2 (L-Pad)", valueStr: "\(String(format: "%.2f", r2)) Ω", color: .systemOrange)
            drawJunctionDot(point: CGPoint(x: tCurX, y: tweeterGroundY))
        }

        // Wire to Tweeter
        drawWire(from: CGPoint(x: tCurX, y: tweeterY), to: CGPoint(x: speakerX, y: tweeterY))

        let tweeterTitle = crossover.invertTweeterPolarity ? "TWEETER (-180°)" : "TWEETER (+)"
        drawSpeakerSymbol(
            topX: speakerX,
            topY: tweeterY,
            groundY: tweeterGroundY,
            title: tweeterTitle,
            subTitle: "Re = \(String(format: "%.1f", driver.tweeter.re)) Ω",
            invertPolarity: crossover.invertTweeterPolarity
        )
        drawJunctionDot(point: CGPoint(x: speakerX, y: tweeterGroundY))
    }

    // MARK: - Phase Alignment Status & Warning Alert Box (Page 2)
    private func drawWarningBanner(bounds: CGRect, startY: CGFloat) -> CGFloat {
        let margin: CGFloat = 36.0
        let width = bounds.width - (margin * 2)

        let status = crossover.allpassAlignmentStatus
        let errVal = String(format: "%.2f°", crossover.allpassOptimizationErrorDeg ?? 0.0)
        let primaryLine = "RMS Phase Alignment (\(errVal)): \(status.label)"
        let allLines = [primaryLine] + crossover.allpassWarnings
        let warningH: CGFloat = CGFloat(allLines.count * 15 + 14)

        let fillColor: NSColor
        let strokeColor: NSColor
        let textColor: NSColor
        let iconSymbol: String

        switch status {
        case .optimal:
            fillColor = NSColor(calibratedRed: 0.90, green: 0.98, blue: 0.92, alpha: 1.0)
            strokeColor = NSColor(calibratedRed: 0.15, green: 0.65, blue: 0.30, alpha: 1.0)
            textColor = NSColor(calibratedRed: 0.08, green: 0.45, blue: 0.18, alpha: 1.0)
            iconSymbol = "✓  "
        case .acceptable:
            fillColor = NSColor(calibratedRed: 1.0, green: 0.96, blue: 0.86, alpha: 1.0)
            strokeColor = NSColor(calibratedRed: 0.90, green: 0.60, blue: 0.08, alpha: 1.0)
            textColor = NSColor(calibratedRed: 0.65, green: 0.38, blue: 0.02, alpha: 1.0)
            iconSymbol = "⚠  "
        case .largeOffset:
            fillColor = NSColor(calibratedRed: 1.0, green: 0.91, blue: 0.91, alpha: 1.0)
            strokeColor = NSColor(calibratedRed: 0.85, green: 0.20, blue: 0.20, alpha: 1.0)
            textColor = NSColor(calibratedRed: 0.68, green: 0.10, blue: 0.10, alpha: 1.0)
            iconSymbol = "✖  "
        }

        let warnRect = CGRect(x: margin, y: startY, width: width, height: warningH)
        let path = NSBezierPath(roundedRect: warnRect, xRadius: 4, yRadius: 4)
        fillColor.setFill()
        path.fill()
        strokeColor.setStroke()
        path.lineWidth = 1.0
        path.stroke()

        let warnTitleAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 8.5),
            .foregroundColor: textColor
        ]
        let warnTextAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 8.0),
            .foregroundColor: textColor
        ]

        var lineY = startY + 6.0
        for (idx, w) in allLines.enumerated() {
            let prefix = idx == 0 ? iconSymbol : "⚠  "
            prefix.draw(at: CGPoint(x: margin + 8, y: lineY), withAttributes: warnTitleAttrs)
            w.draw(at: CGPoint(x: margin + 24, y: lineY + 0.5), withAttributes: warnTextAttrs)
            lineY += 15.0
        }

        return startY + warningH + 12.0
    }

    // MARK: - Page 2 BOM Table
    private func drawBOMTable(bounds: CGRect, startY: CGFloat) -> CGFloat {
        let margin: CGFloat = 36.0
        let sectionY = startY
        let tableY = startY + 16.0
        let width = bounds.width - (margin * 2)

        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 11),
            .foregroundColor: NSColor(calibratedRed: 0.1, green: 0.25, blue: 0.5, alpha: 1.0)
        ]
        "CROSSOVER BILL OF MATERIALS (BOM) COMPONENT TABLE".draw(at: CGPoint(x: margin, y: sectionY), withAttributes: titleAttrs)

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

        let colWidths: [CGFloat] = [80.0, 240.0, 150.0, width - 470.0]
        let rowHeight: CGFloat = 17.0

        // Table Header
        let headerRect = CGRect(x: margin, y: tableY, width: width, height: rowHeight)
        NSColor(calibratedRed: 0.15, green: 0.22, blue: 0.35, alpha: 1.0).setFill()
        NSBezierPath(rect: headerRect).fill()

        let headers = ["Designator", "Component Description", "Calculated / Snapped Value", "Recommended Specification & Tolerance"]
        var currentX = margin
        for (i, h) in headers.enumerated() {
            h.draw(at: CGPoint(x: currentX + 6, y: tableY + 3), withAttributes: headerAttrs)
            currentX += colWidths[i]
        }

        // Table Rows Data
        var rows: [(String, String, String, String)] = []
        if let l1 = components.L1_mH { rows.append(("L1", "Woofer Low-Pass Series Inductor", "\(String(format: "%.2f", l1)) mH", "1.2mm OFC Wire, Low DCR")) }
        if let c1 = components.C1_uF { rows.append(("C1", "Woofer Low-Pass Shunt Capacitor", "\(String(format: "%.2f", c1)) µF", "400V DC Metalized Polypropylene Film Cap, ±5%")) }
        if let l2 = components.L2_mH { rows.append(("L2", "Woofer Low-Pass Series Inductor (Higher Order)", "\(String(format: "%.2f", l2)) mH", "1.0mm OFC Wire")) }
        if let c2 = components.C2_uF { rows.append(("C2", "Woofer Low-Pass Shunt Capacitor (4th Order)", "\(String(format: "%.2f", c2)) µF", "250V DC Film Cap")) }

        // All-Pass Delay Compensation Components
        if crossover.enableAllpassFilter {
            let f0Str = crossover.allpassOptimizedF0 != nil ? " (F0 = \(Int(crossover.allpassOptimizedF0!)) Hz)" : ""
            if let lap = components.L_AP_mH { rows.append(("L_AP", "Woofer All-Pass Delay Inductor\(f0Str)", "\(String(format: "%.2f", lap)) mH", "OFC Wire, Low DCR, High Saturation Current")) }
            if let cap = components.C_AP_uF { rows.append(("C_AP", "Woofer All-Pass Delay Capacitor", "\(String(format: "%.2f", cap)) µF", "400V DC Polypropylene Film Cap, ±5% Tolerance")) }
        }

        if let c1 = components.C_HP1_uF { rows.append(("C_HP1", "Tweeter High-Pass Series Capacitor", "\(String(format: "%.2f", c1)) µF", "250V DC High Precision Polypropylene Audio Cap")) }
        if let l1 = components.L_HP1_mH { rows.append(("L_HP1", "Tweeter High-Pass Shunt Inductor", "\(String(format: "%.2f", l1)) mH", "0.8mm Air-Core Wire")) }
        if let c2 = components.C_HP2_uF { rows.append(("C_HP2", "Tweeter High-Pass Series Capacitor (Higher Order)", "\(String(format: "%.2f", c2)) µF", "250V DC Film Cap")) }
        if let l2 = components.L_HP2_mH { rows.append(("L_HP2", "Tweeter High-Pass Shunt Inductor (4th Order)", "\(String(format: "%.2f", l2)) mH", "0.8mm Air-Core Wire")) }

        if let rz = components.R_zobel_ohms { rows.append(("R_zobel", "Woofer Zobel Impedance Compensation Resistor", "\(String(format: "%.2f", rz)) Ω", "10W Non-Inductive Ceramic Resistor")) }
        if let cz = components.C_zobel_uF { rows.append(("C_zobel", "Woofer Zobel Impedance Compensation Capacitor", "\(String(format: "%.2f", cz)) µF", "100V DC Bipolar / Film Cap")) }
        if let r1 = components.R1_lpad_ohms { rows.append(("R1 (L-Pad)", "Tweeter L-Pad Attenuator (Series Element)", "\(String(format: "%.2f", r1)) Ω", "10W Power Metal Oxide / Wirewound Resistor")) }
        if let r2 = components.R2_lpad_ohms { rows.append(("R2 (L-Pad)", "Tweeter L-Pad Attenuator (Shunt Element)", "\(String(format: "%.2f", r2)) Ω", "10W Power Metal Oxide / Wirewound Resistor")) }
        if crossover.enableCDHornCompensation {
            if let ccd = components.C_cd_uF { rows.append(("C_eq (CD Horn)", "CD Horn Mass Roll-Off Bypass Capacitor (|| R1)", "\(String(format: "%.2f", ccd)) µF", "250V DC Polypropylene Film Cap (f_eq = \(Int(crossover.cdHornCornerFrequency)) Hz)")) }
            let rcd = components.R_cd_ohms ?? 0.39
            rows.append(("R_eq (CD Horn)", "CD Horn HF Shelf Damping Resistor (Series w/ C_eq)", "\(String(format: "%.2f", rcd)) Ω", "5W Non-Inductive Metal Oxide Resistor (+\(String(format: "%.1f", crossover.cdHornBoostdB)) dB Shelf)"))
        }

        if cabinet.enclosureType == .vented {
            let lv = cabinet.computedPortLengthCm(for: driver.wooferTS)
            let np = cabinet.numberOfPorts
            let dia = cabinet.portDiameterCm
            rows.append(("Port Duct", "Bass-Reflex Helmholtz Port Duct", "\(np)x Ø\(String(format: "%.1f", dia)) cm × \(String(format: "%.1f", lv)) cm", "Rigid Cylindrical Port Tube, Anti-Turbulence Flared Ends"))
        }

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
                v.0.draw(at: CGPoint(x: currentX + 6, y: curRowY + 3), withAttributes: v.1)
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

        return curRowY
    }

    // MARK: - Technical Specification Cards (Page 2)
    private func drawTechnicalSpecCards(bounds: CGRect, startY: CGFloat) {
        let margin: CGFloat = 36.0
        let totalW = bounds.width - (margin * 2)
        let gap: CGFloat = 14.0
        let cardW = (totalW - (gap * 2)) / 3.0
        let cardH: CGFloat = 160.0

        let vb = cabinet.computedVolumeLiters(for: driver.wooferTS)
        let fc = cabinet.computedResonanceFc(for: driver.wooferTS)
        let f3 = cabinet.actualF3(for: driver.wooferTS)
        let qtc = cabinet.actualQtc(for: driver.wooferTS)
        let qmc = cabinet.actualQmc(for: driver.wooferTS)
        let alpha = cabinet.computedComplianceAlpha(for: driver.wooferTS)

        // Card 1: Enclosure Alignment
        let card1Title = cabinet.enclosureType == .vented ? "4TH-ORDER VENTED ENCLOSURE" : "SEALED ENCLOSURE ALIGNMENT"
        let card1HeaderColor = cabinet.enclosureType == .vented
            ? NSColor(calibratedRed: 0.1, green: 0.45, blue: 0.50, alpha: 1.0)
            : NSColor(calibratedRed: 0.1, green: 0.35, blue: 0.65, alpha: 1.0)

        let card1Items: [(String, String)]
        if cabinet.enclosureType == .vented {
            let fb = cabinet.actualTuningFb(for: driver.wooferTS)
            let lv = cabinet.computedPortLengthCm(for: driver.wooferTS)
            let minDia = cabinet.minRecommendedPortDiameterCm(for: driver.wooferTS)
            card1Items = [
                ("Architecture", "Vented (Bass-Reflex, 4th-Order)"),
                ("Alignment Preset", cabinet.ventedAlignment.rawValue),
                ("Net Volume (Vb)", "\(String(format: "%.1f", vb)) L (\(String(format: "%.2f", vb / 28.3168)) cu ft)"),
                ("Tuning Freq (Fb)", "\(String(format: "%.1f", fb)) Hz"),
                ("Cutoff Freq (f3)", "\(String(format: "%.1f", f3)) Hz"),
                ("Port Spec", "\(cabinet.numberOfPorts)x Ø\(String(format: "%.1f", cabinet.portDiameterCm)) cm × \(String(format: "%.1f", lv)) cm"),
                ("Port Chuffing Limit", "Min Dia ≥ \(String(format: "%.1f", minDia)) cm")
            ]
        } else {
            card1Items = [
                ("Target Alignment", cabinet.alignment.rawValue),
                ("Net Volume (Vb)", "\(String(format: "%.2f", vb)) L (\(String(format: "%.2f", vb / 28.3168)) cu ft)"),
                ("Resonance Freq (Fc)", "\(String(format: "%.1f", fc)) Hz"),
                ("Cutoff Frequency (f3)", "\(String(format: "%.1f", f3)) Hz"),
                ("Total Q (Qtc)", String(format: "%.3f", qtc)),
                ("Mechanical Q (Qmc)", String(format: "%.2f", qmc)),
                ("Compliance Ratio (α)", String(format: "%.2f", alpha))
            ]
        }

        drawSpecCard(
            rect: CGRect(x: margin, y: startY, width: cardW, height: cardH),
            title: card1Title,
            headerColor: card1HeaderColor,
            items: card1Items
        )

        // Card 2: Driver Voice Coil Specs
        drawSpecCard(
            rect: CGRect(x: margin + cardW + gap, y: startY, width: cardW, height: cardH),
            title: "COAXIAL DRIVER SPECIFICATIONS",
            headerColor: NSColor(calibratedRed: 0.2, green: 0.45, blue: 0.25, alpha: 1.0),
            items: [
                ("Woofer Model", driver.name),
                ("Woofer Re / Le", "\(String(format: "%.1f", driver.wooferTS.re)) Ω / \(String(format: "%.2f", driver.wooferTS.le)) mH"),
                ("Woofer Fs / Qts", "\(String(format: "%.1f", driver.wooferTS.fs)) Hz / \(String(format: "%.2f", driver.wooferTS.qts))"),
                ("Woofer Vas / SPL", "\(String(format: "%.1f", driver.wooferTS.vas)) L / \(String(format: "%.1f", driver.wooferTS.spl)) dB"),
                ("Tweeter Re / Le", "\(String(format: "%.1f", driver.tweeter.re)) Ω / \(String(format: "%.2f", driver.tweeter.le)) mH"),
                ("Tweeter Fs / SPL", "\(String(format: "%.0f", driver.tweeter.fs)) Hz / \(String(format: "%.1f", driver.tweeter.spl)) dB"),
                ("Tweeter Nominal Z", "\(String(format: "%.0f", driver.tweeter.nominalImpedance)) Ω")
            ]
        )

        // Card 3: Acoustic Alignment & All-Pass Optimizer Report
        let apfStatus = crossover.allpassAlignmentStatus
        let apfAchievedStr = crossover.enableAllpassFilter
            ? apfStatus.label
            : "Off (Disabled)"
        let f0Str = (crossover.enableAllpassFilter && crossover.allpassOptimizedF0 != nil) ? "\(Int(crossover.allpassOptimizedF0!)) Hz" : "N/A"
        let qStr = (crossover.enableAllpassFilter && crossover.allpassOptimizedQ != nil) ? String(format: "%.2f", crossover.allpassOptimizedQ!) : "N/A"
        let errStr = crossover.allpassOptimizationErrorDeg != nil ? String(format: "%.2f°", crossover.allpassOptimizationErrorDeg!) : "N/A"
        let delayMs = (crossover.acousticCenterOffsetMM / 1000.0) / 343.0 * 1000.0

        let xoSpecPoint = crossover.enableIndependentFrequencies
            ? "\(Int(crossover.actualWooferFrequency)) Hz (W) / \(Int(crossover.actualTweeterFrequency)) Hz (T)"
            : "\(Int(crossover.crossoverFrequency)) Hz"

        var card3Colors: [String: NSColor] = [:]
        if crossover.enableAllpassFilter {
            let statusNSColor: NSColor
            switch apfStatus {
            case .optimal:
                statusNSColor = NSColor(calibratedRed: 0.08, green: 0.50, blue: 0.20, alpha: 1.0)
            case .acceptable:
                statusNSColor = NSColor(calibratedRed: 0.72, green: 0.44, blue: 0.02, alpha: 1.0)
            case .largeOffset:
                statusNSColor = NSColor(calibratedRed: 0.78, green: 0.12, blue: 0.12, alpha: 1.0)
            }
            card3Colors["APF Optimization"] = statusNSColor
            card3Colors["Residual Phase RMS"] = statusNSColor
        }

        drawSpecCard(
            rect: CGRect(x: margin + (cardW + gap) * 2, y: startY, width: cardW, height: cardH),
            title: "ACOUSTIC DELAY & APF OPTIMIZER",
            headerColor: NSColor(calibratedRed: 0.1, green: 0.5, blue: 0.55, alpha: 1.0),
            items: [
                ("Crossover Point (fx)", xoSpecPoint),
                ("Tweeter Depth Delay", "\(String(format: "%.1f", crossover.acousticCenterOffsetMM)) mm (\(String(format: "%.2f", delayMs)) ms)"),
                ("Tweeter Polarity", crossover.invertTweeterPolarity ? "Inverted (-180°)" : "Normal (+)"),
                ("APF Optimization", apfAchievedStr),
                ("Optimal APF F0", f0Str),
                ("Optimal APF Q", qStr),
                ("Residual Phase RMS", errStr)
            ],
            itemColors: card3Colors
        )
    }

    private func drawSpecCard(rect: CGRect, title: String, headerColor: NSColor, items: [(String, String)], itemColors: [String: NSColor] = [:]) {
        // Card Background Box
        let boxPath = NSBezierPath(roundedRect: rect, xRadius: 4, yRadius: 4)
        NSColor(calibratedRed: 0.98, green: 0.98, blue: 0.99, alpha: 1.0).setFill()
        boxPath.fill()
        NSColor(calibratedRed: 0.82, green: 0.85, blue: 0.88, alpha: 1.0).setStroke()
        boxPath.lineWidth = 1.0
        boxPath.stroke()

        // Card Header Bar
        let headerH: CGFloat = 20.0
        let headerRect = CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: headerH)
        headerColor.setFill()
        let headerPath = NSBezierPath(roundedRect: headerRect, xRadius: 4, yRadius: 4)
        headerPath.fill()

        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 8.0),
            .foregroundColor: NSColor.white
        ]
        title.draw(at: CGPoint(x: rect.minX + 8, y: rect.minY + 4), withAttributes: titleAttrs)

        // Card Items
        let labelAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 8.0),
            .foregroundColor: NSColor.darkGray
        ]

        var itemY = rect.minY + headerH + 6.0
        for item in items {
            item.0.draw(at: CGPoint(x: rect.minX + 8, y: itemY), withAttributes: labelAttrs)
            let labelSize = item.0.size(withAttributes: labelAttrs)
            let maxValWidth = rect.width - 22.0 - labelSize.width
            let valColor = itemColors[item.0] ?? NSColor.black

            var fontSize: CGFloat = 8.0
            var valAttrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.boldSystemFont(ofSize: fontSize),
                .foregroundColor: valColor
            ]
            var valSize = item.1.size(withAttributes: valAttrs)
            while valSize.width > maxValWidth && fontSize > 5.5 {
                fontSize -= 0.5
                valAttrs[.font] = NSFont.boldSystemFont(ofSize: fontSize)
                valSize = item.1.size(withAttributes: valAttrs)
            }

            item.1.draw(at: CGPoint(x: rect.maxX - 8 - valSize.width, y: itemY), withAttributes: valAttrs)
            itemY += 18.0
        }
    }

    // MARK: - NSBezierPath Vector Drawing Helpers

    private func drawTerminalDot(point: CGPoint, text: String, isPositive: Bool) {
        let r: CGFloat = 3.5
        let p = NSBezierPath(ovalIn: CGRect(x: point.x - r, y: point.y - r, width: r * 2, height: r * 2))
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
        let p = NSBezierPath(ovalIn: CGRect(x: point.x - r, y: point.y - r, width: r * 2, height: r * 2))
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
        path.line(to: CGPoint(x: midX - capGap / 2, y: y))
        path.move(to: CGPoint(x: midX - capGap / 2, y: y - capH / 2))
        path.line(to: CGPoint(x: midX - capGap / 2, y: y + capH / 2))

        // Plate 2
        path.move(to: CGPoint(x: midX + capGap / 2, y: y - capH / 2))
        path.line(to: CGPoint(x: midX + capGap / 2, y: y + capH / 2))
        path.move(to: CGPoint(x: midX + capGap / 2, y: y))
        path.line(to: CGPoint(x: endX, y: y))

        NSColor.black.setStroke()
        path.lineWidth = 1.5
        path.stroke()

        drawBadge(point: CGPoint(x: startX, y: y - 18), text: "\(name): \(valueStr)", textColor: color)
    }

    private func drawResistorSymbol(startX: CGFloat, endX: CGFloat, y: CGFloat, name: String, valueStr: String, color: NSColor, badgeBelow: Bool = false) {
        let midX = (startX + endX) / 2.0
        let resW: CGFloat = 24.0
        let resH: CGFloat = 10.0

        let path = NSBezierPath()
        path.move(to: CGPoint(x: startX, y: y))
        path.line(to: CGPoint(x: midX - resW / 2, y: y))

        let rect = CGRect(x: midX - resW / 2, y: y - resH / 2, width: resW, height: resH)
        path.appendRect(rect)

        path.move(to: CGPoint(x: midX + resW / 2, y: y))
        path.line(to: CGPoint(x: endX, y: y))

        NSColor.black.setStroke()
        path.lineWidth = 1.5
        path.stroke()

        let badgeY = badgeBelow ? (y + 10.0) : (y - 18.0)
        drawBadge(point: CGPoint(x: startX, y: badgeY), text: "\(name): \(valueStr)", textColor: color)
    }

    private func drawShuntCapacitor(topX: CGFloat, topY: CGFloat, groundY: CGFloat, name: String, valueStr: String, color: NSColor) {
        let midY = (topY + groundY) / 2.0
        let capGap: CGFloat = 6.0
        let capW: CGFloat = 16.0

        let path = NSBezierPath()
        path.move(to: CGPoint(x: topX, y: topY))
        path.line(to: CGPoint(x: topX, y: midY - capGap / 2))

        path.move(to: CGPoint(x: topX - capW / 2, y: midY - capGap / 2))
        path.line(to: CGPoint(x: topX + capW / 2, y: midY - capGap / 2))

        path.move(to: CGPoint(x: topX - capW / 2, y: midY + capGap / 2))
        path.line(to: CGPoint(x: topX + capW / 2, y: midY + capGap / 2))

        path.move(to: CGPoint(x: topX, y: midY + capGap / 2))
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
        path.line(to: CGPoint(x: topX, y: midY - len / 2))

        for i in 0..<numLoops {
            let cy = midY - len / 2 + loopR + CGFloat(i * 2) * loopR
            path.appendArc(withCenter: CGPoint(x: topX, y: cy), radius: loopR, startAngle: 270, endAngle: 90, clockwise: true)
        }

        path.move(to: CGPoint(x: topX, y: midY + len / 2))
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
        path.line(to: CGPoint(x: topX, y: midY - resH / 2))

        let rect = CGRect(x: topX - resW / 2, y: midY - resH / 2, width: resW, height: resH)
        path.appendRect(rect)

        path.move(to: CGPoint(x: topX, y: midY + resH / 2))
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
        let rRect = CGRect(x: topX - rW / 2, y: midY - 20.0, width: rW, height: rH)
        path.appendRect(rRect)

        // Wire Rz to Cz
        path.move(to: CGPoint(x: topX, y: midY - 4.0))
        path.line(to: CGPoint(x: topX, y: midY + 10.0 - capGap / 2))

        // Cz Capacitor Plates
        path.move(to: CGPoint(x: topX - capW / 2, y: midY + 10.0 - capGap / 2))
        path.line(to: CGPoint(x: topX + capW / 2, y: midY + 10.0 - capGap / 2))

        path.move(to: CGPoint(x: topX - capW / 2, y: midY + 10.0 + capGap / 2))
        path.line(to: CGPoint(x: topX + capW / 2, y: midY + 10.0 + capGap / 2))

        // Wire Cz to Ground
        path.move(to: CGPoint(x: topX, y: midY + 10.0 + capGap / 2))
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
        subTitle: String,
        invertPolarity: Bool = false
    ) {
        let midY = (topY + groundY) / 2.0
        let spkW: CGFloat = 16.0
        let spkH: CGFloat = 34.0
        let coneDepth: CGFloat = 16.0
        let coneSpread: CGFloat = 12.0

        let path = NSBezierPath()

        path.move(to: CGPoint(x: topX, y: topY))
        path.line(to: CGPoint(x: topX, y: midY - spkH / 2))

        path.move(to: CGPoint(x: topX, y: midY + spkH / 2))
        path.line(to: CGPoint(x: topX, y: groundY))

        // Voice Coil Box
        let boxRect = CGRect(x: topX, y: midY - spkH / 2, width: spkW, height: spkH)
        path.appendRect(boxRect)

        // Cone Flared Trapezoid
        path.move(to: CGPoint(x: topX + spkW, y: midY - spkH / 2))
        path.line(to: CGPoint(x: topX + spkW + coneDepth, y: midY - spkH / 2 - coneSpread))
        path.line(to: CGPoint(x: topX + spkW + coneDepth, y: midY + spkH / 2 + coneSpread))
        path.line(to: CGPoint(x: topX + spkW, y: midY + spkH / 2))

        NSColor.black.setStroke()
        path.lineWidth = 1.5
        path.stroke()

        let plusAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 9),
            .foregroundColor: NSColor.systemRed
        ]
        let minusAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 9),
            .foregroundColor: NSColor(calibratedWhite: 0.15, alpha: 1.0)
        ]

        if !invertPolarity {
            "+".draw(at: CGPoint(x: topX + 4, y: midY - spkH / 2 + 2), withAttributes: plusAttrs)
            "-".draw(at: CGPoint(x: topX + 5, y: midY + spkH / 2 - 11), withAttributes: minusAttrs)
        } else {
            "-".draw(at: CGPoint(x: topX + 5, y: midY - spkH / 2 + 2), withAttributes: minusAttrs)
            "+".draw(at: CGPoint(x: topX + 4, y: midY + spkH / 2 - 11), withAttributes: plusAttrs)
        }

        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 8.5),
            .foregroundColor: NSColor.black
        ]
        let subAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 8),
            .foregroundColor: NSColor.darkGray
        ]

        title.draw(at: CGPoint(x: topX + spkW + coneDepth + 8, y: midY - 8), withAttributes: titleAttrs)
        subTitle.draw(at: CGPoint(x: topX + spkW + coneDepth + 8, y: midY + 4), withAttributes: subAttrs)

        if invertPolarity {
            drawBadge(
                point: CGPoint(x: topX + spkW + coneDepth + 8, y: midY - 24),
                text: "INVERTED POLARITY (-180°)",
                textColor: NSColor(calibratedRed: 0.85, green: 0.35, blue: 0.05, alpha: 1.0)
            )
        }
    }
}
