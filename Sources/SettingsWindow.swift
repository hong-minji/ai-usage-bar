import AppKit

@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    private let window: NSWindow
    private let onChange: () -> Void
    private let onLanguageChange: () -> Void

    private let intervalField = NSTextField()
    private let agyField = NSTextField()
    private let loginToggle = NSButton()
    private let languageMenu = NSPopUpButton()
    private var connectionMenus: [ProviderID: NSPopUpButton] = [:]
    private var providerToggles: [ProviderID: NSButton] = [:]

    /// Labels are built once here in the current language; `onLanguageChange`
    /// lets the owner replace this window when the user picks another one.
    init(onChange: @escaping () -> Void, onLanguageChange: @escaping () -> Void) {
        self.onChange = onChange
        self.onLanguageChange = onLanguageChange
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 100),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        super.init()

        window.title = L("AI 사용량 설정", "AI Usage Bar Settings")
        window.delegate = self
        window.isReleasedWhenClosed = false
        window.contentView = buildContent()
        window.center()
        loadValues()
    }

    func show() {
        loadValues()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func close() {
        window.close()
    }

    var frameOrigin: NSPoint {
        get { window.frame.origin }
        set { window.setFrameOrigin(newValue) }
    }

    // MARK: - Layout

    private func buildContent() -> NSView {
        let grid = NSGridView(views: [
            [label(L("갱신 주기", "Refresh every")), numberRow(intervalField, suffix: L("분", "min"))],
            [label(L("표시 항목", "Show")), providerStack()],
            [label(L("Claude 연결", "Claude connection")), connectionRow(.claude)],
            [label(L("GPT 연결", "GPT connection")), connectionRow(.codex)],
            [label(L("agy 경로", "agy path")), agyRow()],
            [label(L("웹 연결", "Web connection")), geminiLoginRow()],
            [label(L("언어", "Language")), languageRow()],
            [NSGridCell.emptyContentView, loginRow()],
        ])
        grid.rowSpacing = 12
        grid.columnSpacing = 14
        grid.column(at: 0).xPlacement = .trailing
        for index in 0..<grid.numberOfRows {
            grid.row(at: index).yPlacement = .center
        }

        let footer = NSTextField(wrappingLabelWithString: L(
            "퍼센트는 '남은 양'입니다. 숫자가 작을수록 한도에 가깝습니다. "
            + "모델 표시는 대표색, 퍼센트 숫자는 항상 흰색입니다. 위 주기는 메뉴바 갱신 간격이며, "
            + "웹 자동 조회는 Chrome 실행 중 10분마다입니다. 확장에서 자동 조회를 끌 수 있습니다. GPT는 플랜 사용량을 표시합니다. 포함되는 기능은 ChatGPT 사용량 페이지에서 확인하세요.",
            "Percentages show what is left, so a smaller number is closer to the limit. "
            + "Service names use their brand color and the numbers are always white. The interval above is how often the menu bar refreshes; "
            + "automatic web checks run every 10 minutes while Chrome is open and can be turned off in the extension. GPT shows plan usage. Check the ChatGPT usage page for which features count."))
        footer.font = .systemFont(ofSize: 11)
        footer.textColor = .secondaryLabelColor
        footer.preferredMaxLayoutWidth = 380

        let stack = NSStackView(views: [grid, separator(), footer])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 14
        stack.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        stack.translatesAutoresizingMaskIntoConstraints = false

        let container = NSView()
        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.topAnchor),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            footer.widthAnchor.constraint(lessThanOrEqualToConstant: 380),
        ])
        return container
    }

    private func label(_ text: String) -> NSTextField {
        let field = NSTextField(labelWithString: text)
        field.font = .systemFont(ofSize: 12)
        field.textColor = .secondaryLabelColor
        return field
    }

    private func separator() -> NSBox {
        let box = NSBox()
        box.boxType = .separator
        return box
    }

    private func numberRow(_ field: NSTextField, suffix: String) -> NSView {
        field.formatter = integerFormatter()
        field.alignment = .right
        field.target = self
        field.action = #selector(commit)
        field.translatesAutoresizingMaskIntoConstraints = false
        field.widthAnchor.constraint(equalToConstant: 56).isActive = true

        let stack = NSStackView(views: [field, label(suffix)])
        stack.orientation = .horizontal
        stack.spacing = 6
        return stack
    }

    private func integerFormatter() -> NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .none
        formatter.minimum = 0
        formatter.maximum = 120
        return formatter
    }

    private func providerStack() -> NSView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 6

        for id in ProviderID.allCases {
            let toggle = NSButton(checkboxWithTitle: id.displayName, target: self, action: #selector(commit))
            toggle.font = .systemFont(ofSize: 12)
            providerToggles[id] = toggle
            stack.addView(toggle, in: .leading)
        }
        return stack
    }

    private func connectionRow(_ id: ProviderID) -> NSView {
        let menu = NSPopUpButton()
        menu.addItems(withTitles: [
            L("자동 — 웹 연결 시 웹 사용", "Automatic — web when connected"),
            L("Chrome 웹만 — 터미널 불필요", "Chrome web only — no terminal"),
            L("로컬 로그인 — 앱 직접 조회", "Local login — direct app query"),
        ])
        menu.font = .systemFont(ofSize: 11)
        menu.target = self
        menu.action = #selector(commit)
        connectionMenus[id] = menu
        return menu
    }

    private func agyRow() -> NSView {
        agyField.placeholderString = AgySource.resolveBinary(override: nil) ?? L("자동 탐색 실패", "Not found automatically")
        agyField.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        agyField.target = self
        agyField.action = #selector(commit)
        agyField.translatesAutoresizingMaskIntoConstraints = false
        agyField.widthAnchor.constraint(equalToConstant: 250).isActive = true
        return agyField
    }

    private func geminiLoginRow() -> NSView {
        let button = NSButton(title: L("Chrome 연결…", "Connect Chrome…"), target: self, action: #selector(openGeminiLogin))
        button.bezelStyle = .rounded
        button.font = .systemFont(ofSize: 12)
        let note = NSTextField(wrappingLabelWithString: L(
            "Claude · GPT · Gemini를 사용하는 Chrome에 확장을 추가하세요.\n"
            + "개발자 모드 → 압축해제된 확장 프로그램 로드 → 열린 폴더 선택.\n"
            + "선택창에서 ⌘⇧G 후 붙여넣으면 복사된 경로로 이동합니다.\n"
            + "확장 팝업에서 Claude·GPT 연결을 켜세요. Gemini는 자동 연결됩니다.\n"
            + "자동: 웹 연결을 켰으면 웹, 아니면 로컬 로그인을 사용합니다.\n"
            + "로컬 조회는 사용량 탭을 열지 않습니다. 로컬만 쓸 때 확장의 해당 웹 연결도 끄세요.\n"
            + "웹과 로컬 앱의 계정은 다를 수 있습니다.",
            "Add the extension to the Chrome you use for Claude, GPT and Gemini.\n"
            + "Developer mode → Load unpacked → select the folder that opened.\n"
            + "In the file dialog, press ⌘⇧G and paste to jump to the copied path.\n"
            + "Turn on Claude and GPT in the extension popup. Gemini connects automatically.\n"
            + "Automatic: uses the web when a web connection is on, otherwise the local login.\n"
            + "Local queries open no usage tabs. For local only, also turn off that web connection in the extension.\n"
            + "Your web and local accounts can differ."))
        note.font = .systemFont(ofSize: 11)
        note.textColor = .secondaryLabelColor
        note.preferredMaxLayoutWidth = 250
        let stack = NSStackView(views: [button, note])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        return stack
    }

    @objc private func openGeminiLogin() {
        GeminiWebSource.shared.presentLogin()
    }

    /// The two language names stay in their own language so either reader can
    /// find theirs regardless of what the interface currently shows.
    private func languageRow() -> NSView {
        languageMenu.addItems(withTitles: [L("시스템 설정 따름", "System default"), "한국어", "English"])
        languageMenu.font = .systemFont(ofSize: 11)
        languageMenu.target = self
        languageMenu.action = #selector(languageChanged)
        return languageMenu
    }

    private func loginRow() -> NSView {
        loginToggle.setButtonType(.switch)
        loginToggle.title = L("로그인 시 자동 실행", "Launch at login")
        loginToggle.font = .systemFont(ofSize: 12)
        loginToggle.target = self
        loginToggle.action = #selector(toggleLoginItem)
        return loginToggle
    }

    // MARK: - Values

    private func loadValues() {
        let prefs = Prefs.shared
        intervalField.stringValue = String(prefs.refreshMinutes)
        agyField.stringValue = prefs.agyPath ?? ""
        loginToggle.state = LoginItem.isEnabled ? .on : .off
        languageMenu.selectItem(at: Self.languageChoices.firstIndex(of: prefs.language) ?? 0)
        for (id, menu) in connectionMenus { menu.selectItem(at: prefs.connectionMode(id)) }
        for (id, toggle) in providerToggles {
            toggle.state = prefs.isVisible(id) ? .on : .off
        }
    }

    @objc private func commit() {
        let prefs = Prefs.shared
        if let minutes = Int(intervalField.stringValue) { prefs.refreshMinutes = minutes }

        let trimmed = agyField.stringValue.trimmingCharacters(in: .whitespaces)
        prefs.agyPath = trimmed.isEmpty ? nil : trimmed

        for (id, toggle) in providerToggles {
            prefs.setVisible(id, toggle.state == .on)
        }

        for (id, menu) in connectionMenus { prefs.setConnectionMode(id, menu.indexOfSelectedItem) }

        // Re-read through the clamping accessors so the fields show what was
        // actually stored rather than what was typed.
        loadValues()
        onChange()
    }

    /// Same order as the popup: follow the system, Korean, English.
    private static let languageChoices: [AppLanguage?] = [nil, .korean, .english]

    @objc private func languageChanged() {
        let index = languageMenu.indexOfSelectedItem
        guard Self.languageChoices.indices.contains(index) else { return }
        let choice = Self.languageChoices[index]
        guard choice != Prefs.shared.language else { return }
        let before = AppLanguage.current
        Prefs.shared.language = choice
        AppLanguage.override = choice
        guard AppLanguage.current != before else { return }
        // Let this control finish its action before the window is replaced.
        DispatchQueue.main.async { [onLanguageChange] in onLanguageChange() }
    }

    @objc private func toggleLoginItem() {
        let enable = loginToggle.state == .on
        do {
            try LoginItem.setEnabled(enable, appPath: Bundle.main.bundlePath)
        } catch {
            loginToggle.state = LoginItem.isEnabled ? .on : .off
            let alert = NSAlert()
            alert.messageText = L("로그인 항목을 변경할 수 없습니다", "Could not change the login item")
            alert.informativeText = error.localizedDescription
            alert.runModal()
        }
    }

    func windowWillClose(_ notification: Notification) {
        commit()
    }
}
