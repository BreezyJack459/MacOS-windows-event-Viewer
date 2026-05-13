# Windows Event Log Viewer

Windows Event Log Viewer is a native macOS utility for opening, searching, and reviewing Windows event log files without starting a Windows virtual machine. It is built with SwiftUI and a small parsing library that reads Windows EVTX logs, Windows Event XML exports, and simple text-based log files.

The app is designed for IT support, system administrators, security analysts, and engineers who need to inspect Windows logs from a Mac. Open an event log, filter by severity, search across event fields, and inspect the selected record in a readable detail view.

## Features

- Open Windows `.evtx` files directly on macOS.
- Parse Windows Event XML exports.
- Read plain text, `.log`, and `.json` files as simple event rows.
- Search across provider, event ID, channel, computer, message, record ID, and raw text.
- Filter events by severity, including Critical, Error, Warning, Information, Audit Success, Audit Failure, Verbose, and Unknown.
- View event metadata such as provider, event ID, record ID, channel, computer, timestamp, and source offset.
- Inspect decoded messages, extracted text, raw XML, and parser notes.
- Use a native macOS split-view interface with selectable text for copying investigation details.

## Requirements

- macOS 13 or later
- Xcode command line tools
- Swift 5.9 or later

## Run from Source

Clone or open this repository, then run:

```sh
swift test
./script/build_and_run.sh
```

The build script compiles the Swift package, creates a local `.app` bundle in `dist/`, generates the app icon if needed, and launches the app.

You can also build the Swift package directly:

```sh
swift build --product WinEventLogViewer
```

## Usage

1. Launch Windows Event Log Viewer.
2. Click the toolbar `Open` button or use `Command-O`.
3. Select a Windows event log file, such as `.evtx` or `.xml`.
4. Use the search field to find relevant events.
5. Use the severity menu to narrow the event list.
6. Select an event to view its message, metadata, extracted text, and parser notes.

## Packaging

To create a release app bundle:

```sh
./script/build_and_run.sh --package
```

To create a signed local DMG installer:

```sh
./script/create_dmg.sh
```

The DMG script builds the release app, applies local ad-hoc signing, stages the app with an Applications shortcut, writes Finder layout metadata, and verifies the final disk image.

## Project Structure

```text
Sources/
  EventLogCore/          Core event log models and parsers
  WinEventLogViewer/     SwiftUI macOS app
Tests/
  EventLogCoreTests/     Parser tests
Assets/                  App icon and DMG artwork
script/                  Build, run, icon, and DMG scripts
```

## Supported Input Formats

| Format | Notes |
| --- | --- |
| `.evtx` | Windows Event Log files. Records are decoded from EVTX Binary XML where possible, with readable string extraction as a fallback. |
| `.xml` | Windows Event XML exports. |
| `.txt`, `.log`, `.json` | Parsed as plain text event rows for quick review. |

## Development

Run the test suite with:

```sh
swift test
```

The parser tests cover Windows Event XML field extraction, Windows FILETIME conversion, plain text parsing, and basic EVTX record detection.

## Notes

EVTX is a complex binary format. This app focuses on practical local inspection and keeps extracted raw text or parser notes visible when an event cannot be fully decoded.
