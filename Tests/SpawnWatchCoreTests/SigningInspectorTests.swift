import Foundation
import Testing
@testable import SpawnWatchCore

@Suite("SigningInspector Tests")
struct SigningInspectorTests {
    let inspector = SigningInspector()

    @Test("Inspects /bin/ls as Apple-signed")
    func systemBinaryIsApple() async {
        let info = await inspector.info(for: "/bin/ls")
        #expect(info.signingType == .apple)
        #expect(!info.signingAuthority.isEmpty)
    }

    @Test("Returns unknown for non-existent path")
    func nonExistentPath() async {
        let info = await inspector.info(for: "/this/path/does/not/exist/spawnwatch-test")
        #expect(info.signingType == .unknown)
    }

    @Test("Cache returns same instance on repeated inspections of unchanged file")
    func cacheHit() async {
        let first = await inspector.info(for: "/bin/ls")
        let second = await inspector.info(for: "/bin/ls")
        #expect(first.signingType == second.signingType)
        #expect(first.cdHash == second.cdHash)
        #expect(first.sha256 == second.sha256)
    }

    @Test("clearCache forces re-inspection")
    func clearCache() async {
        _ = await inspector.info(for: "/bin/ls")
        await inspector.clearCache()
        let after = await inspector.info(for: "/bin/ls")
        #expect(after.signingType == .apple)
    }

    @Test("Returns unsigned or unknown for an unsigned ad-hoc file")
    func unsignedFile() async throws {
        // Write a tiny dummy executable to a temp path; it has no signature.
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("spawnwatch-unsigned-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: tmp) }
        try Data(repeating: 0, count: 64).write(to: tmp)

        let info = await inspector.info(for: tmp.path)
        // Either .unsigned or .unknown is acceptable — both indicate "no valid signature."
        #expect(info.signingType == .unsigned || info.signingType == .unknown)
    }
}
