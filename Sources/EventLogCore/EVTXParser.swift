import Foundation

struct EVTXParser {
    private let chunkSize = 0x10000
    private let chunkHeaderSize = 0x200
    private let fileHeaderSize = 0x1000

    func parse(data: Data, sourceName: String) throws -> EventLogDocument {
        guard data.starts(with: Array("ElfFile".utf8)) else {
            throw EventLogParserError.invalidEVTX
        }

        var entries: [EventLogEntry] = []
        var notes = [
            "EVTX records are decoded from Binary XML, with string extraction kept as a fallback."
        ]

        var chunkOffset = fileHeaderSize
        while chunkOffset + chunkHeaderSize < data.count {
            let chunkEnd = min(chunkOffset + chunkSize, data.count)
            guard data.hasBytes(Array("ElfChnk".utf8), at: chunkOffset) else {
                chunkOffset += chunkSize
                continue
            }

            var cursor = chunkOffset + chunkHeaderSize
            while cursor + 28 <= chunkEnd {
                guard data.readUInt32LE(at: cursor) == 0x0000_2a2a else {
                    cursor += 8
                    continue
                }

                let size = Int(data.readUInt32LE(at: cursor + 4))
                guard size >= 28, cursor + size <= chunkEnd else {
                    cursor += 8
                    continue
                }

                let trailingSize = Int(data.readUInt32LE(at: cursor + size - 4))
                guard trailingSize == size else {
                    cursor += 8
                    continue
                }

                entries.append(parseRecord(data: data, recordOffset: cursor, size: size, chunkBase: chunkOffset))
                cursor += max(size, 8)
            }

            chunkOffset += chunkSize
        }

        if entries.isEmpty {
            throw EventLogParserError.noEventsFound
        }

        notes.append("Found \(entries.count) EVTX record frame\(entries.count == 1 ? "" : "s").")
        return EventLogDocument(sourceName: sourceName, entries: entries, parserNotes: notes)
    }

    private func parseRecord(data: Data, recordOffset: Int, size: Int, chunkBase: Int) -> EventLogEntry {
        let record = data.subdata(in: recordOffset..<(recordOffset + size))
        let recordID = record.readUInt64LE(at: 8)
        let timestamp = Date(fileTime: record.readUInt64LE(at: 16))

        if let decodedEntry = parseDecodedRecord(
            data: data,
            payloadOffset: recordOffset + 24,
            chunkBase: chunkBase,
            recordID: recordID,
            timestamp: timestamp,
            sourceOffset: recordOffset
        ) {
            return decodedEntry
        }

        let payload = record.dropFirst(min(24, record.count))
        let strings = Array(payload).utf16LEStrings(minimumLength: 3)
        let meaningfulStrings = strings
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .uniqued()

        let provider = inferProvider(from: meaningfulStrings)
        let eventID = inferEventID(from: meaningfulStrings)
        let level = inferSeverity(from: meaningfulStrings)
        let message = meaningfulStrings.prefix(24).joined(separator: "\n")
        let summary = provider ?? meaningfulStrings.first ?? "EVTX record \(recordID)"

        return EventLogEntry(
            recordID: recordID,
            timestamp: timestamp,
            provider: provider,
            eventID: eventID,
            level: level,
            channel: inferChannel(from: meaningfulStrings),
            computer: inferComputer(from: meaningfulStrings),
            summary: summary,
            message: message.isEmpty ? "No readable text strings were found in this record." : message,
            rawText: meaningfulStrings.joined(separator: "\n"),
            sourceOffset: recordOffset
        )
    }

    private func parseDecodedRecord(
        data: Data,
        payloadOffset: Int,
        chunkBase: Int,
        recordID: UInt64,
        timestamp: Date?,
        sourceOffset: Int
    ) -> EventLogEntry? {
        guard let decoded = try? EVTXBinXMLDecoder(data: data, chunkBase: chunkBase).decodeRecordPayload(at: payloadOffset),
              let xmlDocument = try? WindowsEventXMLParser().parse(data: Data(decoded.xml.utf8), sourceName: "event.xml"),
              var entry = xmlDocument.entries.first else {
            return nil
        }

        entry.recordID = entry.recordID ?? recordID
        entry.timestamp = entry.timestamp ?? timestamp
        entry.rawText = decoded.xml
        entry.sourceOffset = sourceOffset

        if entry.message == "This event has no EventData payload.", !decoded.values.isEmpty {
            entry.message = decoded.values.enumerated()
                .map { "Value \($0.offset + 1): \($0.element)" }
                .joined(separator: "\n")
        }

        return entry
    }

    private func inferProvider(from strings: [String]) -> String? {
        strings.first { value in
            value.contains("-") && value.range(of: #"^[A-Za-z0-9_. -]+$"#, options: .regularExpression) != nil
        }
    }

    private func inferEventID(from strings: [String]) -> String? {
        strings.first { value in
            value.range(of: #"^\d{3,6}$"#, options: .regularExpression) != nil
        }
    }

    private func inferChannel(from strings: [String]) -> String? {
        strings.first { value in
            value.contains("/") && value.count <= 80
        }
    }

    private func inferComputer(from strings: [String]) -> String? {
        strings.first { value in
            value.range(of: #"^[A-Za-z0-9][A-Za-z0-9.-]{1,62}$"#, options: .regularExpression) != nil
                && !value.contains("/")
                && !value.contains("\\")
        }
    }

    private func inferSeverity(from strings: [String]) -> EventSeverity {
        let joined = strings.joined(separator: " ").lowercased()
        if joined.contains("critical") { return .critical }
        if joined.contains("audit failure") { return .auditFailure }
        if joined.contains("audit success") { return .auditSuccess }
        if joined.contains("error") || joined.contains("failed") { return .error }
        if joined.contains("warning") { return .warning }
        if joined.contains("verbose") || joined.contains("debug") { return .verbose }
        if joined.contains("information") || joined.contains("info") { return .information }
        return .unknown
    }
}
