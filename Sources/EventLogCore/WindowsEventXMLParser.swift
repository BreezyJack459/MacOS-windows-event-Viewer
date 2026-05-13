import Foundation

final class WindowsEventXMLParser: NSObject, XMLParserDelegate {
    private var sourceName = ""
    private var entries: [EventLogEntry] = []
    private var currentEvent: XMLAccumulator?
    private var path: [String] = []
    private var textBuffer = ""
    private var parseError: Error?

    func parse(data: Data, sourceName: String) throws -> EventLogDocument {
        self.sourceName = sourceName
        entries = []
        currentEvent = nil
        path = []
        textBuffer = ""
        parseError = nil

        let parser = XMLParser(data: data)
        parser.delegate = self

        guard parser.parse() else {
            throw parser.parserError ?? parseError ?? EventLogParserError.noEventsFound
        }

        guard !entries.isEmpty else {
            throw EventLogParserError.noEventsFound
        }

        return EventLogDocument(
            sourceName: sourceName,
            entries: entries,
            parserNotes: ["Parsed Windows Event XML export."]
        )
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        path.append(elementName)
        textBuffer = ""

        if elementName == "Event" {
            currentEvent = XMLAccumulator()
        }

        guard var event = currentEvent else { return }
        if elementName == "Provider" {
            event.provider = attributeDict["Name"] ?? attributeDict["Guid"]
        } else if elementName == "TimeCreated" {
            event.timestamp = Date(windowsEventTime: attributeDict["SystemTime"])
        } else if elementName == "Data" || elementName == "Binary" {
            let name = attributeDict["Name"] ?? elementName
            event.currentDataName = name
        }
        currentEvent = event
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        textBuffer += string
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        let value = textBuffer.trimmingCharacters(in: .whitespacesAndNewlines)

        guard var event = currentEvent else {
            _ = path.popLast()
            return
        }

        switch elementName {
        case "EventID":
            if !value.isEmpty { event.eventID = value }
        case "Level":
            event.level = EventSeverity(windowsLevel: value)
        case "Channel":
            event.channel = value.nilIfEmpty
        case "Computer":
            event.computer = value.nilIfEmpty
        case "EventRecordID":
            event.recordID = UInt64(value)
        case "Data", "Binary":
            if !value.isEmpty {
                event.data.append((event.currentDataName ?? elementName, value))
            }
            event.currentDataName = nil
        case "Event":
            entries.append(event.makeEntry())
            currentEvent = nil
            _ = path.popLast()
            textBuffer = ""
            return
        default:
            break
        }

        currentEvent = event
        _ = path.popLast()
        textBuffer = ""
    }
}

private struct XMLAccumulator {
    var recordID: UInt64?
    var timestamp: Date?
    var provider: String?
    var eventID: String?
    var level: EventSeverity = .unknown
    var channel: String?
    var computer: String?
    var data: [(String, String)] = []
    var currentDataName: String?

    func makeEntry() -> EventLogEntry {
        let dataText = data
            .map { "\($0.0): \($0.1)" }
            .joined(separator: "\n")

        let summaryParts = [
            provider,
            eventID.map { "Event \($0)" },
            channel
        ].compactMap { $0 }

        return EventLogEntry(
            recordID: recordID,
            timestamp: timestamp,
            provider: provider,
            eventID: eventID,
            level: level,
            channel: channel,
            computer: computer,
            summary: summaryParts.isEmpty ? "Windows Event" : summaryParts.joined(separator: " · "),
            message: dataText.isEmpty ? "This event has no EventData payload." : dataText,
            rawText: dataText,
            sourceOffset: nil
        )
    }
}
