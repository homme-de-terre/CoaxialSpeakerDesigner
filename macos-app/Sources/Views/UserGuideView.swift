import SwiftUI

public struct UserGuideView: View {
    @Binding var isPresented: Bool
    @State private var selectedTab: Int = 0
    
    public init(isPresented: Binding<Bool>) {
        self._isPresented = isPresented
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "book.fill")
                    .foregroundColor(.orange)
                Text("HP-35 macOS User Manual & Shortcuts")
                    .font(.system(size: 14, weight: .bold))
                Spacer()
                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding()
            .background(Color(red: 0.1, green: 0.1, blue: 0.12))
            
            // Picker
            Picker("", selection: $selectedTab) {
                Text("Keyboard Shortcuts").tag(0)
                Text("Dead Key '^°' Guide").tag(1)
                Text("RPN Stack Manual").tag(2)
                Text("Examples").tag(3)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal)
            .padding(.vertical, 8)
            
            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if selectedTab == 0 {
                        ShortcutsTabView()
                    } else if selectedTab == 1 {
                        DeadKeyGuideTabView()
                    } else if selectedTab == 2 {
                        RPNManualTabView()
                    } else {
                        ExamplesTabView()
                    }
                }
                .padding()
            }
        }
        .frame(width: 520, height: 420)
        .background(Color(red: 0.14, green: 0.15, blue: 0.18))
        .foregroundColor(.white)
    }
}

struct ShortcutsTabView: View {
    let shortcuts: [(key: String, label: String)] = [
        ("0 – 9, .", "Enter Digits & Decimal Point"),
        ("Enter / Space", "ENTER ↑ (Push & duplicate X)"),
        ("Backspace", "CL X (Clear display X register)"),
        ("Escape / Delete", "CLR (Clear entire stack)"),
        ("+  –  *  /", "Basic Operations (+, –, ×, ÷)"),
        ("^ or ^° or Y", "x^y (Power function – handles Dead key)"),
        ("V", "√x (Square Root)"),
        ("U", "1/x (Reciprocal)"),
        ("G", "LOG (Base 10 Logarithm)"),
        ("H", "LN (Natural Logarithm)"),
        ("D", "e^x (Exponential)"),
        ("R / Q", "R↓ (Roll stack down)"),
        ("X / W", "x≷y (Swap X and Y)"),
        ("S / C / T", "SIN / COS / TAN"),
        ("A / I", "ARC (Toggle Inverse Trig Mode)"),
        ("M", "STO (Store X into Memory)"),
        ("L / K", "RCL (Recall Memory into X)"),
        ("E", "EEX (Enter Scientific Exponent)"),
        ("P", "π (Enter Pi constant)"),
        ("N / ~", "CH S (Change Sign)")
    ]
    
    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
            ForEach(shortcuts, id: \.key) { item in
                HStack {
                    Text(item.key)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.white.opacity(0.12))
                        .cornerRadius(4)
                        .foregroundColor(.orange)
                    Spacer()
                    Text(item.label)
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                }
                .padding(6)
                .background(Color.black.opacity(0.25))
                .cornerRadius(6)
            }
        }
    }
}

struct DeadKeyGuideTabView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("European & International Keyboard Dead Key Resolution")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.orange)
            
            Text("On European QWERTZ (German), AZERTY (French), and ISO Mac keyboards, pressing the '^°' key sends physical key code 10 or 'Dead' composition key events.")
                .font(.system(size: 11))
                .foregroundColor(.gray)
            
            VStack(alignment: .leading, spacing: 6) {
                Text("How this native macOS app handles '^°':")
                    .font(.system(size: 11, weight: .bold))
                Text("1. Native AppKit Event Monitoring: Intercepts raw key code 10 before macOS input composition takes place.")
                    .font(.system(size: 11))
                Text("2. Triggers x^y ('power of') immediately with zero latency.")
                    .font(.system(size: 11))
                Text("3. Alternative shortcuts: You can also press 'Y' or '^' or '**'.")
                    .font(.system(size: 11))
            }
            .padding()
            .background(Color.black.opacity(0.3))
            .cornerRadius(8)
        }
    }
}

struct RPNManualTabView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("HP-35 Reverse Polish Notation (RPN)")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.orange)
            
            Text("The HP-35 uses a 4-register operational stack (X, Y, Z, T). Numbers typed go into register X. Operators act immediately on values in Y and X without needing parentheses.")
                .font(.system(size: 11))
                .foregroundColor(.gray)
            
            VStack(alignment: .leading, spacing: 6) {
                Text("• Automatic Stack Lift: Typing numbers after an operation pushes values up (X→Y, Y→Z, Z→T).")
                Text("• Binary Operations Drop: Operators like +, -, ×, ÷, x^y combine Y and X, replacing X with the result and dropping Z to Y, T to Z.")
                Text("• Roll Down (R↓): Rotates all 4 registers downward.")
                Text("• Swap (x≷y): Exchanges values in X and Y.")
            }
            .font(.system(size: 11))
            .padding()
            .background(Color.black.opacity(0.3))
            .cornerRadius(8)
        }
    }
}

struct ExamplesTabView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Calculation Walkthroughs")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.orange)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("1. Compute 2^10 = 1024:")
                    .fontWeight(.bold)
                Text("Press: 2 ➔ ENTER↑ ➔ 10 ➔ x^y")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.orange)
                
                Divider()
                
                Text("2. Hypotenuse: √(3² + 4²) = 5:")
                    .fontWeight(.bold)
                Text("Press: 3 ➔ ENTER↑ ➔ × ➔ 4 ➔ ENTER↑ ➔ × ➔ + ➔ √x")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.orange)
            }
            .font(.system(size: 11))
            .padding()
            .background(Color.black.opacity(0.3))
            .cornerRadius(8)
        }
    }
}
