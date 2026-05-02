# WhatCable Design System

> What can this USB-C cable actually do?

WhatCable is a small macOS menu bar app that tells you, in plain English, what each USB-C cable plugged into your Mac can do. and why your laptop might be charging slowly. The whole product is one popover. No web app, no mobile, no marketing surface.

This design system is the kit for making more of it: more screens, more copy, more occasional marketing. all in the same voice and visual idiom.

## Design language. one line

**Minimal layout. Graphical status. Colourful only where it carries meaning. Text short and human.**

Every screen in WhatCable should pass these four tests:

1. **Minimal**. could you delete a word, a line, or a colour? Do it.
2. **Graphical**. the verdict (good / warning / bad) is readable as a coloured shape before any text is read.
3. **Colourful for status only**. neutrals everywhere else. Green/orange/red are reserved for the three states.
4. **Plain language**. short sentences. Watts and gigabits when useful. Never "PDO", never "negotiate", never "suboptimal".

## What's in here

| File | What it's for |
| --- | --- |
| `colors_and_type.css` | Colour and type tokens. Geist for everything; system colours adapt light/dark. |
| `assets/` | Icon notes and the reference popover screenshot. |
| `preview/` | One card per design-system surface (type, colour, voice, components). Registered for review. |
| `ui_kits/macos_popover/` | Click-through HTML recreation of the menubar popover. |
| `Sources/WhatCable/` | The production SwiftUI source, kept as the implementation reference. |
| `SKILL.md` | One-paragraph brief for picking up this system in a new chat. |

---

## Voice

A knowledgeable friend explaining what's happening. Short. Plain. No jargon, no exclamation marks, no "Smart" anything.

**Write like this:**
- Charging well at 30 W
- This cable can't go faster than 60 W
- Your charger could go up to 45 W. Your laptop isn't asking for it.
- Plug a cable in to see what it can do
- Cable connected upside down. that's fine

**Not like this:**
- ⚡ Smart charging detected!
- Cable performance is suboptimal
- Connect a USB-C Cable to Begin
- Oops! We couldn't read your cable.
- PDO 4 active: 20V @ 1.5A negotiated via PD 3.1

