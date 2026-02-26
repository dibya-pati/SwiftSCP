import AppKit
import Foundation

guard CommandLine.arguments.count >= 2 else {
    fputs("Usage: make_icon.swift <output-png-path>\n", stderr)
    exit(1)
}

let outputPath = CommandLine.arguments[1]
let size = 1024.0
let image = NSImage(size: NSSize(width: size, height: size))

image.lockFocus()

let canvas = NSRect(x: 0, y: 0, width: size, height: size)
let corner: CGFloat = 220
let background = NSBezierPath(roundedRect: canvas.insetBy(dx: 28, dy: 28), xRadius: corner, yRadius: corner)
let gradient = NSGradient(colors: [
    NSColor(calibratedRed: 0.05, green: 0.45, blue: 0.88, alpha: 1.0),
    NSColor(calibratedRed: 0.06, green: 0.75, blue: 0.72, alpha: 1.0)
])!
gradient.draw(in: background, angle: 90)

NSColor.white.withAlphaComponent(0.2).setStroke()
background.lineWidth = 18
background.stroke()

let plateRect = NSRect(x: 180, y: 260, width: 664, height: 504)
let plate = NSBezierPath(roundedRect: plateRect, xRadius: 86, yRadius: 86)
NSColor.white.withAlphaComponent(0.2).setFill()
plate.fill()
NSColor.white.withAlphaComponent(0.55).setStroke()
plate.lineWidth = 12
plate.stroke()

let leftArrow = NSBezierPath()
leftArrow.move(to: NSPoint(x: 350, y: 515))
leftArrow.line(to: NSPoint(x: 510, y: 515))
leftArrow.line(to: NSPoint(x: 510, y: 460))
leftArrow.line(to: NSPoint(x: 650, y: 560))
leftArrow.line(to: NSPoint(x: 510, y: 660))
leftArrow.line(to: NSPoint(x: 510, y: 605))
leftArrow.line(to: NSPoint(x: 350, y: 605))
leftArrow.close()

let rightArrow = NSBezierPath()
rightArrow.move(to: NSPoint(x: 674, y: 509))
rightArrow.line(to: NSPoint(x: 514, y: 509))
rightArrow.line(to: NSPoint(x: 514, y: 454))
rightArrow.line(to: NSPoint(x: 374, y: 554))
rightArrow.line(to: NSPoint(x: 514, y: 654))
rightArrow.line(to: NSPoint(x: 514, y: 599))
rightArrow.line(to: NSPoint(x: 674, y: 599))
rightArrow.close()

NSColor.white.withAlphaComponent(0.92).setFill()
leftArrow.fill()
NSColor.white.withAlphaComponent(0.82).setFill()
rightArrow.fill()

image.unlockFocus()

guard
    let tiff = image.tiffRepresentation,
    let bitmap = NSBitmapImageRep(data: tiff),
    let pngData = bitmap.representation(using: .png, properties: [:])
else {
    fputs("Failed to render icon image data\n", stderr)
    exit(1)
}

do {
    try pngData.write(to: URL(fileURLWithPath: outputPath), options: .atomic)
} catch {
    fputs("Failed to write icon PNG: \(error.localizedDescription)\n", stderr)
    exit(1)
}
