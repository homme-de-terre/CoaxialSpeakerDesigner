import SwiftUI

public struct ImpedanceChartView: View {
    @ObservedObject var viewModel: MainDesignerViewModel
    public var isDetachedWindow: Bool

    public init(viewModel: MainDesignerViewModel, isDetachedWindow: Bool = false) {
        self.viewModel = viewModel
        self.isDetachedWindow = isDetachedWindow
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 12) {
                    Text("System Electrical Load Impedance (|Z| in Ohms vs Log Hz)")
                        .font(.headline)
                        .lineLimit(1)
                    Spacer()

                    if !isDetachedWindow {
                        Button(action: { viewModel.openDetachedChart(.impedance) }) {
                            Label("Detach", systemImage: "arrow.up.forward.square")
                                .font(.caption)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .help("Open System Impedance in a floating live window")
                    }
                }

                HStack(spacing: 14) {
                    Button(action: { viewModel.showWoofer.toggle() }) {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(viewModel.showWoofer ? Color.blue : Color.gray.opacity(0.35))
                                .frame(width: 8, height: 8)
                            Text("Woofer |Z|")
                                .foregroundColor(viewModel.showWoofer ? .blue : .secondary)
                                .font(.caption).bold()
                        }
                    }
                    .buttonStyle(.plain)

                    Button(action: { viewModel.showTweeter.toggle() }) {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(viewModel.showTweeter ? Color.red : Color.gray.opacity(0.35))
                                .frame(width: 8, height: 8)
                            Text("Tweeter |Z|")
                                .foregroundColor(viewModel.showTweeter ? .red : .secondary)
                                .font(.caption).bold()
                        }
                    }
                    .buttonStyle(.plain)

