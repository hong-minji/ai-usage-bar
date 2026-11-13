import Foundation

// Minimal harness: no XCTest, because Command Line Tools ships no test runner.
var failures = 0
var checks = 0

func check(_ condition: Bool, _ what: String, _ detail: @autoclosure () -> String = "") {
    checks += 1
    if !condition {
        failures += 1
        let extra = detail()
        print("  FAIL  \(what)" + (extra.isEmpty ? "" : " — \(extra)"))
    }
}

func equal<T: Equatable>(_ actual: T, _ expected: T, _ what: String) {
    check(actual == expected, what, "got \(actual), expected \(expected)")
}

func section(_ name: String) { print("\n\(name)") }

let now = Date(timeIntervalSince1970: 1_794_000_000)  // fixed clock

// Fixtures are verbatim captures from this machine, trimmed of irrelevant keys.

section("Claude — api.anthropic.com/api/oauth/usage")
do {
    let json = """
    {"five_hour":{"utilization":6.0,"resets_at":"2026-11-07T13:40:00.981920+00:00",
     "limit_dollars":null,"locked_reason":null},
     "seven_day":{"utilization":73.0,"resets_at":"2026-11-10T00:00:00.981939+00:00"},
     "seven_day_opus":null,"pace":null,"indicator":null}
    """.data(using: .utf8)!

    let reading = try parseClaudeUsage(json, planLabel: "Pro", now: now)
    equal(reading.windows.count, 2, "both windows parsed")
    equal(reading.windows[0].label, "5시간", "first window label")
    equal(reading.windows[0].usedPercent, 6.0, "five-hour utilization")
    equal(reading.windows[1].usedPercent, 73.0, "seven-day utilization")
    equal(reading.lowestRemainingPercent, 27.0, "binding window is the one with least left")
    check(reading.windows[0].resetsAt != nil, "fractional-second reset time parsed")
    equal(reading.planLabel, "Pro", "plan label carried through")
}

do {
    // Consumer accounts return null for most sibling windows; that must not throw.
    let sparse = #"{"five_hour":{"utilization":12.0},"seven_day":null}"#.data(using: .utf8)!
    let reading = try parseClaudeUsage(sparse, planLabel: nil, now: now)
    equal(reading.windows.count, 1, "null windows skipped, not fatal")
}

do {
    let profile = #"{"account":{"has_claude_max":false,"has_claude_pro":true}}"#.data(using: .utf8)!
    equal(parseClaudePlanLabel(profile), "Pro", "plan label from profile")
    let max = #"{"account":{"has_claude_max":true,"has_claude_pro":true}}"#.data(using: .utf8)!
    equal(parseClaudePlanLabel(max), "Max", "Max wins over Pro")
}

section("ChatGPT — chatgpt.com/backend-api/codex/usage")
do {
    let json = """
    {"plan_type":"pro",
     "rate_limit":{"allowed":true,"limit_reached":false,
       "primary_window":{"used_percent":72,"limit_window_seconds":604800,
                         "reset_after_seconds":365784,"reset_at":1794408877},
       "secondary_window":null},
     "credits":{"has_credits":false,"balance":"0"}}
    """.data(using: .utf8)!

    let reading = try parseChatGPTUsage(json, now: now)
    equal(reading.windows.count, 1, "primary window only")
    equal(reading.windows[0].usedPercent, 72.0, "used_percent")
    equal(reading.windows[0].label, "7일", "604800s renders as 7일")
    equal(reading.planLabel, "Pro", "plan_type capitalised")
    equal(reading.windows[0].resetsAt, Date(timeIntervalSince1970: 1_794_408_877), "unix reset time")
}

do {
    // Plans with both a short and a long window must surface both.
    let two = """
    {"plan_type":"plus","rate_limit":{
       "primary_window":{"used_percent":40,"limit_window_seconds":18000,"reset_at":1794000900},
       "secondary_window":{"used_percent":91,"limit_window_seconds":604800,"reset_at":1794400000}}}
    """.data(using: .utf8)!
    let reading = try parseChatGPTUsage(two, now: now)
    equal(reading.windows.count, 2, "both windows parsed")
    equal(reading.windows[0].label, "5시간", "18000s renders as 5시간")
    equal(reading.lowestRemainingPercent, 9.0, "picks the window with least left")
}

