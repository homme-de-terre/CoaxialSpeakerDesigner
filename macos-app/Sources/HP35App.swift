import SwiftUI

@main
struct HP35App: App {
    var body: some Scene {
        WindowGroup {
            CalculatorView()
                .navigationTitle("HP-35 RPN Scientific Calculator Simulator")
        }
        .windowStyle(HiddenTitleBarWindowStyle())
        .windowResizability(.contentSize)
    }
}
