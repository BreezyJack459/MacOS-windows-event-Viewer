import Foundation

struct EVTXBinXMLDecoder {
    struct DecodedRecord {
        var xml: String
        var values: [String]
    }

    private let data: Data
    private let chunkBase: Int

    init(data: Data, chunkBase: Int) {
        self.data = data
        self.chunkBase = chunkBase
    }

    func decodeRecordPayload(at payloadOffset: Int) throws -> DecodedRecord {
        var cursor = payloadOffset
        if data.byte(at: cursor) == 0x0f {
            cursor += 4
        }

        guard data.byte(at: cursor) == 0x0c else {
            throw EventLogParserError.invalidEVTX
        }

        let templateOffset = Int(data.readUInt32LE(at: cursor + 6))
        let templateAbsoluteOffset = chunkBase + templateOffset
        let residentTemplateLength = templateOffset > cursor - chunkBase
            ? templateLength(at: templateAbsoluteOffset)
            : 0
        let substitutionsOffset = cursor + 10 + residentTemplateLength
        let substitutions = try parseSubstitutions(at: substitutionsOffset)

        var templateCursor = templateAbsoluteOffset + 0x18
        if data.byte(at: templateCursor) == 0x0f {
            templateCursor += 4
        }

        let xml = try parseNodes(from: templateCursor, substitutions: substitutions, stopTokens: [0x00]).text
        return DecodedRecord(xml: xml, values: substitutions.map(\.text))
    }

    private func templateLength(at offset: Int) -> Int {
        0x18 + Int(data.readUInt32LE(at: offset + 20))
    }

    private func parseSubstitutions(at offset: Int) throws -> [VariantValue] {
        var cursor = offset
        let count = Int(data.readUInt32LE(at: cursor))
        cursor += 4

        guard count >= 0, count < 1024 else {
            throw EventLogParserError.invalidEVTX
        }

        var specs: [(length: Int, type: UInt8)] = []
        for _ in 0..<count {
            specs.append((Int(data.readUInt16LE(at: cursor)), data.byte(at: cursor + 2)))
            cursor += 4
        }

        return specs.map { spec in
            defer { cursor += spec.length }
            if spec.type == 0x21,
               let decoded = try? decodeRecordPayload(at: cursor) {
                return VariantValue(
                    type: spec.type,
                    data: data.safeSubdata(in: cursor..<(cursor + spec.length)),
                    overrideText: decoded.xml
                )
            }
            return VariantValue(type: spec.type, data: data.safeSubdata(in: cursor..<(cursor + spec.length)))
        }
    }

    private func parseNodes(from offset: Int, substitutions: [VariantValue], stopTokens: Set<UInt8>) throws -> (text: String, cursor: Int) {
        var cursor = offset
        var output = ""

        while cursor < data.count {
            let token = data.byte(at: cursor)
            if stopTokens.contains(token) {
                return (output, cursor)
            }

            switch token & 0x0f {
            case 0x01:
                let parsed = try parseElement(at: cursor, substitutions: substitutions)
                output += parsed.text
                cursor = parsed.cursor
            case 0x05:
                let parsed = parseInlineValue(at: cursor, substitutions: substitutions)
                output += escapeXMLText(parsed.text)
                cursor = parsed.cursor
            case 0x08:
                output += xmlCharacterReference(data.readUInt16LE(at: cursor + 1))
                cursor += 3
            case 0x09:
                let nameOffset = Int(data.readUInt32LE(at: cursor + 1))
                let name = readName(atChunkOffset: nameOffset).name
                output += name.isEmpty ? "" : "&\(name);"
                cursor += tokenLengthForChunkString(at: cursor, baseLength: 5, stringOffset: nameOffset)
            case 0x0d, 0x0e:
                let parsed = parseSubstitutionForContent(at: cursor, substitutions: substitutions)
                output += parsed.isXML ? parsed.text : escapeXMLText(parsed.text)
                cursor = parsed.cursor
            case 0x0f:
                cursor += 4
            default:
                throw EventLogParserError.invalidEVTX
            }
        }

        return (output, cursor)
    }