section("ChatGPT fallback — ~/.codex/sessions/**/*.jsonl")
do {
    // Same shape, different key names (`primary`, `window_minutes`).
    let line = """
    {"timestamp":"2026-11-04T16:48:23.205Z","type":"event_msg","payload":{"type":"token_count",
      "info":{"total_token_usage":{"total_tokens":14123481}},
      "rate_limits":{"limit_id":"codex","plan_type":"pro",
        "primary":{"used_percent":2.0,"window_minutes":10080,"resets_at":1794408878},
        "secondary":null}}}
    """
    let reading = try parseCodexSessionRateLimits(line: line, now: now)
    equal(reading.windows[0].usedPercent, 2.0, "used_percent from session file")
    equal(reading.windows[0].label, "7일", "window_minutes converted to seconds")
    equal(reading.planLabel, "Pro", "plan from session file")
    check(reading.fetchedAt < now, "fetchedAt comes from the record, not the clock")
}

section("Antigravity — agy -p \"/quota\" (all groups → one provider)")
do {
    let json = """
    {"conversation_id":"","status":"SUCCESS","num_turns":0,
     "usage":{"input_tokens":0,"output_tokens":0,"total_tokens":0},
     "command":{"name":"usage","data":{"description":"Within each group...",
       "groups":[
         {"name":"Gemini Models","description":"Gemini Flash, Gemini Pro",
          "buckets":[{"id":"gemini-weekly","name":"Weekly Limit Remaining",
                      "window":"weekly","remaining_fraction":1,
                      "reset_time":"2026-11-14T11:50:32Z"}]},
         {"name":"Claude and GPT models","description":"Claude Opus, Claude Sonnet, GPT-OSS",
          "buckets":[{"id":"3p-weekly","name":"Weekly Limit Remaining",
                      "window":"weekly","remaining_fraction":0.25,
                      "reset_time":"2026-11-14T11:50:32Z"}]}]}}}
    """.data(using: .utf8)!

    let reading = try parseAgyQuota(json, now: now)
    equal(reading.id, .antigravity, "all agy groups collapse into Antigravity")
    equal(reading.windows.count, 2, "one window per group")
    equal(reading.windows[0].label, "Gemini", "first group label shortened")
    equal(reading.windows[0].usedPercent, 0.0, "remaining 1.0 means 0% used")
    equal(reading.windows[1].label, "Claude/GPT", "second group label shortened")
    equal(reading.windows[1].usedPercent, 75.0, "remaining 0.25 means 75% used")
    check(reading.windows[0].resetsAt != nil, "Z-suffixed reset time parsed")
}

do {
    equal(agyGroupLabel("Gemini Models"), "Gemini", "Gemini group label")
    equal(agyGroupLabel("Claude and GPT models"), "Claude/GPT", "3P group label")
    equal(agyGroupLabel("Something New"), "Something New", "unknown group kept verbatim")
}

section("Gemini web — scraped from gemini.google.com/usage")
do {
    // Two meters on the page: current (5-hourly) then weekly.
    let json = #"{"used":[95,32],"block":"현재 사용량 95% 사용됨 주간 한도 32% 사용됨"}"#.data(using: .utf8)!
    let reading = try parseGeminiWebUsage(json, now: now)
    equal(reading.id, .gemini, "routed to the web Gemini provider")
    equal(reading.windows.count, 2, "both meters captured")
    equal(reading.windows[0].label, "5시간", "first meter is the short window")
    equal(reading.windows[0].usedPercent, 95.0, "current usage")
    equal(reading.windows[1].label, "주간", "second meter is weekly")
    equal(reading.windows[1].usedPercent, 32.0, "weekly usage")
    equal(reading.lowestRemainingPercent, 5.0, "binding window is the 5% one")
}

do {
    // Some accounts show only the weekly meter.
    let single = #"{"used":[32]}"#.data(using: .utf8)!
    let reading = try parseGeminiWebUsage(single, now: now)
    equal(reading.windows.count, 1, "single meter handled")
    equal(reading.windows[0].label, "주간", "single meter is weekly")
}

section("Severity thresholds (percent remaining -- less is worse)")
do {
    equal(severity(forRemaining: 21, warnBelow: 20, dangerBelow: 5), .normal, "plenty left")
    equal(severity(forRemaining: 20, warnBelow: 20, dangerBelow: 5), .warn, "at warn boundary")
    equal(severity(forRemaining: 6, warnBelow: 20, dangerBelow: 5), .warn, "between thresholds")
    equal(severity(forRemaining: 5, warnBelow: 20, dangerBelow: 5), .danger, "at danger boundary")
    equal(severity(forRemaining: 0, warnBelow: 20, dangerBelow: 5), .danger, "exhausted")
}

