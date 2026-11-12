import AppKit

@main
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    /// `NSApplication.delegate` is weak, so the delegate needs an owner.
    private static var retained: AppDelegate?

    private var controller: MenuBarController?

    static func main() {
        if CommandLine.arguments.contains("--gemini-chrome-host") {
            GeminiChromeBridge.runNativeHost()
        }
        if CommandLine.arguments.contains("--once") {
            Diagnostics.runOnce()
        }

        // Explicit update/relaunch path: replace only this menu bar app, leaving
        // Chrome and every provider's login session running as they are.
        if CommandLine.arguments.contains("--replace") {
            for running in NSRunningApplication.runningApplications(withBundleIdentifier: "com.local.ai-usage-bar")
            where running.processIdentifier != ProcessInfo.processInfo.processIdentifier {
                running.terminate()
            }
        }

        let app = NSApplication.shared
        // Menu bar only: no Dock icon, no app-switcher entry.
        app.setActivationPolicy(.accessory)

        let delegate = AppDelegate()
        retained = delegate
        app.delegate = delegate
        app.run()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        controller = MenuBarController()
    }
}