    private func parseElement(at offset: Int, substitutions: [VariantValue]) throws -> (text: String, cursor: Int) {
        let token = data.byte(at: offset)
        let flags = token >> 4
        let elementSize = Int(data.readUInt32LE(at: offset + 3))
        let nameOffset = Int(data.readUInt32LE(at: offset + 7))
        let name = readName(atChunkOffset: nameOffset)

        var cursor = offset + 11
        if flags & 0x04 != 0 {
            cursor += 4
        }
        if nameOffset > offset - chunkBase {
            cursor += name.length
        }

        var attributes = ""
        while cursor < data.count, data.byte(at: cursor) & 0x0f == 0x06 {
            let parsed = parseAttribute(at: cursor, substitutions: substitutions)
            attributes += parsed.text
            cursor = parsed.cursor
        }

        let closeToken = data.byte(at: cursor)
        if closeToken == 0x03 {
            return ("<\(name.name)\(attributes)/>", cursor + 1)
        }

        guard closeToken == 0x02 else {
            throw EventLogParserError.invalidEVTX
        }

        let content = try parseNodes(from: cursor + 1, substitutions: substitutions, stopTokens: [0x04])
        let cursorAfterEnd = content.cursor + 1
        let expectedEnd = elementSize > 0 ? offset + 7 + elementSize : cursorAfterEnd
        return ("<\(name.name)\(attributes)>\(content.text)</\(name.name)>", max(cursorAfterEnd, expectedEnd))
    }

    private func parseAttribute(at offset: Int, substitutions: [VariantValue]) -> (text: String, cursor: Int) {
        let nameOffset = Int(data.readUInt32LE(at: offset + 1))
        let name = readName(atChunkOffset: nameOffset)
        let valueOffset = offset + tokenLengthForChunkString(at: offset, baseLength: 5, stringOffset: nameOffset)
        let value = parseInlineValue(at: valueOffset, substitutions: substitutions)
        return (" \(name.name)=\"\(escapeXMLAttribute(value.text))\"", value.cursor)
    }

    private func parseInlineValue(at offset: Int, substitutions: [VariantValue]) -> (text: String, cursor: Int) {
        let token = data.byte(at: offset)

        switch token & 0x0f {
        case 0x05:
            return parseImmediateValue(type: data.byte(at: offset + 1), at: offset + 2)
        case 0x0d, 0x0e:
            return parseSubstitution(at: offset, substitutions: substitutions)
        case 0x08:
            return (xmlCharacterReference(data.readUInt16LE(at: offset + 1)), offset + 3)
        case 0x09:
            let nameOffset = Int(data.readUInt32LE(at: offset + 1))
            let name = readName(atChunkOffset: nameOffset).name
            return (name.isEmpty ? "" : "&\(name);", offset + tokenLengthForChunkString(at: offset, baseLength: 5, stringOffset: nameOffset))
        default:
            return ("", offset + 1)
        }
    }

    private func parseImmediateValue(type: UInt8, at offset: Int) -> (text: String, cursor: Int) {
        switch type {
        case 0x01:
            let charCount = Int(data.readUInt16LE(at: offset))
            let byteLength = charCount * 2
            return (data.utf16String(at: offset + 2, byteLength: byteLength).trimmedNulls, offset + 2 + byteLength)
        case 0x02:
            let length = Int(data.readUInt16LE(at: offset))
            return (data.ansiString(at: offset + 2, byteLength: length).trimmedNulls, offset + 2 + length)
        default:
            let size = fixedValueSize(for: type) ?? 0
            return (VariantValue(type: type, data: data.safeSubdata(in: offset..<(offset + size))).text, offset + size)
        }
    }

    private func parseSubstitution(at offset: Int, substitutions: [VariantValue]) -> (text: String, cursor: Int) {
        let parsed = parseSubstitutionForContent(at: offset, substitutions: substitutions)
        return (parsed.text, parsed.cursor)
    }

