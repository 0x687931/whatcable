/* global React, ReactDOM */

// ----- ICONS -------------------------------------------------------------
const Svg = ({ children, size = 22, fill = "none", stroke = "currentColor", sw = 1.5 }) => (
  <svg viewBox="0 0 24 24" width={size} height={size} fill={fill} stroke={stroke} strokeWidth={sw}
       strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">{children}</svg>
);

const Bolt = ({ size = 22, color = "currentColor" }) => (
  <svg viewBox="0 0 24 24" width={size} height={size} aria-hidden="true">
    <path d="M13 2 4 14h6.5l-1 8 9.5-12h-6.5l1-8z" fill={color}/>
  </svg>
);

const Cable = ({ size = 22, color = "currentColor" }) => (
  <svg viewBox="0 0 24 24" width={size} height={size} aria-hidden="true" fill="none"
       stroke={color} strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round">
    <circle cx="12" cy="20" r="1.6" fill={color}/>
    <path d="M12 20 V6"/>
    <path d="M12 6 9.5 9 M12 6 14.5 9"/>
    <path d="M12 12 7 14 V17"/>
    <rect x="5.5" y="14" width="3" height="3" fill={color} stroke="none"/>
    <path d="M12 14 17 11 V8.5"/>
    <circle cx="17" cy="7" r="1.4" fill={color}/>
  </svg>
);

const Display = ({ size = 22, color = "currentColor" }) => (
  <svg viewBox="0 0 24 24" width={size} height={size} fill="none"
       stroke={color} strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
    <rect x="3" y="4" width="18" height="12" rx="1.5"/>
    <path d="M9 21h6M12 16v5"/>
  </svg>
);

const Plug = ({ size = 22, color = "currentColor" }) => (
  <svg viewBox="0 0 24 24" width={size} height={size} fill="none"
       stroke={color} strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
    <path d="M9 3v6M15 3v6"/>
    <path d="M5 9h14v3a7 7 0 0 1-14 0z"/>
    <path d="M12 16v5"/>
  </svg>
);

const Externaldrive = (p) => <Svg {...p}><rect x="3" y="9" width="18" height="9" rx="2"/><circle cx="17" cy="13.5" r="0.8" fill="currentColor"/></Svg>;
const Gear = (p) => <Svg {...p} sw={1.6}><circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.7 1.7 0 0 0 .3 1.8l.1.1a2 2 0 1 1-2.8 2.8l-.1-.1a1.7 1.7 0 0 0-1.8-.3 1.7 1.7 0 0 0-1 1.5V21a2 2 0 1 1-4 0v-.1a1.7 1.7 0 0 0-1.1-1.5 1.7 1.7 0 0 0-1.8.3l-.1.1a2 2 0 1 1-2.8-2.8l.1-.1a1.7 1.7 0 0 0 .3-1.8 1.7 1.7 0 0 0-1.5-1H3a2 2 0 1 1 0-4h.1a1.7 1.7 0 0 0 1.5-1.1 1.7 1.7 0 0 0-.3-1.8l-.1-.1a2 2 0 1 1 2.8-2.8l.1.1a1.7 1.7 0 0 0 1.8.3H9a1.7 1.7 0 0 0 1-1.5V3a2 2 0 1 1 4 0v.1a1.7 1.7 0 0 0 1 1.5 1.7 1.7 0 0 0 1.8-.3l.1-.1a2 2 0 1 1 2.8 2.8l-.1.1a1.7 1.7 0 0 0-.3 1.8V9a1.7 1.7 0 0 0 1.5 1H21a2 2 0 1 1 0 4h-.1a1.7 1.7 0 0 0-1.5 1z"/></Svg>;
const ExclamGlyph = () => (
  <svg viewBox="0 0 24 24" width="12" height="12" aria-hidden="true">
    <path d="M12 5 V13" stroke="white" strokeWidth="2.6" strokeLinecap="round"/>
    <circle cx="12" cy="17.6" r="1.4" fill="white"/>
  </svg>
);
const TickGlyph = () => (
  <svg viewBox="0 0 24 24" width="12" height="12" aria-hidden="true" fill="none">
    <polyline points="6 12 10 16 18 8" stroke="white" strokeWidth="2.6" strokeLinecap="round" strokeLinejoin="round"/>
  </svg>
);

// ----- TILE STATE LOGIC --------------------------------------------------
function tileGlyph(p) {
  switch (p.kind) {
    case "empty":         return <Plug color="rgba(60,60,67,0.30)" />;
    case "charging-ok":   return <Bolt color="#34C759" />;
    case "charging-warn": return <Bolt color="#FF9500" />;
    case "data":          return <Cable color="rgba(0,0,0,0.85)" />;
    case "thunderbolt":   return <Cable color="rgba(0,0,0,0.85)" />;
    case "display":       return <Display color="rgba(0,0,0,0.85)" />;
    default:              return <Plug color="rgba(60,60,67,0.30)" />;
  }
}

function Tile({ port }) {
  const muted = port.kind === "empty";
  return (
    <div className={"tile" + (muted ? " empty" : "")}>
      <div className="tile-icon">{tileGlyph(port)}</div>
      <div className="tile-name">{port.name}</div>
      <div className="tile-headline">{port.headline}</div>
      {port.context && <div className="tile-context">{port.context}</div>}
    </div>
  );
}

function PortWarningBanner({ portName, summary, detail }) {
  return (
    <div className="pw">
      <div className="pw-label">{portName}</div>
      <div className="diag diag-warn">
        <div className="diag-badge"><ExclamGlyph /></div>
        <div>
          <div className="diag-summary">{summary}</div>
          <div className="diag-detail">{detail}</div>
        </div>
      </div>
    </div>
  );
}

// ----- FIXTURE -----------------------------------------------------------
// One canonical scenario. A MacBook Pro with a charger on MagSafe, a
// Thunderbolt dock on USB-C 1, a USB drive on USB-C 2, and two free ports.
// Includes a warning banner so every component is on screen.
const FIXTURE = {
  warnings: [
    { portName: "USB-C 1", summary: "Cable is limiting charging speed",
      detail: "Charger can deliver up to 96 W, but this cable is only rated to carry 60 W. Replace the cable to charge faster." },
  ],
  ports: [
    { name: "MagSafe", kind: "charging-warn", headline: "Cable can't go faster", context: "60 W of 96 W" },
    { name: "USB-C 1", kind: "thunderbolt",   headline: "Thunderbolt",           context: "40 Gbps" },
    { name: "USB-C 2", kind: "data",          headline: "USB device",            context: "5 Gbps" },
    { name: "USB-C 3", kind: "empty",         headline: "Empty",                 context: null },
  ],
};

// ----- APP ---------------------------------------------------------------
function App() {
  const f = FIXTURE;
  return (
    <div className="popover">
      <div className="window">
        <div className="header">
          <div className="wordmark">WhatCable</div>
          <div className="spacer" />
          <button className="iconbtn" title="Settings"><Gear size={14} /></button>
        </div>

        <div className="body">
          {f.warnings.map((w, i) => <PortWarningBanner key={i} {...w} />)}
          <div className="grid">
            {f.ports.map((p, i) => <Tile key={i} port={p} />)}
          </div>
        </div>
      </div>
    </div>
  );
}

document.querySelectorAll(".popover-mount").forEach((el) => {
  ReactDOM.createRoot(el).render(<App />);
});
