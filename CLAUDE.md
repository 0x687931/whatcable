# WhatCable

A macOS menu bar app that reads USB-C / MagSafe port state from IOKit and reports, in plain English, what each connected cable can do and why charging or data might be slow. Distributed as a notarised `.app` and a bundled CLI.

## Stack

- Swift 5.9+, SwiftUI, AppKit (NSPopover / NSStatusItem)
- Swift Package Manager (no Xcode project committed)
- macOS 14+ only. Apple Silicon only (Intel Macs route USB-C through Titan Ridge / JHL9580 chips that don't expose PD or e-marker data via public IOKit accessors)
- No entitlements, no private APIs, no helper daemons. App Store distribution is blocked by App Sandbox restricting IOKit reads.

## Layout

- `Sources/WhatCable/` is the main app target (UI + glue).
- `Sources/WhatCableCore/` is the shared engine consumed by both the menu bar app and the CLI. Anything that decodes IOKit, PD VDOs, or generates plain-English summaries belongs here.
- `Sources/whatcable-cli/` is the CLI executable. It links `WhatCableCore` and prints human or `--json` output.
- `Tests/WhatCableTests/` is XCTest. Run with `swift test`. There are 49 tests covering vendor lookup, port summary, JSON formatting, update checker version comparison, and AppInfo path walking.

## Key files

- [App.swift](Sources/WhatCable/App.swift): NSApplicationDelegate, status item, popover lifecycle, `RefreshSignal` (ephemeral UI state).
- [ContentView.swift](Sources/WhatCable/ContentView.swift): main popover layout. Owns the four watchers as `@StateObject`.
- [USBCPortWatcher.swift](Sources/WhatCable/USBCPortWatcher.swift): port enumeration via `AppleHPMInterfaceType10/11/12` and `AppleTCControllerType10`.
- [USBWatcher.swift](Sources/WhatCable/USBWatcher.swift): `IOUSBHostDevice` enumeration. Currently surfaces all devices on every active port (intentional fallback, see #10's four-layer plan for the proper port-to-device mapping).
- [PortSummary.swift](Sources/WhatCable/PortSummary.swift): the plain-English logic. The headline + bullets come from here.
- [PDVDO.swift](Sources/WhatCable/PDVDO.swift): bit-twiddling for PD Discover Identity VDOs.
- [AppSettings.swift](Sources/WhatCable/AppSettings.swift): UserDefaults-backed persistent preferences.
- [scripts/release.sh](scripts/release.sh): end-to-end release script. Read this before shipping.
- [scripts/build-app.sh](scripts/build-app.sh): build, sign, notarise, smoke-test. Holds the `VERSION` and `BUILD_NUMBER` (single source of truth).

## Building and testing

```bash
swift build                  # menu bar app + CLI, debug
swift test                   # XCTest suite
swift run WhatCable          # menu bar app from source
swift run whatcable-cli      # CLI from source
./scripts/build-app.sh       # universal signed + notarised .app + .zip in dist/
```

Always run `swift test` before committing UI / engine changes. Tests are fast (under a second).

## Release flow

The release pipeline is fully scripted by [scripts/release.sh](scripts/release.sh). **Don't bump the version manually beforehand**; the script handles that as one of its steps. Usage:

```bash
./scripts/release.sh --dry-run 0.5.4   # validate state without side effects
./scripts/release.sh 0.5.4             # ship for real
```

What it does, in order:

1. **Sanity checks**: clean tree, on `main`, tag doesn't already exist, `gh` authed, `release-notes/v<version>.md` present, optional tap dir clean.
2. **Bumps `VERSION` and `BUILD_NUMBER`** in `scripts/build-app.sh` and commits the bump.
3. **Builds, signs (Developer ID, hardened runtime), notarises (5 to 10 minutes), staples, and smoke-tests** the `.app` and CLI.
4. **Tags `v<version>` and pushes `main` + tag** to origin.
5. **Creates the GitHub release** via `gh release create` with the zip and the notes file as body.
6. **Verifies the uploaded asset's sha matches** the locally built one.
7. **Syncs the release notes into the Homebrew tap**, amends the cask commit with them, force-pushes the tap.

Pre-requisites:

- `release-notes/v<version>.md` must exist locally. The directory is gitignored intentionally; it's a local working area.
- The first line of the notes file (after stripping `#` markers) becomes the GitHub release title suffix. Convention: `## What's fixed` or `## What's new`.
- `.env` must contain `DEVELOPER_ID` and `NOTARY_PROFILE`. `TAP_DIR` is optional but expected on this machine for the cask sync.
- Be on `main`, clean tree.

The in-app updater polls GitHub releases and shows users a banner when a new tag appears. Existing users will see the update offer within minutes of the release going live.

## Conventions

- **Visible-to-users actions need explicit go-ahead each time.** Releases, GitHub issue closes / comments, README changes pushed to `main`. The user has active users on this app, so don't blanket-assume prior approval carries.
- **Don't commit planning, design, or analysis documents.** Per global memory, those stay uncommitted unless the user says otherwise. Issue bodies and PR descriptions are the right place for design discussion.
- **No em-dashes anywhere.** Per global memory, banned in writing across all projects, code and prose. Use commas, semicolons, or restructure sentences.
- **Match existing patterns over introducing new ones.** Watchers follow a consistent shape (start / stop / refresh, IOKit notification port + iterators). New watchers should mirror that.
- **README as audience-facing docs.** It's the first thing users read on the GitHub repo. Keep the tone friendly and concrete. Caveats list is doing real work managing expectations; add to it when a real-world limitation surfaces.

## Open architectural work

[#10](https://github.com/darrylmorley/whatcable/issues/10) is the next big piece. It bundles three related changes:

1. **Four-layer connection diagnostic** (host / cable / device / negotiated) replacing the current "what is this cable" framing.
2. **E-marker verification badge** (green / amber / red on the cable row) flagging implausible VID-vs-capability combinations. Framed as verification of the chip's claims, not authentication of the cable.
3. **Session-quality monitoring** layered on the negotiated row. Snapshot `plugEventCount` / `overcurrentCount` / `connectionCount` at connection start, watch deltas while `connectionActive` stays true, surface a banner only when something happened mid-session.

Active benchmarks (deliberate load-push to truth-test claimed speed and power) are deferred until passive #10 work lands and we see what users actually ask for. iPhone-as-test-target was investigated; deep dive lives in the conversation thread that produced #10.

## Out of scope

- Anything iOS, including a companion app. iOS sandboxing blocks the IOKit / PD / e-marker reads we'd need.
- Intel Mac support. The relevant data isn't exposed there.
- App Store distribution. App Sandbox blocks our IOKit reads.
- True counterfeit detection (a well-cloned e-marker is software-indistinguishable from a real one).
