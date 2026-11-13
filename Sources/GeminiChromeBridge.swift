import Foundation
import Darwin

/// Accepts usage-only messages from the Gemini Chrome extension. Credentials and
/// cookies stay inside Chrome; the menu bar reads this small local cache.
enum GeminiChromeBridge {
    /// Which Google account to trust is the extension's decision -- it is the
    /// only side that can see the signed-in Chrome profile. The app requires
    /// that the extension names the account it verified on the page itself.
    static let allowedExtensionOrigin = "chrome-extension://edmmoiejceaokbohcdedkehoabkgkole/"
    static let updatedNotificationName = Notification.Name("com.local.ai-usage-bar.gemini-updated")
    static let maximumMessageBytes = 16 * 1024
    static let maximumAge: TimeInterval = 15 * 60

    struct Report: Codable {
        let version: Int
        let status: String
        let sourceURL: String
        let account: String
        let observedAt: String
        let used: [Double]?
        let labels: [String]?

        var observationDate: Date? {
            let fractional = ISO8601DateFormatter()
            fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            return fractional.date(from: observedAt) ?? ISO8601DateFormatter().date(from: observedAt)
        }

        var reading: ProviderReading? {
            guard status == "ok", let date = observationDate, let used else { return nil }
            let windows = used.enumerated().map { index, value in
                let supplied = labels.flatMap { index < $0.count ? $0[index] : nil }
                let label: String
                if let supplied, !supplied.isEmpty, supplied.count <= 40,
                   supplied.rangeOfCharacter(from: .controlCharacters) == nil {
                    label = supplied
                } else {
                    label = "사용량"
                }
                return UsageWindow(label: label, usedPercent: value, resetsAt: nil)
            }
            return ProviderReading(id: .gemini, planLabel: nil, windows: windows, fetchedAt: date)
        }
    }

    private struct Cache: Codable {
        let version: Int
        let latest: Report
        let receivedAt: Date
        let lastSuccess: Report?
    }

    private enum BridgeError: LocalizedError {
        case invalidMessage
        case invalidSource
        case invalidAccount
        case invalidTime
        case invalidUsage
        case incompleteFrame

        var errorDescription: String? {
            switch self {
            case .invalidMessage: return "Gemini 연동 메시지 형식이 올바르지 않습니다"
            case .invalidSource: return "Gemini 사용량 페이지에서 보낸 메시지만 허용됩니다"
            case .invalidAccount: return "Gemini 계정을 확인할 수 없습니다"
            case .invalidTime: return "Gemini 사용량 시각이 오래되었거나 올바르지 않습니다"
            case .invalidUsage: return "Gemini 사용량 수치가 올바르지 않습니다"
            case .incompleteFrame: return "Gemini 연동 메시지가 완전하지 않습니다"
            }
        }
    }

