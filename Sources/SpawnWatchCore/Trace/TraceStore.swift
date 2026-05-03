import Foundation

public actor TraceStore {
    public enum StoreError: Error, LocalizedError {
        case directoryUnavailable
        case writeFailed(String)
        case readFailed(String)

        public var errorDescription: String? {
            switch self {
            case .directoryUnavailable: return "Could not locate Application Support directory"
            case .writeFailed(let m): return "Trace write failed: \(m)"
            case .readFailed(let m): return "Trace read failed: \(m)"
            }
        }
    }

    private let directoryURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(directoryURL: URL? = nil) {
        if let directoryURL {
            self.directoryURL = directoryURL
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
            self.directoryURL = appSupport
                .appendingPathComponent("SpawnWatch", isDirectory: true)
                .appendingPathComponent("Traces", isDirectory: true)
        }

        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder = enc

        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        self.decoder = dec
    }

    public var directory: URL { directoryURL }

    public func ensureDirectory() throws {
        if !FileManager.default.fileExists(atPath: directoryURL.path) {
            try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        }
    }

    public func save(_ session: TraceSession) throws {
        try ensureDirectory()
        let url = url(for: session.id)
        let tmpURL = url.appendingPathExtension("tmp")
        let data = try encoder.encode(session)
        try data.write(to: tmpURL, options: [.atomic])
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
        try FileManager.default.moveItem(at: tmpURL, to: url)
    }

    public func load(id: UUID) throws -> TraceSession {
        let data = try Data(contentsOf: url(for: id))
        return try decoder.decode(TraceSession.self, from: data)
    }

    public func delete(id: UUID) throws {
        try? FileManager.default.removeItem(at: url(for: id))
    }

    public func list() throws -> [TraceSession] {
        try ensureDirectory()
        let contents = (try? FileManager.default.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: nil
        )) ?? []
        return contents.compactMap { url in
            guard url.pathExtension == "json" else { return nil }
            guard let data = try? Data(contentsOf: url) else { return nil }
            return try? decoder.decode(TraceSession.self, from: data)
        }
    }

    private func url(for id: UUID) -> URL {
        directoryURL.appendingPathComponent("\(id.uuidString).json")
    }
}
