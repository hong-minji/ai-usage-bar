import AppKit

/// Chrome renders the usage page with its existing signed-in session. The
/// Gemini-only extension sends quota figures to our local native-message host;
/// the app never copies browser credentials into a separate web view.
@MainActor
final class GeminiWebSource {
    static let shared = GeminiWebSource()
    private init() {}

    func fetch(now: Date = Date()) async throws -> ProviderReading {
        try GeminiChromeBridge.fetch(now: now)
    }

    func presentLogin() {
        let extensionURL = Bundle.main.resourceURL!.appendingPathComponent("ChromeExtension")
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: extensionURL.path)
        let chromeURL = URL(fileURLWithPath: "/Applications/Google Chrome.app")
        NSWorkspace.shared.open([URL(string: "chrome://extensions/")!],
                                withApplicationAt: chromeURL,
                                configuration: NSWorkspace.OpenConfiguration())
    }
}