section("Used is stored, remaining is displayed")
do {
    let w = UsageWindow(label: "7일", usedPercent: 73, resetsAt: nil)
    equal(w.usedPercent, 73.0, "upstream value kept as-is")
    equal(w.remainingPercent, 27.0, "display value inverted")
    equal(UsageWindow(label: "x", usedPercent: 140, resetsAt: nil).remainingPercent, 0.0,
          "over-consumption clamps to nothing left")
    equal(UsageWindow(label: "x", usedPercent: -5, resetsAt: nil).remainingPercent, 100.0,
          "negative usage clamps to full")
}

section("Brand colours")
do {
    equal(ProviderID.claude.brandHex, "D97757", "Anthropic antique brass")
    equal(ProviderID.chatgpt.brandHex, "10A37F", "OpenAI teal green")
    equal(ProviderID.gemini.brandHex, "3186FF", "Gemini blue")
    equal(ProviderID.antigravity.brandHex, ProviderID.gemini.brandHex,
          "Antigravity shares Gemini's blue, per request")
    equal(ProviderID.claude.shortLabel, "C", "distinct tags separate same-coloured providers")
    equal(ProviderID.antigravity.shortLabel, "Ag", "Antigravity tag")
}

section("Menu bar composition")
do {
    let claude = ProviderReading(id: .claude, planLabel: "Pro", windows: [
        UsageWindow(label: "5시간", usedPercent: 6, resetsAt: nil),
        UsageWindow(label: "7일", usedPercent: 73, resetsAt: nil),
    ], fetchedAt: now)
    let chatgpt = ProviderReading(id: .chatgpt, planLabel: "Pro", windows: [
        UsageWindow(label: "7일", usedPercent: 72, resetsAt: nil),
    ], fetchedAt: now)
    let gemini = ProviderReading(id: .gemini, planLabel: nil, windows: [
        UsageWindow(label: "주간", usedPercent: 0, resetsAt: nil),
    ], fetchedAt: now)

    let segments = barSegments(
        for: [.claude, .chatgpt, .gemini],
        states: [.claude: .ok(claude), .chatgpt: .ok(chatgpt), .gemini: .ok(gemini)],
        warnBelow: 20, dangerBelow: 5, now: now
    )
    equal(barPlainText(segments), "C 27% · G 28% · Ge 100%", "bar shows what is left")

    // The provider tag carries the brand colour; the number carries the warning.
    equal(segments[0].style, .brand(.claude), "tag is brand-coloured")
    equal(segments[1].style, .severity(.normal), "number is severity-coloured")
    equal(segments[2].style, .plain, "separator is neutral")

    let two = barSegments(
        for: [.claude, .gemini],
        states: [.claude: .ok(claude), .gemini: .ok(gemini)],
        warnBelow: 20, dangerBelow: 5, now: now
    )
    equal(barPlainText(two), "C 27% · Ge 100%", "hidden provider drops cleanly")

    // Stale readings keep the number but admit their age.
    let old = ProviderReading(id: .chatgpt, planLabel: "Pro", windows: [
        UsageWindow(label: "7일", usedPercent: 72, resetsAt: nil),
    ], fetchedAt: now.addingTimeInterval(-2 * 86400))
    let stale = barSegments(
        for: [.chatgpt],
        states: [.chatgpt: .stale(old, reason: "401")],
        warnBelow: 20, dangerBelow: 5, now: now
    )
    equal(barPlainText(stale), "G 28%(2일 전)", "stale reading is labelled")

    let dead = barSegments(
        for: [.gemini],
        states: [.gemini: .unavailable(reason: "agy 없음")],
        warnBelow: 20, dangerBelow: 5, now: now
    )
    equal(barPlainText(dead), "Ge –", "unavailable provider shows a dash")

    // Colour must track the emptiest window, not the first one.
    let hot = ProviderReading(id: .claude, planLabel: nil, windows: [
        UsageWindow(label: "5시간", usedPercent: 3, resetsAt: nil),
        UsageWindow(label: "7일", usedPercent: 96, resetsAt: nil),
    ], fetchedAt: now)
    let hotSegments = barSegments(for: [.claude], states: [.claude: .ok(hot)],
                                  warnBelow: 20, dangerBelow: 5, now: now)
    equal(barPlainText(hotSegments), "C 4%", "reports the emptiest window")
    equal(hotSegments[1].style, .severity(.danger), "emptiest window drives the colour")
}

