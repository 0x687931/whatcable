---
name: whatcable-design
description: Use this skill to generate well-branded interfaces and assets for WhatCable, either for production or throwaway prototypes/mocks/etc. Contains essential design guidelines, colors, type, fonts, assets, and UI kit components for prototyping.
user-invocable: true
---

Read the README.md file within this skill, and explore the other available files.

WhatCable is a SwiftUI macOS menu bar app. The visual language is **native macOS**. SF Pro, SF Symbols, system tints, vibrant materials. Do not invent a custom palette, do not add gradients or emoji, do not use a marketing voice.

Key files:
- `README.md`. voice, visual foundations, iconography. Read first.
- `colors_and_type.css`. design tokens, drop-in CSS vars.
- `../../Sources/WhatCable/`. production SwiftUI source, source of truth. This design-system import does not duplicate it.
- `ui_kits/macos_popover/`. pixel-faithful HTML/JSX recreation of the popover.
- `preview/`. reference cards for every token and component.
- `assets/icons/sf-to-lucide.md`. substitution map for SF Symbols.

If creating visual artifacts (slides, mocks, throwaway prototypes, etc), copy assets out of this skill and create static HTML files for the user to view, importing `colors_and_type.css` and the popover components. If working on production code, copy the SwiftUI sources as reference and read the rules in README.md to become an expert in designing with this brand.

If the user invokes this skill without any other guidance, ask them what they want to build or design (a marketing site? release notes card? changelog? a new popover screen?), ask some questions, and act as an expert designer who outputs HTML artifacts _or_ Swift/SwiftUI code, depending on the need.
