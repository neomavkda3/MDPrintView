import Foundation

/// A row in the welcome window's recent / pinned list. Carries enough
/// metadata to render a preview card and filter by search.
struct RecentDocument: Identifiable, Hashable {
    let url: URL
    let modificationDate: Date
    let preview: String

    var id: URL { url }

    /// Filename without the `.md` extension.
    var displayTitle: String {
        url.deletingPathExtension().lastPathComponent
    }

    /// "5m ago", "2d ago", etc. Uses the system-localized short style.
    /// Formatter cached as `static let` — instantiating one per row was
    /// flagged by the architecture audit as a hot allocation, since
    /// `documentCard()` reads this for every visible row.
    // nonisolated(unsafe): Foundation formatters aren't `Sendable`, but
    // RelativeDateTimeFormatter's `localizedString(for:relativeTo:)` is
    // read-only after configuration — no mutable shared state.
    nonisolated(unsafe) private static let relativeFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .short
        return f
    }()

    var relativeDate: String {
        Self.relativeFormatter.localizedString(for: modificationDate, relativeTo: Date())
    }

    func matches(_ query: String) -> Bool {
        if query.isEmpty { return true }
        return url.lastPathComponent.localizedCaseInsensitiveContains(query)
            || preview.localizedCaseInsensitiveContains(query)
    }

    /// Load a doc from disk. Returns nil if the file is missing (URL is
    /// stale from `NSDocumentController.recentDocumentURLs`).
    static func load(from url: URL) -> RecentDocument? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }

        let modDate = (try? url.resourceValues(forKeys: [.contentModificationDateKey])
            .contentModificationDate) ?? Date.distantPast

        // Read only the first ~2KB — enough for a 2-line preview without
        // pulling huge files into memory on every welcome refresh.
        var preview = ""
        if let data = try? Data(contentsOf: url, options: [.mappedIfSafe]) {
            let head = data.prefix(2048)
            if let text = String(data: head, encoding: .utf8) {
                preview = sanitize(text)
            }
        }

        return RecentDocument(url: url, modificationDate: modDate, preview: preview)
    }

    /// Strip basic markdown syntax + YAML frontmatter so the preview reads
    /// as plain prose. Not a real markdown parser — just enough to skip
    /// headings/emphasis markers visually.
    private static func sanitize(_ text: String) -> String {
        var lines = text.components(separatedBy: .newlines)

        // Drop YAML frontmatter if present.
        if let first = lines.first?.trimmingCharacters(in: .whitespaces), first == "---" {
            if let closeIdx = lines.dropFirst().firstIndex(where: { $0.trimmingCharacters(in: .whitespaces) == "---" }) {
                lines = Array(lines[(closeIdx + 1)...])
            }
        }

        // Skip leading blank lines.
        while let first = lines.first, first.trimmingCharacters(in: .whitespaces).isEmpty {
            lines.removeFirst()
        }

        let body = lines.prefix(6).joined(separator: " ")

        var clean = body
        clean = clean.replacingOccurrences(of: "#", with: "")
        clean = clean.replacingOccurrences(of: "**", with: "")
        clean = clean.replacingOccurrences(of: "__", with: "")
        clean = clean.replacingOccurrences(of: "`", with: "")
        // Collapse runs of whitespace.
        clean = clean.replacingOccurrences(
            of: "\\s+",
            with: " ",
            options: .regularExpression
        )
        clean = clean.trimmingCharacters(in: .whitespaces)

        return String(clean.prefix(220))
    }
}

/// Buckets recent docs into headings ("Today", "Yesterday", etc.) the way
/// Grammarly / Notion / Files.app do.
enum DateGroup: Int, CaseIterable {
    case today, yesterday, lastWeek, lastMonth, older

    var label: String {
        switch self {
        case .today:     return "Today"
        case .yesterday: return "Yesterday"
        case .lastWeek:  return "Last 7 Days"
        case .lastMonth: return "Last 30 Days"
        case .older:     return "Older"
        }
    }

    static func group(for date: Date) -> DateGroup {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return .today }
        if cal.isDateInYesterday(date) { return .yesterday }
        let now = Date()
        if let week = cal.date(byAdding: .day, value: -7, to: now), date > week {
            return .lastWeek
        }
        if let month = cal.date(byAdding: .day, value: -30, to: now), date > month {
            return .lastMonth
        }
        return .older
    }
}