                    Button(action: { viewModel.showTotalSystem.toggle() }) {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(viewModel.showTotalSystem ? Color.purple : Color.gray.opacity(0.35))
                                .frame(width: 8, height: 8)
                            Text("Amplifier System Load |Z|")
                                .foregroundColor(viewModel.showTotalSystem ? .purple : .secondary)
                                .font(.caption).bold()
                        }
                    }
                    .buttonStyle(.plain)

                    Spacer()
                }
            }
            .padding(.horizontal)

            let _ = viewModel.simulationRevision
            let _ = viewModel.simulationPoints.count

            Canvas { context, size in
                let (minZ, maxZ, stepZ) = Self.determineImpedanceRange(
                    points: viewModel.simulationPoints,
                    showWoofer: viewModel.showWoofer,
                    showTweeter: viewModel.showTweeter,
                    showTotalSystem: viewModel.showTotalSystem
                )
                drawLogGrid(context: context, size: size, minZ: minZ, maxZ: maxZ, stepZ: stepZ)
                drawImpedanceCurves(context: context, size: size, minZ: minZ, maxZ: maxZ)
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

    /// Computes auto-scaled Y-axis range and grid step for the Impedance plot to maximize vertical resolution.
    public static func determineImpedanceRange(
        points: [SimulationPoint],
        showWoofer: Bool,
        showTweeter: Bool,
        showTotalSystem: Bool
    ) -> (minZ: Double, maxZ: Double, stepZ: Double) {
        guard !points.isEmpty else {
            return (0.0, 50.0, 10.0)
        }
        var maxObserved: Double = 0.0

        for p in points {
            if showWoofer && p.wooferImpedanceMag.isFinite {
                maxObserved = max(maxObserved, p.wooferImpedanceMag)
            }
            if showTweeter && p.tweeterImpedanceMag.isFinite {
                maxObserved = max(maxObserved, p.tweeterImpedanceMag)
            }
            if showTotalSystem && p.totalSystemImpedanceMag.isFinite {
                maxObserved = max(maxObserved, p.totalSystemImpedanceMag)
            }
        }

        if maxObserved <= 0.0 {
            return (0.0, 50.0, 10.0)
        }

        let targetMax = max(8.0, maxObserved * 1.08)
        let stepZ: Double
        if targetMax <= 16.0 {
            stepZ = 2.0
        } else if targetMax <= 45.0 {
            stepZ = 5.0
        } else if targetMax <= 120.0 {
            stepZ = 10.0
        } else {
            stepZ = 20.0
        }

        let maxZ = ceil(targetMax / stepZ) * stepZ
        return (0.0, maxZ, stepZ)
    }

    private func drawLogGrid(context: GraphicsContext, size: CGSize, minZ: Double, maxZ: Double, stepZ: Double) {
        let minF = 20.0
        let maxF = 20000.0
        let logMin = log10(minF)
        let logMax = log10(maxF)
        let spanZ = max(maxZ - minZ, 1.0)

        // Vertical Logarithmic Frequency Gridlines
        let majorFreqs = [20, 50, 100, 200, 500, 1000, 2000, 5000, 10000, 20000]
        for f in majorFreqs {
            let x = size.width * CGFloat((log10(Double(f)) - logMin) / (logMax - logMin))
            var path = Path()
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: size.height))
            context.stroke(path, with: .color(Color.gray.opacity(0.25)), lineWidth: 1)

            let labelText = f >= 1000 ? "\(f/1000)k" : "\(f)"
            let textX = f == 20000 ? x - 14 : x + 10
            context.draw(Text(labelText).font(.caption2).foregroundColor(.secondary), at: CGPoint(x: textX, y: size.height - 12))
        }

        // Auto-scaled Horizontal Impedance Gridlines
        for z in stride(from: minZ, through: maxZ + 0.01, by: stepZ) {
            let y = size.height * CGFloat(1.0 - (z - minZ) / spanZ)
            var path = Path()
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: size.width, y: y))
            context.stroke(path, with: .color(Color.gray.opacity(0.2)), lineWidth: 1)

            if z > minZ + 0.01 {
                let textY = y <= 2.0 ? y + 8 : y - 8
                context.draw(Text("\(Int(round(z))) Ω").font(.caption2).foregroundColor(.secondary), at: CGPoint(x: 18, y: textY))
            }
        }
    }

    private func drawImpedanceCurves(context: GraphicsContext, size: CGSize, minZ: Double, maxZ: Double) {
        let minF = 20.0
        let maxF = 20000.0
        let logMin = log10(minF)
        let logMax = log10(maxF)
        let spanZ = max(maxZ - minZ, 1.0)

        let points = viewModel.simulationPoints
        guard !points.isEmpty else { return }

        func zToCanvas(freq: Double, zMag: Double) -> CGPoint {
            let clampedZ = max(min(zMag, maxZ), minZ)
            let x = size.width * CGFloat((log10(freq) - logMin) / (logMax - logMin))
            let y = size.height * CGFloat(1.0 - (clampedZ - minZ) / spanZ)
            return CGPoint(x: x, y: y)
        }

        // Woofer Raw / Box Impedance
        if viewModel.showWoofer {
            var wPath = Path()
            wPath.move(to: zToCanvas(freq: points[0].frequency, zMag: points[0].wooferImpedanceMag))
            for p in points.dropFirst() {
                wPath.addLine(to: zToCanvas(freq: p.frequency, zMag: p.wooferImpedanceMag))
            }
            context.stroke(wPath, with: .color(.blue.opacity(0.8)), lineWidth: 1.5)
        }

        // Tweeter Raw Impedance
        if viewModel.showTweeter {
            var tPath = Path()
            tPath.move(to: zToCanvas(freq: points[0].frequency, zMag: points[0].tweeterImpedanceMag))
            for p in points.dropFirst() {
                tPath.addLine(to: zToCanvas(freq: p.frequency, zMag: p.tweeterImpedanceMag))
            }
            context.stroke(tPath, with: .color(.red.opacity(0.8)), lineWidth: 1.5)
        }

        // Total Amplifier System Load Impedance
        if viewModel.showTotalSystem {
            var totalPath = Path()
            totalPath.move(to: zToCanvas(freq: points[0].frequency, zMag: points[0].totalSystemImpedanceMag))
            for p in points.dropFirst() {
                totalPath.addLine(to: zToCanvas(freq: p.frequency, zMag: p.totalSystemImpedanceMag))
            }
            context.stroke(totalPath, with: .color(.purple), lineWidth: 2.5)
        }
    }
}
