import SwiftUI

public struct PhaseBodeChartView: View {
    @ObservedObject var viewModel: MainDesignerViewModel

    public init(viewModel: MainDesignerViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 16) {
                Text("Acoustic Phase & Driver Delay Alignment (Degrees vs Log Hz)")
                    .font(.headline)
                Spacer()

                Text("Woofer Phase").foregroundColor(.blue).font(.caption).bold()
                Text("Tweeter Phase").foregroundColor(.red).font(.caption).bold()
                Text("System Phase").foregroundColor(.green).font(.caption).bold()
                Text("Phase Difference (ΔΦ)").foregroundColor(.orange).font(.caption).bold()
            }
            .padding(.horizontal)

            GeometryReader { geo in
                Canvas { context, size in
                    drawLogGrid(context: context, size: size)
                    drawPhaseCurves(context: context, size: size)
                }
            }
            .frame(minHeight: 380)
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

        // Horizontal Phase Gridlines (-180, -90, 0, 90, 180)
        let phaseAngles = [-180.0, -135.0, -90.0, -45.0, 0.0, 45.0, 90.0, 135.0, 180.0]
        for deg in phaseAngles {
            let y = size.height * CGFloat(1.0 - (deg - (-180.0)) / (360.0))
            var path = Path()
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: size.width, y: y))
            context.stroke(path, with: .color(deg == 0 ? Color.gray.opacity(0.6) : Color.gray.opacity(0.2)), lineWidth: deg == 0 ? 1.5 : 1)

            context.draw(Text("\(Int(deg))°").font(.caption2).foregroundColor(.secondary), at: CGPoint(x: 18, y: y - 8))
        }
    }

    private func drawPhaseCurves(context: GraphicsContext, size: CGSize) {
        let minF = 20.0
        let maxF = 20000.0
        let logMin = log10(minF)
        let logMax = log10(maxF)

        let points = viewModel.simulationPoints
        guard !points.isEmpty else { return }

        func phaseToCanvas(freq: Double, deg: Double) -> CGPoint {
            let safeDeg = deg.isFinite ? deg : 0.0
            let clampedDeg = max(min(safeDeg, 180.0), -180.0)
            let safeF = (freq.isFinite && freq > 0) ? freq : minF
            let x = size.width * CGFloat((log10(safeF) - logMin) / (logMax - logMin))
            let y = size.height * CGFloat(1.0 - (clampedDeg - (-180.0)) / 360.0)
            return CGPoint(x: x, y: y)
        }

        func drawPhaseCurve(keyPath: KeyPath<SimulationPoint, Double>, color: Color, lineWidth: CGFloat = 1.5, isDashed: Bool = false) {
            var path = Path()
            var started = false
            var prevDeg: Double = 0.0

            for p in points {
                let deg = p[keyPath: keyPath]
                guard deg.isFinite else { continue }
                let pt = phaseToCanvas(freq: p.frequency, deg: deg)

                if !started {
                    path.move(to: pt)
                    started = true
                } else if abs(deg - prevDeg) > 170.0 {
                    // Phase wrap jump (-180 to +180 boundary). Break path to avoid vertical sawtooth line.
                    path.move(to: pt)
                } else {
                    path.addLine(to: pt)
                }
                prevDeg = deg
            }

            if isDashed {
                context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: lineWidth, dash: [4, 4]))
            } else {
                context.stroke(path, with: .color(color), lineWidth: lineWidth)
            }
        }

        // Woofer Phase
        drawPhaseCurve(keyPath: \.wooferPhaseDeg, color: .blue.opacity(0.85), lineWidth: 1.5)

        // Tweeter Phase
        drawPhaseCurve(keyPath: \.tweeterPhaseDeg, color: .red.opacity(0.85), lineWidth: 1.5)

        // Inter-Driver Phase Difference Delta Phi
        drawPhaseCurve(keyPath: \.phaseDifferenceDeg, color: .orange, lineWidth: 1.5, isDashed: true)

        // Total System Phase
        drawPhaseCurve(keyPath: \.totalSystemPhaseDeg, color: .green, lineWidth: 2.5)
    }
}
