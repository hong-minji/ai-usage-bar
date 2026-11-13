import Foundation

/// Owns the current reading for every provider and knows how to refresh them.
///
/// Each provider is fetched independently so that one broken source degrades
/// only its own row. Failures fall back to the newest reading we have on hand
/// and are reported as `.stale`, never as a silently stale `.ok`.
@MainActor
final class UsageCoordinator {
    private(set) var states: [ProviderID: ProviderState] = [:]
    private(set) var lastRefresh: Date?
    private(set) var isRefreshing = false

    /// Called on the main actor whenever `states` changes.
    var onUpdate: (() -> Void)?

    init() {
        // Show whatever we knew at launch, marked as not-yet-verified, so the
        // bar is populated before the first network round trip completes.
        for id in ProviderID.allCases {
            if Prefs.shared.usesBrowser(id) { states[id] = BrowserUsageBridge.state(id); continue }
            if let cached = ReadingCache.shared.reading(for: id) {
                states[id] = .stale(cached, reason: "갱신 대기 중")
            }
        }
    }

    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        onUpdate?()

        let wanted = Set(Prefs.shared.visibleProviders)
        let agyPath = Prefs.shared.agyPath

        async let claude = Self.fetchClaude(skip: !wanted.contains(.claude))
        async let chatgpt = Self.fetchChatGPT(skip: !wanted.contains(.codex))
        async let antigravity = Self.fetchAntigravity(skip: !wanted.contains(.antigravity), override: agyPath)
        async let gemini = Self.fetchGeminiWeb(skip: !wanted.contains(.gemini))

        var next: [ProviderID: ProviderState] = [:]
        if let claude = await claude { next[.claude] = claude }
        if let chatgpt = await chatgpt { next[.codex] = chatgpt }
        if let antigravity = await antigravity { next[.antigravity] = antigravity }
        if let gemini = await gemini { next[.gemini] = gemini }

        // Keep rows for providers that were skipped this round rather than
        // dropping them, so toggling visibility doesn't erase history.
        for (id, state) in states where next[id] == nil {
            next[id] = state
        }

        states = next
        lastRefresh = Date()
        isRefreshing = false
        onUpdate?()
    }

    // MARK: - Per-provider fetches

    /// A new Chrome observation can update Gemini without re-polling every API.
    func refreshGeminiOnly() async {
        guard Prefs.shared.isVisible(.gemini) else { return }
        if let state = await Self.fetchGeminiWeb(skip: false) {
            states[.gemini] = state
            onUpdate?()
        }
    }

    func refreshBrowserOnly() {
        for id in [ProviderID.claude, .codex] where Prefs.shared.isVisible(id) && Prefs.shared.usesBrowser(id) {
            states[id] = BrowserUsageBridge.state(id)
        }
        onUpdate?()
    }

    private static func fetchClaude(skip: Bool) async -> ProviderState? {
        guard !skip else { return nil }
        if Prefs.shared.usesBrowser(.claude) { return BrowserUsageBridge.state(.claude) }
        do {
            let reading = try await ClaudeSource.fetch()
            ReadingCache.shared.store(reading)
            return .ok(reading)
        } catch {
            return degrade(.claude, reason: message(for: error))
        }
    }

    private static func fetchChatGPT(skip: Bool) async -> ProviderState? {
        guard !skip else { return nil }
        if Prefs.shared.usesBrowser(.codex) { return BrowserUsageBridge.state(.codex) }
        do {
            let reading = try await ChatGPTSource.fetch()
            ReadingCache.shared.store(reading)
            return .ok(reading)
        } catch {
            let reason = message(for: error)
            // Codex writes its rate limits into every session log, which may be
            // fresher than our own cache if the app has been closed a while.
            let fromSessions = ChatGPTSource.lastKnownFromSessions()
            let cached = ReadingCache.shared.reading(for: .codex)
            let best = [fromSessions, cached]
                .compactMap { $0 }
                .max(by: { $0.fetchedAt < $1.fetchedAt })

            guard let best else { return .unavailable(reason: reason) }
            ReadingCache.shared.store(best)
            return .stale(best, reason: reason)
        }
    }

    /// `agy /quota` reports the Antigravity coding budget. It is a blocking
    /// process launch of several seconds, so it runs off the main actor.
    private static func fetchAntigravity(skip: Bool, override: String?) async -> ProviderState? {
        guard !skip else { return nil }

        guard let binary = AgySource.resolveBinary(override: override) else {
            return degrade(.antigravity, reason: FetchError.toolMissing("agy").localizedDescription)
        }

        let outcome: Result<ProviderReading, Error> = await Task.detached {
            do { return .success(try AgySource.fetch(binary: binary)) }
            catch { return .failure(error) }
        }.value

        switch outcome {
        case .success(let reading):
            ReadingCache.shared.store(reading)
            return .ok(reading)
        case .failure(let error):
            return degrade(.antigravity, reason: message(for: error))
        }
    }

    /// Reads the latest verified usage page observation from the Chrome bridge.
    private static func fetchGeminiWeb(skip: Bool) async -> ProviderState? {
        guard !skip else { return nil }
        do {
            let reading = try await GeminiWebSource.shared.fetch()
            ReadingCache.shared.store(reading)
            return .ok(reading)
        } catch {
            if let reading = GeminiChromeBridge.cachedReading(),
               reading.fetchedAt > (ReadingCache.shared.reading(for: .gemini)?.fetchedAt ?? .distantPast) {
                ReadingCache.shared.store(reading)
            }
            return degrade(.gemini, reason: message(for: error))
        }
    }

        // MARK: - Helpers

    /// Fall back to the cached reading, or admit we have nothing.
    private static func degrade(_ id: ProviderID, reason: String) -> ProviderState? {
        if let cached = ReadingCache.shared.reading(for: id) {
            return .stale(cached, reason: reason)
        }
        return .unavailable(reason: reason)
    }

    private static func message(for error: Error) -> String {
        if let fetchError = error as? FetchError { return fetchError.localizedDescription }
        if let parseError = error as? ParseError { return parseError.localizedDescription }
        if (error as? URLError)?.code == .notConnectedToInternet { return "네트워크 연결 없음" }
        if error is URLError { return "네트워크 오류" }
        return error.localizedDescription
    }
}
