#!/usr/bin/env swift
//
//  Generates SpawnWatch's AppIcon.icns by drawing the brand mark with CoreGraphics
//  at every required size, then bundling via /usr/bin/iconutil.
//
//  Run:  swift Scripts/generate-icon.swift
//  Out:  build/Brand/AppIcon.icns
//
//  The drawing here mirrors Brand/AppIcon.svg one-to-one. If you change the SVG,
//  update this file (or vice-versa) and re-run the script.

import AppKit
import CoreGraphics
import Foundation

// MARK: - Drawing

func drawIcon(in ctx: CGContext, size pixels: CGFloat) {
    let s = pixels
    let scale = s / 1024.0
    let cs = CGColorSpaceCreateDeviceRGB()

    // Helpers: SVG uses y-down origin top-left; CG uses y-up origin bottom-left.
    func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
        CGPoint(x: x * scale, y: (1024 - y) * scale)
    }
    func len(_ v: CGFloat) -> CGFloat { v * scale }

    // 1. Squircle background with linear gradient
    let cornerRadius = s * 0.2265
    let bgRect = CGRect(x: 0, y: 0, width: s, height: s)
    let bgPath = CGPath(
        roundedRect: bgRect,
        cornerWidth: cornerRadius,
        cornerHeight: cornerRadius,
        transform: nil
    )

    ctx.saveGState()
    ctx.addPath(bgPath)
    ctx.clip()

    let bgColors = [
        CGColor(srgbRed: 0.039, green: 0.518, blue: 1.000, alpha: 1.0),  // #0A84FF
        CGColor(srgbRed: 0.000, green: 0.251, blue: 0.788, alpha: 1.0),  // #0040C9
    ] as CFArray
    let bgGradient = CGGradient(colorsSpace: cs, colors: bgColors, locations: [0, 1])!
    ctx.drawLinearGradient(
        bgGradient,
        start: CGPoint(x: 0, y: s),
        end: CGPoint(x: s, y: 0),
        options: []
    )

    // 2. Top-left highlight (radial)
    let hiliteColors = [
        CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.20),
        CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.0),
    ] as CFArray
    let hiliteGradient = CGGradient(colorsSpace: cs, colors: hiliteColors, locations: [0, 1])!
    ctx.drawRadialGradient(
        hiliteGradient,
        startCenter: pt(225, 225), startRadius: 0,
        endCenter: pt(225, 225), endRadius: len(563),
        options: []
    )

    // 3. Soft glow around focal child
    let glowColors = [
        CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.55),
        CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.10),
        CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.0),
    ] as CFArray
    let glowGradient = CGGradient(colorsSpace: cs, colors: glowColors, locations: [0, 0.65, 1])!
    ctx.drawRadialGradient(
        glowGradient,
        startCenter: pt(720, 512), startRadius: 0,
        endCenter: pt(720, 512), endRadius: len(180),
        options: []
    )

    // 4. Three branches
    func stroke(path: CGPath, alpha: CGFloat, width: CGFloat) {
        ctx.setStrokeColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: alpha))
        ctx.setLineWidth(width)
        ctx.setLineCap(.round)
        ctx.addPath(path)
        ctx.strokePath()
    }

    let branchWidth = len(22)

    let topPath = CGMutablePath()
    topPath.move(to: pt(380, 512))
    topPath.addQuadCurve(to: pt(700, 260), control: pt(540, 380))
    stroke(path: topPath, alpha: 0.55, width: branchWidth)

    let midPath = CGMutablePath()
    midPath.move(to: pt(380, 512))
    midPath.addLine(to: pt(700, 512))
    stroke(path: midPath, alpha: 0.95, width: branchWidth)

    let botPath = CGMutablePath()
    botPath.move(to: pt(380, 512))
    botPath.addQuadCurve(to: pt(700, 764), control: pt(540, 644))
    stroke(path: botPath, alpha: 0.35, width: branchWidth)

    // 5. Helper to fill solid white circles with alpha
    func dot(cx: CGFloat, cy: CGFloat, r: CGFloat, alpha: CGFloat) {
        ctx.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: alpha))
        let center = pt(cx, cy)
        let radius = len(r)
        let rect = CGRect(
            x: center.x - radius, y: center.y - radius,
            width: 2 * radius, height: 2 * radius
        )
        ctx.fillEllipse(in: rect)
    }

    // 6. Parent process
    dot(cx: 300, cy: 512, r: 84, alpha: 1.0)

    // 7. Pulse ring around focal child
    do {
        ctx.setStrokeColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.35))
        ctx.setLineWidth(len(5))
        let center = pt(720, 512)
        let radius = len(92)
        let rect = CGRect(
            x: center.x - radius, y: center.y - radius,
            width: 2 * radius, height: 2 * radius
        )
        ctx.strokeEllipse(in: rect)
    }

    // 8. Three children at varying opacity (life states)
    dot(cx: 720, cy: 260, r: 52, alpha: 0.65)  // exited
    dot(cx: 720, cy: 512, r: 64, alpha: 1.00)  // alive
    dot(cx: 720, cy: 764, r: 44, alpha: 0.45)  // killed

    // 9. Live-status accent
    do {
        ctx.setFillColor(CGColor(srgbRed: 0.204, green: 0.780, blue: 0.349, alpha: 1.0))  // #34C759
        let center = pt(754, 478)
        let radius = len(14)
        let rect = CGRect(
            x: center.x - radius, y: center.y - radius,
            width: 2 * radius, height: 2 * radius
        )
        ctx.fillEllipse(in: rect)
    }

    ctx.restoreGState()
}

