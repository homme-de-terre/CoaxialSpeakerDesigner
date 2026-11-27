import SwiftUI

public struct StepResponseChartView: View {
    @ObservedObject var viewModel: MainDesignerViewModel
    public var isDetachedWindow: Bool

    public init(viewModel: MainDesignerViewModel, isDetachedWindow: Bool = false) {
        self.viewModel = viewModel
        self.isDetachedWindow = isDetachedWindow
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header with legend and transient alignment controls
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Acoustic Transient Step Response (Amplitude vs Time)")
                        .font(.headline)
                    let delayMs = (viewModel.crossover.acousticCenterOffsetMM / 1000.0) / 343.0 * 1000.0
                    let apfStatus = viewModel.crossover.enableAllpassFilter ? " • All-Pass Delay: Active (\(Int(viewModel.crossover.allpassOptimizedF0 ?? viewModel.crossover.crossoverFrequency)) Hz, Q=\(String(format: "%.2f", viewModel.crossover.allpassOptimizedQ ?? 0.7)))" : ""
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
                            Text("Woofer (LP)")
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
                            Text("Tweeter (HP)")
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
                            Text("Total System")
                                .foregroundColor(viewModel.showTotalSystem ? .green : .secondary)
                                .font(.caption).bold()
                        }
                    }
                    .buttonStyle(.plain)
                }

                Divider().frame(height: 18)

                Toggle("Invert Polarity", isOn: $viewModel.crossover.invertTweeterPolarity)
                    .toggleStyle(.checkbox)
                    .font(.caption)

                if !isDetachedWindow {
                    Divider().frame(height: 16)
                    Button(action: { viewModel.openDetachedChart(.stepResponse) }) {
                        Label("Detach", systemImage: "arrow.up.forward.square")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help("Open Step Response in a floating live window")
                }
            }
            .padding(.horizontal)

            let _ = viewModel.simulationRevision
            let _ = viewModel.stepResponsePoints.count

            // Step Response Canvas Plot
            Canvas { context, size in
                drawGrid(context: context, size: size)
                drawStepCurves(context: context, size: size)
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

    private func drawGrid(context: GraphicsContext, size: CGSize) {
        let maxTimeMs = 6.0
        let minAmp = -0.6
        let maxAmp = 1.4

        // Vertical Time Gridlines (every 0.5 ms, labels every 1.0 ms)
        for t in stride(from: 0.0, through: maxTimeMs, by: 0.5) {
            let x = size.width * CGFloat(t / maxTimeMs)
            var path = Path()
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: size.height))
            let isMajor = (Int(round(t * 10.0)) % 10 == 0)
            context.stroke(
                path,
                with: .color(isMajor ? Color.gray.opacity(0.35) : Color.gray.opacity(0.15)),
                lineWidth: isMajor ? 1.0 : 0.5
            )

            if isMajor {
                let label = t == 0 ? "0 ms" : "\(Int(t)) ms"
                let textX = t >= maxTimeMs - 0.01 ? x - 18 : x + 14
                context.draw(
                    Text(label).font(.caption2).foregroundColor(.secondary),
                    at: CGPoint(x: textX, y: size.height - 12)
                )
            }
        }

        // Horizontal Amplitude Gridlines (every 0.25 units, prominent 0.0 line)
        for amp in stride(from: minAmp, through: maxAmp, by: 0.25) {
            let y = size.height * CGFloat(1.0 - (amp - minAmp) / (maxAmp - minAmp))
            var path = Path()
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: size.width, y: y))

            let isZero = abs(amp) < 0.01
            context.stroke(
                path,
                with: .color(isZero ? Color.primary.opacity(0.5) : Color.gray.opacity(0.2)),
                lineWidth: isZero ? 1.5 : 0.8
            )

            if amp > minAmp + 0.01 {
                let textY = y <= 2.0 ? y + 8 : y - 8
                context.draw(
                    Text(String(format: "%.2f", amp)).font(.caption2).foregroundColor(isZero ? .primary : .secondary),
                    at: CGPoint(x: 22, y: textY)
                )
            }
        }
    }

    private func drawStepCurves(context: GraphicsContext, size: CGSize) {
        let points = viewModel.stepResponsePoints
        guard !points.isEmpty else { return }

        let maxTimeMs = 6.0
        let minAmp = -0.6
        let maxAmp = 1.4

        func toCanvas(timeMs: Double, amp: Double) -> CGPoint {
            let clampedT = max(0.0, min(maxTimeMs, timeMs))
            let clampedA = max(minAmp, min(maxAmp, amp))
            let x = size.width * CGFloat(clampedT / maxTimeMs)
            let y = size.height * CGFloat(1.0 - (clampedA - minAmp) / (maxAmp - minAmp))
            return CGPoint(x: x, y: y)
        }

        func drawPath(color: Color, lineWidth: CGFloat, keyPath: KeyPath<StepResponsePoint, Double>) {
            var path = Path()
            var started = false

            for p in points {
                let pt = toCanvas(timeMs: p.timeMs, amp: p[keyPath: keyPath])
                if !started {
                    path.move(to: pt)
                    started = true
                } else {
                    path.addLine(to: pt)
                }
            }

            context.stroke(path, with: .color(color), lineWidth: lineWidth)
        }

        // 1. Woofer (Low-Pass Filtered) - Blue
        if viewModel.showWoofer {
            drawPath(color: Color.blue.opacity(0.85), lineWidth: 2.0, keyPath: \.woofer)
        }

        // 2. Tweeter (High-Pass + Delay + Polarity) - Red
        if viewModel.showTweeter {
            drawPath(color: Color.red.opacity(0.85), lineWidth: 2.0, keyPath: \.tweeter)
        }

        // 3. Combined Total System - Green
        if viewModel.showTotalSystem {
            drawPath(color: Color.green, lineWidth: 2.5, keyPath: \.total)
        }
    }
}
