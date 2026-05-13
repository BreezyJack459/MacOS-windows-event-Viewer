import Foundation

public enum EventLogParserError: LocalizedError {
    case unsupportedFileType(String)
    case unreadableData
    case invalidEVTX
    case noEventsFound

    public var errorDescription: String? {
        switch self {
        case .unsupportedFileType(let ext):
            return "Unsupported event log type: \(ext)"
        case .unreadableData:
            return "The selected file could not be read."
        case .invalidEVTX:
            return "The file does not look like a valid Windows EVTX log."
        case .noEventsFound:
            return "No event records were found in the selected file."
        }
    }
}

public struct EventLogParser {
    public init() {}

    public func parse(url: URL) throws -> EventLogDocument {
        guard let data = try? Data(contentsOf: url) else {
            throw EventLogParserError.unreadableData
        }

        let sourceName = url.lastPathComponent
        switch url.pathExtension.lowercased() {
        case "evtx":
            return try EVTXParser().parse(data: data, sourceName: sourceName)
        case "xml":
            return try WindowsEventXMLParser().parse(data: data, sourceName: sourceName)
        case "json", "txt", "log":
            return PlainTextEventParser().parse(data: data, sourceName: sourceName)
        default:
            if data.starts(with: Array("ElfFile".utf8)) {
                return try EVTXParser().parse(data: data, sourceName: sourceName)
            }
            if data.first == UInt8(ascii: "<") {
                return try WindowsEventXMLParser().parse(data: data, sourceName: sourceName)
            }
            throw EventLogParserError.unsupportedFileType(url.pathExtension)
        }
    }
}
