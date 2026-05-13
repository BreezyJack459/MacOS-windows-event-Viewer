import Foundation
import XCTest
@testable import EventLogCore

final class EventLogParserTests: XCTestCase {
    func testWindowsEventXMLParserReadsSystemFields() throws {
        let xml = """
        <Events>
          <Event>
            <System>
              <Provider Name="Microsoft-Windows-Security-Auditing"/>
              <EventID>4624</EventID>
              <Level>0</Level>
              <TimeCreated SystemTime="2026-05-13T03:00:00.000Z"/>
              <EventRecordID>123</EventRecordID>
              <Channel>Security</Channel>
              <Computer>WIN-TEST</Computer>
            </System>
            <EventData>
              <Data Name="SubjectUserName">jack</Data>
              <Data Name="LogonType">2</Data>
            </EventData>
          </Event>
        </Events>
        """

        let document = try WindowsEventXMLParser().parse(data: Data(xml.utf8), sourceName: "sample.xml")

        XCTAssertEqual(document.entries.count, 1)
        let entry = try XCTUnwrap(document.entries.first)
        XCTAssertEqual(entry.provider, "Microsoft-Windows-Security-Auditing")
        XCTAssertEqual(entry.eventID, "4624")
        XCTAssertEqual(entry.recordID, 123)
        XCTAssertEqual(entry.channel, "Security")
        XCTAssertEqual(entry.computer, "WIN-TEST")
        XCTAssertTrue(entry.message.contains("SubjectUserName: jack"))
    }

    func testFileTimeConversion() throws {
        let date = try XCTUnwrap(Date(fileTime: 132_539_328_000_000_000))
        XCTAssertEqual(Int(date.timeIntervalSince1970), 1_609_459_200)
    }

    func testPlainTextParserCreatesRows() {
        let document = PlainTextEventParser().parse(
            data: Data("warning first\n\nerror second".utf8),
            sourceName: "events.log"
        )

        XCTAssertEqual(document.entries.count, 2)
        XCTAssertEqual(document.entries[0].level, .warning)
        XCTAssertEqual(document.entries[1].level, .error)
    }

    func testEVTXParserAcceptsNullTerminatedChunkSignature() throws {
        var data = Data(repeating: 0, count: 0x1000 + 0x200 + 28)
        data.replaceSubrange(0..<7, with: Array("ElfFile".utf8))
        data.replaceSubrange(0x1000..<0x1008, with: Array("ElfChnk\0".utf8))

        let recordOffset = 0x1200
        data.writeUInt32LE(0x0000_2a2a, at: recordOffset)
        data.writeUInt32LE(28, at: recordOffset + 4)
        data.writeUInt64LE(42, at: recordOffset + 8)
        data.writeUInt64LE(132_539_328_000_000_000, at: recordOffset + 16)
        data.writeUInt32LE(28, at: recordOffset + 24)

        let document = try EVTXParser().parse(data: data, sourceName: "minimal.evtx")

        XCTAssertEqual(document.entries.count, 1)
        XCTAssertEqual(document.entries.first?.recordID, 42)
    }
}

private extension Data {
    mutating func writeUInt32LE(_ value: UInt32, at offset: Int) {
        replaceSubrange(offset..<offset + 4, with: [
            UInt8(value & 0xff),
            UInt8((value >> 8) & 0xff),
            UInt8((value >> 16) & 0xff),
            UInt8((value >> 24) & 0xff)
        ])
    }

    mutating func writeUInt64LE(_ value: UInt64, at offset: Int) {
        replaceSubrange(offset..<offset + 8, with: (0..<8).map { shift in
            UInt8((value >> UInt64(shift * 8)) & 0xff)
        })
    }
}
