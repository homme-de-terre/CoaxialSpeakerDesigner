import SwiftUI

import SwiftUI

public struct PhaseBodeChartView: View {
    @ObservedObject var viewModel: MainDesignerViewModel

    public init(viewModel: MainDesignerViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Acoustic Phase & Driver Delay Alignment (Degrees vs Log Hz)")
                        .font(.headline)
                    if viewModel.crossover.enableAllpassFilter {
                        let f0 = Int(viewModel.crossover.allpassOptimizedF0 ?? viewModel.crossover.crossoverFrequency)
                        let qVal = String(format: "%.2f", viewModel.crossover.allpassOptimizedQ ?? 0.70)
                        let errVal = String(format: "%.1f°", viewModel.crossover.allpassOptimizationErrorDeg ?? 0.0)
                        let statusColor: Color = viewModel.crossover.allpassOptimizationAchieved ? .teal : .orange
                        Text("All-Pass Nelder-Mead Optimization: F0 = \(f0) Hz, Q = \(qVal) • Crossover Window [\(Int(viewModel.crossover.crossoverFrequency / 2))–\(Int(viewModel.crossover.crossoverFrequency * 2)) Hz] Residual RMS: \(errVal)")
                            .font(.caption2)
                            .foregroundColor(statusColor)
                    } else if viewModel.compensateTweeterDelay {
                        let delayMs = (viewModel.crossover.acousticCenterOffsetMM / 1000.0) / 343.0 * 1000.0
                        Text("Tweeter Acoustic Center Delay Compensated: \(String(format: "%.1f mm (%.2f ms)", viewModel.crossover.acousticCenterOffsetMM, delayMs)) removed from tweeter phase")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()

                Button(action: { viewModel.showWoofer.toggle() }) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(viewModel.showWoofer ? Color.blue : Color.gray.opacity(0.35))
                            .frame(width: 8, height: 8)
                        Text("Woofer Phase")
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
                        Text("Tweeter Phase")
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
                        Text("System Phase")
                            .foregroundColor(viewModel.showTotalSystem ? .green : .secondary)
                            .font(.caption).bold()
                    }
                }
                .buttonStyle(.plain)

