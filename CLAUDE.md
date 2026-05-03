# Claude / AI agent context for SpawnWatch

This file gives an AI agent (or a new contributor) enough orientation to do useful work without re-discovering the architecture.

## Product north star

SpawnWatch is **the developer's microscope for `fork`/`exec` on macOS**, with app-attribution as its signature feature and trace mode as its killer demo. It is not an EDR product, not a network monitor, not a persistence detector. Stay narrow.

The audience is developers debugging Electron / Tauri / native subprocess behavior, build pipelines, and "what does this app actually do behind my back."

## Repository layout

```
Package.swift                       # SPM, two targets, macOS 14+, Swift 6
Scripts/build-app.sh                # Builds an unsigned .app bundle
Sources/SpawnWatchCore/             # UI-free library
  Models/
    ProcessKey.swift                # Composite (pid, spawnTime) — fixes PID reuse
    ProcessInfo.swift               # ProcessIdentity (wire-level identity)
    ProcessRecord.swift             # @Observable @MainActor live record
    ProcessTree.swift               # Legacy tree node (used in tests)
    SpawnEvent.swift                # Codable wire event with backward-compat decoding
  Monitors/
    SpawnMonitor.swift              # Protocol
    ESLoggerMonitor.swift           # Real-time via /usr/bin/eslogger
    PollingMonitor.swift            # libproc fallback, also synthesizes exit events
    CompositeMonitor.swift          # Runs both, dedups via actor
  Parsers/
    ESLoggerParser.swift            # Handles ES_EVENT_TYPE_NOTIFY_{EXEC,FORK,EXIT}
    BundleResolver.swift            # Walks .app bundles, classifies relationships
    ProcessInfoQuery.swift          # libproc / sysctl wrappers
  Trust/
    TrustInfo.swift                 # Codable signing info struct
    SigningInspector.swift          # actor; SecStaticCode + cache by (path, mtime, size)
  Trace/
    TraceSession.swift              # Codable session model
    TraceStore.swift                # actor; persists JSON to ~/Library/Application Support
    TraceDiffer.swift               # Multiset diff with argv normalization
  Utilities/
    PrivilegeHelper.swift           # osascript wrapper for eslogger
Sources/SpawnWatch/                 # SwiftUI app
  SpawnWatchApp.swift               # @main entry
  ViewModels/
    SpawnEventStore.swift           # @MainActor @Observable, the one big store
    TraceController.swift           # @MainActor @Observable, recording state
  Views/
    MainContentView.swift           # NavigationSplitView shell, toolbar, sheets
    EventListView.swift             # Middle pane
    EventDetailView.swift           # Right pane (uses TrustPanelView, LineagePanelView)
    ProcessTreeView.swift           # Sidebar mode
    AppGroupListView.swift          # Sidebar mode
    TraceListView.swift             # Sidebar mode
    TraceSessionView.swift          # Sheet — opened trace
    TraceDiffView.swift             # Sheet — A vs B
    TrustPanelView.swift            # Detail card
    LineagePanelView.swift          # Detail card
    SectionCard.swift               # Shared card chrome
    FilterBarView.swift             # Filter chips
    StatusBarView.swift             # Bottom status pills
    Format.swift                    # Duration / bytes formatters
Tests/SpawnWatchCoreTests/          # Library tests (parsing, models, monitors, persistence)
Tests/SpawnWatchTests/              # App tests (SpawnEventStore, TraceController)
```

## Key conventions

- **Concurrency**: `SpawnEventStore`, `TraceController`, and `ProcessRecord` are `@MainActor`. `SigningInspector`, `TraceStore`, and the dedup helper are `actor`s. Never use `@unchecked Sendable` without a comment.
- **Identity**: prefer `ProcessKey` over raw `pid_t`. PIDs reuse; `ProcessKey` does not. The `pidToLatestKey` map in `SpawnEventStore` resolves wire-level pids back to the most recent record.
- **Observation**: `ProcessRecord` is `@Observable` so SwiftUI tracks per-property reads. Mutating a record in place re-renders only the views that read the changed property.
- **Decoding**: every `Codable` model uses `decodeIfPresent` for fields added after v0.1 (e.g., `spawnTime`, `exitCode`). Old exported JSONs must continue to load.
- **Comments**: only when the *why* is non-obvious. Don't narrate code.

## Build / test commands

```sh
swift build                       # debug
swift test --parallel             # 98 tests in 16 suites
swift build -c release            # release
swift run                         # runs SwiftPM executable directly
./Scripts/build-app.sh release    # produces build/SpawnWatch.app
```

## Privilege model (don't change without thinking)

`PrivilegeHelper.launchPrivilegedESLogger` shells out to `osascript … with administrator privileges` to launch `/usr/bin/eslogger exec fork exit --format json`. This requires admin auth on each app launch. Two reasons we don't use the Endpoint Security framework directly:

1. The `com.apple.developer.endpoint-security.client` entitlement requires an Apple-issued provisioning profile that costs $99/year and isn't viable for a free OSS dev tool.
2. Without a paid signing identity, we can't ship a `SMAppService` privileged helper either.

If a contributor proposes "let's use the ES framework directly," confirm they understand the entitlement situation first.

## Things to avoid

- Adding network monitoring (that's Little Snitch's territory).
- Adding file I/O monitoring (`fs_usage` covers it; very high noise).
- Persistence detection (KnockKnock).
- Cross-platform abstractions (Linux has bpftrace, Windows has Sysmon — different tools, different audiences).
- "Security alerting" features that turn this into a half-baked EDR.

## Roadmap (where to focus)

| Version | Focus |
|---------|-------|
| v0.1 *(current)* | Live monitor, trust, lineage, trace mode + diff |
| v0.2 | Menu-bar mode, always-on JSONL log to disk |
| v0.3 | Rules + macOS notifications |
| v0.4 | CLI companion (`spawnwatch tail`, `spawnwatch trace --`) |

## Common pitfalls

- **PID reuse**: anything keyed on raw `pid_t` will silently corrupt over long sessions. Always use `ProcessKey`.
- **`@Observable` re-render granularity**: mutating a value type inside `@Observable` triggers full-property re-evaluation. Mutating a property of a `@Observable` *class* is much more granular. We rely on this for `ProcessRecord`.
- **Trust cache invalidation**: keyed on `(path, mtime, size)` — atomic-rename installs (`cp + rename`) invalidate cleanly. If you add a new cache, follow the same pattern.
- **Exit events from polling are partial**: `PollingMonitor` synthesizes exit events when PIDs disappear, but cannot determine exit code. Keep `exitCode` optional.
- **Trace persistence is async**: stopping a trace returns immediately; the JSON write happens on a detached task. If you ever quit the app right after stopping, the trace might not yet be on disk.
