import AppKit
import Foundation

let rootURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let iconsetURL = rootURL.appendingPathComponent("Assets/AppIcon.iconset", isDirectory: true)

try? FileManager.default.removeItem(at: iconsetURL)
try FileManager.default.createDirectory(at: iconsetURL, withIntermediateDirectories: true)

let iconFiles: [(name: String, size: CGFloat, scale: CGFloat)] = [
    ("icon_16x16.png", 16, 1),
    ("icon_16x16@2x.png", 16, 2),
    ("icon_32x32.png", 32, 1),
    ("icon_32x32@2x.png", 32, 2),
    ("icon_128x128.png", 128, 1),
    ("icon_128x128@2x.png", 128, 2),
    ("icon_256x256.png", 256, 1),
    ("icon_256x256@2x.png", 256, 2),
    ("icon_512x512.png", 512, 1),
    ("icon_512x512@2x.png", 512, 2)
]

for iconFile in iconFiles {
    let pixelSize = iconFile.size * iconFile.scale
    let image = NSImage(size: NSSize(width: pixelSize, height: pixelSize))
    image.lockFocus()
    drawIcon(in: NSRect(x: 0, y: 0, width: pixelSize, height: pixelSize), scale: pixelSize / 1024)
    image.unlockFocus()

    guard
        let tiff = image.tiffRepresentation,
        let bitmap = NSBitmapImageRep(data: tiff),
        let png = bitmap.representation(using: .png, properties: [:])
    else {
        fatalError("Could not render \(iconFile.name)")
    }

    try png.write(to: iconsetURL.appendingPathComponent(iconFile.name))
}

func drawIcon(in rect: NSRect, scale: CGFloat) {
    let s = scale
    let base = NSBezierPath(roundedRect: rect.insetBy(dx: 36 * s, dy: 36 * s), xRadius: 220 * s, yRadius: 220 * s)
    NSGradient(colors: [
        NSColor(calibratedRed: 0.07, green: 0.16, blue: 0.35, alpha: 1.0),
        NSColor(calibratedRed: 0.02, green: 0.08, blue: 0.18, alpha: 1.0)
    ])?.draw(in: base, angle: -45)

    NSColor(calibratedWhite: 1, alpha: 0.12).setStroke()
    base.lineWidth = 5 * s
    base.stroke()

    drawWindowPanes(scale: s)
    drawLogSheet(scale: s)
    drawMagnifier(scale: s)
    drawAlertDot(scale: s)
}

func drawWindowPanes(scale s: CGFloat) {
    let paneColor = NSColor(calibratedRed: 0.42, green: 0.73, blue: 1.0, alpha: 0.92)
    paneColor.setFill()

    let left = 192 * s
    let top = 608 * s
    let gap = 18 * s
    let pane = CGSize(width: 154 * s, height: 138 * s)

    for row in 0..<2 {
        for column in 0..<2 {
            let x = left + CGFloat(column) * (pane.width + gap)
            let y = top - CGFloat(row) * (pane.height + gap)
            NSBezierPath(
                roundedRect: NSRect(x: x, y: y, width: pane.width, height: pane.height),
                xRadius: 18 * s,
                yRadius: 18 * s
            ).fill()
        }
    }
}

func drawLogSheet(scale s: CGFloat) {
    let sheet = NSBezierPath(
        roundedRect: NSRect(x: 380 * s, y: 222 * s, width: 430 * s, height: 520 * s),
        xRadius: 46 * s,
        yRadius: 46 * s
    )
    NSColor(calibratedRed: 0.94, green: 0.97, blue: 1.0, alpha: 0.97).setFill()
    sheet.fill()

    NSColor(calibratedRed: 0.10, green: 0.20, blue: 0.40, alpha: 0.18).setStroke()
    sheet.lineWidth = 5 * s
    sheet.stroke()

    let lineColors = [
        NSColor(calibratedRed: 0.07, green: 0.16, blue: 0.35, alpha: 0.72),
        NSColor(calibratedRed: 0.07, green: 0.16, blue: 0.35, alpha: 0.50),
        NSColor(calibratedRed: 0.77, green: 0.12, blue: 0.18, alpha: 0.85),
        NSColor(calibratedRed: 0.07, green: 0.16, blue: 0.35, alpha: 0.48),
        NSColor(calibratedRed: 0.07, green: 0.16, blue: 0.35, alpha: 0.42)
    ]

    for index in 0..<5 {
        lineColors[index].setFill()
        let y = (632 - CGFloat(index) * 72) * s
        let width = (index == 2 ? 246 : 300 - CGFloat(index % 2) * 52) * s
        NSBezierPath(
            roundedRect: NSRect(x: 456 * s, y: y, width: width, height: 22 * s),
            xRadius: 11 * s,
            yRadius: 11 * s
        ).fill()
    }

    NSColor(calibratedRed: 0.21, green: 0.57, blue: 0.86, alpha: 0.75).setStroke()
    let graph = NSBezierPath()
    graph.lineWidth = 18 * s
    graph.lineCapStyle = .round
    graph.lineJoinStyle = .round
    graph.move(to: NSPoint(x: 458 * s, y: 330 * s))
    graph.line(to: NSPoint(x: 520 * s, y: 374 * s))
    graph.line(to: NSPoint(x: 590 * s, y: 298 * s))
    graph.line(to: NSPoint(x: 666 * s, y: 404 * s))
    graph.line(to: NSPoint(x: 746 * s, y: 350 * s))
    graph.stroke()
}

func drawMagnifier(scale s: CGFloat) {
    NSColor(calibratedRed: 0.02, green: 0.08, blue: 0.18, alpha: 0.88).setStroke()
    let lens = NSBezierPath(ovalIn: NSRect(x: 634 * s, y: 244 * s, width: 176 * s, height: 176 * s))
    lens.lineWidth = 28 * s
    lens.stroke()

    let handle = NSBezierPath()
    handle.lineWidth = 34 * s
    handle.lineCapStyle = .round
    handle.move(to: NSPoint(x: 772 * s, y: 274 * s))
    handle.line(to: NSPoint(x: 854 * s, y: 192 * s))
    handle.stroke()
}

func drawAlertDot(scale s: CGFloat) {
    NSColor(calibratedRed: 0.90, green: 0.12, blue: 0.17, alpha: 1).setFill()
    NSBezierPath(ovalIn: NSRect(x: 254 * s, y: 228 * s, width: 118 * s, height: 118 * s)).fill()

    NSColor.white.setFill()
    NSBezierPath(
        roundedRect: NSRect(x: 305 * s, y: 278 * s, width: 16 * s, height: 48 * s),
        xRadius: 8 * s,
        yRadius: 8 * s
    ).fill()
    NSBezierPath(ovalIn: NSRect(x: 302 * s, y: 248 * s, width: 22 * s, height: 22 * s)).fill()
}
