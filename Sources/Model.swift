import Foundation

/// The four things we can report on. `gemini` is the gemini.google.com web app's
/// chat quota (read through the Chrome extension); `antigravity` is the separate
/// coding-agent budget read from the `agy` CLI. Google tracks the two
/// independently even on the same account, so they are distinct providers.
enum ProviderID: String, CaseIterable, Codable {
    case claude
    case chatgpt
    case gemini        // gemini.google.com 웹(채팅) 사용량
    case antigravity   // Antigravity 코딩 에이전트 사용량 (별도 집계)

    /// Compact tag used in the menu bar, where width is scarce.
    var shortLabel: String {
        switch self {
        case .claude: return "C"
        case .chatgpt: return "G"
        case .gemini: return "Ge"
        case .antigravity: return "Ag"
        }
    }

    /// Brand colour as a hex string -- kept stringly-typed so this file stays
    /// free of AppKit and can be linked into the test binary.
    var brandHex: String {
        switch self {
        case .claude: return "D97757"          // Anthropic antique brass
        case .chatgpt: return "10A37F"         // OpenAI teal green
        // Gemini 웹과 Antigravity는 같은 구글 제품군이라 색을 통일 -- 숫자/라벨로 구분.
        case .gemini: return "3186FF"          // Gemini blue
        case .antigravity: return "3186FF"     // same blue, per user request
        }
    }

    var displayName: String {
        switch self {
        case .claude: return "Claude"
        case .chatgpt: return "ChatGPT"
        case .gemini: return "Gemini (웹)"
        case .antigravity: return "Antigravity"
        }
    }
}

/// One rate-limit window, normalised to "percent consumed" no matter whether the
/// upstream API reported usage or remaining.
struct UsageWindow: Equatable, Codable {
    let label: String
    let usedPercent: Double
    let resetsAt: Date?

    /// What gets displayed: a fuel gauge, not an odometer.
    var remainingPercent: Double {
        min(100, max(0, 100 - usedPercent))
    }
}

struct ProviderReading: Equatable, Codable {
    let id: ProviderID
    var planLabel: String?
    var windows: [UsageWindow]
    var fetchedAt: Date

    /// What the menu bar shows: whichever window is closest to blocking you,
    /// which in "remaining" terms is the one with the least left.
    var lowestRemainingPercent: Double? {
        windows.map(\.remainingPercent).min()
    }
}

enum ProviderState {
    /// Fetched successfully just now.
    case ok(ProviderReading)
    /// Fetch failed, but we still have an older reading worth showing.
    case stale(ProviderReading, reason: String)
    /// Fetch failed and we have nothing to fall back on.
    case unavailable(reason: String)

    var reading: ProviderReading? {
        switch self {
        case .ok(let r): return r
        case .stale(let r, _): return r
        case .unavailable: return nil
        }
    }

    var failureReason: String? {
        switch self {
        case .ok: return nil
        case .stale(_, let reason): return reason
        case .unavailable(let reason): return reason
        }
    }
}

enum Severity {
    case normal
    case warn
    case danger
}

/// Thresholds are expressed in the same unit as the display: percent remaining.
/// Less left means more urgent, so the comparisons run downward.
func severity(forRemaining remaining: Double, warnBelow warn: Double, dangerBelow danger: Double) -> Severity {
    if remaining <= danger { return .danger }
    if remaining <= warn { return .warn }
    return .normal
}

/// "방금", "12분 전", "3시간 전", "2일 전" -- used to label stale readings.
func koreanRelativeAge(from then: Date, to now: Date) -> String {
    let seconds = max(0, now.timeIntervalSince(then))
    if seconds < 90 { return "방금" }
    let minutes = Int((seconds / 60).rounded())
    if minutes < 60 { return "\(minutes)분 전" }
    let hours = Int((seconds / 3600).rounded(.down))
    if hours < 24 { return "\(hours)시간 전" }
    return "\(Int((seconds / 86400).rounded(.down)))일 전"
}

/// "4일 후", "6시간 후", "35분 후" -- used for reset times in the dropdown.
func koreanTimeUntil(_ date: Date, from now: Date) -> String {
    let seconds = date.timeIntervalSince(now)
    if seconds <= 0 { return "곧" }
    if seconds < 3600 { return "\(max(1, Int((seconds / 60).rounded())))분 후" }
    if seconds < 86400 { return "\(Int((seconds / 3600).rounded(.down)))시간 후" }
    return "\(Int((seconds / 86400).rounded(.down)))일 후"
}
