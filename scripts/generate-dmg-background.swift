#!/usr/bin/env swift
import AppKit
import Foundation

guard CommandLine.arguments.count == 2 else {
    FileHandle.standardError.write(Data("usage: generate-dmg-background.swift <output.png>\n".utf8))
    exit(64)
}

let outputURL = URL(fileURLWithPath: CommandLine.arguments[1])
try FileManager.default.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)

let size = NSSize(width: 640, height: 420)
let image = NSImage(size: size)

func drawText(_ text: String, at point: NSPoint, font: NSFont, color: NSColor, alignment: NSTextAlignment = .left) {
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = alignment
    let attrs: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: color,
        .paragraphStyle: paragraph
    ]
    text.draw(at: point, withAttributes: attrs)
}

image.lockFocus()

let rect = NSRect(origin: .zero, size: size)
NSGradient(colors: [
    NSColor(calibratedRed: 0.04, green: 0.07, blue: 0.10, alpha: 1),
    NSColor(calibratedRed: 0.06, green: 0.14, blue: 0.18, alpha: 1)
])?.draw(in: rect, angle: 35)

NSColor(calibratedRed: 0.12, green: 0.55, blue: 0.95, alpha: 0.18).setFill()
NSBezierPath(ovalIn: NSRect(x: 380, y: 230, width: 300, height: 260)).fill()
NSColor(calibratedRed: 0.25, green: 0.90, blue: 0.65, alpha: 0.14).setFill()
NSBezierPath(ovalIn: NSRect(x: -120, y: -80, width: 320, height: 260)).fill()

let card = NSBezierPath(roundedRect: rect.insetBy(dx: 22, dy: 22), xRadius: 24, yRadius: 24)
NSColor.white.withAlphaComponent(0.06).setFill()
card.fill()
NSColor.white.withAlphaComponent(0.12).setStroke()
card.lineWidth = 1
card.stroke()

drawText("Audiyo", at: NSPoint(x: 48, y: 338), font: .systemFont(ofSize: 34, weight: .bold), color: .white)
drawText("Audio routing that stays out of the way.", at: NSPoint(x: 50, y: 312), font: .systemFont(ofSize: 14, weight: .medium), color: NSColor.white.withAlphaComponent(0.72))

let wave = NSBezierPath()
wave.lineWidth = 5
wave.lineCapStyle = .round
wave.lineJoinStyle = .round
NSColor.white.withAlphaComponent(0.82).setStroke()
wave.move(to: NSPoint(x: 220, y: 205))
wave.curve(to: NSPoint(x: 420, y: 205), controlPoint1: NSPoint(x: 280, y: 285), controlPoint2: NSPoint(x: 360, y: 125))
wave.stroke()

let arrow = NSBezierPath()
arrow.lineWidth = 3
arrow.lineCapStyle = .round
NSColor.white.withAlphaComponent(0.65).setStroke()
arrow.move(to: NSPoint(x: 300, y: 188))
arrow.line(to: NSPoint(x: 348, y: 188))
arrow.move(to: NSPoint(x: 334, y: 202))
arrow.line(to: NSPoint(x: 348, y: 188))
arrow.line(to: NSPoint(x: 334, y: 174))
arrow.stroke()

drawText("Drag Audiyo to Applications", at: NSPoint(x: 0, y: 58), font: .systemFont(ofSize: 16, weight: .semibold), color: NSColor.white.withAlphaComponent(0.82), alignment: .center)

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else {
    throw NSError(domain: "DMGBackground", code: 1)
}
try png.write(to: outputURL)
