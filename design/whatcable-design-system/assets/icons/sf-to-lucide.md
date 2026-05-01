# SF Symbols → Lucide map

WhatCable uses SF Symbols natively. For HTML mocks we substitute Lucide icons (CDN: `https://unpkg.com/lucide-static@latest/icons/<name>.svg`). Closest visual match per symbol; **flagged as a substitution** — for pixel-perfect mocks, export the real SF Symbol from Apple's SF Symbols app and drop it into this folder.

| SF Symbol | Lucide name | Notes |
| --- | --- | --- |
| `cable.connector.horizontal` | `cable` | Lucide is a generic patch cord; SF shows a USB-C plug. |
| `cable.connector` | `usb` | Lucide `usb` is a USB-A icon — closer than `cable` for the menu bar glyph but still imperfect. |
| `bolt.fill` | `zap` (filled) | Apply `fill="currentColor"` and `stroke="none"` for the filled variant. |
| `bolt.horizontal.fill` | `zap` rotated 90° | Or use `arrow-right-from-line` for a flatter look. |
| `display` | `monitor` | |
| `powerplug` | `plug` | |
| `questionmark.circle` | `circle-help` | |
| `arrow.clockwise` | `rotate-cw` | |
| `gearshape` | `settings` | |
| `arrow.down.circle.fill` | `arrow-down-circle` | Add `fill="currentColor"`. |
| `exclamationmark.triangle.fill` | `triangle-alert` | |
| `checkmark.seal.fill` | `badge-check` | Filled. |
| `checkmark.circle.fill` | `circle-check` (filled) | |
| `circle` (empty) | `circle` | |

## Usage pattern

```html
<img src="https://unpkg.com/lucide-static@latest/icons/zap.svg"
     width="28" height="28"
     style="filter: invert(0); color: var(--tint-yellow);"
     alt="">
```

For colourable icons, prefer inline SVG with `stroke="currentColor"` so `color:` cascades. Inline templates live in `ui_kits/macos_popover/icons.jsx`.
