import Foundation

/// Interface language. Korean is the original UI; a system set to any other
/// language gets English.
enum AppLanguage: String, CaseIterable {
    case korean = "ko"
    case english = "en"

    private static let lock = NSLock()
    private static var storedOverride: AppLanguage?

    /// The ordered language list also carries a per-app language chosen in
    /// System Settings, so that choice is honoured without extra code.
    private static let detected = resolve(preferredLanguages: Locale.preferredLanguages)

    /// An explicit choice from Settings; `nil` follows the system. Guarded by a
    /// lock because error text is also built on background tasks.
    static var override: AppLanguage? {
        get { lock.lock(); defer { lock.unlock() }; return storedOverride }
        set { lock.lock(); storedOverride = newValue; lock.unlock() }
    }

    static var current: AppLanguage { override ?? detected }

    /// The first listed language this app has an interface for. Someone who
    /// lists Japanese then Korean reads Korean better than the English default.
    static func resolve(preferredLanguages: [String]) -> AppLanguage {
        for tag in preferredLanguages {
            let code = tag.lowercased().split(whereSeparator: { $0 == "-" || $0 == "_" }).first.map(String.init)
            if code == "ko" { return .korean }
            if code == "en" { return .english }
        }
        return .english
    }
}

/// The string for the current interface language. Both arguments are
/// autoclosures so only the chosen one is built.
func L(_ korean: @autoclosure () -> String, _ english: @autoclosure () -> String) -> String {
    AppLanguage.current == .korean ? korean() : english()
}

/// Window labels are stored, cached and exchanged with the Chrome extension in
/// their original form ("5시간", "주간"). Changing those would break existing
/// caches and installed extensions, so they are translated only when drawn.
func localizedWindowLabel(_ label: String, language: AppLanguage = .current) -> String {
    guard language == .english else { return label }
    switch label {
    case "주간": return "Weekly"
    case "일간": return "Daily"
    case "월간": return "Monthly"
    case "한도": return "Limit"
    case "사용량": return "Usage"
    default: break
    }
    // "5시간" -> "5-hour", "7일" -> "7-day"
    for (suffix, unit) in [("시간", "hour"), ("일", "day")] where label.hasSuffix(suffix) {
        if let count = Int(label.dropLast(suffix.count)) { return "\(count)-\(unit)" }
    }
    return label
}
