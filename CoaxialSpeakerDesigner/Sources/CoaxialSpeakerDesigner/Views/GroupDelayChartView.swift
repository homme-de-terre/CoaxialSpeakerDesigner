import SwiftUI

public struct GroupDelayChartView: View {
    @ObservedObject var viewModel: MainDesignerViewModel
    public var isDetachedWindow: Bool

    public init(viewModel: MainDesignerViewModel, isDetachedWindow: Bool = false) {
        self.viewModel = viewModel
        self.isDetachedWindow = isDetachedWindow
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header with legend and delay alignment summary
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Acoustic & Electrical Group Delay (Milliseconds vs Log Hz)")
                        .font(.headline)
                    let delayMs = (viewModel.crossover.acousticCenterOffsetMM / 1000.0) / 343.0 * 1000.0
                    let apfStatus = viewModel.crossover.enableAllpassFilter
                        ? " • APF Delay: Active (\(Int(viewModel.crossover.allpassOptimizedF0 ?? viewModel.crossover.crossoverFrequency)) Hz, Q=\(String(format: "%.2f", viewModel.crossover.allpassOptimizedQ ?? 0.70)))"
                        : ""
                    Text("Tweeter Depth Delay: \(String(format: "%.1f mm (%.2f ms)", viewModel.crossover.acousticCenterOffsetMM, delayMs)) • Polarity: \(viewModel.crossover.invertTweeterPolarity ? "Inverted (-)" : "Normal (+)")\(apfStatus)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Spacer()

                HStack(spacing: 12) {
                    Button(action: { viewModel.showWoofer.toggle() }) {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(viewModel.showWoofer ? Color.blue : Color.gray.opacity(0.35))
                                .frame(width: 8, height: 8)
                            Text("Woofer GD")
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
                            Text("Tweeter GD")
                                .foregroundColor(viewModel.showTweeter ? .red : .secondary)
                                .font(.caption).bold()
                        }
                    }
                    .buttonStyle(.plain)

                    Button(action: { viewModel.showTotalSystem.toggle() }) {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(viewModel.showTotalSystem ? Color.green : Color.gray.opacity(0.35))
                                .frame(width: 8, height: 8)
                            Text("Total System GD")
                                .foregroundColor(viewModel.showTotalSystem ? .green : .secondary)
                                .font(.caption).bold()
                        }
                    }
                    .buttonStyle(.plain)

                    if !isDetachedWindow {
                        Divider().frame(height: 16)
                        Button(action: { viewModel.openDetachedChart(.groupDelay) }) {
                            Label("Detach", systemImage: "arrow.up.forward.square")
                                .font(.caption)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .help("Open Group Delay in a floating live window")
                    }
                }
            }
            .padding(.horizontal)

            let _ = viewModel.simulationRevision
            let _ = viewModel.simulationPoints.count

