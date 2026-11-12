import Foundation

/// User settings, backed by UserDefaults. Values are clamped on read so a
/// hand-edited plist can't produce a 0-minute polling loop.
final class Prefs {
    static let shared = Prefs()
    private let store = UserDefaults.standard

    private enum Key {
        static let refreshMinutes = "refreshMinutes"
        // Named for the unit they are stored in: percent *remaining*.
        static let warnRemaining = "warnRemainingPercent"
        static let dangerRemaining = "dangerRemainingPercent"
        static let hiddenProviders = "hiddenProviders"
        static let agyPath = "agyPath"
    }

    private init() {
        store.register(defaults: [
            Key.refreshMinutes: 5,
            Key.warnRemaining: 20.0,
            Key.dangerRemaining: 5.0,
            // Antigravity is a separate coding budget; off by default. Gemini web
            // and the two subscriptions are on.
            Key.hiddenProviders: [ProviderID.antigravity.rawValue],
        ])
    }

    var refreshMinutes: Int {
        get { min(120, max(1, store.integer(forKey: Key.refreshMinutes))) }
        set { store.set(min(120, max(1, newValue)), forKey: Key.refreshMinutes) }
    }

    /// Warn once this little is left.
    var warnRemaining: Double {
        get { min(100, max(0, store.double(forKey: Key.warnRemaining))) }
        set { store.set(min(100, max(0, newValue)), forKey: Key.warnRemaining) }
    }

    /// Danger is the tighter threshold, so it can never exceed the warn level.
    var dangerRemaining: Double {
        get { min(warnRemaining, max(0, store.double(forKey: Key.dangerRemaining))) }
        set { store.set(min(100, max(0, newValue)), forKey: Key.dangerRemaining) }
    }

    var agyPath: String? {
        get { store.string(forKey: Key.agyPath) }
        set { store.set(newValue, forKey: Key.agyPath) }
    }

    private var hiddenProviders: Set<String> {
        get { Set(store.stringArray(forKey: Key.hiddenProviders) ?? []) }
        set { store.set(Array(newValue), forKey: Key.hiddenProviders) }
    }

    func isVisible(_ id: ProviderID) -> Bool {
        !hiddenProviders.contains(id.rawValue)
    }

    func setVisible(_ id: ProviderID, _ visible: Bool) {
        var hidden = hiddenProviders
        if visible { hidden.remove(id.rawValue) } else { hidden.insert(id.rawValue) }
        hiddenProviders = hidden
    }

    /// Menu bar order is fixed; only membership is configurable.
    var visibleProviders: [ProviderID] {
        ProviderID.allCases.filter(isVisible)
    }
}

// MARK: - Cache

/// Last successful reading per provider, persisted so that a relaunch during a
/// token outage still shows "72% (2일 전)" rather than a bare dash.
final class ReadingCache {
    static let shared = ReadingCache()

    private let fileURL: URL
    private var readings: [String: ProviderReading]

    private init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("AIUsageBar", isDirectory: true)
        try? FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        fileURL = support.appendingPathComponent("last-readings.json")

        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode([String: ProviderReading].self, from: data) {
            readings = decoded
        } else {
            readings = [:]
        }
    }

    func store(_ reading: ProviderReading) {
        readings[reading.id.rawValue] = reading
        persist()
    }

    func reading(for id: ProviderID) -> ProviderReading? {
        readings[id.rawValue]
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(readings) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}

// MARK: - Launch at login

/// A plain LaunchAgent rather than SMAppService: this app is unsigned, and
/// SMAppService registration is unreliable for unsigned bundles.
enum LoginItem {
    static let label = "com.local.ai-usage-bar"

    private static var plistURL: URL {
        URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Library/LaunchAgents/\(label).plist")
    }

    static var isEnabled: Bool {
        FileManager.default.fileExists(atPath: plistURL.path)
    }

    static func setEnabled(_ enabled: Bool, appPath: String) throws {
        let fm = FileManager.default
        if !enabled {
            if fm.fileExists(atPath: plistURL.path) {
                try fm.removeItem(at: plistURL)
            }
            return
        }

        try fm.createDirectory(at: plistURL.deletingLastPathComponent(),
                               withIntermediateDirectories: true)
        let plist: [String: Any] = [
            "Label": label,
            "ProgramArguments": ["/usr/bin/open", "-a", appPath],
            "RunAtLoad": true,
        ]
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try data.write(to: plistURL, options: .atomic)
    }
}
