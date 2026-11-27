import Foundation

/// Discrete Hilbert Transform for generating minimum phase response from an amplitude response curve.
public enum HilbertTransform {
    /// Computes minimum phase angle (in degrees) for a sequence of (frequency, magnitude_dB) points.
    public static func computeMinimumPhase(points: [ResponseDataPoint]) -> [ResponseDataPoint] {
        guard points.count >= 4 else { return points }
        
        var result = points
        let n = points.count
        
        for i in 0..<n {
            let f0 = points[i].frequency
            var phaseRad = 0.0
            
            for j in 0..<(n - 1) {
                let f1 = points[j].frequency
                let f2 = points[j + 1].frequency
                let mag1 = points[j].magnitude
                let mag2 = points[j + 1].magnitude
                
                guard f1 != f2 else { continue }
                
                // Logarithmic frequency derivative of amplitude d(ln |A|)/d(ln f)
                let dLnA = (log(max(pow(10.0, mag2 / 20.0), 1e-6)) - log(max(pow(10.0, mag1 / 20.0), 1e-6)))
                let dLnF = log(f2 / f1)
                let slope = dLnA / dLnF
                
                // Weighting kernel W = ln |(f + f0) / (f - f0)|
                let fAvg = sqrt(f1 * f2)
                let diff = abs(fAvg - f0)
                if diff > 1e-4 {
                    let ratio = (fAvg + f0) / diff
                    if ratio > 1e-6 {
                        let kernel = log(ratio)
                        let term = (1.0 / .pi) * slope * kernel * dLnF
                        if term.isFinite {
                            phaseRad -= term
                        }
                    }
                }
            }
            
            // Wrap phase to -180...180 range
            var phaseDeg = phaseRad * (180.0 / .pi)
            if !phaseDeg.isFinite {
                phaseDeg = 0.0
            } else {
                phaseDeg = phaseDeg.truncatingRemainder(dividingBy: 360.0)
                if phaseDeg > 180.0 { phaseDeg -= 360.0 }
                if phaseDeg < -180.0 { phaseDeg += 360.0 }
            }
            
            result[i].phase = phaseDeg
        }
        
        return result
    }
}
