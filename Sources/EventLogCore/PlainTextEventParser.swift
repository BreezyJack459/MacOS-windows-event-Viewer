import Foundation

struct PlainTextEventParser {
    func parse(data: Data, sourceName: String) -> EventLogDocument {
        let text = String(data: data, encoding: .utf8)
            ?? String(data: data, encoding: .utf16LittleEndian)
            ?? ""

        let entries = text
            .components(separatedBy: .newlines)
            .enumerated()
            .compactMap { index, line -> EventLogEntry? in
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return nil }

                return EventLogEntry(
                    recordID: UInt64(index + 1),
                    timestamp: nil,
                    provider: nil,
                    eventID: nil,
                    level: inferSeverity(from: trimmed),
                    channel: nil,
                    computer: nil,
                    summary: String(trimmed.prefix(120)),
                    message: trimmed,
                    rawText: trimmed,
                    sourceOffset: nil
                )
            }

        return EventLogDocument(
            sourceName: sourceName,
            entries: entries,
            parserNotes: ["Loaded plain text as one event per non-empty line."]
        )
    }

    private func inferSeverity(from text: String) -> EventSeverity {
        let lowercased = text.lowercased()
        if lowercased.contains("critical") { return .critical }
        if lowercased.contains("error") || lowercased.contains("failed") { return .error }
        if lowercased.contains("warning") { return .warning }
        if lowercased.contains("verbose") || lowercased.contains("debug") { return .verbose }
        if lowercased.contains("information") || lowercased.contains("info") { return .information }
        return .unknown
    }
}
