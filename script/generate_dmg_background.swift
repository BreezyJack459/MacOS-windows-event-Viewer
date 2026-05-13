import AppKit
import Foundation

let rootURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let outputURL = rootURL.appendingPathComponent("Assets/DMGBackground.png")
try FileManager.default.createDirectory(
    at: outputURL.deletingLastPathComponent(),
    withIntermediateDirectories: true
)

let size = NSSize(width: 960, height: 540)
let image = NSImage(size: size)
image.lockFocus()

let bounds = NSRect(origin: .zero, size: size)
NSGradient(colors: [
    NSColor(calibratedRed: 0.04, green: 0.10, blue: 0.22, alpha: 1),
    NSColor(calibratedRed: 0.08, green: 0.18, blue: 0.36, alpha: 1)
])?.draw(in: bounds, angle: -22)

drawSoftPanel()
drawLogMotif()
drawArrow()
drawText()

image.unlockFocus()

guard
    let tiff = image.tiffRepresentation,
    let bitmap = NSBitmapImageRep(data: tiff),
    let png = bitmap.representation(using: .png, properties: [:])
else {
    fatalError("Could not render DMG background")
}

try png.write(to: outputURL)

func drawSoftPanel() {
    let panel = NSBezierPath(
        roundedRect: NSRect(x: 46, y: 42, width: 868, height: 456),
        xRadius: 28,
        yRadius: 28
    )
    NSColor(calibratedWhite: 1, alpha: 0.10).setFill()
    panel.fill()
    NSColor(calibratedWhite: 1, alpha: 0.14).setStroke()
    panel.lineWidth = 1
    panel.stroke()

    NSColor(calibratedRed: 0.77, green: 0.12, blue: 0.18, alpha: 0.92).setFill()
    NSBezierPath(roundedRect: NSRect(x: 94, y: 414, width: 104, height: 8), xRadius: 4, yRadius: 4).fill()
}

func drawLogMotif() {
    NSColor(calibratedWhite: 1, alpha: 0.09).setFill()
    for index in 0..<7 {
        let width = CGFloat([250, 180, 220, 150, 260, 200, 170][index])
        let y = 138 + CGFloat(index) * 34
        NSBezierPath(
            roundedRect: NSRect(x: 350, y: y, width: width, height: 10),
            xRadius: 5,
            yRadius: 5
        ).fill()
    }

    NSColor(calibratedRed: 0.37, green: 0.72, blue: 1, alpha: 0.14).setStroke()
    let curve = NSBezierPath()
    curve.lineWidth = 6
    curve.lineCapStyle = .round
    curve.move(to: NSPoint(x: 86, y: 112))
    curve.curve(
        to: NSPoint(x: 878, y: 116),
        controlPoint1: NSPoint(x: 280, y: 196),
        controlPoint2: NSPoint(x: 628, y: 42)
    )
    curve.stroke()
}

func drawArrow() {
    NSColor(calibratedWhite: 1, alpha: 0.72).setStroke()
    let path = NSBezierPath()
    path.lineWidth = 6
    path.lineCapStyle = .round
    path.lineJoinStyle = .round
    path.move(to: NSPoint(x: 382, y: 272))
    path.line(to: NSPoint(x: 578, y: 272))
    path.stroke()

    let head = NSBezierPath()
    head.move(to: NSPoint(x: 578, y: 272))
    head.line(to: NSPoint(x: 552, y: 294))
    head.move(to: NSPoint(x: 578, y: 272))
    head.line(to: NSPoint(x: 552, y: 250))
    head.lineWidth = 6
    head.lineCapStyle = .round
    head.stroke()
}

func drawText() {
    let titleStyle = NSMutableParagraphStyle()
    titleStyle.alignment = .center

    let titleAttributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 32, weight: .semibold),
        .foregroundColor: NSColor.white,
        .paragraphStyle: titleStyle
    ]

    "Windows Event Log Viewer".draw(
        in: NSRect(x: 120, y: 420, width: 720, height: 48),
        withAttributes: titleAttributes
    )

    let captionAttributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 17, weight: .medium),
        .foregroundColor: NSColor(calibratedWhite: 1, alpha: 0.72),
        .paragraphStyle: titleStyle
    ]

    "Drag the app into Applications".draw(
        in: NSRect(x: 120, y: 76, width: 720, height: 32),
        withAttributes: captionAttributes
    )

    let labelStyle = NSMutableParagraphStyle()
    labelStyle.alignment = .center
    let labelAttributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 15, weight: .semibold),
        .foregroundColor: NSColor(calibratedWhite: 1, alpha: 0.78),
        .paragraphStyle: labelStyle
    ]

    "WinEventLogViewer".draw(in: NSRect(x: 126, y: 176, width: 220, height: 28), withAttributes: labelAttributes)
    "Applications".draw(in: NSRect(x: 614, y: 176, width: 220, height: 28), withAttributes: labelAttributes)
}
