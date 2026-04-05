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
                .frame(minWidth: 1320, minHeight: 820)
                .preferredColorScheme(store.appThemeMode.colorScheme)
        }
        .windowResizability(.contentMinSize)
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
