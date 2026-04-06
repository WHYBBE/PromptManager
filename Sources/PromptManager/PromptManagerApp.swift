import AppKit
import SwiftUI

@main
struct PromptManager: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = PromptStore.persistedOrSample

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .id(store.appThemeMode.rawValue)
                .frame(minWidth: 1320, minHeight: 820)
                .preferredColorScheme(store.appThemeMode.colorScheme)
                .background(WindowAppearanceSync(mode: store.appThemeMode))
        }
        .windowResizability(.contentMinSize)
    }
}

private struct WindowAppearanceSync: NSViewRepresentable {
    let mode: AppThemeMode

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        applyAppearance()
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        applyAppearance()
    }

    private func applyAppearance() {
        DispatchQueue.main.async {
            let appearance = mode.nsAppearanceName.flatMap(NSAppearance.init(named:))
            NSApp.appearance = appearance
            for window in NSApp.windows {
                window.appearance = appearance
                window.contentView?.appearance = appearance
                window.contentView?.needsDisplay = true
                window.invalidateShadow()
            }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.applicationIconImage = applicationIcon
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        DispatchQueue.main.async {
            NSApp.windows.first?.makeKeyAndOrderFront(nil)
            NSApp.mainWindow?.makeKeyAndOrderFront(nil)
        }
    }

    private var applicationIcon: NSImage? {
        let configuration = NSImage.SymbolConfiguration(pointSize: 512, weight: .regular)
        guard let symbolImage = NSImage(
            systemSymbolName: "info.circle.text.page.fill",
            accessibilityDescription: "Prompt Manager"
        )?.withSymbolConfiguration(configuration) else {
            return nil
        }

        let size = NSSize(width: 512, height: 512)
        let image = NSImage(size: size)
        image.lockFocus()

        NSColor.clear.setFill()
        NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()

        let backgroundRect = NSRect(x: 32, y: 32, width: 448, height: 448)
        let background = NSBezierPath(roundedRect: backgroundRect, xRadius: 96, yRadius: 96)
        NSColor.controlAccentColor.withAlphaComponent(0.16).setFill()
        background.fill()

        let symbolRect = NSRect(x: 88, y: 88, width: 336, height: 336)
        symbolImage.draw(in: symbolRect)

        image.unlockFocus()
        image.isTemplate = false
        return image
    }
}
