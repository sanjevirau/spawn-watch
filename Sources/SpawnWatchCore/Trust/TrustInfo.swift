import Foundation

public enum SigningType: String, Codable, Sendable {
    case apple = "Apple"
    case developerID = "Developer ID"
    case appStore = "Mac App Store"
    case adhoc = "Ad-hoc"
    case unsigned = "Unsigned"
    case unknown = "Unknown"
}

public struct TrustInfo: Codable, Sendable, Hashable {
    public let signingType: SigningType
    public let teamID: String?
    public let signingAuthority: [String]
    public let notarized: Bool
    public let hardenedRuntime: Bool
    public let libraryValidation: Bool
    public let sandboxed: Bool
    public let cdHash: String?
    public let sha256: String?
    public let entitlementCount: Int
    public let inspectedAt: Date

    public init(
        signingType: SigningType,
        teamID: String? = nil,
        signingAuthority: [String] = [],
        notarized: Bool = false,
        hardenedRuntime: Bool = false,
        libraryValidation: Bool = false,
        sandboxed: Bool = false,
        cdHash: String? = nil,
        sha256: String? = nil,
        entitlementCount: Int = 0,
        inspectedAt: Date = Date()
    ) {
        self.signingType = signingType
        self.teamID = teamID
        self.signingAuthority = signingAuthority
        self.notarized = notarized
        self.hardenedRuntime = hardenedRuntime
        self.libraryValidation = libraryValidation
        self.sandboxed = sandboxed
        self.cdHash = cdHash
        self.sha256 = sha256
        self.entitlementCount = entitlementCount
        self.inspectedAt = inspectedAt
    }

    public var summary: String {
        switch signingType {
        case .apple: return "Apple"
        case .developerID:
            if let team = teamID { return "Developer ID · \(team)" }
            return "Developer ID"
        case .appStore: return "App Store"
        case .adhoc: return "Ad-hoc signed"
        case .unsigned: return "Unsigned"
        case .unknown: return "Unknown"
        }
    }
}
