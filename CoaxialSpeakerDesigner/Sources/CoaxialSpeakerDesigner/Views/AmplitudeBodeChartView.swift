import SwiftUI

public struct AmplitudeBodeChartView: View {
    @ObservedObject var viewModel: MainDesignerViewModel
    public var isDetachedWindow: Bool

    public init(viewModel: MainDesignerViewModel, isDetachedWindow: Bool = false) {
        self.viewModel = viewModel
        self.isDetachedWindow = isDetachedWindow
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Chart Legend Header with interactive toggles
            HStack(spacing: 14) {
                Text("Amplitude Frequency Response (dB SPL vs Log Hz)")
                    .font(.headline)
                Spacer()

                Button(action: { viewModel.showWoofer.toggle() }) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(viewModel.showWoofer ? Color.blue : Color.gray.opacity(0.35))
                            .frame(width: 8, height: 8)
                        Text("Woofer (LP)")
                            .foregroundColor(viewModel.showWoofer ? .blue : .secondary)
                            .font(.caption).bold()
                    }
                }
                .buttonStyle(.plain)
                .help("Toggle Woofer response curve")

                Button(action: { viewModel.showTweeter.toggle() }) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(viewModel.showTweeter ? Color.red : Color.gray.opacity(0.35))
                            .frame(width: 8, height: 8)
                        Text("Tweeter (HP)")
                            .foregroundColor(viewModel.showTweeter ? .red : .secondary)
                            .font(.caption).bold()
                    }
                }
                .buttonStyle(.plain)
                .help("Toggle Tweeter response curve")

                Button(action: { viewModel.showTotalSystem.toggle() }) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(viewModel.showTotalSystem ? Color.green : Color.gray.opacity(0.35))
                            .frame(width: 8, height: 8)
                        Text("Total System")
                            .foregroundColor(viewModel.showTotalSystem ? .green : .secondary)
                            .font(.caption).bold()
                    }
                }
                .buttonStyle(.plain)
                .help("Toggle Combined System response curve")

                Button(action: { viewModel.showTargetReference.toggle() }) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(viewModel.showTargetReference ? Color.gray : Color.gray.opacity(0.2))
                            .frame(width: 8, height: 8)
                        Text("Target Line")
                            .foregroundColor(viewModel.showTargetReference ? .secondary : Color.gray.opacity(0.5))
                            .font(.caption).bold()
                    }
                }
                .buttonStyle(.plain)
                .help("Toggle target reference line")

                if !isDetachedWindow {
                    Divider().frame(height: 16)
                    Button(action: { viewModel.openDetachedChart(.amplitude) }) {
                        Label("Detach", systemImage: "arrow.up.forward.square")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help("Open Amplitude Response in a floating live window")
                }
            }
            .padding(.horizontal)

            let _ = viewModel.simulationRevision
            let _ = viewModel.simulationPoints.count

            // Canvas Logarithmic Plot Render
            Canvas { context, size in
                drawLogGrid(context: context, size: size)
                drawCurves(context: context, size: size)
            }
            .id(viewModel.simulationRevision)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
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
            let textX = f == 20000 ? x - 14 : x + 10
            context.draw(Text(labelText).font(.caption2).foregroundColor(.secondary), at: CGPoint(x: textX, y: size.height - 12))
        }

        // Horizontal SPL Gridlines (every 10 dB)
        for spl in stride(from: minSPL, through: maxSPL, by: 10.0) {
            let y = size.height * CGFloat(1.0 - (spl - minSPL) / (maxSPL - minSPL))
            var path = Path()
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: size.width, y: y))
            context.stroke(path, with: .color(Color.gray.opacity(0.2)), lineWidth: 1)

            if spl > minSPL {
                let textY = (spl == maxSPL) ? y + 8 : y - 8
                context.draw(Text("\(Int(spl)) dB").font(.caption2).foregroundColor(.secondary), at: CGPoint(x: 18, y: textY))
            }
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
            let safeSPL = spl.isFinite ? spl : minSPL
            let clampedSPL = max(min(safeSPL, maxSPL), minSPL)
            let safeF = (freq.isFinite && freq > 0) ? freq : minF
            let x = size.width * CGFloat((log10(safeF) - logMin) / (logMax - logMin))
            let y = size.height * CGFloat(1.0 - (clampedSPL - minSPL) / (maxSPL - minSPL))
            return CGPoint(x: x, y: y)
        }

        func drawSplCurve(keyPath: KeyPath<SimulationPoint, Double>, color: Color, lineWidth: CGFloat) {
            var path = Path()
            var started = false
            for p in points {
                let spl = p[keyPath: keyPath]
                guard spl.isFinite else { continue }
                let pt = pointToCanvas(freq: p.frequency, spl: spl)
                if !started {
                    path.move(to: pt)
                    started = true
                } else {
                    path.addLine(to: pt)
                }
            }
            context.stroke(path, with: .color(color), lineWidth: lineWidth)
        }

        // Target Reference Line (Dashed)
        if viewModel.showTargetReference {
            let yRef = size.height * CGFloat(1.0 - (viewModel.targetReferenceSPL - minSPL) / (maxSPL - minSPL))
            var refPath = Path()
            refPath.move(to: CGPoint(x: 0, y: yRef))
            refPath.addLine(to: CGPoint(x: size.width, y: yRef))
            context.stroke(refPath, with: .color(.gray.opacity(0.6)), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
        }

        // Woofer Final Curve (Blue)
        if viewModel.showWoofer {
            drawSplCurve(keyPath: \.wooferFinalSPL, color: .blue, lineWidth: 2)
        }

        // Tweeter Final Curve (Red)
        if viewModel.showTweeter {
            drawSplCurve(keyPath: \.tweeterFinalSPL, color: .red, lineWidth: 2)
        }

        // Total System Curve (Green)
        if viewModel.showTotalSystem {
            drawSplCurve(keyPath: \.totalSystemSPL, color: .green, lineWidth: 3)
        }
    }
}
