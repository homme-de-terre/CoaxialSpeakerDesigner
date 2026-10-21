import Foundation
import Combine

public enum AngleMode: String, CaseIterable, Identifiable {
    case deg = "DEG"
    case rad = "RAD"
    
    public var id: String { self.rawValue }
}

public struct StackState: Equatable {
    public var X: Double = 0.0
    public var Y: Double = 0.0
    public var Z: Double = 0.0
    public var T: Double = 0.0
    
    public init(X: Double = 0.0, Y: Double = 0.0, Z: Double = 0.0, T: Double = 0.0) {
        self.X = X
        self.Y = Y
        self.Z = Z
        self.T = T
    }
}

public struct HistoryItem: Identifiable, Equatable {
    public let id = UUID()
    public let op: String
    public let note: String
    public let stackAfter: StackState
}

public class RPNEngine: ObservableObject {
    @Published public var stack = StackState()
    @Published public var memory: Double = 0.0
    @Published public var angleMode: AngleMode = .deg
    @Published public var arcActive: Bool = false
    @Published public var powerOn: Bool = true
    
    @Published public var entryBuffer: String = "0"
    @Published public var isEnteringNumber: Bool = false
    @Published public var liftEnabled: Bool = true
    @Published public var eexMode: Bool = false
    @Published public var eexBuffer: String = ""
    @Published public var errorMessage: String? = nil
    
    @Published public var history: [HistoryItem] = []
    
    // UI State Properties (eliminates @State macro reliance for compiler compatibility)
    @Published public var activeKeyPressed: String = ""
    @Published public var showUserGuide: Bool = false
    @Published public var selectedGuideTab: Int = 0
    
    public init() {}
    
    // MARK: - Display Formatting
    public var displayString: String {
        guard powerOn else { return "" }
        if let err = errorMessage {
            return err
        }
        
        if eexMode {
            let main = entryBuffer.isEmpty ? "0" : entryBuffer
            let exp = eexBuffer.isEmpty ? "0" : eexBuffer
            let paddedExp = exp.count < 2 ? String(repeating: " ", count: 2 - exp.count) + exp : exp
            return "\(main) E \(paddedExp)"
        }
        
        if isEnteringNumber {
            return entryBuffer
        }
        
        let val = stack.X
        if val.isNaN {
            return "  ERROR"
        }
        if val.isInfinite {
            return val > 0 ? "  9.99999 E 99" : " -9.99999 E 99"
        }
        if val == 0 {
            return "0."
        }
        
        let absVal = abs(val)
        if absVal >= 1e10 || absVal < 1e-7 {
            let formatter = NumberFormatter()
            formatter.numberStyle = .scientific
            formatter.maximumFractionDigits = 5
            let formatted = formatter.string(from: NSNumber(value: val)) ?? "\(val)"
            return formatted.replacingOccurrences(of: "E", with: " E ")
        }
        
        // Fixed precision with dot
        let str = String(format: "%.8g", val)
        if !str.contains(".") {
            return str + "."
        }
        return str
    }
    
    private func logStep(_ opName: String, _ note: String = "") {
        let item = HistoryItem(op: opName, note: note, stackAfter: stack)
        history.insert(item, at: 0)
        if history.count > 50 {
            history.removeLast()
        }
    }
    
    private func liftStack(newX: Double) -> StackState {
        return StackState(X: newX, Y: stack.X, Z: stack.Y, T: stack.Z)
    }
    
    // MARK: - Calculator Actions
    
    public func digit(_ digit: String) {
        guard powerOn else { return }
        errorMessage = nil
        
        if eexMode {
            if digit == "." { return }
            var newEex = eexBuffer
            if newEex.count < 2 {
                newEex += digit
            }
            eexBuffer = newEex
            let mainVal = Double(entryBuffer) ?? 0.0
            let expVal = Double(newEex) ?? 0.0
            stack.X = mainVal * pow(10, expVal)
            return
        }
        
        if !isEnteringNumber {
            if liftEnabled {
                stack = liftStack(newX: 0)
            }
            let newBuf = (digit == ".") ? "0." : digit
            entryBuffer = newBuf
            isEnteringNumber = true
            liftEnabled = true
            stack.X = Double(newBuf) ?? 0.0
        } else {
            if digit == "." && entryBuffer.contains(".") { return }
            let newBuf = (entryBuffer == "0" && digit != ".") ? digit : entryBuffer + digit
            entryBuffer = newBuf
            stack.X = Double(newBuf) ?? 0.0
        }
    }
    