section("Meters and relative time")
do {
    // Filled cells are fuel left, so an exhausted quota reads as an empty tank.
    equal(asciiMeter(remaining: 0), "░░░░░░░░░░", "nothing left")
    equal(asciiMeter(remaining: 27), "███░░░░░░░", "27% left")
    equal(asciiMeter(remaining: 100), "██████████", "untouched")
    equal(asciiMeter(remaining: 140), "██████████", "over-100 clamped")
    equal(asciiMeter(remaining: -5), "░░░░░░░░░░", "negative clamped")

    equal(koreanRelativeAge(from: now, to: now), "방금", "just now")
    equal(koreanRelativeAge(from: now.addingTimeInterval(-720), to: now), "12분 전", "minutes")
    equal(koreanRelativeAge(from: now.addingTimeInterval(-10800), to: now), "3시간 전", "hours")
    equal(koreanRelativeAge(from: now.addingTimeInterval(-172800), to: now), "2일 전", "days")

    equal(koreanTimeUntil(now.addingTimeInterval(2100), from: now), "35분 후", "minutes until")
    equal(koreanTimeUntil(now.addingTimeInterval(21600), from: now), "6시간 후", "hours until")
    equal(koreanTimeUntil(now.addingTimeInterval(4 * 86400), from: now), "4일 후", "days until")
    equal(koreanTimeUntil(now.addingTimeInterval(-50), from: now), "곧", "already past")
}

