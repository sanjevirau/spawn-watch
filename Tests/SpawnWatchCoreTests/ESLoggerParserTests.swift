import Testing
@testable import SpawnWatchCore

@Suite("ESLoggerParser Tests")
struct ESLoggerParserTests {
    let parser = ESLoggerParser()

    @Test("Parses exec event JSON")
    func parseExecEvent() {
        let json = """
        {
            "event_type": "ES_EVENT_TYPE_NOTIFY_EXEC",
            "process": {
                "executable": {"path": "/bin/zsh"},
                "audit_token": {"pid": 100}
            },
            "event": {
                "exec": {
                    "target": {
                        "executable": {"path": "/usr/bin/ls"},
                        "audit_token": {"pid": 200}
                    },
                    "args": ["ls", "-la"],
                    "cwd": {"path": "/Users/test"}
                }
            }
        }
        """

        let event = parser.parse(line: json)

        #expect(event != nil)
        #expect(event?.eventType == .exec)
        #expect(event?.parent.pid == 100)
        #expect(event?.parent.name == "zsh")
        #expect(event?.child.pid == 200)
        #expect(event?.child.name == "ls")
        #expect(event?.commandLine == ["ls", "-la"])
        #expect(event?.workingDirectory == "/Users/test")
        #expect(event?.source == .eslogger)
        #expect(event?.relationship == .system)
    }

    @Test("Parses fork event JSON")
    func parseForkEvent() {
        let json = """
        {
            "event_type": "ES_EVENT_TYPE_NOTIFY_FORK",
            "process": {
                "executable": {"path": "/bin/zsh"},
                "audit_token": {"pid": 100}
            },
            "event": {
                "fork": {
                    "child": {
                        "executable": {"path": "/bin/zsh"},
                        "audit_token": {"pid": 201}
                    }
                }
            }
        }
        """

        let event = parser.parse(line: json)

        #expect(event != nil)
        #expect(event?.eventType == .fork)
        #expect(event?.child.pid == 201)
    }

    @Test("Resolves XPC service relationship and owning app")
    func xpcServiceResolution() {
        let json = """
        {
            "event_type": "ES_EVENT_TYPE_NOTIFY_EXEC",
            "process": {
                "executable": {"path": "/usr/libexec/launchd"},
                "audit_token": {"pid": 1}
            },
            "event": {
                "exec": {
                    "target": {
                        "executable": {"path": "/Applications/MyApp.app/Contents/XPCServices/EngineXPC.xpc/Contents/MacOS/EngineXPC"},
                        "audit_token": {"pid": 500}
                    },
                    "args": ["EngineXPC"]
                }
            }
        }
        """

        let event = parser.parse(line: json)

        #expect(event != nil)
        #expect(event?.relationship == .xpcService)
        #expect(event?.owningApp?.name == "MyApp")
        #expect(event?.owningApp?.bundlePath == "/Applications/MyApp.app")
        #expect(event?.parent.name == "MyApp")
    }

    @Test("Returns nil for invalid JSON")
    func invalidJson() {
        #expect(parser.parse(line: "not json") == nil)
        #expect(parser.parse(line: "") == nil)
        #expect(parser.parse(line: "{}") == nil)
    }

    @Test("Returns nil for unknown event type")
    func unknownEventType() {
        let json = """
        {"event_type": "ES_EVENT_TYPE_NOTIFY_OPEN", "event": {}, "process": {}}
        """
        #expect(parser.parse(line: json) == nil)
    }
}

@Suite("BundleResolver Tests")
struct BundleResolverTests {
    let resolver = BundleResolver()

    @Test("Resolves app bundle from XPC service path")
    func xpcPath() {
        let path = "/Applications/NXPowerLite Desktop/NXPowerLite Desktop.app/Contents/XPCServices/NXEngineXPCService.xpc/Contents/MacOS/NXEngineXPCService"
        let app = resolver.resolveApp(fromExecutablePath: path)

        #expect(app != nil)
        #expect(app?.name == "NXPowerLite Desktop")
        #expect(app?.bundlePath == "/Applications/NXPowerLite Desktop/NXPowerLite Desktop.app")
    }

    @Test("Resolves app bundle from main executable path")
    func mainExePath() {
        let path = "/Applications/NXPowerLite Desktop/NXPowerLite Desktop.app/Contents/MacOS/NXPowerLite Desktop"
        let app = resolver.resolveApp(fromExecutablePath: path)

        #expect(app != nil)
        #expect(app?.name == "NXPowerLite Desktop")
    }

    @Test("Returns nil for system paths")
    func systemPath() {
        let path = "/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/Metadata.framework/Versions/A/Support/mdworker_shared"
        let app = resolver.resolveApp(fromExecutablePath: path)

        #expect(app == nil)
    }

    @Test("Detects XPC service relationship")
    func xpcRelationship() {
        let path = "/Applications/MyApp.app/Contents/XPCServices/Helper.xpc/Contents/MacOS/Helper"
        #expect(resolver.resolveRelationship(executablePath: path) == .xpcService)
    }

    @Test("Detects app extension relationship")
    func appExtension() {
        let path = "/Applications/TestFlight.app/Contents/PlugIns/TestFlightServiceExtension.appex/Contents/MacOS/TestFlightServiceExtension"
        #expect(resolver.resolveRelationship(executablePath: path) == .appExtension)
    }

    @Test("Detects framework service relationship")
    func framework() {
        let path = "/System/Library/Frameworks/CoreGraphics.framework/Versions/A/XPCServices/CGPDFService.xpc/Contents/MacOS/CGPDFService"
        #expect(resolver.resolveRelationship(executablePath: path) == .framework)
    }

    @Test("Detects system process")
    func systemProcess() {
        let path = "/usr/libexec/something"
        #expect(resolver.resolveRelationship(executablePath: path) == .system)
    }

    @Test("Identifies system noise")
    func systemNoise() {
        #expect(resolver.isSystemNoise("/path/to/mdworker_shared") == true)
        #expect(resolver.isSystemNoise("/usr/libexec/xpcproxy") == true)
        #expect(resolver.isSystemNoise("/path/to/MTLCompilerService") == true)
        #expect(resolver.isSystemNoise("/Applications/MyApp.app/Contents/MacOS/MyApp") == false)
    }
}
