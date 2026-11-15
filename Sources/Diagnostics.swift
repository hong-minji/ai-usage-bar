import Foundation

/// `AIUsageBar --once` prints what the menu bar and dropdown would show, then
/// exits. Lets the whole data path be checked from a terminal without a GUI.
@MainActor
enum Diagnostics {
    static func runOnce() -> Never {
        let coordinator = UsageCoordinator()
        var finished = false

        Task {
            await coordinator.refresh()
            report(coordinator)
            finished = true
        }

        // Pump the run loop so the main-actor task above can make progress.
        let deadline = Date().addingTimeInterval(90)
        while !finished && Date() < deadline {
            RunLoop.main.run(mode: .default, before: Date().addingTimeInterval(0.1))
        }
        if !finished {
            print(L("시간 초과", "Timed out"))
            exit(1)
        }
        exit(0)
    }

    private static func report(_ coordinator: UsageCoordinator) {
        let prefs = Prefs.shared
        let now = Date()
        let segments = barSegments(
            for: prefs.visibleProviders,
            states: coordinator.states,
            warnBelow: prefs.warnRemaining,
            dangerBelow: prefs.dangerRemaining,
            now: now
        )

        print("\(L("메뉴바", "Menu bar")):  \(barPlainText(segments))")
        print(String(repeating: "─", count: 52))

        for id in prefs.visibleProviders {
            guard let state = coordinator.states[id] else {
                print("\(id.displayName): \(L("상태 없음", "no state"))")
                continue
            }

            var header = id.displayName
            if let plan = state.reading?.planLabel { header += "  \(plan)" }
            print(header)

            for window in state.reading?.windows ?? [] {
                print(windowRowText(window, now: now))
            }

            if let reason = state.failureReason {
                print("  ⚠︎ \(reason)")
            }
        }

        print(String(repeating: "─", count: 52))
        let hidden = ProviderID.allCases.filter { !prefs.isVisible($0) }
        if !hidden.isEmpty {
            print("\(L("숨김", "Hidden")): \(hidden.map(\.displayName).joined(separator: ", "))")
        }
    }
}
