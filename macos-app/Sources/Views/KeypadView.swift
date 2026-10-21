import SwiftUI

public enum KeyVariant {
    case funcKey, digitKey, enterKey, accentKey
    
    var backgroundColor: Color {
        switch self {
        case .digitKey: return Color(red: 0.22, green: 0.23, blue: 0.28)
        case .funcKey: return Color(red: 0.15, green: 0.22, blue: 0.32)
        case .enterKey: return Color(red: 0.12, green: 0.30, blue: 0.70)
        case .accentKey: return Color(red: 0.55, green: 0.20, blue: 0.10)
        }
    }
    
    var textColor: Color {
        switch self {
        case .digitKey: return .white
        case .funcKey: return Color(red: 0.88, green: 0.95, blue: 1.0)
        case .enterKey: return .white
        case .accentKey: return Color(red: 1.0, green: 0.9, blue: 0.8)
        }
    }
    
    var borderColor: Color {
        switch self {
        case .digitKey: return Color(red: 0.32, green: 0.33, blue: 0.38)
        case .funcKey: return Color(red: 0.25, green: 0.35, blue: 0.48)
        case .enterKey: return Color(red: 0.25, green: 0.50, blue: 0.95)
        case .accentKey: return Color(red: 0.80, green: 0.30, blue: 0.15)
        }
    }
}

public struct HP35Button: View {
    let id: String
    let label: String
    let subLabel: String?
    let variant: KeyVariant
    let activeKeyPressed: String
    let action: () -> Void
    
    public init(id: String, label: String, subLabel: String? = nil, variant: KeyVariant = .funcKey, activeKeyPressed: String, action: @escaping () -> Void) {
        self.id = id
        self.label = label
        self.subLabel = subLabel
        self.variant = variant
        self.activeKeyPressed = activeKeyPressed
        self.action = action
    }
    
    var isPressed: Bool {
        return activeKeyPressed == id
    }
    
    public var body: some View {
        Button(action: {
            AudioPlayer.shared.playKeyClick(isEnter: id == "enter")
            action()
        }) {
            VStack(spacing: 1) {
                if let sub = subLabel {
                    Text(sub)
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.orange)
                }
                Text(label)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(variant.textColor)
            }
            .frame(maxWidth: .infinity, minHeight: 42)
            .background(variant.backgroundColor)
            .cornerRadius(5)
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(variant.borderColor, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.6), radius: isPressed ? 1 : 3, x: 0, y: isPressed ? 1 : 2)
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.08), value: isPressed)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

public struct KeypadView: View {
    @ObservedObject var engine: RPNEngine
    let activeKeyPressed: String
    
    public init(engine: RPNEngine, activeKeyPressed: String) {
        self.engine = engine
        self.activeKeyPressed = activeKeyPressed
    }
    
