import SwiftUI

public struct ImpedanceChartView: View {
    @ObservedObject var viewModel: MainDesignerViewModel

    public init(viewModel: MainDesignerViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 16) {
                Text("System Electrical Load Impedance (|Z| in Ohms vs Log Hz)")
                    .font(.headline)
                Spacer()

                Text("Woofer |Z|").foregroundColor(.blue).font(.caption).bold()
                Text("Tweeter |Z|").foregroundColor(.red).font(.caption).bold()
                Text("Amplifier System Load |Z|").foregroundColor(.purple).font(.caption).bold()
            }
            .padding(.horizontal)

            GeometryReader { geo in
                Canvas { context, size in
                    drawLogGrid(context: context, size: size)
                    drawImpedanceCurves(context: context, size: size)
                }
                .id(viewModel.simulationPoints.first?.totalSystemSPL ?? 0)
            }
            .background(Color(NSColor.textBackgroundColor))
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.3), lineWidth: 1))
        }
        .padding()
    }

    private func drawLogGrid(context: GraphicsContext, size: CGSize) {
        let minF = 20.0
        let maxF = 20000.0
        let logMin = log10(minF)
        let logMax = log10(maxF)

        let maxZScale: Double = 100.0 // 0 to 100 Ohms scale

        // Vertical Logarithmic Frequency Gridlines
        let majorFreqs = [20, 50, 100, 200, 500, 1000, 2000, 5000, 10000, 20000]
        for f in majorFreqs {
            let x = size.width * CGFloat((log10(Double(f)) - logMin) / (logMax - logMin))
            var path = Path()
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: size.height))
            context.stroke(path, with: .color(Color.gray.opacity(0.25)), lineWidth: 1)

            let labelText = f >= 1000 ? "\(f/1000)k" : "\(f)"
            context.draw(Text(labelText).font(.caption2).foregroundColor(.secondary), at: CGPoint(x: x + 10, y: size.height - 12))
        }

        // Horizontal Impedance Gridlines (0 to 100 Ohms, step 10 Ohms)
        for z in stride(from: 0.0, through: maxZScale, by: 10.0) {
            let y = size.height * CGFloat(1.0 - z / maxZScale)
            var path = Path()
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: size.width, y: y))
            context.stroke(path, with: .color(Color.gray.opacity(0.2)), lineWidth: 1)

            context.draw(Text("\(Int(z)) Ω").font(.caption2).foregroundColor(.secondary), at: CGPoint(x: 18, y: y - 8))
        }
    }

    private func drawImpedanceCurves(context: GraphicsContext, size: CGSize) {
        let minF = 20.0
        let maxF = 20000.0
        let logMin = log10(minF)
        let logMax = log10(maxF)
        let maxZScale: Double = 100.0

        let points = viewModel.simulationPoints
        guard !points.isEmpty else { return }

        func zToCanvas(freq: Double, zMag: Double) -> CGPoint {
            let clampedZ = max(min(zMag, maxZScale), 0.0)
            let x = size.width * CGFloat((log10(freq) - logMin) / (logMax - logMin))
            let y = size.height * CGFloat(1.0 - clampedZ / maxZScale)
            return CGPoint(x: x, y: y)
        }

        // Woofer Raw / Box Impedance
        var wPath = Path()
        wPath.move(to: zToCanvas(freq: points[0].frequency, zMag: points[0].wooferImpedanceMag))
        for p in points.dropFirst() {
            wPath.addLine(to: zToCanvas(freq: p.frequency, zMag: p.wooferImpedanceMag))
        }
        context.stroke(wPath, with: .color(.blue.opacity(0.8)), lineWidth: 1.5)

        // Tweeter Raw Impedance
        var tPath = Path()
        tPath.move(to: zToCanvas(freq: points[0].frequency, zMag: points[0].tweeterImpedanceMag))
        for p in points.dropFirst() {
            tPath.addLine(to: zToCanvas(freq: p.frequency, zMag: p.tweeterImpedanceMag))
        }
        context.stroke(tPath, with: .color(.red.opacity(0.8)), lineWidth: 1.5)

        // Total Amplifier System Load Impedance
        var totalPath = Path()
        totalPath.move(to: zToCanvas(freq: points[0].frequency, zMag: points[0].totalSystemImpedanceMag))
        for p in points.dropFirst() {
            totalPath.addLine(to: zToCanvas(freq: p.frequency, zMag: p.totalSystemImpedanceMag))
        }
        context.stroke(totalPath, with: .color(.purple), lineWidth: 2.5)
    }
}
