import SwiftUI

public struct CalculatorView: View {
    @StateObject private var engine = RPNEngine()
    @State private var keyboardMonitor = KeyboardMonitor()
    @State private var activeKeyPressed: String = ""
    @State private var showUserGuide: Bool = false
    
    public init() {}
    
    public var body: some View {
        HStack(alignment: .top, spacing: 20) {
            // Left Column: Authentic HP-35 Calculator Body
            VStack(spacing: 12) {
                // Metallic Badge Header
                HStack {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 10, height: 10)
                    Text("HEWLETT · PACKARD")
                        .font(.system(size: 13, weight: .black, design: .serif))
                        .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.12))
                    Spacer()
                    Text("35")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.black)
                        .foregroundColor(.orange)
                        .cornerRadius(4)
                    
                    Button(action: { AudioPlayer.shared.soundEnabled.toggle() }) {
                        Image(systemName: AudioPlayer.shared.soundEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.black)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Button(action: { showUserGuide = true }) {
                        Image(systemName: "questionmark.circle.fill")
                            .font(.system(size: 13))
                            .foregroundColor(.black)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    LinearGradient(gradient: Gradient(colors: [Color.gray, Color(red: 0.5, green: 0.5, blue: 0.55)]), startPoint: .top, endPoint: .bottom)
                )
                .cornerRadius(6)
                
                // Switches Panel (Power ON/OFF & DEG/RAD)
                HStack {
                    // Power Switch
                    HStack(spacing: 6) {
                        Text("OFF")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.gray)
                        
                        Toggle("", isOn: Binding(
                            get: { engine.powerOn },
                            set: { _ in
                                AudioPlayer.shared.playSwitchSound()
                                engine.togglePower()
                            }
                        ))
                        .toggleStyle(SwitchToggleStyle(tint: .green))
                        .labelsHidden()
                        
                        Text("ON")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.green)
                    }
                    
                    Spacer()
                    
                    // Angle Mode
                    Button(action: {
                        AudioPlayer.shared.playSwitchSound()
                        engine.toggleAngleMode()
                    }) {
                        Text("MODE: \(engine.angleMode.rawValue)")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.white.opacity(0.1))
                            .foregroundColor(.orange)
                            .cornerRadius(4)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(!engine.powerOn)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.black.opacity(0.4))
                .cornerRadius(8)
                
                // Seven Segment LED Display
                SevenSegmentLEDView(engine: engine)
                
                // Keypad Grid
                KeypadView(engine: engine, activeKeyPressed: activeKeyPressed)
            }
            .padding(16)
            .frame(width: 320)
            .background(
                LinearGradient(gradient: Gradient(colors: [Color(red: 0.18, green: 0.19, blue: 0.23), Color(red: 0.12, green: 0.13, blue: 0.16)]), startPoint: .top, endPoint: .bottom)
            )
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.8), radius: 15, x: 0, y: 10)
            
            // Right Column: Stack Inspector & History
            StackInspectorView(engine: engine)
                .frame(width: 320)
        }
        .padding(20)
        .background(Color(red: 0.08, green: 0.09, blue: 0.11))
        .onAppear {
            keyboardMonitor.startMonitoring(engine: engine) { keyId in
                self.activeKeyPressed = keyId
            }
        }
        .onDisappear {
            keyboardMonitor.stopMonitoring()
        }
        .sheet(isPresented: $showUserGuide) {
            UserGuideView(isPresented: $showUserGuide)
        }
    }
}
