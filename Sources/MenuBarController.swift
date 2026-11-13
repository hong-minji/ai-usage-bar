import AppKit

extension NSColor {
    /// Six-digit RRGGBB. The brand palette is fixed, so an invalid string here
    /// would be a programming error rather than user input -- fall back to the
    /// default label colour instead of crashing.
    convenience init(brandHex hex: String) {
        var value: UInt64 = 0
        guard hex.count == 6, Scanner(string: hex).scanHexInt64(&value) else {
            self.init(cgColor: NSColor.labelColor.cgColor)!
            return
        }
        self.init(
            srgbRed: CGFloat((value >> 16) & 0xFF) / 255,
            green: CGFloat((value >> 8) & 0xFF) / 255,
            blue: CGFloat(value & 0xFF) / 255,
            alpha: 1
        )
    }
}

@MainActor
final class MenuBarController: NSObject, NSMenuDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let coordinator = UsageCoordinator()
    private let menu = NSMenu()
    private var timer: Timer?
    private var settings: SettingsWindowController?

    private static let rowFont = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular)
    private static let barFont = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium)

    override init() {
        super.init()
        menu.delegate = self
        statusItem.menu = menu
        statusItem.button?.font = Self.barFont

        coordinator.onUpdate = { [weak self] in
            self?.renderBar()
            self?.rebuildMenu()
        }

        renderBar()
        rebuildMenu()
        scheduleTimer()
        observeWake()
        DistributedNotificationCenter.default().addObserver(
            forName: GeminiChromeBridge.updatedNotificationName, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in await self?.coordinator.refreshGeminiOnly() }
        }
        DistributedNotificationCenter.default().addObserver(
            forName: BrowserUsageBridge.updatedNotificationName, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.coordinator.refreshBrowserOnly() }
        }
        refreshNow()
    }

    // MARK: - Scheduling

    /// Called again whenever the interval changes in Settings.
    func scheduleTimer() {
        timer?.invalidate()
        let interval = TimeInterval(Prefs.shared.refreshMinutes * 60)
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refreshNow() }
        }
        // Generous tolerance: this is a status display, not a deadline.
        timer.tolerance = interval * 0.2
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    /// Readings go stale while the machine sleeps, so catch up on wake.
    private func observeWake() {
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.refreshNow() }
        }
    }

    func refreshNow() {
        Task { await coordinator.refresh() }
    }

    // MARK: - Menu bar title

    private func renderBar() {
        let prefs = Prefs.shared
        let segments = barSegments(
            for: prefs.visibleProviders,
            states: coordinator.states,
            warnBelow: prefs.warnRemaining,
            dangerBelow: prefs.dangerRemaining,
            now: Date()
        )

        let title = NSMutableAttributedString()
        for segment in segments {
            let textColor: NSColor
            if case .brand(let provider) = segment.style {
                textColor = NSColor(brandHex: provider.brandHex)
            } else {
                textColor = .white
            }
            title.append(NSAttributedString(string: segment.text, attributes: [
                .font: Self.barFont,
                .foregroundColor: textColor,
            ]))
        }

        if title.length == 0 {
            title.append(NSAttributedString(string: "AI", attributes: [
                .font: Self.barFont,
                .foregroundColor: NSColor.white,
            ]))
        }

        statusItem.button?.attributedTitle = title
    }

    // MARK: - Dropdown

    /// Opening the menu only renders the current state; scheduled refreshes and
    /// the explicit Refresh action do the I/O. Repeated clicks never launch agy.
    func menuWillOpen(_ menu: NSMenu) {
        renderBar()
        rebuildMenu()
    }

    private func rebuildMenu() {
        menu.removeAllItems()

        let visible = Prefs.shared.visibleProviders
        if visible.isEmpty {
            menu.addItem(disabledItem("설정에서 표시할 항목을 선택하세요"))
        }

        for id in visible {
            menu.addItem(headerItem(for: id))
            switch coordinator.states[id] {
            case .ok(let reading):
                addWindowRows(reading, to: menu)
            case .stale(let reading, let reason):
                addWindowRows(reading, to: menu)
                menu.addItem(noteItem("\(reason) · \(koreanRelativeAge(from: reading.fetchedAt, to: Date())) 기준"))
                if id == .codex && !Prefs.shared.usesBrowser(id) { menu.addItem(noteItem("로컬 로그인 또는 설정의 Chrome 웹 연결을 확인하세요")) }
            case .unavailable(let reason):
                menu.addItem(noteItem(reason))
                menu.addItem(hintItem(for: id))
            case nil:
                menu.addItem(noteItem("불러오는 중…"))
            }
            if id == .codex {
                menu.addItem(noteItem("ChatGPT 설정의 플랜 한도 기준"))
                let open = NSMenuItem(title: "ChatGPT 플랜 사용량 확인…", action: #selector(openChatGPT), keyEquivalent: "")
                open.target = self
                menu.addItem(open)
            }
            menu.addItem(.separator())
        }

        menu.addItem(disabledItem(statusLine()))

        let refresh = NSMenuItem(title: "지금 갱신", action: #selector(didTapRefresh), keyEquivalent: "r")
        refresh.target = self
        refresh.isEnabled = !coordinator.isRefreshing
        menu.addItem(refresh)

        let settingsItem = NSMenuItem(title: "설정…", action: #selector(didTapSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())
        let quit = NSMenuItem(title: "종료", action: #selector(didTapQuit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
    }

    private func statusLine() -> String {
        if coordinator.isRefreshing { return "갱신 중…" }
        guard let last = coordinator.lastRefresh else { return "아직 갱신되지 않음" }
        return "\(koreanRelativeAge(from: last, to: Date())) 갱신 · \(Prefs.shared.refreshMinutes)분마다"
    }

    private func headerItem(for id: ProviderID) -> NSMenuItem {
        var title = id.displayName
        if let plan = coordinator.states[id]?.reading?.planLabel { title += "  \(plan)" }
        let item = disabledItem(title)
        item.attributedTitle = NSAttributedString(string: title, attributes: [
            .font: NSFont.systemFont(ofSize: 12, weight: .semibold),
            .foregroundColor: NSColor(brandHex: id.brandHex),
        ])
        return item
    }

    /// Meter and percent come first so they line up in a monospaced font; the
    /// variable-width Korean window label trails where misalignment is harmless.
    private func addWindowRows(_ reading: ProviderReading, to menu: NSMenu) {
        for window in reading.windows {
            let remaining = window.remainingPercent
            var line = "  \(asciiMeter(remaining: remaining)) \(String(format: "%3d", Int(remaining.rounded())))% 남음   \(window.label)"
            if let reset = window.resetsAt {
                line += " · \(koreanTimeUntil(reset, from: Date())) 리셋"
            }

            let item = disabledItem(line)
            item.attributedTitle = NSAttributedString(string: line, attributes: [
                .font: Self.rowFont,
                .foregroundColor: NSColor.white,
            ])
            menu.addItem(item)
        }
    }

    private func hintItem(for id: ProviderID) -> NSMenuItem {
        let hint: String
        switch id {
        case .claude: hint = "설정 → Chrome 연결 또는 기존 Claude Code 로그인을 사용하세요"
        case .codex: hint = "설정 → Chrome 연결 또는 기존 Codex 로그인을 사용하세요"
        case .gemini: hint = "설정 → Chrome 연결에서 확장 프로그램을 추가하세요"
        case .antigravity: hint = "agy 를 실행해 로그인하세요"
        }
        return noteItem(hint)
    }

    private func noteItem(_ text: String) -> NSMenuItem {
        let line = "  \(text)"
        let item = disabledItem(line)
        item.attributedTitle = NSAttributedString(string: line, attributes: [
            .font: NSFont.systemFont(ofSize: 11),
            .foregroundColor: NSColor.secondaryLabelColor,
        ])
        return item
    }

    private func disabledItem(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    // MARK: - Actions

    @objc private func openChatGPT() { NSWorkspace.shared.open(URL(string: "https://chatgpt.com/settings/usage?tab=overview")!) }

    @objc private func didTapRefresh() { refreshNow() }

    @objc private func didTapSettings() {
        if settings == nil {
            settings = SettingsWindowController { [weak self] in
                self?.scheduleTimer()
                self?.renderBar()
                self?.refreshNow()
            }
        }
        settings?.show()
    }

    @objc private func didTapQuit() { NSApp.terminate(nil) }
}