// MARK: - PNG export

func renderPNG(size: Int) -> Data {
    let pixels = size
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixels,
        pixelsHigh: pixels,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 32
    ) else {
        fatalError("Could not allocate bitmap rep at \(size)x\(size)")
    }

    NSGraphicsContext.saveGraphicsState()
    let gctx = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.current = gctx
    let cgctx = gctx.cgContext

    drawIcon(in: cgctx, size: CGFloat(pixels))

    NSGraphicsContext.restoreGraphicsState()

    guard let data = rep.representation(using: .png, properties: [:]) else {
        fatalError("PNG encode failed at \(size)x\(size)")
    }
    return data
}

// MARK: - Driver

let argv = CommandLine.arguments
let workingDirectory = FileManager.default.currentDirectoryPath
let outDir = (argv.dropFirst().first.map { ($0 as NSString).expandingTildeInPath })
    ?? (workingDirectory + "/build/Brand")

let iconsetURL = URL(fileURLWithPath: outDir).appendingPathComponent("AppIcon.iconset")
let icnsURL = URL(fileURLWithPath: outDir).appendingPathComponent("AppIcon.icns")
let standalonePNG = URL(fileURLWithPath: outDir).appendingPathComponent("AppIcon-1024.png")

try? FileManager.default.removeItem(at: iconsetURL)
try FileManager.default.createDirectory(at: iconsetURL, withIntermediateDirectories: true)

struct IconConfig {
    let size: Int
    let filename: String
}

let configs: [IconConfig] = [
    IconConfig(size: 16,   filename: "icon_16x16.png"),
    IconConfig(size: 32,   filename: "icon_16x16@2x.png"),
    IconConfig(size: 32,   filename: "icon_32x32.png"),
    IconConfig(size: 64,   filename: "icon_32x32@2x.png"),
    IconConfig(size: 128,  filename: "icon_128x128.png"),
    IconConfig(size: 256,  filename: "icon_128x128@2x.png"),
    IconConfig(size: 256,  filename: "icon_256x256.png"),
    IconConfig(size: 512,  filename: "icon_256x256@2x.png"),
    IconConfig(size: 512,  filename: "icon_512x512.png"),
    IconConfig(size: 1024, filename: "icon_512x512@2x.png"),
]

print("==> Rendering \(configs.count) PNGs natively at each size…")

for cfg in configs {
    let data = renderPNG(size: cfg.size)
    let fileURL = iconsetURL.appendingPathComponent(cfg.filename)
    try data.write(to: fileURL)
}

// Also write a stand-alone 1024 PNG for previews / docs
try renderPNG(size: 1024).write(to: standalonePNG)
print("    wrote \(standalonePNG.path)")

// Bundle into .icns
print("==> iconutil → \(icnsURL.path)")
let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", "-o", icnsURL.path, iconsetURL.path]
let stderr = Pipe()
process.standardError = stderr
try process.run()
process.waitUntilExit()

if process.terminationStatus != 0 {
    let err = String(data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    fputs("iconutil failed (\(process.terminationStatus)): \(err)\n", stderr_native())
    exit(Int32(process.terminationStatus))
}

print("\nBuilt \(icnsURL.path)")

func stderr_native() -> UnsafeMutablePointer<FILE> { Darwin.stderr }
