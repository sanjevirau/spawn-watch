#!/usr/bin/env swift
//
// Composites a SpawnWatch screenshot onto a branded gradient background
// with rounded corners + drop shadow + decorative branches.
//
// Run:  swift Scripts/generate-hero.swift [path/to/screenshot.png]
// Out:  Brand/hero.png  (and a Retina @2x variant is the same file)
//
// If no screenshot path is given, defaults to the latest in .context/attachments/.

import AppKit
import Foundation

// MARK: - Inputs

let argv = CommandLine.arguments
let workingDirectory = FileManager.default.currentDirectoryPath
let defaultScreenshot = "\(workingDirectory)/.context/attachments/Screenshot 2026-05-03 at 15.47.30@2x.png"
let inputPath = argv.dropFirst().first ?? defaultScreenshot
let outputPath = "\(workingDirectory)/Brand/hero.png"

guard FileManager.default.fileExists(atPath: inputPath) else {
    fputs("Screenshot not found: \(inputPath)\n", stderr)
    fputs("Pass a path as the first argument: swift Scripts/generate-hero.swift path/to/screenshot.png\n", stderr)
    exit(1)
}

guard let screenshot = NSImage(byReferencingFile: inputPath) else {
    fputs("Could not load screenshot\n", stderr)
    exit(1)
}

let screenshotRep = NSBitmapImageRep(data: try! Data(contentsOf: URL(fileURLWithPath: inputPath)))!
let screenshotW = CGFloat(screenshotRep.pixelsWide)
let screenshotH = CGFloat(screenshotRep.pixelsHigh)

// MARK: - Layout

// Canvas with comfortable padding around the screenshot
let marginX: CGFloat = 220
let marginTop: CGFloat = 200
let marginBottom: CGFloat = 260
let canvasW = screenshotW + marginX * 2
let canvasH = screenshotH + marginTop + marginBottom
let cornerRadius: CGFloat = 28
let shadowOffsetY: CGFloat = -38
let shadowBlur: CGFloat = 80

print("Canvas: \(Int(canvasW)) × \(Int(canvasH))   screenshot: \(Int(screenshotW)) × \(Int(screenshotH))")

// MARK: - Render

guard let canvas = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: Int(canvasW),
    pixelsHigh: Int(canvasH),
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 32
) else {
    fputs("Could not allocate canvas\n", stderr)
    exit(1)
}

NSGraphicsContext.saveGraphicsState()
let nsctx = NSGraphicsContext(bitmapImageRep: canvas)!
NSGraphicsContext.current = nsctx
let ctx = nsctx.cgContext

let cs = CGColorSpaceCreateDeviceRGB()

// 1. Background gradient
let bgColors = [
    CGColor(srgbRed: 0.039, green: 0.145, blue: 0.251, alpha: 1.0), // #0A2540
    CGColor(srgbRed: 0.059, green: 0.106, blue: 0.176, alpha: 1.0), // #0F1B2D
] as CFArray
let bgGradient = CGGradient(colorsSpace: cs, colors: bgColors, locations: [0, 1])!
ctx.drawLinearGradient(
    bgGradient,
    start: CGPoint(x: 0, y: canvasH),
    end: CGPoint(x: canvasW, y: 0),
    options: []
)

