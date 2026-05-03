#!/usr/bin/env swift
//
// Renders the SpawnWatch social-preview card programmatically via CoreGraphics
// at exact 1280 × 640 (GitHub social preview spec). Mirrors Brand/social-card.svg.
//
// Run:  swift Scripts/generate-social.swift [outputPath]
// Default output:  Brand/social-card.png

import AppKit
import CoreGraphics
import Foundation

let argv = CommandLine.arguments
let workingDirectory = FileManager.default.currentDirectoryPath
let outputPath = argv.dropFirst().first
    ?? "\(workingDirectory)/Brand/social-card.png"

let canvasW: CGFloat = 1280
let canvasH: CGFloat = 640

// MARK: - Drawing

func drawSocial(in ctx: CGContext) {
    let cs = CGColorSpaceCreateDeviceRGB()

    // Coordinate helper: SVG y-down → CG y-up
    func cgY(_ svgY: CGFloat) -> CGFloat { canvasH - svgY }
    func pt(_ x: CGFloat, _ svgY: CGFloat) -> CGPoint {
        CGPoint(x: x, y: cgY(svgY))
    }

    // 1. Dark background
    let bgColors = [
        CGColor(srgbRed: 0.039, green: 0.145, blue: 0.251, alpha: 1.0), // #0A2540
        CGColor(srgbRed: 0.059, green: 0.106, blue: 0.176, alpha: 1.0), // #0F1B2D
    ] as CFArray
    let bgGradient = CGGradient(colorsSpace: cs, colors: bgColors, locations: [0, 1])!
    ctx.drawLinearGradient(
        bgGradient,
        start: CGPoint(x: 0, y: canvasH),
        end: CGPoint(x: 0, y: 0),
        options: []
    )

    // 2. Decorative faded branches (right side)
    ctx.saveGState()
    ctx.setLineWidth(3)
    ctx.setLineCap(.round)
    ctx.setStrokeColor(CGColor(srgbRed: 0.039, green: 0.518, blue: 1.0, alpha: 0.07))
    let branchPaths: [(CGPoint, CGPoint, CGPoint)] = [
        (CGPoint(x: 100,  y: 100), CGPoint(x: 250,  y: 250), CGPoint(x: 400, y: 200)),
        (CGPoint(x: 100,  y: 100), CGPoint(x: 250,  y: 100), CGPoint(x: 400, y: 100)),
        (CGPoint(x: 100,  y: 540), CGPoint(x: 250,  y: 400), CGPoint(x: 400, y: 460)),
        (CGPoint(x: 1100, y: 540), CGPoint(x: 950,  y: 400), CGPoint(x: 800, y: 460)),
        (CGPoint(x: 1180, y: 100), CGPoint(x: 1030, y: 250), CGPoint(x: 880, y: 200)),
    ]
    for (start, control, end) in branchPaths {
        let p = CGMutablePath()
        p.move(to: pt(start.x, start.y))
        p.addQuadCurve(to: pt(end.x, end.y), control: pt(control.x, control.y))
        ctx.addPath(p)
        ctx.strokePath()
    }
    ctx.restoreGState()

    // 3. Brand mark — translated SVG transform="translate(140, 175) scale(0.2832)"
    drawBrandMark(in: ctx, originSVG: CGPoint(x: 140, y: 175), scale: 0.2832)

    // 4. Text — drawn in raw CG coords (y-up). For each item we know the
    //    SVG baseline y; convert to CG and adjust by descender so draw(at:)
    //    (which anchors the bbox lower-left) lands the baseline correctly.

    drawTextSVG("SpawnWatch",
                atSVGBaseline: CGPoint(x: 490, y: 270),
                size: 86, weight: .heavy,
                color: CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1),
                tracking: -2.5)

    drawTextSVG("App-attributed subprocess tracer for macOS",
                atSVGBaseline: CGPoint(x: 490, y: 335),
                size: 30, weight: .medium,
                color: CGColor(srgbRed: 0.502, green: 0.706, blue: 1.0, alpha: 1.0),
                tracking: 0.5)

    drawTextSVG("github.com/sanjevirau/spawn-app  ·  MIT",
                atSVGBaseline: CGPoint(x: 490, y: 500),
                size: 22, weight: .regular,
                color: CGColor(srgbRed: 0.369, green: 0.439, blue: 0.502, alpha: 1.0),
                tracking: 0)

    // Feature pills row — pill backgrounds at y=380, label baselines at y≈408
    let pills: [(String, CGFloat, CGColor, CGColor)] = [
        ("live exec/fork/exit", 200, CGColor(srgbRed: 0.039, green: 0.518, blue: 1.0, alpha: 0.18),
         CGColor(srgbRed: 0.502, green: 0.706, blue: 1.0, alpha: 1.0)),
        ("code-signing",        158, CGColor(srgbRed: 0.204, green: 0.780, blue: 0.349, alpha: 0.18),
         CGColor(srgbRed: 0.486, green: 0.882, blue: 0.569, alpha: 1.0)),
        ("trace mode",          138, CGColor(srgbRed: 1.0, green: 0.271, blue: 0.227, alpha: 0.18),
         CGColor(srgbRed: 1.0,   green: 0.557, blue: 0.518, alpha: 1.0)),
        ("argv diff",           146, CGColor(srgbRed: 0.749, green: 0.353, blue: 0.949, alpha: 0.18),
         CGColor(srgbRed: 0.827, green: 0.588, blue: 0.972, alpha: 1.0)),
    ]

    var pillX: CGFloat = 490
    let pillSVGY: CGFloat = 380
    let pillH: CGFloat = 44
    for (text, width, bg, fg) in pills {
        // Pill bg — SVG y=380 → CG bottom = canvasH - (380+44) = bottom of pill
        let cgPillY = canvasH - pillSVGY - pillH
        let rect = CGRect(x: pillX, y: cgPillY, width: width, height: pillH)
        ctx.saveGState()
        ctx.setFillColor(bg)
        let path = CGPath(roundedRect: rect, cornerWidth: 22, cornerHeight: 22, transform: nil)
        ctx.addPath(path)
        ctx.fillPath()
        ctx.restoreGState()
        // Label centered vertically inside the pill — baseline at pill-center + offset
        drawTextSVG(text,
                    atSVGBaseline: CGPoint(x: pillX + 22, y: pillSVGY + 29),
                    size: 20, weight: .semibold, color: fg, tracking: 0.2)
        pillX += width + 16
    }
}

