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
            let clampedDeg = max(min(deg, 180.0), -180.0)
            let x = size.width * CGFloat((log10(freq) - logMin) / (logMax - logMin))
            let y = size.height * CGFloat(1.0 - (clampedDeg - (-180.0)) / 360.0)
            return CGPoint(x: x, y: y)
        }

        // Woofer Phase
        var wPath = Path()
        wPath.move(to: phaseToCanvas(freq: points[0].frequency, deg: points[0].wooferPhaseDeg))
        for p in points.dropFirst() {
            wPath.addLine(to: phaseToCanvas(freq: p.frequency, deg: p.wooferPhaseDeg))
        }
        context.stroke(wPath, with: .color(.blue.opacity(0.8)), lineWidth: 1.5)

        // Tweeter Phase
        var tPath = Path()
        tPath.move(to: phaseToCanvas(freq: points[0].frequency, deg: points[0].tweeterPhaseDeg))
        for p in points.dropFirst() {
            tPath.addLine(to: phaseToCanvas(freq: p.frequency, deg: p.tweeterPhaseDeg))
        }
        context.stroke(tPath, with: .color(.red.opacity(0.8)), lineWidth: 1.5)

        // Inter-Driver Phase Difference Delta Phi
        var dPath = Path()
        dPath.move(to: phaseToCanvas(freq: points[0].frequency, deg: points[0].phaseDifferenceDeg))
        for p in points.dropFirst() {
            dPath.addLine(to: phaseToCanvas(freq: p.frequency, deg: p.phaseDifferenceDeg))
        }
        context.stroke(dPath, with: .color(.orange), style: StrokeStyle(lineWidth: 1.5, dash: [3, 3]))

        // Total System Phase
        var sysPath = Path()
        sysPath.move(to: phaseToCanvas(freq: points[0].frequency, deg: points[0].totalSystemPhaseDeg))
        for p in points.dropFirst() {
            sysPath.addLine(to: phaseToCanvas(freq: p.frequency, deg: p.totalSystemPhaseDeg))
        }
        context.stroke(sysPath, with: .color(.green), lineWidth: 2.5)
    }
}
