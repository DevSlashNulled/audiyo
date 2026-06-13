#!/usr/bin/env swift
import AppKit
import Foundation

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let appIconURL = root
    .appendingPathComponent("Sources/Audiyo/Assets.xcassets", isDirectory: true)
    .appendingPathComponent("AppIcon.appiconset", isDirectory: true)

try FileManager.default.createDirectory(at: appIconURL, withIntermediateDirectories: true)

let sizes = [16, 32, 128, 256, 512]

func drawIcon(size: Int) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()

    let rect = NSRect(x: 0, y: 0, width: size, height: size)
    NSColor(calibratedRed: 0.05, green: 0.08, blue: 0.12, alpha: 1).setFill()
    NSBezierPath(roundedRect: rect, xRadius: CGFloat(size) * 0.22, yRadius: CGFloat(size) * 0.22).fill()

    let gradient = NSGradient(colors: [
        NSColor(calibratedRed: 0.18, green: 0.56, blue: 0.98, alpha: 1),
        NSColor(calibratedRed: 0.28, green: 0.88, blue: 0.68, alpha: 1)
    ])
    gradient?.draw(in: NSBezierPath(roundedRect: rect.insetBy(dx: CGFloat(size) * 0.08, dy: CGFloat(size) * 0.08), xRadius: CGFloat(size) * 0.18, yRadius: CGFloat(size) * 0.18), angle: 35)

    let stroke = NSBezierPath()
    stroke.lineWidth = max(2, CGFloat(size) * 0.055)
    stroke.lineCapStyle = .round
    stroke.lineJoinStyle = .round
    NSColor.white.withAlphaComponent(0.95).setStroke()

    let centerY = CGFloat(size) * 0.52
    let step = CGFloat(size) * 0.095
    let startX = CGFloat(size) * 0.22
    let points: [CGFloat] = [-0.06, 0.18, -0.24, 0.30, -0.16, 0.08, -0.04]
    stroke.move(to: NSPoint(x: startX, y: centerY))
    for (index, offset) in points.enumerated() {
        stroke.line(to: NSPoint(x: startX + CGFloat(index + 1) * step, y: centerY + offset * CGFloat(size)))
    }
    stroke.stroke()

    let knob = NSBezierPath(ovalIn: NSRect(
        x: CGFloat(size) * 0.66,
        y: CGFloat(size) * 0.63,
        width: CGFloat(size) * 0.13,
        height: CGFloat(size) * 0.13
    ))
    NSColor.white.withAlphaComponent(0.92).setFill()
    knob.fill()

    image.unlockFocus()
    return image
}

func writePNG(_ image: NSImage, to url: URL) throws {
    guard let tiff = image.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let png = rep.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "IconGeneration", code: 1)
    }
    try png.write(to: url)
}

var images: [[String: String]] = []
for size in sizes {
    let oneX = "icon_\(size)x\(size).png"
    try writePNG(drawIcon(size: size), to: appIconURL.appendingPathComponent(oneX))
    images.append(["idiom": "mac", "size": "\(size)x\(size)", "scale": "1x", "filename": oneX])

    let twoX = "icon_\(size)x\(size)@2x.png"
    try writePNG(drawIcon(size: size * 2), to: appIconURL.appendingPathComponent(twoX))
    images.append(["idiom": "mac", "size": "\(size)x\(size)", "scale": "2x", "filename": twoX])
}

let contents: [String: Any] = [
    "images": images,
    "info": ["author": "xcode", "version": 1]
]
let data = try JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys])
try data.write(to: appIconURL.appendingPathComponent("Contents.json"))
