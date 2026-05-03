import Foundation

public struct ProcessIdentity: Hashable, Codable, Sendable {
    public let pid: Int32
    public let name: String
    public let executablePath: String?
    public let bundleName: String?
    public let spawnTime: Date?

    public init(
        pid: Int32,
        name: String,
        executablePath: String? = nil,
        bundleName: String? = nil,
        spawnTime: Date? = nil
    ) {
        self.pid = pid
        self.name = name
        self.executablePath = executablePath
        self.bundleName = bundleName
        self.spawnTime = spawnTime
    }

    public func key(fallback: Date) -> ProcessKey {
        ProcessKey(pid: pid, spawnTime: spawnTime ?? fallback)
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.pid = try c.decode(Int32.self, forKey: .pid)
        self.name = try c.decode(String.self, forKey: .name)
        self.executablePath = try c.decodeIfPresent(String.self, forKey: .executablePath)
        self.bundleName = try c.decodeIfPresent(String.self, forKey: .bundleName)
        self.spawnTime = try c.decodeIfPresent(Date.self, forKey: .spawnTime)
    }

    private enum CodingKeys: String, CodingKey {
        case pid, name, executablePath, bundleName, spawnTime
    }
}
