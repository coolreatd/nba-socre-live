#!/usr/bin/env swift

import AppKit
import Foundation

struct IconGenerator {
    let outputDirectory: URL

    private let iconEntries: [(name: String, size: CGFloat)] = [
        ("icon_16x16.png", 16),
        ("icon_16x16@2x.png", 32),
        ("icon_32x32.png", 32),
        ("icon_32x32@2x.png", 64),
        ("icon_128x128.png", 128),
        ("icon_128x128@2x.png", 256),
        ("icon_256x256.png", 256),
        ("icon_256x256@2x.png", 512),
        ("icon_512x512.png", 512),
        ("icon_512x512@2x.png", 1024)
    ]

    func generate() throws {
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

        for entry in iconEntries {
            let image = drawIcon(size: entry.size)
            let fileURL = outputDirectory.appendingPathComponent(entry.name)
            try write(image: image, to: fileURL)
        }
    }

    private func drawIcon(size: CGFloat) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size))
        image.lockFocus()

        let rect = NSRect(x: 0, y: 0, width: size, height: size)
        let background = NSBezierPath(roundedRect: rect.insetBy(dx: size * 0.05, dy: size * 0.05), xRadius: size * 0.24, yRadius: size * 0.24)

        let gradient = NSGradient(colors: [
            NSColor(calibratedRed: 0.06, green: 0.10, blue: 0.22, alpha: 1),
            NSColor(calibratedRed: 0.08, green: 0.28, blue: 0.52, alpha: 1)
        ])!
        gradient.draw(in: background, angle: -45)

        NSGraphicsContext.current?.saveGraphicsState()
        background.addClip()

        let glowRect = NSRect(x: size * 0.1, y: size * 0.5, width: size * 0.9, height: size * 0.5)
        let glowPath = NSBezierPath(ovalIn: glowRect)
        NSColor(calibratedRed: 0.22, green: 0.82, blue: 0.62, alpha: 0.24).setFill()
        glowPath.fill()
        NSGraphicsContext.current?.restoreGraphicsState()

        let ballSize = size * 0.56
        let ballRect = NSRect(
            x: (size - ballSize) / 2,
            y: size * 0.2,
            width: ballSize,
            height: ballSize
        )
        let ballPath = NSBezierPath(ovalIn: ballRect)
        let ballGradient = NSGradient(colors: [
            NSColor(calibratedRed: 0.99, green: 0.63, blue: 0.20, alpha: 1),
            NSColor(calibratedRed: 0.88, green: 0.34, blue: 0.09, alpha: 1)
        ])!
        ballGradient.draw(in: ballPath, angle: -90)

        let seamColor = NSColor(calibratedWhite: 0.07, alpha: 0.82)
        seamColor.setStroke()

        let seamWidth = max(2, size * 0.028)

        let verticalSeam = NSBezierPath()
        verticalSeam.lineWidth = seamWidth
        verticalSeam.move(to: NSPoint(x: ballRect.midX, y: ballRect.minY + size * 0.03))
        verticalSeam.curve(to: NSPoint(x: ballRect.midX, y: ballRect.maxY - size * 0.03),
                           controlPoint1: NSPoint(x: ballRect.midX - size * 0.05, y: ballRect.midY - size * 0.12),
                           controlPoint2: NSPoint(x: ballRect.midX + size * 0.05, y: ballRect.midY + size * 0.12))
        verticalSeam.stroke()

        let horizontalSeam = NSBezierPath()
        horizontalSeam.lineWidth = seamWidth
        horizontalSeam.move(to: NSPoint(x: ballRect.minX + size * 0.02, y: ballRect.midY))
        horizontalSeam.curve(to: NSPoint(x: ballRect.maxX - size * 0.02, y: ballRect.midY),
                             controlPoint1: NSPoint(x: ballRect.minX + size * 0.16, y: ballRect.midY + size * 0.06),
                             controlPoint2: NSPoint(x: ballRect.maxX - size * 0.16, y: ballRect.midY - size * 0.06))
        horizontalSeam.stroke()

        let leftArc = NSBezierPath()
        leftArc.lineWidth = seamWidth
        leftArc.move(to: NSPoint(x: ballRect.minX + ballRect.width * 0.22, y: ballRect.minY + ballRect.height * 0.05))
        leftArc.curve(to: NSPoint(x: ballRect.minX + ballRect.width * 0.22, y: ballRect.maxY - ballRect.height * 0.05),
                      controlPoint1: NSPoint(x: ballRect.minX - ballRect.width * 0.10, y: ballRect.midY - ballRect.height * 0.18),
                      controlPoint2: NSPoint(x: ballRect.minX - ballRect.width * 0.10, y: ballRect.midY + ballRect.height * 0.18))
        leftArc.stroke()

        let rightArc = NSBezierPath()
        rightArc.lineWidth = seamWidth
        rightArc.move(to: NSPoint(x: ballRect.maxX - ballRect.width * 0.22, y: ballRect.minY + ballRect.height * 0.05))
        rightArc.curve(to: NSPoint(x: ballRect.maxX - ballRect.width * 0.22, y: ballRect.maxY - ballRect.height * 0.05),
                       controlPoint1: NSPoint(x: ballRect.maxX + ballRect.width * 0.10, y: ballRect.midY - ballRect.height * 0.18),
                       controlPoint2: NSPoint(x: ballRect.maxX + ballRect.width * 0.10, y: ballRect.midY + ballRect.height * 0.18))
        rightArc.stroke()

        let wordmark = NSString(string: "LIVE")
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: size * 0.12, weight: .black),
            .foregroundColor: NSColor.white,
            .paragraphStyle: paragraph,
            .kern: size * 0.02
        ]
        let wordmarkRect = NSRect(x: size * 0.18, y: size * 0.09, width: size * 0.64, height: size * 0.16)
        wordmark.draw(in: wordmarkRect, withAttributes: attributes)

        let accentRect = NSRect(x: size * 0.72, y: size * 0.68, width: size * 0.14, height: size * 0.14)
        let accentPath = NSBezierPath(ovalIn: accentRect)
        NSColor(calibratedRed: 0.22, green: 0.82, blue: 0.62, alpha: 1).setFill()
        accentPath.fill()

        image.unlockFocus()
        return image
    }

    private func write(image: NSImage, to url: URL) throws {
        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let png = bitmap.representation(using: .png, properties: [:]) else {
            throw NSError(domain: "IconGenerator", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to encode PNG"])
        }
        try png.write(to: url)
    }
}

let outputPath = CommandLine.arguments.dropFirst().first ?? "./dist/AppIcon.iconset"
let generator = IconGenerator(outputDirectory: URL(fileURLWithPath: outputPath, isDirectory: true))
try generator.generate()
