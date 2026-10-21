import SwiftUI

public struct StackInspectorView: View {
    @ObservedObject var engine: RPNEngine
    
    public init(engine: RPNEngine) {
        self.engine = engine
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "square.3.layers.3d.down.right")
                    .foregroundColor(.orange)
                Text("RPN Operational Stack")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                Text("4-Level Stack")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(4)
            }
            .padding(.bottom, 4)
            
            // Register Cards
            VStack(spacing: 6) {
                RegisterRowView(name: "T", label: "Top Register", val: engine.stack.T, color: .indigo)
                RegisterRowView(name: "Z", label: "Third Register", val: engine.stack.Z, color: .blue)
                RegisterRowView(name: "Y", label: "Second Register", val: engine.stack.Y, color: .green)
                RegisterRowView(name: "X", label: "Display Register", val: engine.stack.X, color: .orange, isHighlighted: true)
            }
            
            // Memory & Lift Status
            HStack(spacing: 8) {
                HStack {
                    Image(systemName: "externaldrive")
                        .foregroundColor(.green)
                    Text("Memory:")
                        .foregroundColor(.gray)
                    Text(String(format: "%.4g", engine.memory))
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                }
                .font(.system(size: 11, design: .monospaced))
                .padding(6)
                .frame(maxWidth: .infinity)
                .background(Color.black.opacity(0.4))
                .cornerRadius(6)
                
                HStack {
                    Text("Lift:")
                        .foregroundColor(.gray)
                    Text(engine.liftEnabled ? "ENABLED" : "DISABLED")
                        .fontWeight(.bold)
                        .foregroundColor(engine.liftEnabled ? .cyan : .gray)
                }
                .font(.system(size: 11, design: .monospaced))
                .padding(6)
                .frame(maxWidth: .infinity)
                .background(Color.black.opacity(0.4))
                .cornerRadius(6)
            }
            
            Divider()
                .background(Color.gray.opacity(0.3))
            
            // History Log
            HStack {
                Image(systemName: "clock.arrow.circlepath")
                    .foregroundColor(.orange)
                Text("Calculation History")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                if !engine.history.isEmpty {
                    Button(action: { engine.history.removeAll() }) {
                        Image(systemName: "trash")
                            .font(.system(size: 10))
                            .foregroundColor(.gray)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            
            if engine.history.isEmpty {
                VStack(spacing: 4) {
                    Text("No calculations logged yet")
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 6) {
                        ForEach(engine.history) { item in
                            Button(action: {
                                engine.stack = item.stackAfter
                            }) {
                                HStack {
                                    Text(item.op)
                                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.orange.opacity(0.2))
                                        .foregroundColor(.orange)
                                        .cornerRadius(4)
                                    
                                    Text(item.note)
                                        .font(.system(size: 11))
                                        .foregroundColor(.white)
                                        .lineLimit(1)
                                    
                                    Spacer()
                                    
                                    Text("Restore")
                                        .font(.system(size: 9))
                                        .foregroundColor(.gray)
                                }
                                .padding(6)
                                .background(Color.black.opacity(0.3))
                                .cornerRadius(6)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
            }
        }
        .padding(14)
        .background(Color(red: 0.12, green: 0.13, blue: 0.16))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}

public struct RegisterRowView: View {
    let name: String
    let label: String
    let val: Double
    let color: Color
    var isHighlighted: Bool = false
    
    public var body: some View {
        HStack {
            Text(name)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(color)
                .frame(width: 22, height: 22)
                .background(Color.black.opacity(0.6))
                .cornerRadius(4)
            
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.gray)
            
            Spacer()
            
            Text(String(format: "%.8g", val))
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundColor(isHighlighted ? .orange : .white)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(color.opacity(0.12))
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
    }
}
