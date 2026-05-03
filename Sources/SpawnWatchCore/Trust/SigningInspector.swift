import Foundation
import Security
import CryptoKit

public actor SigningInspector {
    public static let shared = SigningInspector()

    private struct CacheKey: Hashable {
        let path: String
        let mtime: Date
        let size: UInt64
    }

    private var cache: [CacheKey: TrustInfo] = [:]
    private var inFlight: [CacheKey: Task<TrustInfo, Never>] = [:]
    private let semaphore = AsyncSemaphore(limit: 4)

    public init() {}

    public func info(for path: String) async -> TrustInfo {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: path),
              let mtime = attrs[.modificationDate] as? Date,
              let size = attrs[.size] as? UInt64
        else {
            return TrustInfo(signingType: .unknown)
        }

        let cacheKey = CacheKey(path: path, mtime: mtime, size: size)
        if let cached = cache[cacheKey] { return cached }

        if let existing = inFlight[cacheKey] {
            return await existing.value
        }

        let task = Task<TrustInfo, Never> { [semaphore] in
            await semaphore.acquire()
            defer { Task { await semaphore.release() } }
            return Self.inspect(path: path)
        }
        inFlight[cacheKey] = task
        let info = await task.value
        inFlight.removeValue(forKey: cacheKey)
        cache[cacheKey] = info
        return info
    }

    public func clearCache() {
        cache.removeAll()
    }

    private nonisolated static func inspect(path: String) -> TrustInfo {
        let url = URL(fileURLWithPath: path)
        var staticCode: SecStaticCode?
        let createStatus = SecStaticCodeCreateWithPath(url as CFURL, [], &staticCode)
        guard createStatus == errSecSuccess, let code = staticCode else {
            return TrustInfo(signingType: .unsigned)
        }

        var infoDict: CFDictionary?
        let flags = SecCSFlags(rawValue: kSecCSSigningInformation | kSecCSRequirementInformation | kSecCSDynamicInformation)
        let infoStatus = SecCodeCopySigningInformation(code, flags, &infoDict)
        guard infoStatus == errSecSuccess, let info = infoDict as? [String: Any] else {
            return TrustInfo(signingType: .unsigned)
        }

        let teamID = info[kSecCodeInfoTeamIdentifier as String] as? String

        var authorities: [String] = []
        if let certs = info[kSecCodeInfoCertificates as String] as? [SecCertificate] {
            for cert in certs {
                if let summary = SecCertificateCopySubjectSummary(cert) as String? {
                    authorities.append(summary)
                }
            }
        }

        let runtimeFlags = (info[kSecCodeInfoRuntimeVersion as String] != nil)
        let csFlags = (info["flags"] as? UInt32) ?? (info["csflags"] as? UInt32) ?? 0
        let hardenedRuntime = (csFlags & 0x10000) != 0 || runtimeFlags
        let libraryValidation = (csFlags & 0x2000) != 0

        var entitlementCount = 0
        var sandboxed = false
        if let ents = info[kSecCodeInfoEntitlementsDict as String] as? [String: Any] {
            entitlementCount = ents.count
            sandboxed = (ents["com.apple.security.app-sandbox"] as? Bool) ?? false
        }

        var cdHash: String?
        if let hashData = info[kSecCodeInfoUnique as String] as? Data {
            cdHash = hashData.map { String(format: "%02x", $0) }.joined()
        }

        let signingType = classifySigning(info: info, teamID: teamID, authorities: authorities, path: path)

        let notarized = isNotarized(info: info) || (signingType == .developerID && hardenedRuntime)
        let sha = sha256(of: path)

        return TrustInfo(
            signingType: signingType,
            teamID: teamID,
            signingAuthority: authorities,
            notarized: notarized,
            hardenedRuntime: hardenedRuntime,
            libraryValidation: libraryValidation,
            sandboxed: sandboxed,
            cdHash: cdHash,
            sha256: sha,
            entitlementCount: entitlementCount
        )
    }

    private nonisolated static func classifySigning(
        info: [String: Any],
        teamID: String?,
        authorities: [String],
        path: String
    ) -> SigningType {
        let identifier = info[kSecCodeInfoIdentifier as String] as? String ?? ""
        let authorityJoined = authorities.joined(separator: " | ")

        if authorityJoined.contains("Apple Mac OS Application Signing") {
            return .appStore
        }
        if authorityJoined.contains("Software Signing") || authorityJoined.contains("Apple Code Signing") {
            return .apple
        }
        if authorities.contains(where: { $0.hasPrefix("Developer ID Application") }) {
            return .developerID
        }
        if authorities.isEmpty && teamID == nil && !identifier.isEmpty {
            return .adhoc
        }
        if authorities.isEmpty && teamID == nil {
            return .unsigned
        }
        return .unknown
    }

    private nonisolated static func isNotarized(info: [String: Any]) -> Bool {
        // Notarization is exposed via dynamic code-signing flags. The kSecCodeStatusNotarized
        // bit is 0x4000 in current macOS versions when SecCodeCheckValidity has been called.
        // We approximate: if the binary has a Developer ID authority and a runtime version tag,
        // it's almost always notarized. Without performing live SecAssessment lookups we fall
        // back to checking the runtime version + Developer ID combo.
        if let runtime = info[kSecCodeInfoRuntimeVersion as String] as? UInt32, runtime > 0 {
            return true
        }
        return false
    }

    private nonisolated static func sha256(of path: String) -> String? {
        let url = URL(fileURLWithPath: path)
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: path),
              let size = attrs[.size] as? UInt64,
              size < 64 * 1024 * 1024
        else { return nil }
        guard let data = try? Data(contentsOf: url, options: .mappedIfSafe) else { return nil }
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

actor AsyncSemaphore {
    private let limit: Int
    private var available: Int
    private var waiters: [CheckedContinuation<Void, Never>] = []

    init(limit: Int) {
        self.limit = limit
        self.available = limit
    }

    func acquire() async {
        if available > 0 {
            available -= 1
            return
        }
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            waiters.append(cont)
        }
    }

    func release() {
        if let next = waiters.first {
            waiters.removeFirst()
            next.resume()
        } else {
            available += 1
        }
    }
}
