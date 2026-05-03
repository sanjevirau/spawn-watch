import Foundation
import Testing
@testable import SpawnWatchCore

@Suite("BundleResolver Edge Cases")
struct BundleResolverEdgeTests {
    let resolver = BundleResolver()

    @Test("Returns nil for nil path")
    func nilPath() {
        #expect(resolver.resolveApp(fromExecutablePath: nil) == nil)
        #expect(resolver.resolveRelationship(executablePath: nil) == .unknown)
    }

    @Test("Helper relationship matches /Helpers/ subdirectory")
    func helperRelationship() {
        let path = "/Applications/Foo.app/Contents/Helpers/FooHelper"
        #expect(resolver.resolveRelationship(executablePath: path) == .helper)
    }

    @Test("Helper relationship matches binaries with leading-slash 'Helper' (e.g. .app/Helper)")
    func helperLeadingSlash() {
        let path = "/Applications/Foo.app/Helper"
        #expect(resolver.resolveRelationship(executablePath: path) == .helper)
    }

    @Test("Direct child detected for main app executable")
    func directChild() {
        let path = "/Applications/Foo.app/Contents/MacOS/Foo"
        // /Applications/ is not /System/ or /usr/, falls through to .directChild
        #expect(resolver.resolveRelationship(executablePath: path) == .directChild)
    }

    @Test("System path containing .app falls back to unknown (avoids mis-labelling system .apps)")
    func systemPathWithApp() {
        let path = "/System/Library/CoreServices/Some.app/Contents/MacOS/Some"
        #expect(resolver.resolveRelationship(executablePath: path) == .unknown)
    }

    @Test("App bundle resolution works for spaces in path")
    func appNameWithSpaces() {
        let path = "/Applications/My Cool App.app/Contents/MacOS/My Cool App"
        let app = resolver.resolveApp(fromExecutablePath: path)
        #expect(app?.name == "My Cool App")
        #expect(app?.bundlePath == "/Applications/My Cool App.app")
    }

    @Test("App bundle resolution for nested apps picks the outermost .app")
    func nestedAppPicksFirst() {
        let path = "/Applications/Outer.app/Contents/MacOS/Inner.app/Contents/MacOS/Inner"
        let app = resolver.resolveApp(fromExecutablePath: path)
        // Resolver finds first ".app/" match, which is the outer bundle.
        #expect(app?.name == "Outer")
    }

    @Test("System noise list catches additional names")
    func systemNoiseExtras() {
        #expect(resolver.isSystemNoise("/usr/libexec/secinitd") == true)
        #expect(resolver.isSystemNoise("/usr/sbin/cfprefsd") == true)
        #expect(resolver.isSystemNoise("/path/to/distnoted") == true)
        #expect(resolver.isSystemNoise(nil) == false)
    }

    @Test("App extension under PlugIns")
    func appExtensionPath() {
        let path = "/Applications/Mail.app/Contents/PlugIns/Foo.appex/Contents/MacOS/Foo"
        #expect(resolver.resolveRelationship(executablePath: path) == .appExtension)
    }

    @Test("Returns nil app for /usr/ binaries")
    func usrPathNoApp() {
        #expect(resolver.resolveApp(fromExecutablePath: "/usr/bin/ls") == nil)
        #expect(resolver.resolveApp(fromExecutablePath: "/bin/zsh") == nil)
    }
}
