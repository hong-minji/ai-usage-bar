import Foundation
import Darwin

/// Credential-free reports from explicitly enabled Claude/Codex usage pages.
/// Gemini keeps its v1 bridge for compatibility with already installed extensions.
enum BrowserUsageBridge {
    static let updatedNotificationName = Notification.Name("com.local.ai-usage-bar.browser-updated")
    static let maximumAge: TimeInterval = 900

    struct Report: Codable {
        let version: Int
        let provider: String
        let status: String
        let sourceURL: String
        let observedAt: String
        let used: [Double]
        let labels: [String]
        var id: ProviderID? { provider == "claude" ? .claude : provider == "codex" ? .codex : nil }
        var date: Date? {
            let f = ISO8601DateFormatter()
            f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            return f.date(from: observedAt) ?? ISO8601DateFormatter().date(from: observedAt)
        }
        var reading: ProviderReading? {
            guard status == "ok", let id, let date else { return nil }
            return ProviderReading(id: id, planLabel: "Chrome 웹", windows: zip(labels, used).map {
                UsageWindow(label: $0.0, usedPercent: $0.1, resetsAt: nil)
            }, fetchedAt: date)
        }
    }
    struct Cache: Codable { let latest: Report; let lastSuccess: Report? }
    static var directory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("AIUsageBar")
    }
    static func canonicalURL(_ provider: String) -> String? {
        switch provider {
        case "claude": return "https://claude.ai/settings/usage"
        case "codex": return "https://chatgpt.com/settings/usage"
        default: return nil
        }
    }
    static func providerForURL(_ value: String) -> String? {
        guard value.count <= 2048, let u = URLComponents(string: value), u.scheme == "https",
              u.user == nil, u.password == nil, u.port == nil || u.port == 443 else { return nil }
        if u.host == "claude.ai", u.path == "/settings/usage" || (u.path == "/new" && u.fragment == "settings/usage") { return "claude" }
        if u.host == "chatgpt.com", u.path == "/settings/usage" { return "codex" }
        return nil
    }
    static func validFields(_ r: Report) -> Bool {
        r.version == 2 && r.id != nil && providerForURL(r.sourceURL) == r.provider &&
        ["ok", "unavailable", "disabled"].contains(r.status) && r.date != nil &&
        r.used.count == r.labels.count &&
        (r.status == "ok" ? (1...2).contains(r.used.count) : r.used.isEmpty) &&
        r.used.allSatisfy { $0.isFinite && (0...100).contains($0) } &&
        r.labels.allSatisfy { ["5시간", "주간"].contains($0) } && Set(r.labels).count == r.labels.count
    }
    static func validate(_ data: Data, now: Date = Date()) throws -> Report {
        guard data.count <= 16384, let r = try? JSONDecoder().decode(Report.self, from: data),
              validFields(r), let date = r.date, date.timeIntervalSince(now) <= 60,
              now.timeIntervalSince(date) <= maximumAge else {
            throw FetchError.toolFailed("웹 사용량 보고서가 올바르지 않습니다")
        }
        return r
    }
    static func file(_ id: ProviderID, in folder: URL) -> URL {
        folder.appendingPathComponent("browser-\(id == .codex ? "codex" : id.rawValue).json")
    }
    static func load(_ id: ProviderID, in folder: URL = directory) -> Cache? {
        guard [.claude, .codex].contains(id),
              let size = try? file(id, in: folder).resourceValues(forKeys: [.fileSizeKey]).fileSize, size <= 32768,
              let data = try? Data(contentsOf: file(id, in: folder)),
              let c = try? JSONDecoder().decode(Cache.self, from: data),
              validFields(c.latest), c.latest.id == id else { return nil }
        if let last = c.lastSuccess, !validFields(last) || last.status != "ok" || last.id != id { return nil }
        return c
    }
    static func isConnected(_ id: ProviderID) -> Bool {
        guard let c = load(id) else { return false }
        return c.latest.status != "disabled"
    }
    static func save(_ report: Report, in folder: URL = directory) throws {
        guard validFields(report), let id = report.id, let url = canonicalURL(report.provider) else {
            throw FetchError.toolFailed("웹 사용량 보고서가 올바르지 않습니다")
        }
        let fm = FileManager.default
        try fm.createDirectory(at: folder, withIntermediateDirectories: true)
        let lock = open(folder.appendingPathComponent(".browser-\(report.provider).lock").path, O_CREAT | O_RDWR, 0o600)
        guard lock >= 0 else { throw FetchError.toolFailed("웹 캐시를 열지 못했습니다") }
        defer { close(lock) }
        guard flock(lock, LOCK_EX) == 0 else { throw FetchError.toolFailed("웹 캐시를 잠그지 못했습니다") }
        defer { flock(lock, LOCK_UN) }
        let previous = load(id, in: folder)
        if let old = previous?.latest.date, let date = report.date, date < old { return }
        // Persist only a fixed URL; discard account parameters, fragments and extra JSON fields.
        let clean = Report(version: 2, provider: report.provider, status: report.status, sourceURL: url,
                           observedAt: report.observedAt, used: report.used, labels: report.labels)
        let cache = Cache(latest: clean, lastSuccess: report.status == "ok" ? clean : report.status == "disabled" ? nil : previous?.lastSuccess)
        let data = try JSONEncoder().encode(cache)
        try data.write(to: file(id, in: folder), options: .atomic)
        try fm.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file(id, in: folder).path)
    }
    static func state(_ id: ProviderID, now: Date = Date(), in folder: URL = directory) -> ProviderState {
        guard let cache = load(id, in: folder), cache.latest.status != "disabled" else {
            return .unavailable(reason: "Chrome 확장 팝업에서 \(id.shortLabel) 연결을 켜세요")
        }
        if let date = cache.latest.date, date.timeIntervalSince(now) <= 60,
           now.timeIntervalSince(date) <= maximumAge, let reading = cache.latest.reading { return .ok(reading) }
        let reason = "Chrome의 \(id.shortLabel) 로그인·사용량 페이지를 확인하세요"
        if let reading = cache.lastSuccess?.reading { return .stale(reading, reason: reason) }
        return .unavailable(reason: reason)
    }
}
