import Foundation

enum ParseError: LocalizedError {
    case badJSON
    case missing(String)
    case noUsableWindow

    var errorDescription: String? {
        switch self {
        case .badJSON: return "응답을 해석할 수 없음"
        case .missing(let f): return "응답에 \(f) 없음"
        case .noUsableWindow: return "사용량 정보 없음"
        }
    }
}

/// Tolerant ISO-8601 reader. The three upstreams disagree about fractional
/// seconds and about `Z` vs `+00:00`, so try the variants rather than assuming.
func parseISODate(_ string: String) -> Date? {
    let withFraction = ISO8601DateFormatter()
    withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let d = withFraction.date(from: string) { return d }

    let plain = ISO8601DateFormatter()
    plain.formatOptions = [.withInternetDateTime]
    return plain.date(from: string)
}

private func asDouble(_ any: Any?) -> Double? {
    if let d = any as? Double { return d }
    if let i = any as? Int { return Double(i) }
    if let n = any as? NSNumber { return n.doubleValue }
    return nil
}

private func object(_ data: Data) throws -> [String: Any] {
    guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
        throw ParseError.badJSON
    }
    return obj
}

/// Turns `limit_window_seconds` into something a human reads at a glance.
func windowLabel(seconds: Double?) -> String {
    guard let seconds, seconds > 0 else { return "한도" }
    switch seconds {
    case 604800: return "7일"
    case 86400: return "1일"
    case 18000: return "5시간"
    default:
        if seconds >= 86400 { return "\(Int(seconds / 86400))일" }
        return "\(Int(seconds / 3600))시간"
    }
}

// MARK: - Claude

/// `GET https://api.anthropic.com/api/oauth/usage`
///
/// Reports utilization already as a percentage. Many sibling keys exist
/// (`seven_day_opus`, assorted codenames) but are null on consumer plans, so we
/// read only the two windows that actually gate a Pro/Max account.
func parseClaudeUsage(_ data: Data, planLabel: String?, now: Date) throws -> ProviderReading {
    let root = try object(data)
    var windows: [UsageWindow] = []

    for (key, label) in [("five_hour", "5시간"), ("seven_day", "7일")] {
        guard let entry = root[key] as? [String: Any],
              let used = asDouble(entry["utilization"]) else { continue }
        let reset = (entry["resets_at"] as? String).flatMap(parseISODate)
        windows.append(UsageWindow(label: label, usedPercent: used, resetsAt: reset))
    }

    guard !windows.isEmpty else { throw ParseError.noUsableWindow }
    return ProviderReading(id: .claude, planLabel: planLabel, windows: windows, fetchedAt: now)
}

/// `GET https://api.anthropic.com/api/oauth/profile` -- only for the plan name.
func parseClaudePlanLabel(_ data: Data) -> String? {
    guard let root = try? object(data),
          let account = root["account"] as? [String: Any] else { return nil }
    if account["has_claude_max"] as? Bool == true { return "Max" }
    if account["has_claude_pro"] as? Bool == true { return "Pro" }
    return nil
}

// MARK: - ChatGPT (Codex)

/// `GET https://chatgpt.com/backend-api/codex/usage`
func parseChatGPTUsage(_ data: Data, now: Date) throws -> ProviderReading {
    let root = try object(data)
    guard let limit = root["rate_limit"] as? [String: Any] else {
        throw ParseError.missing("rate_limit")
    }
    let plan = (root["plan_type"] as? String).map { $0.capitalized }
    return ProviderReading(
        id: .chatgpt,
        planLabel: plan,
        windows: try chatGPTWindows(from: limit, now: now),
        fetchedAt: now
    )
}

/// `~/.codex/sessions/**/*.jsonl` carries the same `rate_limits` shape inside
/// `token_count` events. Used only as a fallback when the live call is refused,
/// so an expired token degrades to a timestamped older number instead of a dash.
func parseCodexSessionRateLimits(line: String, now: Date) throws -> ProviderReading {
    guard let data = line.data(using: .utf8) else { throw ParseError.badJSON }
    let root = try object(data)
    guard let payload = root["payload"] as? [String: Any],
          let limit = payload["rate_limits"] as? [String: Any] else {
        throw ParseError.missing("rate_limits")
    }
    let timestamp = (root["timestamp"] as? String).flatMap(parseISODate) ?? now
    let plan = (limit["plan_type"] as? String).map { $0.capitalized }
    return ProviderReading(
        id: .chatgpt,
        planLabel: plan,
        windows: try chatGPTWindows(from: limit, now: timestamp),
        fetchedAt: timestamp
    )
}

