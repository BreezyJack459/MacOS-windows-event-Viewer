import EventLogCore
import Foundation

@MainActor
final class EventLogStore: ObservableObject {
    @Published var document: EventLogDocument?
    @Published var selectedEventID: EventLogEntry.ID?
    @Published var query = ""
    @Published var severityFilter: EventSeverity?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showImporter = false

    private let parser = EventLogParser()

    var filteredEntries: [EventLogEntry] {
        guard let entries = document?.entries else { return [] }

        return entries.filter { entry in
            let matchesSeverity = severityFilter == nil || entry.level == severityFilter
            let matchesQuery = query.isEmpty || entry.searchableText.localizedCaseInsensitiveContains(query)
            return matchesSeverity && matchesQuery
        }
    }

    var selectedEntry: EventLogEntry? {
        guard let selectedEventID else { return filteredEntries.first }
        return filteredEntries.first { $0.id == selectedEventID }
    }

    func load(url: URL) {
        isLoading = true
        errorMessage = nil

        Task {
            let didStartAccessing = url.startAccessingSecurityScopedResource()
            defer {
                if didStartAccessing {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            do {
                let parsed = try parser.parse(url: url)
                await MainActor.run {
                    document = parsed
                    selectedEventID = parsed.entries.first?.id
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }
}

private extension EventLogEntry {
    var searchableText: String {
        [
            recordID.map(String.init),
            provider,
            eventID,
            level.rawValue,
            channel,
            computer,
            summary,
            message,
            rawText
        ]
        .compactMap { $0 }
        .joined(separator: " ")
    }
}
