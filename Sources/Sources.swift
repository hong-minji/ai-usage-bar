import Foundation
import Security

// MARK: - Keychain

/// Reads a generic password item. The first call from a freshly built binary
/// makes macOS prompt the user for access; choosing "Always Allow" binds the
/// grant to that binary, so a rebuild prompts again.
func readGenericPassword(service: String, account: String) -> Data? {
    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: service,
        kSecAttrAccount as String: account,
        kSecReturnData as String: true,
        kSecMatchLimit as String: kSecMatchLimitOne,
    ]
    var item: CFTypeRef?
    guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess else { return nil }
    return item as? Data
}

// MARK: - HTTP


private let session: URLSession = {
    let config = URLSessionConfiguration.ephemeral
    config.timeoutIntervalForRequest = 20
    config.timeoutIntervalForResource = 25
    config.httpAdditionalHeaders = ["User-Agent": "ai-usage-bar"]
    return URLSession(configuration: config)
}()

private func get(_ url: URL, headers: [String: String]) async throws -> Data {
    var request = URLRequest(url: url)
    for (key, value) in headers { request.setValue(value, forHTTPHeaderField: key) }

    let (data, response) = try await session.data(for: request)
    guard let http = response as? HTTPURLResponse else { return data }
    switch http.statusCode {
    case 200..<300: return data
    case 401, 403: throw FetchError.unauthorized
    default: throw FetchError.http(http.statusCode)
    }
}

// MARK: - Claude

enum ClaudeSource {
    static let keychainService = "Claude Code-credentials"
    static let usageURL = URL(string: "https://api.anthropic.com/api/oauth/usage")!

    /// Credentials live in the login keychain, written and refreshed by Claude
    /// Code itself. We only read them -- refreshing here could rotate the token
    /// out from under Claude Code.
    private static func credentials() throws -> (token: String, plan: String?) {
        guard let blob = readGenericPassword(service: keychainService, account: NSUserName()),
              let root = try? JSONSerialization.jsonObject(with: blob) as? [String: Any],
              let oauth = root["claudeAiOauth"] as? [String: Any],
              let token = oauth["accessToken"] as? String, !token.isEmpty
        else { throw FetchError.notSignedIn("Claude Code") }

        let plan = (oauth["subscriptionType"] as? String).map { $0.capitalized }
        return (token, plan)
    }

    static func fetch(now: Date = Date()) async throws -> ProviderReading {
        let (token, plan) = try credentials()
        let data = try await get(usageURL, headers: [
            "Authorization": "Bearer \(token)",
            "anthropic-beta": "oauth-2025-04-20",
            "Content-Type": "application/json",
        ])
        return try parseClaudeUsage(data, planLabel: plan, now: now)
    }
}

// MARK: - ChatGPT (Codex)

enum ChatGPTSource {
    static let usageURL = URL(string: "https://chatgpt.com/backend-api/codex/usage")!
    static var authPath: URL {
        URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".codex/auth.json")
    }
    static var sessionsRoot: URL {
        URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".codex/sessions")
    }

    private static func credentials() throws -> (token: String, accountID: String?) {
        guard let data = try? Data(contentsOf: authPath),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tokens = root["tokens"] as? [String: Any],
              let token = tokens["access_token"] as? String, !token.isEmpty
        else { throw FetchError.notSignedIn("Codex") }

        return (token, tokens["account_id"] as? String)
    }

    static func fetch(now: Date = Date()) async throws -> ProviderReading {
        let (token, accountID) = try credentials()
        var headers = ["Authorization": "Bearer \(token)"]
        if let accountID { headers["chatgpt-account-id"] = accountID }
        let data = try await get(usageURL, headers: headers)
        return try parseChatGPTUsage(data, now: now)
    }

    /// Last resort when the live call is refused: Codex records the same
    /// rate-limit block in every session log, so the newest one still tells us
    /// where usage stood the last time Codex ran.
    static func lastKnownFromSessions() -> ProviderReading? {
        let fm = FileManager.default
        guard let walker = fm.enumerator(
            at: sessionsRoot,
            includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return nil }

        var candidates: [(URL, Date)] = []
        for case let url as URL in walker where url.pathExtension == "jsonl" {
            let values = try? url.resourceValues(forKeys: [.contentModificationDateKey])
            candidates.append((url, values?.contentModificationDate ?? .distantPast))
        }

        // Newest first, and only a handful -- these directories grow without bound.
        for (url, _) in candidates.sorted(by: { $0.1 > $1.1 }).prefix(5) {
            guard let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
            for line in text.split(separator: "\n").reversed() where line.contains("rate_limits") {
                if let reading = try? parseCodexSessionRateLimits(line: String(line), now: Date()) {
                    return reading
                }
            }
        }
        return nil
    }
}

// MARK: - Gemini / Antigravity

enum AgySource {
    /// A GUI app inherits a bare PATH, so look in the places Antigravity
    /// actually installs to rather than relying on `which`.
    static let searchPaths = [
        "\(NSHomeDirectory())/.local/bin/agy",
        "/usr/local/bin/agy",
        "/opt/homebrew/bin/agy",
    ]

    static func resolveBinary(override: String?) -> String? {
        if let override, !override.isEmpty, FileManager.default.isExecutableFile(atPath: override) {
            return override
        }
        return searchPaths.first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    /// `/quota` is a local command: it reports `num_turns: 0` and zero tokens,
    /// so polling it does not spend any of the quota it reports.
    static func fetch(binary: String, timeout: TimeInterval = 45, now: Date = Date())
        throws -> ProviderReading
    {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: binary)
        process.arguments = ["-p", "/quota", "--output-format", "json", "--print-timeout", "30s"]
        process.environment = ProcessInfo.processInfo.environment.merging(
            ["HOME": NSHomeDirectory()], uniquingKeysWith: { _, new in new })

        let out = Pipe()
        process.standardOutput = out
        process.standardError = Pipe()

        try process.run()

        // Drain on a background queue: a full pipe buffer would otherwise
        // deadlock against waitUntilExit.
        var collected = Data()
        let lock = NSLock()
        DispatchQueue.global().async {
            let data = out.fileHandleForReading.readDataToEndOfFile()
            lock.lock(); collected = data; lock.unlock()
        }

        let deadline = Date().addingTimeInterval(timeout)
        while process.isRunning && Date() < deadline {
            Thread.sleep(forTimeInterval: 0.1)
        }
        if process.isRunning {
            process.terminate()
            throw FetchError.timedOut
        }
        process.waitUntilExit()
        Thread.sleep(forTimeInterval: 0.05)  // let the drain finish

        lock.lock(); let data = collected; lock.unlock()
        guard !data.isEmpty else { throw FetchError.toolFailed("agy 응답 없음") }
        return try parseAgyQuota(data, now: now)
    }
}
