import Foundation

extension Data {
    func readUInt16LE(at offset: Int) -> UInt16 {
        guard offset >= 0, offset + 2 <= count else { return 0 }
        return UInt16(self[offset]) | UInt16(self[offset + 1]) << 8
    }

    func readUInt32LE(at offset: Int) -> UInt32 {
        guard offset >= 0, offset + 4 <= count else { return 0 }
        return self[offset..<offset + 4].enumerated().reduce(UInt32(0)) { value, pair in
            value | UInt32(pair.element) << UInt32(pair.offset * 8)
        }
    }

    func readUInt64LE(at offset: Int) -> UInt64 {
        guard offset >= 0, offset + 8 <= count else { return 0 }
        return self[offset..<offset + 8].enumerated().reduce(UInt64(0)) { value, pair in
            value | UInt64(pair.element) << UInt64(pair.offset * 8)
        }
    }

    func starts(with bytes: [UInt8]) -> Bool {
        guard count >= bytes.count else { return false }
        return self[startIndex..<index(startIndex, offsetBy: bytes.count)].elementsEqual(bytes)
    }

    func hasBytes(_ bytes: [UInt8], at offset: Int) -> Bool {
        guard offset >= 0, offset + bytes.count <= count else { return false }
        return self[offset..<offset + bytes.count].elementsEqual(bytes)
    }

    func byte(at offset: Int) -> UInt8 {
        guard offset >= 0, offset < count else { return 0 }
        return self[offset]
    }

    func safeSubdata(in range: Range<Int>) -> Data {
        let lowerBound = Swift.max(0, Swift.min(count, range.lowerBound))
        let upperBound = Swift.max(lowerBound, Swift.min(count, range.upperBound))
        return subdata(in: lowerBound..<upperBound)
    }

    func utf16String(at offset: Int, byteLength: Int) -> String {
        guard byteLength > 0 else { return "" }
        return String(data: safeSubdata(in: offset..<(offset + byteLength)), encoding: .utf16LittleEndian) ?? ""
    }

    func ansiString(at offset: Int, byteLength: Int) -> String {
        guard byteLength > 0 else { return "" }
        let bytes = safeSubdata(in: offset..<(offset + byteLength))
        return String(data: bytes, encoding: .utf8)
            ?? String(data: bytes, encoding: .isoLatin1)
            ?? ""
    }

    func guidString(at offset: Int) -> String? {
        guard offset >= 0, offset + 16 <= count else { return nil }

        let d1 = readUInt32LE(at: offset)
        let d2 = readUInt16LE(at: offset + 4)
        let d3 = readUInt16LE(at: offset + 6)
        let d4 = self[offset + 8..<offset + 16].map { String(format: "%02x", $0) }

        return String(
            format: "%08x-%04x-%04x-%@-%@",
            d1,
            d2,
            d3,
            d4[0...1].joined(),
            d4[2...7].joined()
        )
    }

    var sidString: String? {
        guard count >= 8 else { return nil }
        let revision = byte(at: 0)
        let subAuthorityCount = Int(byte(at: 1))
        guard count >= 8 + subAuthorityCount * 4 else { return nil }

        let identifierAuthority = self[2..<8].reduce(UInt64(0)) { ($0 << 8) | UInt64($1) }
        var parts = ["S", String(revision), String(identifierAuthority)]

        for index in 0..<subAuthorityCount {
            parts.append(String(readUInt32LE(at: 8 + index * 4)))
        }

        return parts.joined(separator: "-")
    }
}

extension Array where Element == UInt8 {
    func utf16LEStrings(minimumLength: Int) -> [String] {
        var strings: [String] = []
        var scalars: [UInt16] = []

        func flush() {
            guard scalars.count >= minimumLength else {
                scalars.removeAll(keepingCapacity: true)
                return
            }

            let data = scalars.withUnsafeBufferPointer { buffer in
                Data(buffer: buffer)
            }

            if let string = String(data: data, encoding: .utf16LittleEndian) {
                strings.append(string)
            }
            scalars.removeAll(keepingCapacity: true)
        }

        var index = 0
        while index + 1 < count {
            let scalar = UInt16(self[index]) | UInt16(self[index + 1]) << 8
            if scalar >= 0x20, scalar != 0x7f, scalar < 0xd800 || scalar > 0xdfff {
                scalars.append(scalar)
            } else {
                flush()
            }
            index += 2
        }

        flush()
        return strings
    }
}

extension Sequence where Element: Hashable {
    func uniqued() -> [Element] {
        var seen: Set<Element> = []
        return filter { seen.insert($0).inserted }
    }
}

extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }

    var trimmedNulls: String {
        trimmingCharacters(in: CharacterSet(charactersIn: "\u{0}"))
    }
}

extension Date {
    init?(fileTime: UInt64) {
        guard fileTime > 0 else { return nil }
        let secondsFrom1601 = TimeInterval(fileTime) / 10_000_000
        let secondsBetween1601And1970: TimeInterval = 11_644_473_600
        self.init(timeIntervalSince1970: secondsFrom1601 - secondsBetween1601And1970)
    }

    init?(windowsEventTime: String?) {
        guard let value = windowsEventTime, !value.isEmpty else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: value) {
            self = date
            return
        }

        formatter.formatOptions = [.withInternetDateTime]
        guard let date = formatter.date(from: value) else { return nil }
        self = date
    }
}

extension EventSeverity {
    init(windowsLevel: String) {
        switch windowsLevel.trimmingCharacters(in: .whitespacesAndNewlines) {
        case "1": self = .critical
        case "2": self = .error
        case "3": self = .warning
        case "4", "0": self = .information
        case "5": self = .verbose
        default: self = .unknown
        }
    }
}
