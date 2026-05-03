import SwiftUI

/// Renders the SpawnWatch brand mark as a SwiftUI view.
/// Mirrors `Brand/AppIcon.svg` and `Scripts/generate-icon.swift` one-to-one.
struct BrandMark: View {
    var size: CGFloat = 96
    var muted: Bool = false

    var body: some View {
        Canvas { context, canvasSize in
            let s = canvasSize.width
            let scale = s / 1024.0

            func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
                CGPoint(x: x * scale, y: y * scale)
            }
            func l(_ v: CGFloat) -> CGFloat { v * scale }

            // Squircle background
            let cornerRadius = s * 0.2265
            let bgPath = Path(roundedRect: CGRect(origin: .zero, size: canvasSize),
                              cornerRadius: cornerRadius,
                              style: .continuous)
            let bgGradient = Gradient(colors: muted
                ? [Color(red: 0.10, green: 0.16, blue: 0.32), Color(red: 0.05, green: 0.10, blue: 0.22)]
                : [Color(red: 0.039, green: 0.518, blue: 1.0), Color(red: 0.0, green: 0.251, blue: 0.788)])
            context.fill(bgPath, with: .linearGradient(
                bgGradient,
                startPoint: .zero,
                endPoint: CGPoint(x: s, y: s)
            ))

            // Top-left highlight (radial)
            context.fill(bgPath, with: .radialGradient(
                Gradient(stops: [
                    .init(color: Color.white.opacity(0.20), location: 0),
                    .init(color: Color.white.opacity(0.0), location: 1),
                ]),
                center: p(225, 225),
                startRadius: 0,
                endRadius: l(563)
            ))

            // Soft glow around focal child
            let glowPath = Path(ellipseIn: CGRect(
                x: p(720 - 180, 512 - 180).x, y: p(720 - 180, 512 - 180).y,
                width: l(360), height: l(360)
            ))
            context.fill(glowPath, with: .radialGradient(
                Gradient(stops: [
                    .init(color: Color.white.opacity(0.55), location: 0),
                    .init(color: Color.white.opacity(0.10), location: 0.65),
                    .init(color: Color.white.opacity(0.0), location: 1),
                ]),
                center: p(720, 512),
                startRadius: 0,
                endRadius: l(180)
            ))

            // Branches
            let lineWidth = l(22)
            let stroke = StrokeStyle(lineWidth: lineWidth, lineCap: .round)

            var topBranch = Path()
            topBranch.move(to: p(380, 512))
            topBranch.addQuadCurve(to: p(700, 260), control: p(540, 380))
            context.stroke(topBranch, with: .color(Color.white.opacity(0.55)), style: stroke)

            var midBranch = Path()
            midBranch.move(to: p(380, 512))
            midBranch.addLine(to: p(700, 512))
            context.stroke(midBranch, with: .color(Color.white.opacity(0.95)), style: stroke)

            var botBranch = Path()
            botBranch.move(to: p(380, 512))
            botBranch.addQuadCurve(to: p(700, 764), control: p(540, 644))
            context.stroke(botBranch, with: .color(Color.white.opacity(0.35)), style: stroke)

            // Parent
            let parentRect = CGRect(x: p(300 - 84, 512 - 84).x, y: p(300 - 84, 512 - 84).y, width: l(168), height: l(168))
            context.fill(Path(ellipseIn: parentRect), with: .color(.white))

            // Pulse ring
            let ringRect = CGRect(x: p(720 - 92, 512 - 92).x, y: p(720 - 92, 512 - 92).y, width: l(184), height: l(184))
            context.stroke(Path(ellipseIn: ringRect),
                           with: .color(Color.white.opacity(0.35)),
                           lineWidth: l(5))

            // Three children
            func dot(cx: CGFloat, cy: CGFloat, r: CGFloat, alpha: CGFloat) {
                let rect = CGRect(x: p(cx - r, cy - r).x, y: p(cx - r, cy - r).y, width: l(r * 2), height: l(r * 2))
                context.fill(Path(ellipseIn: rect), with: .color(Color.white.opacity(alpha)))
            }
            dot(cx: 720, cy: 260, r: 52, alpha: 0.65)
            dot(cx: 720, cy: 512, r: 64, alpha: 1.0)
            dot(cx: 720, cy: 764, r: 44, alpha: 0.45)

            // Live status accent
            let statusColor = Color(red: 0.204, green: 0.780, blue: 0.349)
            let statusRect = CGRect(x: p(754 - 14, 478 - 14).x, y: p(754 - 14, 478 - 14).y, width: l(28), height: l(28))
            context.fill(Path(ellipseIn: statusRect), with: .color(statusColor))
        }
        .frame(width: size, height: size)
        .accessibilityLabel("SpawnWatch")
    }
}

/// Compact wordmark — mark + "SpawnWatch" text, used in headers and empty states.
struct BrandWordmark: View {
    var size: CGFloat = 48

    var body: some View {
        HStack(spacing: size * 0.25) {
            BrandMark(size: size)
            Text("SpawnWatch")
                .font(.system(size: size * 0.5, weight: .heavy, design: .default))
                .tracking(-0.5)
                .foregroundStyle(.primary)
        }
    }
}

#Preview("Mark") { BrandMark(size: 128).padding(40) }
#Preview("Wordmark") { BrandWordmark(size: 64).padding(40) }
