/* global React */
// SF Symbol stand-ins as inline SVG. stroke="currentColor" so color: cascades.
const Svg = ({ children, size = 22, fill = "none", stroke = "currentColor", sw = 2 }) => (
  <svg viewBox="0 0 24 24" width={size} height={size} fill={fill} stroke={stroke} strokeWidth={sw} strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">{children}</svg>
);

const Icons = {
  CableConnector: (p) => <Svg {...p}><path d="M4 12h12"/><circle cx="20" cy="12" r="2" fill="currentColor" stroke="none"/><rect x="2" y="9" width="3" height="6" rx="1" fill="currentColor" stroke="none"/></Svg>,
  BoltFill: (p) => <Svg fill="currentColor" stroke="none" {...p}><path d="M13 2 4 14h7l-1 8 9-12h-7l1-8z"/></Svg>,
  BoltHorizFill: (p) => <Svg fill="currentColor" stroke="none" {...p}><path d="M3 11l8-6v4h10v4H11v4z"/></Svg>,
  Display: (p) => <Svg {...p}><rect x="2" y="4" width="20" height="13" rx="2"/><path d="M9 21h6M12 17v4"/></Svg>,
  Powerplug: (p) => <Svg {...p}><path d="M9 3v6M15 3v6"/><path d="M5 9h14v3a7 7 0 0 1-14 0z"/><path d="M12 16v5"/></Svg>,
  Question: (p) => <Svg {...p}><circle cx="12" cy="12" r="9"/><path d="M9.5 9a2.5 2.5 0 0 1 5 0c0 1.5-2.5 2-2.5 4M12 17.5v.01"/></Svg>,
  Refresh: (p) => <Svg {...p} sw={2}><path d="M21 12a9 9 0 1 1-3-6.7L21 8"/><path d="M21 3v5h-5"/></Svg>,
  Gear: (p) => <Svg {...p} sw={1.6}><circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.7 1.7 0 0 0 .3 1.8l.1.1a2 2 0 1 1-2.8 2.8l-.1-.1a1.7 1.7 0 0 0-1.8-.3 1.7 1.7 0 0 0-1 1.5V21a2 2 0 1 1-4 0v-.1a1.7 1.7 0 0 0-1.1-1.5 1.7 1.7 0 0 0-1.8.3l-.1.1a2 2 0 1 1-2.8-2.8l.1-.1a1.7 1.7 0 0 0 .3-1.8 1.7 1.7 0 0 0-1.5-1H3a2 2 0 1 1 0-4h.1a1.7 1.7 0 0 0 1.5-1.1 1.7 1.7 0 0 0-.3-1.8l-.1-.1a2 2 0 1 1 2.8-2.8l.1.1a1.7 1.7 0 0 0 1.8.3H9a1.7 1.7 0 0 0 1-1.5V3a2 2 0 1 1 4 0v.1a1.7 1.7 0 0 0 1 1.5 1.7 1.7 0 0 0 1.8-.3l.1-.1a2 2 0 1 1 2.8 2.8l-.1.1a1.7 1.7 0 0 0-.3 1.8V9a1.7 1.7 0 0 0 1.5 1H21a2 2 0 1 1 0 4h-.1a1.7 1.7 0 0 0-1.5 1z"/></Svg>,
  ArrowDownCircleFill: (p) => <Svg fill="currentColor" stroke="none" {...p}><circle cx="12" cy="12" r="10"/><path d="M12 7v8M8 11l4 4 4-4" stroke="white" strokeWidth="2.2" fill="none" strokeLinecap="round" strokeLinejoin="round"/></Svg>,
  WarnFill: (p) => <Svg fill="currentColor" stroke="none" {...p}><path d="M12 2 1 21h22z"/><path d="M12 9v6M12 17.5v.01" stroke="white" strokeWidth="2.2" strokeLinecap="round" fill="none"/></Svg>,
  SealFill: (p) => <Svg fill="currentColor" stroke="none" {...p}><path d="M12 2l2.5 2.5L18 4l1 3.5L21.5 9 21 12.5 22.5 16 20 18l-1 3.5-3.5-.5L12 23l-3.5-2L5 21.5 4 18l-2.5-2L3 12.5 1.5 9 4 7.5 5 4l3.5.5z"/><path d="M8.5 12l2.5 2.5L15.5 10" stroke="white" strokeWidth="2.2" fill="none" strokeLinecap="round" strokeLinejoin="round"/></Svg>,
  CheckCircleFill: (p) => <Svg fill="currentColor" stroke="none" {...p}><circle cx="12" cy="12" r="10"/><path d="M8 12l3 3 5-6" stroke="white" strokeWidth="2.2" fill="none" strokeLinecap="round" strokeLinejoin="round"/></Svg>,
  Circle: (p) => <Svg {...p}><circle cx="12" cy="12" r="9"/></Svg>,
};

const STATUS_ICON = {
  charging: { I: Icons.BoltFill, color: "var(--tint-yellow)" },
  data: { I: Icons.CableConnector, color: "var(--tint-blue)" },
  thunderbolt: { I: Icons.BoltHorizFill, color: "var(--tint-purple)" },
  display: { I: Icons.Display, color: "var(--tint-teal)" },
  empty: { I: Icons.Powerplug, color: "var(--fg-secondary)" },
  unknown: { I: Icons.Question, color: "var(--tint-orange)" },
};

window.Icons = Icons;
window.STATUS_ICON = STATUS_ICON;