    public func enter() {
        guard powerOn else { return }
        errorMessage = nil
        
        stack = StackState(X: stack.X, Y: stack.X, Z: stack.Y, T: stack.Z)
        isEnteringNumber = false
        liftEnabled = false
        eexMode = false
        eexBuffer = ""
        logStep("ENTER ↑", "Duplicated X to Y, lifted Z and T")
    }
    
    public enum BinaryOpSymbol {
        case add, sub, mul, div, pow
    }
    
    public func binaryOp(_ op: BinaryOpSymbol) {
        guard powerOn else { return }
        errorMessage = nil
        
        let x = stack.X
        let y = stack.Y
        var res: Double = 0.0
        var err: String? = nil
        var opName = ""
        
        switch op {
        case .add:
            res = y + x
            opName = "+"
        case .sub:
            res = y - x
            opName = "-"
        case .mul:
            res = y * x
            opName = "×"
        case .div:
            if x == 0 { err = "DIV BY ZERO" }
            else { res = y / x }
            opName = "÷"
        case .pow:
            if y < 0 && floor(x) != x { err = "INVALID POW" }
            else { res = Foundation.pow(y, x) }
            opName = "x^y"
        }
        
        if let err = err {
            errorMessage = err
            return
        }
        
        stack = StackState(X: res, Y: stack.Z, Z: stack.T, T: stack.T)
        isEnteringNumber = false
        liftEnabled = true
        eexMode = false
        eexBuffer = ""
        logStep(opName, "\(y) \(opName) \(x) = \(res)")
    }
    
    public enum UnaryOpSymbol {
        case sqrt, inv, ln, log, exp, pow10, sin, cos, tan, asin, acos, atan
    }
    
    public func unaryOp(_ op: UnaryOpSymbol) {
        guard powerOn else { return }
        errorMessage = nil
        
        var targetOp = op
        if arcActive {
            if op == .sin { targetOp = .asin }
            if op == .cos { targetOp = .acos }
            if op == .tan { targetOp = .atan }
            arcActive = false
        }
        
        let x = stack.X
        var res: Double = 0.0
        var err: String? = nil
        var opName = ""
        
        let toRad: (Double) -> Double = { [weak self] val in
            return (self?.angleMode == .deg) ? (val * .pi) / 180.0 : val
        }
        let toAngle: (Double) -> Double = { [weak self] rad in
            return (self?.angleMode == .deg) ? (rad * 180.0) / .pi : rad
        }
        
        switch targetOp {
        case .sqrt:
            if x < 0 { err = "NEG SQRT" }
            else { res = Foundation.sqrt(x) }
            opName = "√x"
        case .inv:
            if x == 0 { err = "DIV BY ZERO" }
            else { res = 1.0 / x }
            opName = "1/x"
        case .ln:
            if x <= 0 { err = "LN DOMAIN" }
            else { res = Foundation.log(x) }
            opName = "LN"
        case .log:
            if x <= 0 { err = "LOG DOMAIN" }
            else { res = Foundation.log10(x) }
            opName = "LOG"
        case .exp:
            res = Foundation.exp(x)
            opName = "e^x"
        case .pow10:
            res = Foundation.pow(10, x)
            opName = "10^x"
        case .sin:
            res = Foundation.sin(toRad(x))
            opName = "SIN"
        case .cos:
            res = Foundation.cos(toRad(x))
            opName = "COS"
        case .tan:
            let rad = toRad(x)
            if abs(Foundation.cos(rad)) < 1e-12 { err = "TAN UNDEF" }
            else { res = Foundation.tan(rad) }
            opName = "TAN"
        case .asin:
            if x < -1 || x > 1 { err = "ARCSIN DOMAIN" }
            else { res = toAngle(Foundation.asin(x)) }
            opName = "arcSIN"
        case .acos:
            if x < -1 || x > 1 { err = "ARCCOS DOMAIN" }
            else { res = toAngle(Foundation.acos(x)) }
            opName = "arcCOS"
        case .atan:
            res = toAngle(Foundation.atan(x))
            opName = "arcTAN"
        }
        
        if let err = err {
            errorMessage = err
            return
        }
        
        stack.X = res
        isEnteringNumber = false
        liftEnabled = true
        eexMode = false
        eexBuffer = ""
        logStep(opName, "\(opName)(\(x)) = \(res)")
    }
    
