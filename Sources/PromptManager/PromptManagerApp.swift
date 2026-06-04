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
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button(store.text(.aboutApp)) {
                    showAboutPanel()
                }
            }

            CommandGroup(replacing: .appSettings) {
                Button(store.text(.settings)) {
                    store.isSettingsPresented = true
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }
    }

    private func showAboutPanel() {
        let isEnglish = store.appLanguage == .english
        let repositoryURLString = "https://github.com/WHYBBE/PromptManager"
        let credits = isEnglish
            ? "Developer: WHYBBE\nRepository: \(repositoryURLString)\nLicense: MIT License"
            : "开发者：WHYBBE\n仓库：\(repositoryURLString)\n许可证：MIT License"

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        paragraphStyle.lineSpacing = 3

        let attributedCredits = NSMutableAttributedString(
            string: credits,
            attributes: [
                .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize),
                .foregroundColor: NSColor.secondaryLabelColor,
                .paragraphStyle: paragraphStyle
            ]
        )
        let repositoryRange = (credits as NSString).range(of: repositoryURLString)
        if repositoryRange.location != NSNotFound,
           let repositoryURL = URL(string: repositoryURLString) {
            attributedCredits.addAttributes(
                [
                    .link: repositoryURL,
                    .foregroundColor: NSColor.linkColor,
                    .underlineStyle: NSUnderlineStyle.single.rawValue
                ],
                range: repositoryRange
            )
        }

        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: store.text(.appName),
            .credits: attributedCredits
        ])
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
        NSApp.setActivationPolicy(.regular)
        focusApplicationWindow()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        focusApplicationWindow()
        return true
    }

    private func focusApplicationWindow(remainingAttempts: Int = 8) {
        NSRunningApplication.current.activate(options: [.activateAllWindows])
        NSApp.activate(ignoringOtherApps: true)

        if let window = NSApp.mainWindow ?? NSApp.windows.first(where: { $0.canBecomeKey }) ?? NSApp.windows.first {
            window.orderFrontRegardless()
            window.makeKeyAndOrderFront(nil)
            return
        }

        guard remainingAttempts > 0 else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
            self?.focusApplicationWindow(remainingAttempts: remainingAttempts - 1)
        }
    }

}
