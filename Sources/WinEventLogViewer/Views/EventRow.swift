import EventLogCore
import SwiftUI

struct EventRow: View {
    let entry: EventLogEntry

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: iconName)
                .foregroundStyle(tint)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .lineLimit(1)

                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .help(entry.summary)
    }

    private var title: String {
        if let provider = entry.provider, let eventID = entry.eventID {
            return "\(provider) · \(eventID)"
        }
        return entry.provider ?? entry.summary
    }

    private var detail: String {
        [
            entry.timestamp.map(DateFormatters.short.string(from:)),
            entry.level == .unknown ? nil : entry.level.rawValue,
            entry.channel,
            entry.recordID.map { "#\($0)" }
        ]
        .compactMap { $0 }
        .joined(separator: " · ")
    }

    private var iconName: String {
        switch entry.level {
        case .critical, .error, .auditFailure:
            return "xmark.octagon.fill"
        case .warning:
            return "exclamationmark.triangle.fill"
        case .information, .auditSuccess:
            return "info.circle"
        case .verbose:
            return "ellipsis.circle"
        case .unknown:
            return "circle"
        }
    }

    private var tint: Color {
        switch entry.level {
        case .critical, .error, .auditFailure:
            return .red
        case .warning:
            return .orange
        case .information, .auditSuccess:
            return .blue
        case .verbose:
            return .secondary
        case .unknown:
            return .secondary
        }
    }
}
