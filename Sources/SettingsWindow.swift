import AppKit

@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    private let window: NSWindow
    private let onChange: () -> Void

    private let intervalField = NSTextField()
    private let agyField = NSTextField()
    private let loginToggle = NSButton()
    private var connectionMenus: [ProviderID: NSPopUpButton] = [:]
    private var providerToggles: [ProviderID: NSButton] = [:]

    init(onChange: @escaping () -> Void) {
        self.onChange = onChange
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 100),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        super.init()

        window.title = "AI 사용량 설정"
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

    // MARK: - Layout

    private func buildContent() -> NSView {
        let grid = NSGridView(views: [
            [label("갱신 주기"), numberRow(intervalField, suffix: "분")],
            [label("표시 항목"), providerStack()],
            [label("Claude 연결"), connectionRow(.claude)],
            [label("Codex 연결"), connectionRow(.codex)],
            [label("agy 경로"), agyRow()],
            [label("웹 연결"), geminiLoginRow()],
            [NSGridCell.emptyContentView, loginRow()],
        ])
        grid.rowSpacing = 12
        grid.columnSpacing = 14
        grid.column(at: 0).xPlacement = .trailing
        for index in 0..<grid.numberOfRows {
            grid.row(at: index).yPlacement = .center
        }

        let footer = NSTextField(wrappingLabelWithString:
            "퍼센트는 '남은 양'입니다. 숫자가 작을수록 한도에 가깝습니다. "
            + "모델 표시는 대표색, 퍼센트 숫자는 항상 흰색입니다. 위 주기는 메뉴바 갱신 간격이며, "
            + "웹 연결은 Chrome 실행 중 5분마다 갱신합니다. GPT 일반 채팅은 정확한 잔여량을 제공받지 못해 — 로 표시합니다.")
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
        menu.addItems(withTitles: ["자동 (연결된 Chrome 우선)", "Chrome 웹만 — 터미널 불필요", "기존 로컬 로그인만"])
        menu.font = .systemFont(ofSize: 11)
        menu.target = self
        menu.action = #selector(commit)
        connectionMenus[id] = menu
        return menu
    }

    private func agyRow() -> NSView {
        agyField.placeholderString = AgySource.resolveBinary(override: nil) ?? "자동 탐색 실패"
        agyField.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        agyField.target = self
        agyField.action = #selector(commit)
        agyField.translatesAutoresizingMaskIntoConstraints = false
        agyField.widthAnchor.constraint(equalToConstant: 250).isActive = true
        return agyField
    }

    private func geminiLoginRow() -> NSView {
        let button = NSButton(title: "Chrome 연결…", target: self, action: #selector(openGeminiLogin))
        button.bezelStyle = .rounded
        button.font = .systemFont(ofSize: 12)
        let note = NSTextField(wrappingLabelWithString:
            "Claude · Codex · Gemini를 사용하는 Chrome에 확장을 추가하세요.\n"
            + "개발자 모드 → 압축해제된 확장 프로그램 로드 → 열린 폴더 선택.\n"
            + "선택창에서 ⌘⇧G 후 붙여넣으면 복사된 경로로 이동합니다.\n"
            + "확장 팝업에서 Claude·Codex 연결을 켜세요. Gemini는 자동 연결됩니다.\n"
            + "웹과 로컬 앱은 로그인 계정이 다를 수 있습니다. 사용할 Chrome 프로필을 확인하세요.")
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

    private func loginRow() -> NSView {
        loginToggle.setButtonType(.switch)
        loginToggle.title = "로그인 시 자동 실행"
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

    @objc private func toggleLoginItem() {
        let enable = loginToggle.state == .on
        do {
            try LoginItem.setEnabled(enable, appPath: Bundle.main.bundlePath)
        } catch {
            loginToggle.state = LoginItem.isEnabled ? .on : .off
            let alert = NSAlert()
            alert.messageText = "로그인 항목을 변경할 수 없습니다"
            alert.informativeText = error.localizedDescription
            alert.runModal()
        }
    }

    func windowWillClose(_ notification: Notification) {
        commit()
    }
}
