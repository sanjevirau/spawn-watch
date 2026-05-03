import Foundation

public struct BundleResolver: Sendable {
    public init() {}

    public func resolveApp(fromExecutablePath path: String?) -> AppBundleInfo? {
        guard let path else { return nil }

        guard let appRange = path.range(of: ".app/") else { return nil }
        let bundlePath = String(path[path.startIndex..<appRange.upperBound].dropLast())
        let appName = (bundlePath as NSString).lastPathComponent.replacingOccurrences(of: ".app", with: "")

        let plistPath = bundlePath + "/Contents/Info.plist"
        var bundleId: String?
        if let plistData = try? Data(contentsOf: URL(fileURLWithPath: plistPath)),
           let plist = try? PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: Any] {
            bundleId = plist["CFBundleIdentifier"] as? String
        }

        return AppBundleInfo(name: appName, bundlePath: bundlePath, bundleIdentifier: bundleId)
    }

    public func resolveRelationship(executablePath path: String?) -> ProcessRelationship {
        guard let path else { return .unknown }

        if path.contains(".framework/") {
            return .framework
        }
        if path.contains("/XPCServices/") {
            return .xpcService
        }
        if path.contains("/PlugIns/") && path.contains(".appex/") {
            return .appExtension
        }
        if path.contains("/Helpers/") || path.contains("/Helper") {
            return .helper
        }
        if path.hasPrefix("/System/") || path.hasPrefix("/usr/") {
            if path.contains(".app/") {
                return .unknown
            }
            return .system
        }
        if path.contains(".app/Contents/MacOS/") {
            return .directChild
        }
        return .unknown
    }

    public func isSystemNoise(_ path: String?) -> Bool {
        guard let path else { return false }
        let noisy = [
            "mdworker_shared",
            "mdworker",
            "mds_stores",
            "xpcproxy",
            "MTLCompilerService",
            "trustd",
            "cfprefsd",
            "distnoted",
            "secinitd",
        ]
        let basename = (path as NSString).lastPathComponent
        return noisy.contains(basename)
    }
}