                Button(action: { viewModel.showPhaseDiff.toggle() }) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(viewModel.showPhaseDiff ? Color.orange : Color.gray.opacity(0.35))
                            .frame(width: 8, height: 8)
                        Text("Phase Diff (ΔΦ)")
                            .foregroundColor(viewModel.showPhaseDiff ? .orange : .secondary)
                            .font(.caption).bold()
                    }
                }
                .buttonStyle(.plain)

                Divider().frame(height: 16)

                Toggle("Unwrap Phase", isOn: $viewModel.unwrapPhase)
                    .toggleStyle(.checkbox)
                    .font(.caption)

                Toggle("Compensate Delay", isOn: $viewModel.compensateTweeterDelay)
                    .toggleStyle(.checkbox)
                    .font(.caption)
            }
            .padding(.horizontal)

            Canvas { context, size in
                let (minDeg, maxDeg) = determinePhaseRange()
                drawLogGrid(context: context, size: size, minDeg: minDeg, maxDeg: maxDeg)
                drawPhaseCurves(context: context, size: size, minDeg: minDeg, maxDeg: maxDeg)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .frame(minHeight: 380)
            .background(Color(NSColor.textBackgroundColor))
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.3), lineWidth: 1))
        }
        .padding()
    }

    private func determinePhaseRange() -> (minDeg: Double, maxDeg: Double) {
        guard viewModel.unwrapPhase, !viewModel.simulationPoints.isEmpty else {
            return (-180.0, 180.0)
        }
        var minVal = 0.0
        var maxVal = 180.0

        for p in viewModel.simulationPoints {
            if viewModel.showWoofer {
                minVal = min(minVal, p.wooferUnwrappedPhaseDeg)
                maxVal = max(maxVal, p.wooferUnwrappedPhaseDeg)
            }
            if viewModel.showTweeter {
                let twPhase = viewModel.compensateTweeterDelay ? p.tweeterDelayCompensatedPhaseDeg : p.tweeterUnwrappedPhaseDeg
                minVal = min(minVal, twPhase)
                maxVal = max(maxVal, twPhase)
            }
            if viewModel.showTotalSystem {
                minVal = min(minVal, p.totalSystemUnwrappedPhaseDeg)
                maxVal = max(maxVal, p.totalSystemUnwrappedPhaseDeg)
            }
        }
        let snappedMin = floor((minVal - 15.0) / 90.0) * 90.0
        let snappedMax = ceil((maxVal + 15.0) / 90.0) * 90.0
        return (min(snappedMin, -180.0), max(snappedMax, 180.0))
    }

    private func drawLogGrid(context: GraphicsContext, size: CGSize, minDeg: Double, maxDeg: Double) {
        let minF = 20.0
        let maxF = 20000.0
        let logMin = log10(minF)
        let logMax = log10(maxF)

        let majorFreqs = [20, 50, 100, 200, 500, 1000, 2000, 5000, 10000, 20000]

        // Subtle shaded band for 2-octave crossover zone when APF is enabled
        if viewModel.crossover.enableAllpassFilter {
            let fLow = min(viewModel.crossover.actualWooferFrequency, viewModel.crossover.actualTweeterFrequency)
            let fHigh = max(viewModel.crossover.actualWooferFrequency, viewModel.crossover.actualTweeterFrequency)
            let f1 = max(minF, fLow / 2.0)
            let f2 = min(maxF, fHigh * 2.0)
            let x1 = size.width * CGFloat((log10(f1) - logMin) / (logMax - logMin))
            let x2 = size.width * CGFloat((log10(f2) - logMin) / (logMax - logMin))
            let zoneRect = CGRect(x: x1, y: 0, width: x2 - x1, height: size.height)
            context.fill(Path(zoneRect), with: .color(Color.teal.opacity(0.06)))
        }

        for f in majorFreqs {
            let x = size.width * CGFloat((log10(Double(f)) - logMin) / (logMax - logMin))
            var path = Path()
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: size.height))
            context.stroke(path, with: .color(Color.gray.opacity(0.25)), lineWidth: 1)

            let labelText = f >= 1000 ? "\(f/1000)k" : "\(f)"
            context.draw(Text(labelText).font(.caption2).foregroundColor(.secondary), at: CGPoint(x: x + 10, y: size.height - 12))
        }

        // Horizontal Phase Gridlines
        let span = maxDeg - minDeg
        let step: Double = span > 540.0 ? 180.0 : (span > 360.0 ? 90.0 : 45.0)
        var deg = minDeg
        while deg <= maxDeg + 0.1 {
            let y = size.height * CGFloat(1.0 - (deg - minDeg) / span)
            var path = Path()
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: size.width, y: y))
            context.stroke(path, with: .color(abs(deg) < 0.01 ? Color.gray.opacity(0.6) : Color.gray.opacity(0.2)), lineWidth: abs(deg) < 0.01 ? 1.5 : 1)

            context.draw(Text("\(Int(deg))°").font(.caption2).foregroundColor(.secondary), at: CGPoint(x: 18, y: y - 8))
            deg += step
        }
    }

    private func drawPhaseCurves(context: GraphicsContext, size: CGSize, minDeg: Double, maxDeg: Double) {
        let minF = 20.0
        let maxF = 20000.0
        let logMin = log10(minF)
        let logMax = log10(maxF)
        let span = maxDeg - minDeg

        let points = viewModel.simulationPoints
        guard !points.isEmpty else { return }

        func phaseToCanvas(freq: Double, deg: Double) -> CGPoint {
            let safeDeg = deg.isFinite ? deg : 0.0
            let clampedDeg = max(min(safeDeg, maxDeg), minDeg)
            let safeF = (freq.isFinite && freq > 0) ? freq : minF
            let x = size.width * CGFloat((log10(safeF) - logMin) / (logMax - logMin))
            let y = size.height * CGFloat(1.0 - (clampedDeg - minDeg) / span)
            return CGPoint(x: x, y: y)
        }

        func drawCurve(phases: [Double], color: Color, lineWidth: CGFloat = 1.5, isDashed: Bool = false) {
            guard phases.count == points.count else { return }
            var path = Path()
            var started = false
            var prevDeg: Double = 0.0

            for i in 0..<points.count {
                let deg = phases[i]
                guard deg.isFinite else { continue }
                let pt = phaseToCanvas(freq: points[i].frequency, deg: deg)

                if !started {
                    path.move(to: pt)
                    started = true
                } else if !viewModel.unwrapPhase && abs(deg - prevDeg) > 170.0 {
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
        if viewModel.showWoofer {
            let wPhases = viewModel.unwrapPhase ? points.map { $0.wooferUnwrappedPhaseDeg } : points.map { $0.wooferPhaseDeg }
            drawCurve(phases: wPhases, color: .blue.opacity(0.85), lineWidth: 1.5)
        }

        // Tweeter Phase (Supports unwrapped and delay-compensated phase)
        if viewModel.showTweeter {
            let tPhases: [Double]
            if viewModel.compensateTweeterDelay {
                tPhases = points.map { $0.tweeterDelayCompensatedPhaseDeg }
            } else if viewModel.unwrapPhase {
                tPhases = points.map { $0.tweeterUnwrappedPhaseDeg }
            } else {
                tPhases = points.map { $0.tweeterPhaseDeg }
            }
            drawCurve(phases: tPhases, color: .red.opacity(0.85), lineWidth: 1.5)
        }

        // Inter-Driver Phase Difference Delta Phi
        if viewModel.showPhaseDiff {
            drawCurve(phases: points.map { $0.phaseDifferenceDeg }, color: .orange, lineWidth: 1.5, isDashed: true)
        }

        // Total System Phase
        if viewModel.showTotalSystem {
            let sPhases = viewModel.unwrapPhase ? points.map { $0.totalSystemUnwrappedPhaseDeg } : points.map { $0.totalSystemPhaseDeg }
            drawCurve(phases: sPhases, color: .green, lineWidth: 2.5)
        }
    }
}