    public var body: some View {
        VStack(spacing: 6) {
            // Row 1
            HStack(spacing: 6) {
                HP35Button(id: "pow", label: "x^y", variant: .funcKey, activeKeyPressed: activeKeyPressed) { engine.binaryOp(.pow) }
                HP35Button(id: "log", label: "LOG", variant: .funcKey, activeKeyPressed: activeKeyPressed) { engine.unaryOp(.log) }
                HP35Button(id: "ln", label: "LN", variant: .funcKey, activeKeyPressed: activeKeyPressed) { engine.unaryOp(.ln) }
                HP35Button(id: "exp", label: "e^x", variant: .funcKey, activeKeyPressed: activeKeyPressed) { engine.unaryOp(.exp) }
                HP35Button(id: "clr", label: "CLR", variant: .accentKey, activeKeyPressed: activeKeyPressed) { engine.clearAll() }
            }
            
            // Row 2
            HStack(spacing: 6) {
                HP35Button(id: "sqrt", label: "√x", variant: .funcKey, activeKeyPressed: activeKeyPressed) { engine.unaryOp(.sqrt) }
                HP35Button(id: "arc", label: "ARC", subLabel: engine.arcActive ? "ACTIVE" : "INV", variant: engine.arcActive ? .accentKey : .funcKey, activeKeyPressed: activeKeyPressed) { engine.toggleArc() }
                HP35Button(id: "sin", label: engine.arcActive ? "arcSIN" : "SIN", variant: .funcKey, activeKeyPressed: activeKeyPressed) { engine.unaryOp(.sin) }
                HP35Button(id: "cos", label: engine.arcActive ? "arcCOS" : "COS", variant: .funcKey, activeKeyPressed: activeKeyPressed) { engine.unaryOp(.cos) }
                HP35Button(id: "tan", label: engine.arcActive ? "arcTAN" : "TAN", variant: .funcKey, activeKeyPressed: activeKeyPressed) { engine.unaryOp(.tan) }
            }
            
            // Row 3
            HStack(spacing: 6) {
                HP35Button(id: "inv", label: "1/x", variant: .funcKey, activeKeyPressed: activeKeyPressed) { engine.unaryOp(.inv) }
                HP35Button(id: "swap", label: "x≷y", variant: .funcKey, activeKeyPressed: activeKeyPressed) { engine.swap() }
                HP35Button(id: "roll", label: "R↓", variant: .funcKey, activeKeyPressed: activeKeyPressed) { engine.rollDown() }
                HP35Button(id: "sto", label: "STO", variant: .funcKey, activeKeyPressed: activeKeyPressed) { engine.storeMemory() }
                HP35Button(id: "rcl", label: "RCL", variant: .funcKey, activeKeyPressed: activeKeyPressed) { engine.recallMemory() }
            }
            
            // Row 4: ENTER ↑ (spanning 2 slots), CH S, EEX, CL X
            HStack(spacing: 6) {
                HP35Button(id: "enter", label: "ENTER ↑", variant: .enterKey, activeKeyPressed: activeKeyPressed) { engine.enter() }
                    .frame(maxWidth: .infinity)
                
                HP35Button(id: "chs", label: "CH S", variant: .funcKey, activeKeyPressed: activeKeyPressed) { engine.changeSign() }
                HP35Button(id: "eex", label: "EEX", variant: .funcKey, activeKeyPressed: activeKeyPressed) { engine.enterExponent() }
                HP35Button(id: "clx", label: "CL X", variant: .accentKey, activeKeyPressed: activeKeyPressed) { engine.clearX() }
            }
            
            // Row 5
            HStack(spacing: 6) {
                HP35Button(id: "sub", label: "–", variant: .funcKey, activeKeyPressed: activeKeyPressed) { engine.binaryOp(.sub) }
                HP35Button(id: "7", label: "7", variant: .digitKey, activeKeyPressed: activeKeyPressed) { engine.digit("7") }
                HP35Button(id: "8", label: "8", variant: .digitKey, activeKeyPressed: activeKeyPressed) { engine.digit("8") }
                HP35Button(id: "9", label: "9", variant: .digitKey, activeKeyPressed: activeKeyPressed) { engine.digit("9") }
                HP35Button(id: "add", label: "+", variant: .funcKey, activeKeyPressed: activeKeyPressed) { engine.binaryOp(.add) }
            }
            
            // Row 6
            HStack(spacing: 6) {
                HP35Button(id: "mul", label: "×", variant: .funcKey, activeKeyPressed: activeKeyPressed) { engine.binaryOp(.mul) }
                HP35Button(id: "4", label: "4", variant: .digitKey, activeKeyPressed: activeKeyPressed) { engine.digit("4") }
                HP35Button(id: "5", label: "5", variant: .digitKey, activeKeyPressed: activeKeyPressed) { engine.digit("5") }
                HP35Button(id: "6", label: "6", variant: .digitKey, activeKeyPressed: activeKeyPressed) { engine.digit("6") }
                HP35Button(id: "div", label: "÷", variant: .funcKey, activeKeyPressed: activeKeyPressed) { engine.binaryOp(.div) }
            }
            
            // Row 7
            HStack(spacing: 6) {
                HP35Button(id: "1", label: "1", variant: .digitKey, activeKeyPressed: activeKeyPressed) { engine.digit("1") }
                HP35Button(id: "2", label: "2", variant: .digitKey, activeKeyPressed: activeKeyPressed) { engine.digit("2") }
                HP35Button(id: "3", label: "3", variant: .digitKey, activeKeyPressed: activeKeyPressed) { engine.digit("3") }
                HP35Button(id: "pi", label: "π", variant: .funcKey, activeKeyPressed: activeKeyPressed) { engine.pi() }
            }
            
            // Row 8
            HStack(spacing: 6) {
                HP35Button(id: "0", label: "0", variant: .digitKey, activeKeyPressed: activeKeyPressed) { engine.digit("0") }
                HP35Button(id: "dot", label: ".", variant: .digitKey, activeKeyPressed: activeKeyPressed) { engine.digit(".") }
            }
        }
        .disabled(!engine.powerOn)
        .opacity(engine.powerOn ? 1.0 : 0.6)
    }
}
