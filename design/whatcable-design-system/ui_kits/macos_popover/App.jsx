/* global React, ReactDOM */
const Svg = ({ children, size = 22, fill = "none", stroke = "currentColor", sw = 1.5 }) => (
  <svg viewBox="0 0 24 24" width={size} height={size} fill={fill} stroke={stroke} strokeWidth={sw} strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">{children}</svg>
);

// Filled green/orange/red electric bolt. single shape, color-driven.
const Bolt = ({ size = 22, color }) => (
  <svg viewBox="0 0 24 24" width={size} height={size} aria-hidden="true">
    <path d="M13 2 4 14h6.5l-1 8 9.5-12h-6.5l1-8z" fill={color}/>
  </svg>
);

// USB SuperSpeed trident
const UsbLogo = ({ size = 22, color = "currentColor" }) => (
  <svg viewBox="0 0 24 24" width={size} height={size} aria-hidden="true" fill="none" stroke={color} strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round">
    <circle cx="12" cy="20" r="1.6" fill={color}/>
    <path d="M12 20 V6"/>
    <path d="M12 6 9.5 9 M12 6 14.5 9" />
    <path d="M12 12 7 14 V17" />
    <rect x="5.5" y="14" width="3" height="3" fill={color} stroke="none"/>
    <path d="M12 14 17 11 V8.5" />
    <circle cx="17" cy="7" r="1.4" fill={color}/>
  </svg>
);

// Display monitor
const Display = ({ size = 22, color = "currentColor" }) => (
  <svg viewBox="0 0 24 24" width={size} height={size} fill="none" stroke={color} strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
    <rect x="3" y="4" width="18" height="12" rx="1.5"/><path d="M9 21h6M12 16v5"/>
  </svg>
);

const Plug = ({ size = 22, color = "currentColor" }) => (
  <svg viewBox="0 0 24 24" width={size} height={size} fill="none" stroke={color} strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
    <path d="M9 3v6M15 3v6"/><path d="M5 9h14v3a7 7 0 0 1-14 0z"/><path d="M12 16v5"/>
  </svg>
);

const Refresh = (p) => <Svg {.p}><path d="M21 12a9 9 0 1 1-3-6.7L21 8"/><path d="M21 3v5h-5"/></Svg>;
const Gear = (p) => <Svg {.p}><circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.7 1.7 0 0 0 .3 1.8l.1.1a2 2 0 1 1-2.8 2.8l-.1-.1a1.7 1.7 0 0 0-1.8-.3 1.7 1.7 0 0 0-1 1.5V21a2 2 0 1 1-4 0v-.1a1.7 1.7 0 0 0-1.1-1.5 1.7 1.7 0 0 0-1.8.3l-.1.1a2 2 0 1 1-2.8-2.8l.1-.1a1.7 1.7 0 0 0 .3-1.8 1.7 1.7 0 0 0-1.5-1H3a2 2 0 1 1 0-4h.1a1.7 1.7 0 0 0 1.5-1.1 1.7 1.7 0 0 0-.3-1.8l-.1-.1a2 2 0 1 1 2.8-2.8l.1.1a1.7 1.7 0 0 0 1.8.3H9a1.7 1.7 0 0 0 1-1.5V3a2 2 0 1 1 4 0v.1a1.7 1.7 0 0 0 1 1.5 1.7 1.7 0 0 0 1.8-.3l.1-.1a2 2 0 1 1 2.8 2.8l-.1.1a1.7 1.7 0 0 0-.3 1.8V9a1.7 1.7 0 0 0 1.5 1H21a2 2 0 1 1 0 4h-.1a1.7 1.7 0 0 0-1.5 1z"/></Svg>;

const FIXTURES = [
  { key: "P1", name: "MagSafe", value: "30 W", verdict: "Charging well", status: "ok" },
  { key: "P2", name: "Thunderbolt 4", value: "40 Gbps", verdict: "Thunderbolt", status: "data" },
  { key: "P3", name: "Thunderbolt 4", value: "5 Gbps", verdict: "USB device", status: "data" },
  { key: "P4", name: "Thunderbolt 4", value: "60 W", verdict: "Cable limited", status: "warn" },
  { key: "P5", name: "HDMI", value: "4K", verdict: "Display", status: "display" },
  { key: "P6", name: "Thunderbolt 4", value: ".", verdict: "Empty", status: "empty" },
];

function statusGlyph(status) {
  if (status === "ok") return <Bolt color="#34C759" />;
  if (status === "warn") return <Bolt color="#FF9500" />;
  if (status === "bad") return <Bolt color="#FF3B30" />;
  if (status === "data") return <UsbLogo color="var(--fg-primary)" />;
  if (status === "display") return <Display color="var(--fg-primary)" />;
  return <Plug color="var(--fg-tertiary)" />;
}

function Tile({ port }) {
  const muted = port.status === "empty";
  return (
    <div className={"tile" + (muted ? " muted" : "")}>
      <div className="tile-icon">{statusGlyph(port.status)}</div>
      <div className="tile-name">{port.name}</div>
      <div className="tile-value">{port.value}</div>
      <div className="tile-verdict">{port.verdict}</div>
    </div>
  );
}

function App() {
  const [tick, setTick] = React.useState(0);
  return (
    <div className="popover">
      <div className="arrow" />
      <div className="window">
        <div className="header">
          <div className="title">WhatCable</div>
          <div className="spacer" />
          <button className="iconbtn" title="Refresh" onClick={() => setTick(tick + 1)}><Refresh size={14} /></button>
          <button className="iconbtn" title="Settings"><Gear size={14} /></button>
        </div>
        <div className="grid">
          {FIXTURES.map((p) => <Tile key={p.key} port={p} />)}
        </div>
      </div>
    </div>
  );
}

ReactDOM.createRoot(document.getElementById("root")).render(<App />);
