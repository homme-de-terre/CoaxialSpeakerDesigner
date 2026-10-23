import SwiftUI

public struct AmplitudeBodeChartView: View {
    @ObservedObject var viewModel: MainDesignerViewModel

    public init(viewModel: MainDesignerViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Chart Legend & Controls Header
            HStack(spacing: 16) {
                Text("Amplitude Frequency Response (dB SPL vs Log Hz)")
                    .font(.headline)
                Spacer()

                Toggle("Woofer", isOn: $viewModel.showWooferFinal)
                    .toggleStyle(.checkbox)
                    .foregroundColor(.blue)

                Toggle("Tweeter", isOn: $viewModel.showTweeterFinal)
                    .toggleStyle(.checkbox)
                    .foregroundColor(.red)

                Toggle("Total System", isOn: $viewModel.showTotalSystem)
                    .toggleStyle(.checkbox)
                    .foregroundColor(.green)

                Toggle("Target Line", isOn: $viewModel.showTargetReference)
                    .toggleStyle(.checkbox)
                    .foregroundColor(.gray)
            }
            .padding(.horizontal)

            // Canvas Logarithmic Plot Render
            GeometryReader { geo in
                Canvas { context, size in
                    drawLogGrid(context: context, size: size)
                    drawCurves(context: context, size: size)
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

        let minSPL = 40.0
        let maxSPL = 110.0

        // Vertical Logarithmic Frequency Gridlines
        let majorFreqs = [20, 50, 100, 200, 500, 1000, 2000, 5000, 10000, 20000]
        for f in majorFreqs {
            let x = size.width * CGFloat((log10(Double(f)) - logMin) / (logMax - logMin))
            var path = Path()
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: size.height))
            context.stroke(path, with: .color(Color.gray.opacity(0.25)), lineWidth: 1)

            // Text Label
            let labelText = f >= 1000 ? "\(f/1000)k" : "\(f)"
            context.draw(Text(labelText).font(.caption2).foregroundColor(.secondary), at: CGPoint(x: x + 10, y: size.height - 12))
        }

        // Horizontal SPL Gridlines (every 10 dB)
        for spl in stride(from: minSPL, through: maxSPL, by: 10.0) {
            let y = size.height * CGFloat(1.0 - (spl - minSPL) / (maxSPL - minSPL))
            var path = Path()
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: size.width, y: y))
            context.stroke(path, with: .color(Color.gray.opacity(0.2)), lineWidth: 1)

            context.draw(Text("\(Int(spl)) dB").font(.caption2).foregroundColor(.secondary), at: CGPoint(x: 18, y: y - 8))
        }
    }

    private func drawCurves(context: GraphicsContext, size: CGSize) {
        let minF = 20.0
        let maxF = 20000.0
        let logMin = log10(minF)
        let logMax = log10(maxF)

        let minSPL = 40.0
        let maxSPL = 110.0

        let points = viewModel.simulationPoints
        guard !points.isEmpty else { return }

        // Helper to compute Canvas CGPoint
        func pointToCanvas(freq: Double, spl: Double) -> CGPoint {
            let clampedSPL = max(min(spl, maxSPL), minSPL)
            let x = size.width * CGFloat((log10(freq) - logMin) / (logMax - logMin))
            let y = size.height * CGFloat(1.0 - (clampedSPL - minSPL) / (maxSPL - minSPL))
            return CGPoint(x: x, y: y)
        }

        // Target Reference Line
        if viewModel.showTargetReference {
            let yRef = size.height * CGFloat(1.0 - (viewModel.targetReferenceSPL - minSPL) / (maxSPL - minSPL))
            var refPath = Path()
            refPath.move(to: CGPoint(x: 0, y: yRef))
            refPath.addLine(to: CGPoint(x: size.width, y: yRef))
            context.stroke(refPath, with: .color(.gray.opacity(0.6)), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
        }

        // Woofer Final Curve
        if viewModel.showWooferFinal {
            var path = Path()
            path.move(to: pointToCanvas(freq: points[0].frequency, spl: points[0].wooferFinalSPL))
            for p in points.dropFirst() {
                path.addLine(to: pointToCanvas(freq: p.frequency, spl: p.wooferFinalSPL))
            }
            context.stroke(path, with: .color(.blue), lineWidth: 2)
        }

        // Tweeter Final Curve
        if viewModel.showTweeterFinal {
            var path = Path()
            path.move(to: pointToCanvas(freq: points[0].frequency, spl: points[0].tweeterFinalSPL))
            for p in points.dropFirst() {
                path.addLine(to: pointToCanvas(freq: p.frequency, spl: p.tweeterFinalSPL))
            }
            context.stroke(path, with: .color(.red), lineWidth: 2)
        }

        // Total System Curve
        if viewModel.showTotalSystem {
            var path = Path()
            path.move(to: pointToCanvas(freq: points[0].frequency, spl: points[0].totalSystemSPL))
            for p in points.dropFirst() {
                path.addLine(to: pointToCanvas(freq: p.frequency, spl: p.totalSystemSPL))
            }
            context.stroke(path, with: .color(.green), lineWidth: 3)
        }
    }
}