section("Malformed input is refused, not guessed")
do {
    check((try? parseClaudeUsage(Data("not json".utf8), planLabel: nil, now: now)) == nil,
          "garbage rejected")
    check((try? parseClaudeUsage(Data("{}".utf8), planLabel: nil, now: now)) == nil,
          "empty object has no usable window")
    check((try? parseChatGPTUsage(Data(#"{"plan_type":"pro"}"#.utf8), now: now)) == nil,
          "missing rate_limit rejected")
    check((try? parseAgyQuota(Data(#"{"command":{"data":{"groups":[]}}}"#.utf8), now: now)) == nil,
          "no groups rejected")
}

section("Gemini Chrome bridge — validated usage-only messages")
do {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    let base: [String: Any] = [
        "version": 1, "status": "ok",
        "sourceURL": "https://gemini.google.com/u/0/usage",
        "account": "someone@example.com",
        "observedAt": formatter.string(from: now),
        "used": [12.5, 78.0], "labels": ["5시간", "주간"],
    ]
    func message(_ overrides: [String: Any] = [:]) -> Data {
        try! JSONSerialization.data(withJSONObject: base.merging(overrides) { _, replacement in replacement })
    }
    let report = try GeminiChromeBridge.validate(message(), now: now)
    equal(report.reading?.windows.count, 2, "Chrome bridge keeps both usage windows")
    equal(report.reading?.windows.map(\.label), ["5시간", "주간"], "Chrome bridge preserves window labels")
    equal(report.reading?.lowestRemainingPercent, 22, "Chrome usage is converted to remaining")
    equal(report.reading?.fetchedAt, now, "Chrome bridge keeps observation time")
    let reversed = try GeminiChromeBridge.validate(message(["labels": ["주간", "5시간"]]), now: now)
    equal(reversed.reading?.windows.first?.label, "주간", "labels do not depend on DOM order")
    let fallback = try GeminiChromeBridge.validate(message(["labels": ["", "bad\nlabel"]]), now: now)
    equal(fallback.reading?.windows.map(\.label), ["사용량", "사용량"], "unsafe or absent labels use neutral fallback")

    for badSource in ["http://gemini.google.com/usage", "https://gemini.google.com.evil.test/usage",
                      "https://gemini.google.com/app", "https://gemini.google.com/usageevil",
                      "https://gemini.google.com/u/other/usage", "https://user:secret@gemini.google.com/usage"] {
        check((try? GeminiChromeBridge.validate(message(["sourceURL": badSource]), now: now)) == nil,
              "Chrome bridge rejects source \(badSource)")
    }
    for badAccount in ["", "   ", "not-an-email", "a@b", "two accounts@example.com", "who@example.com\nx"] {
        check((try? GeminiChromeBridge.validate(message(["account": badAccount]), now: now)) == nil,
              "Chrome bridge requires a verified account for a successful reading")
    }
    // The extension decides which account to trust; the app only requires that
    // one was actually verified on the page.
    check((try? GeminiChromeBridge.validate(message(["account": "another.person@example.com"]), now: now)) != nil,
          "Chrome bridge accepts whichever account the extension verified")
    check((try? GeminiChromeBridge.validate(message(["status": "account_mismatch", "used": [], "labels": []]), now: now)) != nil,
          "Chrome bridge accepts a mismatch report that carries no numbers")
    check((try? GeminiChromeBridge.validate(message(["status": "made_up"]), now: now)) == nil,
          "Chrome bridge rejects unknown status")
    check((try? GeminiChromeBridge.validate(message(["version": 2]), now: now)) == nil,
          "Chrome bridge rejects unknown protocol version")
    let invalidUsage: [[Any]] = [[-1.0], [100.01], [], [1.0, 2.0, 3.0], ["NaN"], [true]]
    for badValues in invalidUsage {
        check((try? GeminiChromeBridge.validate(message(["used": badValues]), now: now)) == nil,
              "Chrome bridge rejects invalid percentage values")
    }
    check((try? GeminiChromeBridge.validate(message(["observedAt": formatter.string(from: now.addingTimeInterval(61))]), now: now)) == nil,
          "Chrome bridge rejects future observations")
    check((try? GeminiChromeBridge.validate(message(["observedAt": formatter.string(from: now.addingTimeInterval(-901))]), now: now)) == nil,
          "Chrome bridge rejects expired observations")
    check((try? GeminiChromeBridge.validate(message(["observedAt": "not a date"]), now: now)) == nil,
          "Chrome bridge rejects malformed observation time")
    let oversized = message() + Data(repeating: 32, count: GeminiChromeBridge.maximumMessageBytes)
    check((try? GeminiChromeBridge.validate(oversized, now: now)) == nil, "Chrome bridge bounds incoming message size")
    for status in ["login_required", "account_mismatch", "unavailable"] {
        let failed = try GeminiChromeBridge.validate(message(["status": status, "account": "", "used": [], "labels": []]), now: now)
        check(failed.reading == nil, "Chrome bridge error status \(status) cannot become a reading")
    }
}

section("Chrome installation — portable app path and private registration")
do {
    let fm = FileManager.default
    let scratch = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? fm.removeItem(at: scratch) }
    let home = scratch.appendingPathComponent("Test User")
    let resources = scratch.appendingPathComponent("응용 프로그램/AIUsageBar.app/Contents/Resources")
    try fm.createDirectory(at: resources, withIntermediateDirectories: true)
    let host = resources.appendingPathComponent("gemini-native-host")
    check((try? ChromeInstallation.register(resources: resources, home: home)) == nil,
          "missing host refuses registration")
    try Data("#!/bin/sh\nexit 0\n".utf8).write(to: host)
    try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: host.path)
    try ChromeInstallation.register(resources: resources, home: home)
    let file = home.appendingPathComponent("Library/Application Support/Google/Chrome/NativeMessagingHosts/com.local.ai_usage_bar.gemini.json")
    let manifest = try JSONSerialization.jsonObject(with: Data(contentsOf: file)) as! [String: Any]
    equal(manifest["path"] as? String, host.path, "registration uses actual app path including spaces and Korean")
    equal(manifest["allowed_origins"] as? [String], [GeminiChromeBridge.allowedExtensionOrigin], "only pinned extension allowed")
    let attributes = try fm.attributesOfItem(atPath: file.path)
    equal((attributes[.posixPermissions] as? NSNumber)?.intValue, 0o600, "registration is owner-only")
    let moved = scratch.appendingPathComponent("Moved.app/Contents/Resources")
    try fm.createDirectory(at: moved.deletingLastPathComponent(), withIntermediateDirectories: true)
    try fm.moveItem(at: resources, to: moved)
    try ChromeInstallation.register(resources: moved, home: home)
    let updated = try JSONSerialization.jsonObject(with: Data(contentsOf: file)) as! [String: Any]
    equal(updated["path"] as? String, moved.appendingPathComponent("gemini-native-host").path,
          "reconnecting repairs registration after app move")
}

print("\n\(checks - failures)/\(checks) checks passed")
if failures > 0 {
    print("\(failures) FAILED")
    exit(1)
}
print("all green")