    public func pi() {
        guard powerOn else { return }
        errorMessage = nil
        
        if liftEnabled && isEnteringNumber {
            stack = liftStack(newX: .pi)
        } else {
            stack.X = .pi
        }
        isEnteringNumber = false
        liftEnabled = true
        eexMode = false
        logStep("π", "Pushed π (3.14159...)")
    }
    
    public func rollDown() {
        guard powerOn else { return }
        errorMessage = nil
        stack = StackState(X: stack.Y, Y: stack.Z, Z: stack.T, T: stack.X)
        isEnteringNumber = false
        liftEnabled = true
        logStep("R↓", "Rolled stack down")
    }
    
    public func swap() {
        guard powerOn else { return }
        errorMessage = nil
        stack = StackState(X: stack.Y, Y: stack.X, Z: stack.Z, T: stack.T)
        isEnteringNumber = false
        liftEnabled = true
        logStep("x≷y", "Swapped X and Y")
    }
    
    public func clearX() {
        guard powerOn else { return }
        errorMessage = nil
        stack.X = 0.0
        entryBuffer = "0"
        isEnteringNumber = false
        eexMode = false
        eexBuffer = ""
        logStep("CL X", "Cleared X display")
    }
    
    public func clearAll() {
        guard powerOn else { return }
        errorMessage = nil
        stack = StackState()
        entryBuffer = "0"
        isEnteringNumber = false
        eexMode = false
        eexBuffer = ""
        logStep("CLR", "Cleared entire stack (X, Y, Z, T)")
    }
    
    public func storeMemory() {
        guard powerOn else { return }
        memory = stack.X
        logStep("STO", "Stored \(stack.X) into memory")
    }
    
    public func recallMemory() {
        guard powerOn else { return }
        errorMessage = nil
        if liftEnabled && isEnteringNumber {
            stack = liftStack(newX: memory)
        } else {
            stack.X = memory
        }
        isEnteringNumber = false
        liftEnabled = true
        logStep("RCL", "Recalled \(memory) from memory")
    }
    
    public func changeSign() {
        guard powerOn else { return }
        if eexMode {
            let val = Int(eexBuffer) ?? 0
            let newEex = "\(-val)"
            eexBuffer = newEex
            let mainVal = Double(entryBuffer) ?? 0.0
            stack.X = mainVal * pow(10, Double(-val))
            return
        }
        
        stack.X = -stack.X
        if isEnteringNumber {
            entryBuffer = entryBuffer.hasPrefix("-") ? String(entryBuffer.dropFirst()) : "-" + entryBuffer
        } else {
            entryBuffer = "\(stack.X)"
        }
    }
    
    public func enterExponent() {
        guard powerOn else { return }
        if eexMode { return }
        eexMode = true
        eexBuffer = ""
        if !isEnteringNumber {
            entryBuffer = "\(stack.X)"
        }
    }
    
    public func toggleArc() {
        guard powerOn else { return }
        arcActive.toggle()
    }
    
    public func toggleAngleMode() {
        guard powerOn else { return }
        angleMode = (angleMode == .deg) ? .rad : .deg
    }
    
    public func togglePower() {
        powerOn.toggle()
        if !powerOn {
            stack = StackState()
            entryBuffer = "0"
            isEnteringNumber = false
            eexMode = false
            eexBuffer = ""
            errorMessage = nil
        }
    }
}
