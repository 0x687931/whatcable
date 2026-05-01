# Fonts

WhatCable uses **system fonts only**:

- **SF Pro** (text body) — set automatically by SwiftUI on macOS 14+.
- **SF Mono** (raw IOKit values, monospaced digits in PDO rows) — `.font(.system(.caption, design: .monospaced))`.

Apple does not redistribute SF Pro / SF Mono as web fonts and they are not on Google Fonts. We do **not** ship font files in this folder.

## Web substitution

`colors_and_type.css` falls back through the standard Apple system stack:

```
-apple-system, BlinkMacSystemFont, "SF Pro Text", "SF Pro",
"Helvetica Neue", "Segoe UI", Roboto, system-ui, sans-serif
```

On macOS this resolves to SF Pro automatically. On other platforms it falls back to the platform's UI font (Segoe UI / Roboto / Inter on Android Chrome). For pixel-perfect screenshots, **render in a Mac browser** so the system stack picks up SF Pro natively.

> ⚠️ **Substitution flagged.** If you need WhatCable mockups to render with SF Pro on Linux/Windows or in PDFs, ask the user to provide the SF Pro / SF Mono font files (Apple ships them via the [SF Pro download page](https://developer.apple.com/fonts/) under their EULA — they cannot be redistributed in this project).