### Rules of thumb
- **Sentence case everywhere.** "Show technical details", not "Show Technical Details".
- **Second person.** "Your charger", not "the user's charger" or "we detected".
- **Specs only when they help.** `30 W` and `5 Gbps` are useful. `PDO 4` is not.
- **State the verdict first, the reason second.** "Cable limited to 60 W. Your charger could go faster."
- **The app is named WhatCable.** One word, two capitals. Never "Whatcable", never "What Cable".
- **British spelling** in long-form copy: "behaviour", "notarised". UI strings stay short enough that it rarely matters.
- **Don't hardcode "MacBook".** WhatCable runs on any Mac with USB-C: MacBook Pro, MacBook Air, Mac mini, Mac Studio, iMac. Query the machine type at runtime (`hw.model` / `IORegistry`) and use the actual product name, or fall back to a generic word.
  - Specific (preferred): "Your MacBook Pro isn't asking for it", "Your Mac Studio isn't asking for it"
  - Generic fallback: "Your Mac isn't asking for it"
  - Never: "Your MacBook isn't asking for it" (when we don't know that it is one)

### Punctuation
- Numbers and watts/volts/amps: tight. `30 W`, `20 V`, `5 Gbps`.
- Em-dash with spaces. like this. for asides.
- Middle-dot `·` between bits of metadata: `v0.2.0 · Bitmoor Ltd`.
- Ellipsis `…` only on menu items that open more UI (Apple HIG): `Check for updates…`.

---

## Look

WhatCable looks quiet. The popover is a tile grid: one tile per port, status carried by a single coloured glyph and one short headline per tile.

### Layout
- **320 px wide popover.** No footer.
- **2-column tile grid**, 8 px gap, 122 px min-height per tile, 10 px radius.
- **Header**: tracked uppercase wordmark · refresh · settings. No icon, no tagline.
- **Warning banners promoted** to the top of the scroll view when a port is in trouble.
- **"Show technical details"** expands a stacked detail section below the grid, not inline in tiles.

### Type
Geist for everything (Vercel, free, Google Fonts). Five roles, sized to the tile grid:

| Role | Size / weight | Tracking | Used for |
| --- | --- | --- | --- |
| Headline | 22 / 500 | -0.025em | Tile big readout. "Charging well", "30 W of 96 W" |
| Banner summary | 12 / 600 | normal | Diagnostic banner first line |
| Body | 12 / 400, secondary | normal | Banner detail, tile context |
| Eyebrow | 10 / 500, uppercase, tertiary | 0.08em | Port name, section label, wordmark |
| Active pill | 9 / 500, green | normal | Active PDO marker |

Tabular numerals on anything that's a number: `font-feature-settings: "tnum"`. Numbers stay aligned without going mono.

### Colour
System neutrals plus four state tints. No brand palette.

- **Primary text**. near-black `#0F1115`
- **Secondary**. ~60% black, for body
- **Tertiary**. ~35% black, for captions
- **Green** `#34C759`. good
- **Orange** `#FF9500`. warning / cable limited
- **Red** `#FF3B30`. bad
- **Neutral grey**. empty / inactive

Tints adapt light/dark. Don't introduce a new accent.

### Voice — two registers
Tile copy is the verdict, three to four words tops: *"Charging well"*, *"Cable can't go faster"*, *"USB device"*. Banner copy states the verdict first, then the reason and what to do: *"Cable is limiting charging speed. Charger can deliver up to 96 W, but this cable is only rated to carry 60 W. Replace the cable to charge faster."* No exclamation marks anywhere. No jargon.

### Status verdicts
The product asks one question per port: *is this OK?* In the tile grid, the answer rides on the icon colour:

- **Green bolt**. working well
- **Orange bolt**. limited / something to know
- **Black/primary glyph**. neutral data state (USB, Thunderbolt, Display)
- **Tertiary plug**. empty

Inside diagnostic banners, the verdict gets a 24 px filled circle badge with a white SF Symbol set on a 10 % tinted ground. Two states only: orange (warn) and green (ok). Red is reserved for hard errors (install failure, currently text-only).

### Spacing
Base unit is 4 px. Common rhythm: 4 / 8 / 12 / 16. Tiles are 10 px radius, 8 px gap. Banner ground is 8 px radius, 10 % tint. Banner badges are 24 px circles. Popover is 320 px wide.

### Surface
Sit on top of a system vibrant material (translucent white). don't paint it solid. Inside the popover, no shadows, no borders on tiles. Hairline dividers (`rgba(0,0,0,0.06)`) where separation is needed. That's it.

### Iconography
Six icons, no more. Each one means a single thing:

- **Bolt**. power flowing (colour carries the verdict)
- **USB trident** (the official USB-IF mark). data
- **Monitor**. display
- **Plug**. empty
- **Refresh**. refresh
- **Cog**. settings

Drawn at 24 px on a 1.5 px stroke, Lucide for utility, official trident for data. No emoji in product UI.

---

## Caveats

- **SF Pro and SF Mono aren't bundled** (Apple licence). Geist is the web substitute and now the canonical face for this system.
- **No imagery** in the kit. WhatCable doesn't ship marketing material; if it ever does, keep it clean cable photography on plain backgrounds.
- **Light mode previews only.** Dark tokens exist in `colors_and_type.css`.
- **Icons are Lucide stand-ins** for SF Symbols where the real glyphs would otherwise appear in mocks. Export from Apple's SF Symbols app for pixel fidelity.

---

## Source

Codebase: `0x687931/whatcable` on GitHub (MIT). Maintained by WhatCable contributors. The repo is the only source of truth. there's no Figma, no separate brand guidelines, no marketing site.