// 2. Decorative branches in the corners
func decorate() {
    ctx.saveGState()
    ctx.setLineWidth(4)
    ctx.setLineCap(.round)
    ctx.setStrokeColor(CGColor(srgbRed: 0.039, green: 0.518, blue: 1.0, alpha: 0.10))

    // Top-left fork
    var p = CGMutablePath()
    p.move(to: CGPoint(x: 60, y: canvasH - 80))
    p.addQuadCurve(to: CGPoint(x: 280, y: canvasH - 200), control: CGPoint(x: 200, y: canvasH - 100))
    p.move(to: CGPoint(x: 60, y: canvasH - 80))
    p.addQuadCurve(to: CGPoint(x: 280, y: canvasH - 80),  control: CGPoint(x: 180, y: canvasH - 30))
    p.move(to: CGPoint(x: 60, y: canvasH - 80))
    p.addQuadCurve(to: CGPoint(x: 280, y: canvasH + 40),  control: CGPoint(x: 200, y: canvasH - 30))
    ctx.addPath(p)
    ctx.strokePath()
    // Tiny dots at branch endpoints
    ctx.setFillColor(CGColor(srgbRed: 0.039, green: 0.518, blue: 1.0, alpha: 0.18))
    for c in [CGPoint(x: 280, y: canvasH - 200), CGPoint(x: 280, y: canvasH - 80), CGPoint(x: 280, y: canvasH + 40)] {
        ctx.fillEllipse(in: CGRect(x: c.x - 6, y: c.y - 6, width: 12, height: 12))
    }
    ctx.fillEllipse(in: CGRect(x: 60 - 10, y: canvasH - 80 - 10, width: 20, height: 20))

    // Bottom-right mirrored
    let mx = canvasW - 60
    p = CGMutablePath()
    p.move(to: CGPoint(x: mx, y: 80))
    p.addQuadCurve(to: CGPoint(x: mx - 220, y: 200), control: CGPoint(x: mx - 100, y: 80))
    p.move(to: CGPoint(x: mx, y: 80))
    p.addQuadCurve(to: CGPoint(x: mx - 220, y: 80),  control: CGPoint(x: mx - 100, y: 30))
    p.move(to: CGPoint(x: mx, y: 80))
    p.addQuadCurve(to: CGPoint(x: mx - 220, y: -40),  control: CGPoint(x: mx - 100, y: 0))
    ctx.addPath(p)
    ctx.strokePath()
    ctx.setFillColor(CGColor(srgbRed: 0.039, green: 0.518, blue: 1.0, alpha: 0.18))
    for c in [CGPoint(x: mx - 220, y: 200), CGPoint(x: mx - 220, y: 80), CGPoint(x: mx - 220, y: -40)] {
        ctx.fillEllipse(in: CGRect(x: c.x - 6, y: c.y - 6, width: 12, height: 12))
    }
    ctx.fillEllipse(in: CGRect(x: mx - 10, y: 80 - 10, width: 20, height: 20))

    ctx.restoreGState()
}
decorate()

// 3. Subtle vignette over background to focus attention on the screenshot
let vignetteColors = [
    CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 0),
    CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 0.40),
] as CFArray
let vignetteGradient = CGGradient(colorsSpace: cs, colors: vignetteColors, locations: [0, 1])!
ctx.drawRadialGradient(
    vignetteGradient,
    startCenter: CGPoint(x: canvasW / 2, y: canvasH / 2),
    startRadius: max(canvasW, canvasH) * 0.25,
    endCenter: CGPoint(x: canvasW / 2, y: canvasH / 2),
    endRadius: max(canvasW, canvasH) * 0.78,
    options: []
)

// 4. Screenshot with rounded corners and a heavy soft shadow
let imgRect = CGRect(
    x: marginX,
    y: marginBottom,
    width: screenshotW,
    height: screenshotH
)

ctx.saveGState()
// Cast shadow first by drawing a fill into a clipped path
ctx.setShadow(
    offset: CGSize(width: 0, height: shadowOffsetY),
    blur: shadowBlur,
    color: CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 0.55)
)
let imgPath = CGPath(
    roundedRect: imgRect,
    cornerWidth: cornerRadius,
    cornerHeight: cornerRadius,
    transform: nil
)
ctx.setFillColor(CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 1))
ctx.addPath(imgPath)
ctx.fillPath()
ctx.restoreGState()

// Now draw the screenshot, clipped to the same rounded rect
ctx.saveGState()
ctx.addPath(imgPath)
ctx.clip()
let cgImage = screenshotRep.cgImage
if let cg = cgImage {
    ctx.draw(cg, in: imgRect)
}
ctx.restoreGState()

// 5. Subtle bezel / inner stroke
ctx.saveGState()
ctx.setStrokeColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.06))
ctx.setLineWidth(1.5)
ctx.addPath(imgPath)
ctx.strokePath()
ctx.restoreGState()

NSGraphicsContext.restoreGraphicsState()

// MARK: - Save

guard let pngData = canvas.representation(using: .png, properties: [.compressionFactor: 0.95]) else {
    fputs("PNG encode failed\n", stderr)
    exit(1)
}

let outURL = URL(fileURLWithPath: outputPath)
try? FileManager.default.createDirectory(at: outURL.deletingLastPathComponent(), withIntermediateDirectories: true)
do {
    try pngData.write(to: outURL)
    print("Wrote \(outURL.path)  (\(pngData.count / 1024) KB)")
} catch {
    fputs("Could not write \(outURL.path): \(error)\n", stderr)
    exit(1)
}
