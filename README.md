# WhatCable

A small macOS menu bar app that tells you, in plain English, what each USB-C cable plugged into your Mac can actually do.

> What can this USB-C cable actually do?

USB-C cables are notoriously hard to tell apart at a glance — the same connector covers everything from USB 2.0 charge-only cables to 240W / 40 Gbps Thunderbolt 4. macOS already exposes most of the relevant info via IOKit; WhatCable surfaces it in a friendly menu bar popover.

## What it shows

For each USB-C / MagSafe port:

- Whether anything is connected
- A plain-English headline (Thunderbolt / USB4, USB device, Charging only, Slow USB / charge-only cable, …)
- Whether the cable carries an e-marker chip
- Active transports (USB 2 / USB 3 / Thunderbolt / DisplayPort)
- Connected USB devices
- A "Show technical details" toggle that reveals the underlying IOKit properties

## Run from source

```bash
swift run WhatCable
```

Requires macOS 14+ and Swift 5.9 (Xcode 15+).

## Build a distributable .app

```bash
./scripts/build-app.sh
```

This produces a universal `dist/WhatCable.app` (arm64 + x86_64) and `dist/WhatCable.zip`.

**Modes:**

| Configuration | Result |
| --- | --- |
| No `.env` | Ad-hoc signed. Works locally; Gatekeeper warns on other Macs. |
| `.env` with `DEVELOPER_ID` | Developer ID signed + hardened runtime. Suitable for limited distribution. |
| `.env` with `DEVELOPER_ID` + `NOTARY_PROFILE` | Full notarisation + stapled ticket. Gatekeeper-clean for everyone. |

**One-time setup for full notarisation:**

```bash
# Find your signing identity
security find-identity -v -p codesigning

# Store notarytool credentials in the keychain
xcrun notarytool store-credentials "WhatCable-notary" \
    --apple-id "you@example.com" \
    --team-id "ABCDE12345" \
    --password "<app-specific-password>"   # from appleid.apple.com

# Then create .env from the template
cp .env.example .env
# ...and fill in DEVELOPER_ID
```

To install locally:

```bash
cp -R dist/WhatCable.app /Applications/
```

## What's not implemented yet

- Specific cable speed numbers (10 / 20 / 40 Gbps) — needs PD VDO parsing from child IOKit services.
- Specific power numbers (60W / 100W / 240W) — same.
- Notarisation. The build is ad-hoc signed, which is fine for personal use but Gatekeeper will warn on first launch.
- An iOS version. iOS sandboxing makes USB-C e-marker access much harder; this is macOS-only for now.

## Credits

Built by Bitmoor Ltd.
