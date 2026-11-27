import Foundation

/// A high-performance structure for complex arithmetic in audio filter physics simulation.
public struct ComplexNumber: Equatable, Sendable {
    public var real: Double
    public var imag: Double

    public init(real: Double, imag: Double = 0.0) {
        self.real = real
        self.imag = imag
    }

    public init(r: Double, theta: Double) {
        self.real = r * cos(theta)
        self.imag = r * sin(theta)
    }

    /// Magnitude |z| = sqrt(real^2 + imag^2)
    public var magnitude: Double {
        return hypot(real, imag)
    }

    /// Phase angle theta in radians (-pi to +pi)
    public var phaseRadians: Double {
        return atan2(imag, real)
    }

    /// Phase angle in degrees (-180 to +180)
    public var phaseDegrees: Double {
        return phaseRadians * (180.0 / .pi)
    }

    /// Conjugate z* = real - j*imag
    public var conjugate: ComplexNumber {
        return ComplexNumber(real: real, imag: -imag)
    }

    // MARK: - Arithmetic Operators

    public static func + (lhs: ComplexNumber, rhs: ComplexNumber) -> ComplexNumber {
        return ComplexNumber(real: lhs.real + rhs.real, imag: lhs.imag + rhs.imag)
    }

    public static func + (lhs: ComplexNumber, rhs: Double) -> ComplexNumber {
        return ComplexNumber(real: lhs.real + rhs, imag: lhs.imag)
    }

    public static func + (lhs: Double, rhs: ComplexNumber) -> ComplexNumber {
        return ComplexNumber(real: lhs + rhs.real, imag: rhs.imag)
    }

    public static func - (lhs: ComplexNumber, rhs: ComplexNumber) -> ComplexNumber {
        return ComplexNumber(real: lhs.real - rhs.real, imag: lhs.imag - rhs.imag)
    }

    public static func - (lhs: ComplexNumber, rhs: Double) -> ComplexNumber {
        return ComplexNumber(real: lhs.real - rhs, imag: lhs.imag)
    }

    public static func - (lhs: Double, rhs: ComplexNumber) -> ComplexNumber {
        return ComplexNumber(real: lhs - rhs.real, imag: -rhs.imag)
    }

    public static prefix func - (val: ComplexNumber) -> ComplexNumber {
        return ComplexNumber(real: -val.real, imag: -val.imag)
    }

    public static func * (lhs: ComplexNumber, rhs: ComplexNumber) -> ComplexNumber {
        return ComplexNumber(
            real: lhs.real * rhs.real - lhs.imag * rhs.imag,
            imag: lhs.real * rhs.imag + lhs.imag * rhs.real
        )
    }

    public static func * (lhs: ComplexNumber, rhs: Double) -> ComplexNumber {
        return ComplexNumber(real: lhs.real * rhs, imag: lhs.imag * rhs)
    }

    public static func * (lhs: Double, rhs: ComplexNumber) -> ComplexNumber {
        return ComplexNumber(real: lhs * rhs.real, imag: lhs * rhs.imag)
    }

    public static func / (lhs: ComplexNumber, rhs: ComplexNumber) -> ComplexNumber {
        let denom = rhs.real * rhs.real + rhs.imag * rhs.imag
        guard denom != 0 else { return ComplexNumber(real: 0, imag: 0) }
        return ComplexNumber(
            real: (lhs.real * rhs.real + lhs.imag * rhs.imag) / denom,
            imag: (lhs.imag * rhs.real - lhs.real * rhs.imag) / denom
        )
    }

    public static func / (lhs: ComplexNumber, rhs: Double) -> ComplexNumber {
        guard rhs != 0 else { return ComplexNumber(real: 0, imag: 0) }
        return ComplexNumber(real: lhs.real / rhs, imag: lhs.imag / rhs)
    }

    public static func / (lhs: Double, rhs: ComplexNumber) -> ComplexNumber {
        let denom = rhs.real * rhs.real + rhs.imag * rhs.imag
        guard denom != 0 else { return ComplexNumber(real: 0, imag: 0) }
        return ComplexNumber(
            real: (lhs * rhs.real) / denom,
            imag: (-lhs * rhs.imag) / denom
        )
    }
}
