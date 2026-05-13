import EventLogCore
import SwiftUI

struct SidebarView: View {
    @ObservedObject var store: EventLogStore

    var body: some View {
        VStack(spacing: 0) {
            header

            Picker("Severity", selection: severityBinding) {
                Text("All").tag(Optional<EventSeverity>.none)
                ForEach(EventSeverity.allCases, id: \.self) { severity in
                    Text(severity.rawValue).tag(Optional(severity))
                }
            }
            .pickerStyle(.menu)
            .padding([.horizontal, .bottom], 12)

            List(store.filteredEntries, selection: $store.selectedEventID) { entry in
                EventRow(entry: entry)
                    .tag(entry.id)
            }
            .listStyle(.sidebar)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(store.document?.sourceName ?? "No Event Log Open")
                .font(.headline)
                .lineLimit(1)

            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
    }

    private var subtitle: String {
        guard let document = store.document else {
            return "Open a .evtx or Windows Event XML export."
        }

        let visible = store.filteredEntries.count
        let total = document.entries.count
        return visible == total ? "\(total) events" : "\(visible) of \(total) events"
    }

    private var severityBinding: Binding<EventSeverity?> {
        Binding(
            get: { store.severityFilter },
            set: {
                store.severityFilter = $0
                store.selectedEventID = store.filteredEntries.first?.id
            }
        )
    }
}
