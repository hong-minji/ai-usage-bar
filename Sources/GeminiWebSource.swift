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
        guard let chromeURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.google.Chrome") else {
            showError("Google Chrome을 먼저 설치하고 한 번 실행하세요.")
            return
        }
        guard let resources = Bundle.main.resourceURL else { return }
        do {
            try ChromeInstallation.register(resources: resources,
                home: FileManager.default.homeDirectoryForCurrentUser)
        } catch {
            showError("Chrome 연결을 등록하지 못했습니다.\n\(error.localizedDescription)")
            return
        }
        let extensionURL = resources.appendingPathComponent("ChromeExtension")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(extensionURL.path, forType: .string)
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: extensionURL.path)
        NSWorkspace.shared.open([URL(string: "chrome://extensions/")!],
                                withApplicationAt: chromeURL,
                                configuration: NSWorkspace.OpenConfiguration()) { _, error in
            if error != nil {
                Task { @MainActor in
                    self.showError("Chrome에서 chrome://extensions/ 를 직접 열어주세요.")
                }
            }
        }
    }

    private func showError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "Gemini Chrome 연결"
        alert.informativeText = message
        alert.runModal()
    }
}