/// Shared by the live endpoint and the session-file fallback. The live response
/// nests windows under `primary_window`/`secondary_window`; the session files
/// use `primary`/`secondary`. Reset time is a unix timestamp in both.
private func chatGPTWindows(from limit: [String: Any], now: Date) throws -> [UsageWindow] {
    var windows: [UsageWindow] = []
    let keys = [("primary_window", "primary"), ("secondary_window", "secondary")]

    for (liveKey, fileKey) in keys {
        guard let window = (limit[liveKey] ?? limit[fileKey]) as? [String: Any],
              let used = asDouble(window["used_percent"]) else { continue }
        let reset = asDouble(window["reset_at"]) ?? asDouble(window["resets_at"])
        windows.append(UsageWindow(
            label: windowLabel(seconds: asDouble(window["limit_window_seconds"])
                               ?? asDouble(window["window_minutes"]).map { $0 * 60 }),
            usedPercent: used,
            resetsAt: reset.map { Date(timeIntervalSince1970: $0) }
        ))
    }

    guard !windows.isEmpty else { throw ParseError.noUsableWindow }
    return windows
}

// MARK: - Gemini / Antigravity

/// `agy -p "/quota" --output-format json`
///
/// Reports `remaining_fraction` (1.0 == untouched) for each budget group. Every
/// group here belongs to the one Antigravity subscription, so they collapse into
/// a single `.antigravity` provider with one window per group. (The user's
/// gemini.google.com web quota is a different thing entirely -- see GeminiWebSource.)
func parseAgyQuota(_ data: Data, now: Date) throws -> ProviderReading {
    let root = try object(data)
    guard let command = root["command"] as? [String: Any],
          let payload = command["data"] as? [String: Any],
          let groups = payload["groups"] as? [[String: Any]] else {
        throw ParseError.missing("command.data.groups")
    }

    var windows: [UsageWindow] = []
    for group in groups {
        guard let name = group["name"] as? String,
              let buckets = group["buckets"] as? [[String: Any]] else { continue }
        for bucket in buckets {
            guard let remaining = asDouble(bucket["remaining_fraction"]) else { continue }
            let reset = (bucket["reset_time"] as? String).flatMap(parseISODate)
            windows.append(UsageWindow(
                label: agyGroupLabel(name),
                usedPercent: (1.0 - remaining) * 100.0,
                resetsAt: reset
            ))
        }
    }

    guard !windows.isEmpty else { throw ParseError.noUsableWindow }
    return ProviderReading(id: .antigravity, planLabel: nil, windows: windows, fetchedAt: now)
}

/// Shortens Antigravity's prose group names for the dropdown.
func agyGroupLabel(_ name: String) -> String {
    let lower = name.lowercased()
    if lower.contains("gemini") { return "Gemini" }
    if lower.contains("claude") || lower.contains("gpt") { return "Claude/GPT" }
    return name
}

func agyWindowLabel(_ window: String?) -> String {
    switch window?.lowercased() {
    case "weekly": return "주간"
    case "daily": return "일간"
    case "monthly": return "월간"
    case .some(let other) where !other.isEmpty: return other
    default: return "한도"
    }
}

// MARK: - Gemini web (scraped DOM)

/// Parses the figures scraped from gemini.google.com's usage page.
///
/// The page shows two meters -- "현재 사용량" (a 5-hourly window) and "주간 한도"
/// (weekly) -- each as "NN% 사용됨". Order on the page is current-then-weekly, so
/// the first figure is the short window. Reset captions are localized prose and
/// not reliably machine-readable, so we skip them here; the percentages are the
/// part the user actually watches.
func parseGeminiWebUsage(_ data: Data, now: Date) throws -> ProviderReading {
    let root = try object(data)
    guard let used = root["used"] as? [Any] else { throw ParseError.missing("used") }

    let values = used.compactMap { asDouble($0) }
    guard !values.isEmpty else { throw ParseError.noUsableWindow }

    // Two meters: current (5-hourly) then weekly. One meter means weekly only.
    let labels = values.count >= 2 ? ["5시간", "주간"] : ["주간"]
    var windows: [UsageWindow] = []
    for (index, value) in values.prefix(2).enumerated() {
        windows.append(UsageWindow(label: labels[index], usedPercent: value, resetsAt: nil))
    }
    return ProviderReading(id: .gemini, planLabel: nil, windows: windows, fetchedAt: now)
}
