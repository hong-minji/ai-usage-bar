import Foundation

/// Registers the running app's host, so moving from build/ to Applications
/// never leaves Chrome pointing at a developer's checkout.
enum ChromeInstallation {
    static let hostName = "com.local.ai_usage_bar.gemini"

    static func register(resources: URL, home: URL) throws {
        let host = resources.appendingPathComponent("gemini-native-host")
        guard FileManager.default.isExecutableFile(atPath: host.path) else {
            throw CocoaError(.fileNoSuchFile)
        }
        let directory = home.appendingPathComponent(
            "Library/Application Support/Google/Chrome/NativeMessagingHosts", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let manifest: [String: Any] = [
            "name": hostName,
            "description": "AI Usage Bar: Gemini usage from the signed-in Chrome session",
            "path": host.path,
            "type": "stdio",
            "allowed_origins": [GeminiChromeBridge.allowedExtensionOrigin],
        ]
        let file = directory.appendingPathComponent("\(hostName).json")
        let data = try JSONSerialization.data(withJSONObject: manifest, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: file, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path)
    }
}
