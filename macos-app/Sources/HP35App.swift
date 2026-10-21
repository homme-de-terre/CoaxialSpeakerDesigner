import SwiftUI

@main
struct HP35App: App {
    var body: some Scene {
        WindowGroup {
            CalculatorView()
                .frame(minWidth: 680, minHeight: 520)
        }
    }
}
