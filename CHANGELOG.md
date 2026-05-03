# Changelog

All notable changes to SpawnWatch are documented here. The format follows [Keep a Changelog](https://keepachangelog.com/) and the project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

## [0.1.0] — 2026-05-03

### Added
- **Real-time process spawn monitor** with `eslogger`-backed `exec` / `fork` / `exit` events and a `libproc` polling fallback when admin auth is denied.
- **App attribution** — every spawn is mapped to its owning macOS app bundle and classified by relationship (XPC service, app extension, helper, framework service, direct child, system).
- **Process lifecycle tracking** — composite `(pid, spawnTime)` keys eliminate PID-reuse corruption. Each `ProcessRecord` carries spawn time, exit time, exit code, terminating signal, and live duration.
- **Code-signing trust info** — async `SecStaticCode`-based inspection with caching. Surfaces signing type, team ID, authority chain, hardened runtime, library validation, sandbox status, cdhash, and SHA-256.
- **Lineage view** — full ancestor chain back to launchd, with depth cap.
- **Trace mode** — bracketed capture sessions persisted to `~/Library/Application Support/SpawnWatch/Traces/`. Each saved trace shows scoped tree, durations, exit codes, signing badges, and aggregate stats.
- **Trace diff** — side-by-side comparison of two saved sessions. Multiset diff over `(parent, child, normalized_argv)` with PID, tmp path, ISO timestamp, and hex normalization.
- **UI**: toolbar record control with pulsing recording indicator, three-pane navigation (Apps / Process tree / Traces), filter chips, status pills, beautiful section cards with tinted borders.
- Pause/resume that buffers events instead of dropping them.
- JSON export of visible events.
- Build script `Scripts/build-app.sh` produces an unsigned `SpawnWatch.app` bundle. Pass `--universal` for an arm64 + x86_64 fat binary.
- GitHub Actions workflows for CI (build + test on every push/PR) and Release (universal `arm64 + x86_64` `.app` automatically built and attached to GitHub Releases on `v*.*.*` tags, with SHA-256 in release notes).

### Architecture
- Two SPM targets: `SpawnWatchCore` (UI-free library) and `SpawnWatch` (SwiftUI app).
- `@MainActor @Observable` store with incremental tree maintenance — no more O(n) rebuild per event.
- Composite monitor with real dedup via 500 ms window keyed on `(pid, eventType)`.

### Tests
- **98 tests across 16 suites** covering parsing, store ingestion lifecycle, code-signing inspection on real system binaries, trace persistence round-trip, dedupe actor behavior, backward-compatible decoding of v0.1 export fixtures, and edge cases for bundle resolution and trace diffing. CI runs the full suite on every push.

[Unreleased]: https://github.com/sanjevirau/spawn-app/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/sanjevirau/spawn-app/releases/tag/v0.1.0
