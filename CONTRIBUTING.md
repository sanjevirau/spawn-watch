# Contributing to SpawnWatch

Thanks for considering a contribution. SpawnWatch is intentionally small and focused — a developer's microscope for `fork`/`exec` on macOS, with app attribution as its signature feature. PRs that reinforce that focus get merged fastest.

## Building and testing

```sh
swift build              # debug build
swift test               # run the test suite (21 tests, ~2s)
swift run                # launch the app from source
./Scripts/build-app.sh   # produce build/SpawnWatch.app (release config)
```

Requires macOS 14 (Sonoma) or later and Swift 6.0 (Xcode 16).

## Code conventions

- **Two targets**: `SpawnWatchCore` is a UI-free library; `SpawnWatch` is the SwiftUI app. Anything in `Models/`, `Monitors/`, `Parsers/`, `Trust/`, or `Trace/` belongs in `SpawnWatchCore`. Anything that imports SwiftUI / AppKit belongs in `SpawnWatch`.
- **Concurrency**: `SpawnEventStore` and `ProcessRecord` are `@MainActor`. Background work (signing inspection, trace I/O) lives in `actor` types. Don't introduce `@unchecked Sendable` without a comment explaining why.
- **Identifiers**: prefer `ProcessKey` (composite `pid + spawnTime`) over raw `pid_t` / `Int32` everywhere. Raw PIDs reuse, `ProcessKey` doesn't.
- **No new comments unless the *why* is non-obvious.** Names should explain the *what*.
- **Tests live in `Tests/SpawnWatchCoreTests/`.** Anything that can be unit-tested without UI should have a test. UI tests not yet wired up.

## Areas welcoming contributions

| Area | Difficulty | Notes |
|------|-----------|-------|
| Argv normalization patterns in `TraceDiffer.normalize` | easy | Add regexes for tool-specific transient tokens (Xcode `--archive-path`, cargo `target/`, etc.) |
| `SigningInspector` test coverage | easy | Inspect well-known system binaries with stable signatures |
| Bundle resolver corner cases | medium | Apps inside DMGs, frameworks-in-helpers, ad-hoc-signed third-party binaries |
| Menu-bar mode | medium | `NSStatusItem` with live counter, "show window" / "pause" actions |
| Always-on JSONL log to disk | medium | New `JSONLEventLogger` actor writing to `~/Library/Logs/SpawnWatch/` |
| CLI companion target | hard | Third SPM target `spawnwatch-cli` reusing `SpawnWatchCore` |
| Performance under fork bombs | hard | Profile with a kernel build; tune ring buffer + tree update rate |

## Submitting changes

1. Fork, branch off `main`
2. Keep PRs small — one feature or fix per PR
3. Add a test if you fixed a bug or added behavior
4. Run `swift build && swift test` before pushing — CI will run the same
5. Describe what changed and why in the PR body. Screenshots welcome for UI changes.

## Bug reports

Useful bug reports include:

- macOS version (e.g. 14.5, 15.0)
- How you launched SpawnWatch (`swift run`, `.app`, etc.)
- Whether you granted admin auth (so we know which monitor was active)
- Steps to reproduce, with at least one example process spawn that demonstrates the issue
- An exported event from the toolbar (the `Export` icon) attached as JSON, if relevant

## Code of conduct

Be kind. Don't be a jerk. The usual.
