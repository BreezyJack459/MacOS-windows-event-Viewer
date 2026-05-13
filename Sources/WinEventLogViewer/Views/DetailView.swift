import EventLogCore
import SwiftUI

struct DetailView: View {
    let entry: EventLogEntry?
    let document: EventLogDocument?

    var body: some View {
        Group {
            if let entry {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        EventHeader(entry: entry)
                        MetadataGrid(entry: entry)
                        MessagePanel(title: "Message", text: entry.message)

                        if !entry.rawText.isEmpty, entry.rawText != entry.message {
                            MessagePanel(title: "Extracted Text", text: entry.rawText)
                        }

                        if let document, !document.parserNotes.isEmpty {
                            NotesPanel(notes: document.parserNotes)
                        }
                    }
                    .padding(24)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                EmptyStateView(hasDocument: document != nil)
            }
        }
    }
}

private struct EventHeader: View {
    let entry: EventLogEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(entry.summary)
                .font(.title2.weight(.semibold))
                .textSelection(.enabled)

            HStack(spacing: 10) {
                Text(entry.level.rawValue)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(levelTint.opacity(0.16), in: Capsule())
                    .foregroundStyle(levelTint)

                if let timestamp = entry.timestamp {
                    Text(DateFormatters.long.string(from: timestamp))
                        .foregroundStyle(.secondary)
                }
            }
            .font(.subheadline)
        }
    }

    private var levelTint: Color {
        switch entry.level {
        case .critical, .error, .auditFailure:
            return .red
        case .warning:
            return .orange
        case .information, .auditSuccess:
            return .blue
        case .verbose, .unknown:
            return .secondary
        }
    }
}

private struct MetadataGrid: View {
    let entry: EventLogEntry

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 10) {
            ForEach(rows, id: \.0) { label, value in
                GridRow {
                    Text(label)
                        .foregroundStyle(.secondary)
                    Text(value)
                }
            }
        }
        .textSelection(.enabled)
    }

    private var rows: [(String, String)] {
        [
            ("Provider", entry.provider),
            ("Event ID", entry.eventID),
            ("Record ID", entry.recordID.map(String.init)),
            ("Channel", entry.channel),
            ("Computer", entry.computer),
            ("Source Offset", entry.sourceOffset.map { "0x" + String($0, radix: 16, uppercase: true) })
        ].compactMap { label, value in
            guard let value, !value.isEmpty else { return nil }
            return (label, value)
        }
    }
}

private struct MessagePanel: View {
    let title: String
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            Text(text)
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct NotesPanel: View {
    let notes: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Parser Notes")
                .font(.headline)
            ForEach(notes, id: \.self) { note in
                Text(note)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct EmptyStateView: View {
    let hasDocument: Bool

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: hasDocument ? "line.3.horizontal.decrease.circle" : "doc.text.magnifyingglass")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text(hasDocument ? "No matching events" : "Open a Windows event log")
                .font(.title3)
            Text(hasDocument ? "Adjust the search or severity filter." : "Use File > Open Event Log... or the toolbar button.")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