/// Draws right-side-up text in a non-flipped CG context, given an SVG-style baseline coordinate.
/// `atSVGBaseline` is the (x, y) where y is the *baseline*, measured from the top of the canvas.
func drawTextSVG(
    _ string: String,
    atSVGBaseline svgPoint: CGPoint,
    size: CGFloat,
    weight: NSFont.Weight,
    color: CGColor,
    tracking: CGFloat
) {
    let font = NSFont.systemFont(ofSize: size, weight: weight)
    let attrs: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: NSColor(cgColor: color) ?? .white,
        .kern: tracking,
    ]
    let attr = NSAttributedString(string: string, attributes: attrs)
    // Convert SVG baseline y (top-down) to CG y of the lower-left of the text bbox (y-up).
    // bbox bottom = baseline - |descent|, and descender is negative.
    let cgBaselineY = canvasH - svgPoint.y
    let cgY = cgBaselineY + font.descender
    attr.draw(at: CGPoint(x: svgPoint.x, y: cgY))
}

func drawBrandMark(in ctx: CGContext, originSVG: CGPoint, scale: CGFloat) {
    // Transform: SVG (0,0) of the mark = canvas point (originSVG.x, originSVG.y) in SVG coords
    // The mark is 1024×1024 in source; we'll scale and offset accordingly.
    ctx.saveGState()
    let cs = CGColorSpaceCreateDeviceRGB()

    // Map SVG y to CG y for the mark's origin
    let originY_CG = canvasH - originSVG.y - 1024 * scale
    ctx.translateBy(x: originSVG.x, y: originY_CG)
    ctx.scaleBy(x: scale, y: scale)
    // Now we draw in 1024×1024 coordinates with y increasing upward (CG).
    // The SVG was in y-down coords, so we need another flip for the mark itself.
    ctx.translateBy(x: 0, y: 1024)
    ctx.scaleBy(x: 1, y: -1)
    // Now we're drawing in 1024×1024 with y-down (matching the SVG).

    // 1. Squircle bg
    let cornerRadius: CGFloat = 232
    let bgRect = CGRect(x: 0, y: 0, width: 1024, height: 1024)
    let bgPath = CGPath(roundedRect: bgRect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
    ctx.saveGState()
    ctx.addPath(bgPath)
    ctx.clip()
    let bgColors = [
        CGColor(srgbRed: 0.039, green: 0.518, blue: 1.0, alpha: 1.0),
        CGColor(srgbRed: 0.0,   green: 0.251, blue: 0.788, alpha: 1.0),
    ] as CFArray
    let bgGradient = CGGradient(colorsSpace: cs, colors: bgColors, locations: [0, 1])!
    ctx.drawLinearGradient(bgGradient,
                           start: CGPoint(x: 0, y: 0),
                           end: CGPoint(x: 1024, y: 1024),
                           options: [])

    // Top-left highlight
    let hiliteColors = [
        CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.20),
        CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.0),
    ] as CFArray
    let hiliteGradient = CGGradient(colorsSpace: cs, colors: hiliteColors, locations: [0, 1])!
    ctx.drawRadialGradient(hiliteGradient,
                           startCenter: CGPoint(x: 225, y: 225),
                           startRadius: 0,
                           endCenter: CGPoint(x: 225, y: 225),
                           endRadius: 563,
                           options: [])

    // Glow around focal child
    let glowColors = [
        CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.55),
        CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.10),
        CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.0),
    ] as CFArray
    let glowGradient = CGGradient(colorsSpace: cs, colors: glowColors, locations: [0, 0.65, 1])!
    ctx.drawRadialGradient(glowGradient,
                           startCenter: CGPoint(x: 720, y: 512),
                           startRadius: 0,
                           endCenter: CGPoint(x: 720, y: 512),
                           endRadius: 180,
                           options: [])

    // Branches
    func stroke(_ pts: [CGPoint], withQuad control: CGPoint?, alpha: CGFloat) {
        ctx.setStrokeColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: alpha))
        ctx.setLineWidth(22)
        ctx.setLineCap(.round)
        let p = CGMutablePath()
        p.move(to: pts[0])
        if let c = control {
            p.addQuadCurve(to: pts[1], control: c)
        } else {
            p.addLine(to: pts[1])
        }
        ctx.addPath(p)
        ctx.strokePath()
    }
    stroke([CGPoint(x: 380, y: 512), CGPoint(x: 700, y: 260)], withQuad: CGPoint(x: 540, y: 380), alpha: 0.55)
    stroke([CGPoint(x: 380, y: 512), CGPoint(x: 700, y: 512)], withQuad: nil,                              alpha: 0.95)
    stroke([CGPoint(x: 380, y: 512), CGPoint(x: 700, y: 764)], withQuad: CGPoint(x: 540, y: 644), alpha: 0.35)

    // Parent dot
    ctx.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1))
    ctx.fillEllipse(in: CGRect(x: 300 - 84, y: 512 - 84, width: 168, height: 168))

    // Pulse ring
    ctx.setStrokeColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.35))
    ctx.setLineWidth(5)
    ctx.strokeEllipse(in: CGRect(x: 720 - 92, y: 512 - 92, width: 184, height: 184))

    // Children
    func dot(cx: CGFloat, cy: CGFloat, r: CGFloat, alpha: CGFloat) {
        ctx.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: alpha))
        ctx.fillEllipse(in: CGRect(x: cx - r, y: cy - r, width: 2 * r, height: 2 * r))
    }
    dot(cx: 720, cy: 260, r: 52, alpha: 0.65)
    dot(cx: 720, cy: 512, r: 64, alpha: 1.0)
    dot(cx: 720, cy: 764, r: 44, alpha: 0.45)

    // Live status dot
    ctx.setFillColor(CGColor(srgbRed: 0.204, green: 0.780, blue: 0.349, alpha: 1.0))
    ctx.fillEllipse(in: CGRect(x: 754 - 14, y: 478 - 14, width: 28, height: 28))

    ctx.restoreGState()
    ctx.restoreGState()
}

// MARK: - Render

guard let rep = NSBitmapImageRep(
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
    fputs("Could not allocate bitmap rep\n", stderr); exit(1)
}

NSGraphicsContext.saveGraphicsState()
let nsctx = NSGraphicsContext(bitmapImageRep: rep)!
NSGraphicsContext.current = nsctx
drawSocial(in: nsctx.cgContext)
NSGraphicsContext.restoreGraphicsState()

guard let pngData = rep.representation(using: .png, properties: [:]) else {
    fputs("PNG encode failed\n", stderr); exit(1)
}

let outURL = URL(fileURLWithPath: outputPath)
try? FileManager.default.createDirectory(at: outURL.deletingLastPathComponent(), withIntermediateDirectories: true)
do {
    try pngData.write(to: outURL)
    print("Wrote \(outURL.path)  (\(Int(canvasW)) × \(Int(canvasH)), \(pngData.count / 1024) KB)")
} catch {
    fputs("Write failed: \(error)\n", stderr); exit(1)
}
