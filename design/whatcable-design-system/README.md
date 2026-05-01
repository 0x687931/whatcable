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
| `../../Sources/WhatCable/` | The production SwiftUI source, intentionally not duplicated in this design-system import. |
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

WhatCable looks quiet. The popover is mostly white space; status is carried by a single coloured glyph and one big number per port.

### Type
Geist for everything (Vercel, free, Google Fonts). Four roles:

| Role | Size / weight | Used for |
| --- | --- | --- |
| Value | 22 / 500 | The big readout. "30 W", "40 Gbps" |
| Name | 14 / 500 | Port label. "MagSafe" |
| Body | 13 / 400, secondary grey | Explanation. "Charging well" |
| Caption | 10 / 500, tracked, uppercase, tertiary | Title bar, section labels |

Tabular numerals on values: `font-feature-settings: "tnum"`. Numbers stay aligned without going mono.

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

### Status verdicts
The product asks one question per port: *is this OK?* Three answers, three glyphs:

- 🟢 **Tick in green circle**. working well
- 🟠 **Exclamation in orange circle**. limited / something to know
- 🔴 **Cross in red circle**. broken, swap something

Used on banners, port cards, and the popover. It's the most important visual system in the product.

### Spacing
Base unit is 4 px. Common rhythm: 4 / 8 / 12 / 16 / 22 / 32. Cards are 10 px radius. Banner badges are 24 px circles. Popover is 320 px wide.

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

Codebase: `0x687931/whatcable` on GitHub (MIT). Author: Darryl Morley. The repo is the only source of truth. there's no Figma, no separate brand guidelines, no marketing site.