    private static var cacheURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("AIUsageBar", isDirectory: true)
            .appendingPathComponent("gemini-chrome.json")
    }

    /// Pure validation entry point, also usable by fixture tests. An ok report
    /// must identify the account verified from the page, not a URL login hint.
    static func validate(_ data: Data, now: Date = Date()) throws -> Report {
        guard !data.isEmpty, data.count <= maximumMessageBytes,
              let report = try? JSONDecoder().decode(Report.self, from: data),
              report.version == 1,
              ["ok", "login_required", "account_mismatch", "unavailable"].contains(report.status)
        else { throw BridgeError.invalidMessage }
        try validateFields(report)
        guard let date = report.observationDate,
              date.timeIntervalSince(now) <= 60,
              now.timeIntervalSince(date) <= maximumAge
        else { throw BridgeError.invalidTime }
        return report
    }

    /// A reading is only accepted with the account the page displayed, so a
    /// blank or malformed value can never pass as a verified identity.
    private static func isPlausibleAccount(_ value: String) -> Bool {
        value.count >= 3 && value.count <= 254
            && value.rangeOfCharacter(from: .whitespacesAndNewlines) == nil
            && value.rangeOfCharacter(from: .controlCharacters) == nil
            && value.range(of: #"^[^@\s]+@[^@\s]+\.[^@\s]+$"#, options: .regularExpression) != nil
    }

    private static func validateFields(_ report: Report) throws {
        guard report.version == 1,
              ["ok", "login_required", "account_mismatch", "unavailable"].contains(report.status)
        else { throw BridgeError.invalidMessage }
        guard report.sourceURL.count <= 2048,
              let source = URLComponents(string: report.sourceURL),
              source.scheme == "https", source.host == "gemini.google.com",
              source.user == nil, source.password == nil,
              source.port == nil || source.port == 443,
              source.path.range(of: #"^/(?:u/[0-9]+/)?usage/?$"#, options: .regularExpression) != nil
        else { throw BridgeError.invalidSource }
        guard report.account.count <= 254, report.observationDate != nil,
              (report.used?.count ?? 0) <= 2, (report.labels?.count ?? 0) <= 2
        else { throw BridgeError.invalidMessage }
        if let values = report.used {
            guard values.allSatisfy({ $0.isFinite && (0...100).contains($0) })
            else { throw BridgeError.invalidUsage }
        }
        if report.status == "ok" {
            guard isPlausibleAccount(report.account) else { throw BridgeError.invalidAccount }
            guard let used = report.used, !used.isEmpty else { throw BridgeError.invalidUsage }
        }
    }

    static func fetch(now: Date = Date()) throws -> ProviderReading {
        guard let cache = loadCache() else {
            throw FetchError.toolFailed("설정에서 Gemini 크롬 연결을 완료하세요")
        }
        guard let observed = cache.latest.observationDate,
              cache.receivedAt.timeIntervalSince(now) <= 60,
              observed.timeIntervalSince(now) <= 60,
              now.timeIntervalSince(observed) <= maximumAge
        else { throw FetchError.toolFailed("Gemini 크롬 연결에서 새 사용량을 기다리는 중") }
        switch cache.latest.status {
        case "ok":
            guard let reading = cache.latest.reading else { throw BridgeError.invalidUsage }
            return reading
        case "login_required":
            throw FetchError.toolFailed("크롬에서 Gemini 로그인이 만료되었습니다")
        case "account_mismatch":
            throw FetchError.toolFailed("크롬에 지정한 계정과 다른 Google 계정이 선택되어 있습니다")
        default:
            throw FetchError.toolFailed("크롬에서 Gemini 사용량을 읽지 못했습니다")
        }
    }

    /// Keeps a good reading available even when the extension observes an error
    /// before the app's next timer tick. Caller must display this as stale.
    static func cachedReading() -> ProviderReading? {
        loadCache()?.lastSuccess?.reading
    }

    private static func loadCache() -> Cache? {
        guard let size = try? cacheURL.resourceValues(forKeys: [.fileSizeKey]).fileSize,
              size <= maximumMessageBytes * 3,
              let data = try? Data(contentsOf: cacheURL),
              let cache = try? JSONDecoder().decode(Cache.self, from: data),
              cache.version == 1,
              (try? validateFields(cache.latest)) != nil else { return nil }
        if let last = cache.lastSuccess {
            guard last.status == "ok", (try? validateFields(last)) != nil else { return nil }
        }
        return cache
    }

    private static func save(_ report: Report, receivedAt: Date) throws {
        let directory = cacheURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        // Chrome can start multiple one-shot hosts; serialize read/modify/write
        // so an error message cannot accidentally discard a concurrent success.
        let lockPath = directory.appendingPathComponent(".gemini-chrome.lock").path
        let lock = open(lockPath, O_CREAT | O_RDWR, 0o600)
        guard lock >= 0 else { throw BridgeError.invalidMessage }
        defer { close(lock) }
        guard flock(lock, LOCK_EX) == 0 else { throw BridgeError.invalidMessage }
        defer { flock(lock, LOCK_UN) }
        let previous = loadCache()
        // A delayed/background tab must not replace a more recent observation.
        if let priorDate = previous?.latest.observationDate,
           let nextDate = report.observationDate, nextDate < priorDate { return }
        let cache = Cache(version: 1, latest: report, receivedAt: receivedAt,
                          lastSuccess: report.status == "ok" ? report : previous?.lastSuccess)
        let data = try JSONEncoder().encode(cache)
        try data.write(to: cacheURL, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: cacheURL.path)
        DistributedNotificationCenter.default().postNotificationName(updatedNotificationName,
                                                     object: nil, userInfo: nil, deliverImmediately: true)
    }

    /// Chrome sendNativeMessage starts a host process for one request. stdout
    /// belongs exclusively to the framed response; never print diagnostics here.
    static func runNativeHost() -> Never {
        do {
            guard let flag = CommandLine.arguments.firstIndex(of: "--gemini-chrome-host"),
                  flag + 1 < CommandLine.arguments.count,
                  CommandLine.arguments[flag + 1] == allowedExtensionOrigin else {
                throw BridgeError.invalidSource
            }
            let prefix = try readExactly(4)
            let length = prefix.enumerated().reduce(UInt32(0)) { partial, entry in
                partial | (UInt32(entry.element) << (8 * entry.offset))
            }
            guard length > 0, length <= UInt32(maximumMessageBytes) else {
                throw BridgeError.invalidMessage
            }
            let now = Date()
            let data = try readExactly(Int(length))
            if let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any], object["version"] as? Int == 2 {
                let report = try BrowserUsageBridge.validate(data, now: now)
                try BrowserUsageBridge.save(report)
                DistributedNotificationCenter.default().postNotificationName(BrowserUsageBridge.updatedNotificationName,
                    object: nil, userInfo: nil, deliverImmediately: true)
            } else {
                let report = try validate(data, now: now)
                try save(report, receivedAt: now)
            }
            try respond(["ok": true])
            exit(0)
        } catch {
            // Only our short, non-sensitive validation errors are returned.
            let message = (error as? BridgeError)?.localizedDescription ?? "Gemini 연동 데이터를 저장하지 못했습니다"
            try? respond(["ok": false, "error": message])
            exit(1)
        }
    }

    private static func readExactly(_ length: Int) throws -> Data {
        var data = Data()
        while data.count < length {
            guard let chunk = try FileHandle.standardInput.read(upToCount: length - data.count),
                  !chunk.isEmpty else { throw BridgeError.incompleteFrame }
            data.append(chunk)
        }
        return data
    }

    private static func respond(_ object: [String: Any]) throws {
        let data = try JSONSerialization.data(withJSONObject: object)
        var length = UInt32(data.count).littleEndian
        let prefix = withUnsafeBytes(of: &length) { Data($0) }
        try FileHandle.standardOutput.write(contentsOf: prefix + data)
    }
}
