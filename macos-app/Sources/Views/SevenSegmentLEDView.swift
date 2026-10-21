import SwiftUI

public struct SevenSegmentLEDView: View {
    @ObservedObject var engine: RPNEngine
    
    public init(engine: RPNEngine) {
        self.engine = engine
    }
    
    public var body: some View {
        VStack(spacing: 4) {
            // LED Top Status Line
            HStack {
                Text(engine.powerOn ? "HP-35 RPN [\(engine.angleMode.rawValue)]" : "POWER OFF")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(red: 0.4, green: 0.1, blue: 0.1))
                Spacer()
                Text(engine.memory != 0 ? "M" : "")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.red)
            }
            
            // Red Glowing LED Digits
            HStack {
                Spacer()
                if engine.powerOn {
                    Text(engine.displayString)
                        .font(.system(size: 26, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(red: 1.0, green: 0.2, blue: 0.2))
                        .shadow(color: Color.red.opacity(0.8), radius: 6, x: 0, y: 0)
                } else {
                    Text("888888888888888")
                        .font(.system(size: 26, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(red: 0.2, green: 0.05, blue: 0.05))
                        .opacity(0.3)
                }
            }
            .frame(height: 38)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color(red: 0.05, green: 0.02, blue: 0.02))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(red: 0.2, green: 0.2, blue: 0.25), lineWidth: 3)
        )
        .shadow(color: .black.opacity(0.8), radius: 8, x: 0, y: 4)
    }
}
