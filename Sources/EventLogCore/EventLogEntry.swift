import Foundation

public enum EventSeverity: String, CaseIterable, Codable, Hashable {
    case critical = "🚨 Critical"
    case error = "❌ Error"
    case warning = "⚠️ Warning"
    case information = "ℹ️ Information"
    case auditSuccess = "✅ Audit Success"
    case auditFailure = "🚫 Audit Failure"
    case verbose = "💬 Verbose"
    case unknown = "❓ Unknown"
}

public struct EventLogEntry: Identifiable, Codable, Hashable {
    public let id: UUID
    public var recordID: UInt64?
    public var timestamp: Date?
    public var provider: String?
    public var eventID: String?
    public var level: EventSeverity
    public var channel: String?
    public var computer: String?
    public var summary: String
    public var message: String
    public var rawText: String
    public var sourceOffset: Int?

    public init(
        id: UUID = UUID(),
        recordID: UInt64?,
        timestamp: Date?,
        provider: String?,
        eventID: String?,
        level: EventSeverity,
        channel: String?,
        computer: String?,
        summary: String,
        message: String,
        rawText: String,
        sourceOffset: Int?
    ) {
        self.id = id
        self.recordID = recordID
        self.timestamp = timestamp
        self.provider = provider
        self.eventID = eventID
        self.level = level
        self.channel = channel
        self.computer = computer
        self.summary = summary
        self.message = message
        self.rawText = rawText
        self.sourceOffset = sourceOffset
    }
}

public struct EventLogDocument: Codable, Hashable {
    public var sourceName: String
    public var entries: [EventLogEntry]
    public var parserNotes: [String]

    public init(sourceName: String, entries: [EventLogEntry], parserNotes: [String] = []) {
        self.sourceName = sourceName
        self.entries = entries
        self.parserNotes = parserNotes
    }
}
