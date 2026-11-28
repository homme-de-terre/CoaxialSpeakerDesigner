import SwiftUI
import AppKit

@main
public struct CoaxialSpeakerDesignerApp: App {
    public init() {
        // Force process to regular foreground app so keyboard input and paste work
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    public var body: some Scene {
        WindowGroup {
            MainSplitView()
                .frame(minWidth: 900, minHeight: 620)
                .onAppear {
                    NSApplication.shared.activate(ignoringOtherApps: true)
                    Self.constrainWindowsToScreenBounds()
                }
                .onReceive(NotificationCenter.default.publisher(for: NSWindow.didEnterFullScreenNotification)) { _ in
                    Self.constrainWindowsToScreenBounds()
                }
                .onReceive(NotificationCenter.default.publisher(for: NSWindow.willEnterFullScreenNotification)) { _ in
                    Self.constrainWindowsToScreenBounds()
                }
                .onReceive(NotificationCenter.default.publisher(for: NSWindow.didResizeNotification)) { _ in
                    Self.constrainWindowsToScreenBounds()
                }
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Open Design...") {
                    NotificationCenter.default.post(name: NSNotification.Name("CSD_LoadDesign"), object: nil)
                }.keyboardShortcut("o", modifiers: .command)

                Button("Save Design As...") {
                    NotificationCenter.default.post(name: NSNotification.Name("CSD_SaveDesign"), object: nil)
                }.keyboardShortcut("s", modifiers: .command)

                Divider()

                Button("FRD Import/Export...") {
                    NotificationCenter.default.post(name: NSNotification.Name("CSD_OpenFRD"), object: nil)
                }.keyboardShortcut("i", modifiers: [.command, .shift])
            }

            CommandGroup(replacing: .appInfo) {
                Button("About Coaxial Speaker Designer") {
                    NSApplication.shared.orderFrontStandardAboutPanel(
                        options: [
                            NSApplication.AboutPanelOptionKey.applicationName: "Coaxial Speaker Designer",
                            NSApplication.AboutPanelOptionKey.applicationVersion: "Version 1.3.0",
                            NSApplication.AboutPanelOptionKey.version: "Build 2026.10",
                            NSApplication.AboutPanelOptionKey(rawValue: "Copyright"): "© 2026 Coaxial Speaker Designer"
                        ]
                    )
                }
            }

            CommandGroup(replacing: .textEditing) {
                Button("Undo") {
                    NSApp.sendAction(Selector(("undo:")), to: nil, from: nil)
                }.keyboardShortcut("z")

                Button("Redo") {
                    NSApp.sendAction(Selector(("redo:")), to: nil, from: nil)
                }.keyboardShortcut("z", modifiers: [.command, .shift])

                Divider()

                Button("Cut") {
                    NSApp.sendAction(#selector(NSText.cut(_:)), to: nil, from: nil)
                }.keyboardShortcut("x")

                Button("Copy") {
                    NSApp.sendAction(#selector(NSText.copy(_:)), to: nil, from: nil)
                }.keyboardShortcut("c")

                Button("Paste") {
                    NSApp.sendAction(#selector(NSText.paste(_:)), to: nil, from: nil)
                }.keyboardShortcut("v")

                Button("Select All") {
                    NSApp.sendAction(#selector(NSText.selectAll(_:)), to: nil, from: nil)
                }.keyboardShortcut("a")
            }
        }
    }

    /// Ensures application windows never exceed the left and right boundaries of their screen,
    /// especially when entering or resizing in macOS Full Screen mode.
    @MainActor
    public static func constrainWindowsToScreenBounds() {
        for window in NSApplication.shared.windows {
            guard let screen = window.screen ?? NSScreen.main else { continue }
            let screenFrame = screen.frame
            let visibleFrame = screen.visibleFrame

            if window.minSize.width > screenFrame.width {
                window.minSize.width = min(900.0, screenFrame.width)
            }
            if window.contentMinSize.width > screenFrame.width {
                window.contentMinSize.width = min(900.0, screenFrame.width)
            }
            window.maxSize.width = screenFrame.width
            window.contentMaxSize.width = screenFrame.width

            let isFullScreen = window.styleMask.contains(.fullScreen)
            let allowedBounds = isFullScreen ? screenFrame : visibleFrame
            var currentFrame = window.frame

            var needsAdjust = false
            if currentFrame.width > allowedBounds.width {
                currentFrame.size.width = allowedBounds.width
                needsAdjust = true
            }
            if currentFrame.minX < allowedBounds.minX {
                currentFrame.origin.x = allowedBounds.minX
                needsAdjust = true
            }
            if currentFrame.maxX > allowedBounds.maxX {
                currentFrame.origin.x = max(allowedBounds.minX, allowedBounds.maxX - currentFrame.width)
                needsAdjust = true
            }

            if needsAdjust {
                window.setFrame(currentFrame, display: true, animate: false)
            }
        }
    }
}