            // Group Delay Canvas Plot
            Canvas { context, size in
                let (minMs, maxMs, stepMs) = Self.determineGroupDelayRange(
                    points: viewModel.simulationPoints,
                    showWoofer: viewModel.showWoofer,
                    showTweeter: viewModel.showTweeter,
                    showTotalSystem: viewModel.showTotalSystem
                )
                drawLogGrid(context: context, size: size, minMs: minMs, maxMs: maxMs, stepMs: stepMs)
                drawGroupDelayCurves(context: context, size: size, minMs: minMs, maxMs: maxMs)
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

    /// Computes auto-scaled Y-axis range and grid step for the Group Delay plot to maximize vertical resolution.
    public static func determineGroupDelayRange(
        points: [SimulationPoint],
        showWoofer: Bool,
        showTweeter: Bool,
        showTotalSystem: Bool
    ) -> (minMs: Double, maxMs: Double, stepMs: Double) {
        guard !points.isEmpty else {
            return (0.0, 5.0, 1.0)
        }
        var maxObserved: Double = -Double.infinity
        var minObserved: Double = Double.infinity

        for p in points {
            if showWoofer && p.wooferGroupDelayMs.isFinite {
                maxObserved = max(maxObserved, p.wooferGroupDelayMs)
                minObserved = min(minObserved, p.wooferGroupDelayMs)
            }
            if showTweeter && p.tweeterGroupDelayMs.isFinite {
                maxObserved = max(maxObserved, p.tweeterGroupDelayMs)
                minObserved = min(minObserved, p.tweeterGroupDelayMs)
            }
            if showTotalSystem && p.totalSystemGroupDelayMs.isFinite {
                maxObserved = max(maxObserved, p.totalSystemGroupDelayMs)
                minObserved = min(minObserved, p.totalSystemGroupDelayMs)
            }
        }

        if !maxObserved.isFinite || !minObserved.isFinite {
            return (0.0, 5.0, 1.0)
        }

        let rawMax = max(0.4, maxObserved * 1.08)
        let rawMin = minObserved < -0.05 ? (minObserved * 1.08) : 0.0
        let rawSpan = max(0.4, rawMax - rawMin)

        let stepMs: Double
        if rawSpan <= 1.2 {
            stepMs = 0.2
        } else if rawSpan <= 3.0 {
            stepMs = 0.5
        } else if rawSpan <= 10.0 {
            stepMs = 1.0
        } else if rawSpan <= 25.0 {
            stepMs = 2.0
        } else {
            stepMs = 5.0
        }

        let minMs = rawMin < 0.0 ? (floor(rawMin / stepMs) * stepMs) : 0.0
        let maxMs = max(minMs + stepMs, ceil(rawMax / stepMs) * stepMs)
        return (minMs, maxMs, stepMs)
    }

    private func drawLogGrid(context: GraphicsContext, size: CGSize, minMs: Double, maxMs: Double, stepMs: Double) {
        let minF = 20.0
        let maxF = 20000.0
        let logMin = log10(minF)
        let logMax = log10(maxF)

        let majorFreqs = [20, 50, 100, 200, 500, 1000, 2000, 5000, 10000, 20000]

        // Subtle shaded band for 2-octave crossover zone
        let fLow = min(viewModel.crossover.actualWooferFrequency, viewModel.crossover.actualTweeterFrequency)
        let fHigh = max(viewModel.crossover.actualWooferFrequency, viewModel.crossover.actualTweeterFrequency)
        let f1 = max(minF, fLow / 2.0)
        let f2 = min(maxF, fHigh * 2.0)
        let x1 = size.width * CGFloat((log10(f1) - logMin) / (logMax - logMin))
        let x2 = size.width * CGFloat((log10(f2) - logMin) / (logMax - logMin))
        let zoneRect = CGRect(x: x1, y: 0, width: x2 - x1, height: size.height)
        context.fill(Path(zoneRect), with: .color(Color.teal.opacity(0.06)))

        // Vertical Logarithmic Frequency Gridlines
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

        // Auto-scaled Horizontal Group Delay Gridlines (ms)
        let span = max(maxMs - minMs, 0.1)
        var ms = minMs
        while ms <= maxMs + 0.001 {
            let y = size.height * CGFloat(1.0 - (ms - minMs) / span)
            var path = Path()
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: size.width, y: y))
            let isZero = abs(ms) < 0.01
            context.stroke(
                path,
                with: .color(isZero ? Color.gray.opacity(0.6) : Color.gray.opacity(0.2)),
                lineWidth: isZero ? 1.5 : 0.8
            )

            if ms > minMs + 0.001 {
                let textY = y <= 2.0 ? y + 8 : y - 8
                let label = stepMs < 1.0 ? String(format: "%.1f ms", ms) : String(format: "%.0f ms", ms)
                context.draw(Text(label).font(.caption2).foregroundColor(.secondary), at: CGPoint(x: 24, y: textY))
            }
            ms += stepMs
        }
    }

    private func drawGroupDelayCurves(context: GraphicsContext, size: CGSize, minMs: Double, maxMs: Double) {
        let minF = 20.0
        let maxF = 20000.0
        let logMin = log10(minF)
        let logMax = log10(maxF)
        let span = maxMs - minMs

        let points = viewModel.simulationPoints
        guard !points.isEmpty else { return }

        func gdToCanvas(freq: Double, gdMs: Double) -> CGPoint {
            let safeMs = gdMs.isFinite ? gdMs : 0.0
            let clampedMs = max(min(safeMs, maxMs), minMs)
            let safeF = (freq.isFinite && freq > 0) ? freq : minF
            let x = size.width * CGFloat((log10(safeF) - logMin) / (logMax - logMin))
            let y = size.height * CGFloat(1.0 - (clampedMs - minMs) / span)
            return CGPoint(x: x, y: y)
        }

        func drawGDCurve(keyPath: KeyPath<SimulationPoint, Double>, color: Color, lineWidth: CGFloat = 1.8) {
            var path = Path()
            var started = false

            for p in points {
                let ms = p[keyPath: keyPath]
                guard ms.isFinite else { continue }
                let pt = gdToCanvas(freq: p.frequency, gdMs: ms)

                if !started {
                    path.move(to: pt)
                    started = true
                } else {
                    path.addLine(to: pt)
                }
            }
            context.stroke(path, with: .color(color), lineWidth: lineWidth)
        }

        // Woofer Group Delay
        if viewModel.showWoofer {
            drawGDCurve(keyPath: \.wooferGroupDelayMs, color: .blue.opacity(0.85), lineWidth: 1.8)
        }

        // Tweeter Group Delay
        if viewModel.showTweeter {
            drawGDCurve(keyPath: \.tweeterGroupDelayMs, color: .red.opacity(0.85), lineWidth: 1.8)
        }

        // Total System Group Delay
        if viewModel.showTotalSystem {
            drawGDCurve(keyPath: \.totalSystemGroupDelayMs, color: .green, lineWidth: 2.5)
        }
    }
}
