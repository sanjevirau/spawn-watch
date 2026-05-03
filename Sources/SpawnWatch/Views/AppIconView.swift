import SwiftUI
import AppKit

/// Renders the real macOS app icon for a given bundle path, falling back to a system glyph.
struct AppIconView: View {
    let bundlePath: String?
    var size: CGFloat = 18
    var fallbackSystemImage: String = "app.fill"
    var fallbackColor: Color = .blue

    var body: some View {
        if let bundlePath, let nsImage = AppIconCache.shared.icon(for: bundlePath) {
            Image(nsImage: nsImage)
                .resizable()
                .interpolation(.high)
                .frame(width: size, height: size)
        } else {
            Image(systemName: fallbackSystemImage)
                .foregroundColor(fallbackColor)
                .frame(width: size, height: size)
        }
    }
}

/// Caches `NSWorkspace.icon(forFile:)` results keyed by bundle path.
/// Icons are cheap to fetch but uniformly hit during scrolling — caching keeps the sidebar smooth.
@MainActor
final class AppIconCache {
    static let shared = AppIconCache()
    private var cache: [String: NSImage] = [:]

    func icon(for bundlePath: String) -> NSImage? {
        if let cached = cache[bundlePath] { return cached }
        guard FileManager.default.fileExists(atPath: bundlePath) else { return nil }
        let image = NSWorkspace.shared.icon(forFile: bundlePath)
        // NSWorkspace returns a placeholder for missing files; trust it.
        cache[bundlePath] = image
        return image
    }

    func clear() { cache.removeAll() }
}