    private func parseSubstitutionForContent(at offset: Int, substitutions: [VariantValue]) -> (text: String, cursor: Int, isXML: Bool) {
        let index = Int(data.readUInt16LE(at: offset + 1))
        guard index < substitutions.count else {
            return ("", offset + 4, false)
        }
        let value = substitutions[index]
        return (value.text, offset + 4, value.type == 0x21 && value.overrideText != nil)
    }

    private func readName(atChunkOffset offset: Int) -> (name: String, length: Int) {
        let absolute = chunkBase + offset
        let characterCount = Int(data.readUInt16LE(at: absolute + 6))
        let byteLength = characterCount * 2
        return (data.utf16String(at: absolute + 8, byteLength: byteLength), 8 + byteLength + 2)
    }

    private func tokenLengthForChunkString(at tokenOffset: Int, baseLength: Int, stringOffset: Int) -> Int {
        if stringOffset > tokenOffset - chunkBase {
            return baseLength + readName(atChunkOffset: stringOffset).length
        }
        return baseLength
    }

    private func fixedValueSize(for type: UInt8) -> Int? {
        switch type {
        case 0x00: return 0
        case 0x03, 0x04, 0x0d: return 1
        case 0x05, 0x06: return 2
        case 0x07, 0x08, 0x0b, 0x10, 0x14: return 4
        case 0x09, 0x0a, 0x0c, 0x11, 0x15: return 8
        case 0x0f, 0x12: return 16
        default: return nil
        }
    }
}

private struct VariantValue {
    var type: UInt8
    var data: Data
    var overrideText: String?

    var text: String {
        if let overrideText {
            return overrideText
        }

        switch type {
        case 0x00:
            return ""
        case 0x01:
            return data.utf16String(at: data.startIndex, byteLength: data.count).trimmedNulls
        case 0x02:
            return String(data: data, encoding: .utf8)?.trimmedNulls ?? ""
        case 0x03:
            return String(Int8(bitPattern: data.byte(at: data.startIndex)))
        case 0x04:
            return String(data.byte(at: data.startIndex))
        case 0x05:
            return String(Int16(bitPattern: data.readUInt16LE(at: data.startIndex)))
        case 0x06:
            return String(data.readUInt16LE(at: data.startIndex))
        case 0x07:
            return String(Int32(bitPattern: data.readUInt32LE(at: data.startIndex)))
        case 0x08:
            return String(data.readUInt32LE(at: data.startIndex))
        case 0x09:
            return String(Int64(bitPattern: data.readUInt64LE(at: data.startIndex)))
        case 0x0a:
            return String(data.readUInt64LE(at: data.startIndex))
        case 0x0d:
            return data.byte(at: data.startIndex) == 0 ? "false" : "true"
        case 0x0e:
            return data.map { String(format: "%02x", $0) }.joined()
        case 0x0f:
            return data.guidString(at: data.startIndex) ?? ""
        case 0x11:
            return Date(fileTime: data.readUInt64LE(at: data.startIndex)).map { ISO8601DateFormatter().string(from: $0) } ?? ""
        case 0x13:
            return data.sidString ?? data.map { String(format: "%02x", $0) }.joined()
        case 0x14:
            return "0x" + String(data.readUInt32LE(at: data.startIndex), radix: 16, uppercase: true)
        case 0x15:
            return "0x" + String(data.readUInt64LE(at: data.startIndex), radix: 16, uppercase: true)
        default:
            return data.map { String(format: "%02x", $0) }.joined()
        }
    }
}

private func escapeXMLText(_ value: String) -> String {
    value
        .replacingOccurrences(of: "&", with: "&amp;")
        .replacingOccurrences(of: "<", with: "&lt;")
        .replacingOccurrences(of: ">", with: "&gt;")
}

private func escapeXMLAttribute(_ value: String) -> String {
    escapeXMLText(value)
        .replacingOccurrences(of: "\"", with: "&quot;")
        .replacingOccurrences(of: "'", with: "&apos;")
}

private func xmlCharacterReference(_ scalar: UInt16) -> String {
    switch scalar {
    case 0x09, 0x0a, 0x0d, 0x20...0xd7ff, 0xe000...0xfffd:
        return "&#x\(String(scalar, radix: 16));"
    default:
        return ""
    }
}
