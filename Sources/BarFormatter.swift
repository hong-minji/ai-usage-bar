import Foundation

/// Semantic roles for menu bar text. Provider labels keep their brand colour;
/// percentages are rendered in fixed white regardless of severity metadata.
enum SegmentStyle: Equatable {
    case brand(ProviderID)
    case severity(Severity)
    case plain
}

struct BarSegment: Equatable {
    let text: String
    let style: SegmentStyle
}

let barSeparator = " · "

/// Builds the menu bar title. Percentages are **remaining**, so a small number
/// is the alarming one. Hidden providers are skipped entirely; a provider with
/// no reading shows a dash so its absence stays visible.
func barSegments(
    for order: [ProviderID],
    states: [ProviderID: ProviderState],
    warnBelow warn: Double,
    dangerBelow danger: Double,
    now: Date
) -> [BarSegment] {
    var segments: [BarSegment] = []

    for id in order {
        guard let state = states[id] else { continue }
        if !segments.isEmpty {
            segments.append(BarSegment(text: barSeparator, style: .plain))
        }
        segments.append(contentsOf: segment(for: id, state: state, warnBelow: warn, dangerBelow: danger, now: now))
    }

    return segments
}

private func segment(
    for id: ProviderID,
    state: ProviderState,
    warnBelow warn: Double,
    dangerBelow danger: Double,
    now: Date
) -> [BarSegment] {
    let label = BarSegment(text: "\(id.shortLabel) ", style: .brand(id))

    guard let reading = state.reading, let remaining = reading.lowestRemainingPercent else {
        return [label, BarSegment(text: "–", style: .plain)]
    }

    let level = severity(forRemaining: remaining, warnBelow: warn, dangerBelow: danger)
    var segments = [label, BarSegment(text: "\(Int(remaining.rounded()))%", style: .severity(level))]

    switch state {
    case .ok:
        break
    case .stale, .unavailable:
        // Keep the number, but admit it is not current.
        segments.append(BarSegment(
            text: "(\(koreanRelativeAge(from: reading.fetchedAt, to: now)))",
            style: .plain
        ))
    }
    return segments
}

/// Plain-text form of the bar, for tests and diagnostics.
func barPlainText(_ segments: [BarSegment]) -> String {
    segments.map(\.text).joined()
}

/// A 10-cell fuel gauge: filled cells are what is left, not what is spent.
func asciiMeter(remaining: Double, width: Int = 10) -> String {
    let clamped = min(100, max(0, remaining))
    let filled = Int((clamped / 100 * Double(width)).rounded())
    return String(repeating: "█", count: filled) + String(repeating: "░", count: width - filled)
}
