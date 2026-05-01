# WhatCable macOS Popover. UI Kit

A pixel-faithful HTML/JSX recreation of the WhatCable popover (760×540, light mode) plus a Settings sub-view. Components are factored loosely matching the SwiftUI source under `Sources/WhatCable/`.

- `index.html`. entry, loads React + Babel + the JSX components
- `App.jsx`. top-level state machine (main / settings)
- `PopoverChrome.jsx`. `NSPopover` macOS chrome with arrow + vibrant material
- `Header.jsx` / `Footer.jsx`
- `PortCard.jsx`. per-port card
- `DiagnosticBanner.jsx` / `UpdateBanner.jsx`
- `PowerSourceList.jsx`. PDO rows
- `SettingsView.jsx`
- `Icons.jsx`. inline SVG SF Symbol stand-ins
- `data.js`. mock cable / port / PDO state

Click "Refresh" or the menu bar to cycle through fixture states.
