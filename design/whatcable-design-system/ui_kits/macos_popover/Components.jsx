/* global React, Icons, STATUS_ICON */

function Header({ deviceCount, version, onRefresh, onSettings }) {
  return (
    <div className="wc-header">
      <Icons.CableConnector size={22} />
      <div className="wc-header-titles">
        <div className="wc-header-name">WhatCable</div>
        <div className="wc-header-tagline">What can this USB-C cable actually do?</div>
      </div>
      <div className="wc-header-spacer" />
      <button className="wc-iconbtn" title="Refresh" onClick={onRefresh}><Icons.Refresh size={16} /></button>
      <button className="wc-iconbtn" title="Settings" onClick={onSettings}><Icons.Gear size={16} /></button>
    </div>
  );
}

function Footer({ deviceCount, version }) {
  const s = deviceCount === 1 ? "" : "s";
  return (
    <div className="wc-footer">
      <span className="wc-footer-meta">{deviceCount} USB device{s}</span>
      <span className="wc-footer-dot">·</span>
      <span className="wc-footer-meta-faint">v{version} · Bitmoor Ltd</span>
    </div>
  );
}

function UpdateBanner({ version, current, onView, onInstall }) {
  return (
    <div className="wc-update">
      <span className="wc-update-icon"><Icons.ArrowDownCircleFill size={16} /></span>
      <div className="wc-update-text">
        <div className="wc-update-title">WhatCable {version} is available</div>
        <div className="wc-update-sub">You're on {current}</div>
      </div>
      <div className="wc-header-spacer" />
      <button className="wc-btn" onClick={onView}>View release</button>
      <button className="wc-btn wc-btn-prom" onClick={onInstall}>Install update</button>
    </div>
  );
}

function DiagnosticBanner({ kind, summary, detail }) {
  const isWarn = kind === "warn";
  const I = isWarn ? Icons.WarnFill : Icons.SealFill;
  const cls = isWarn ? "wc-diag wc-diag-warn" : "wc-diag wc-diag-ok";
  return (
    <div className={cls}>
      <span className="wc-diag-icon"><I size={16} /></span>
      <div>
        <div className="wc-diag-summary">{summary}</div>
        <div className="wc-diag-detail">{detail}</div>
      </div>
    </div>
  );
}

function PowerSourceList({ pdos }) {
  return (
    <div className="wc-pdos">
      <div className="wc-pdos-label">USB-PD profiles</div>
      {pdos.map((p, i) => (
        <div key={i} className="wc-pdo-row">
          {p.active
            ? <span className="wc-pdo-on"><Icons.CheckCircleFill size={12} /></span>
            : <span className="wc-pdo-off"><Icons.Circle size={12} /></span>}
          <span className="wc-pdo-text">{p.v} @ {p.a} - {p.w}</span>
          {p.active && <span className="wc-pdo-active">active</span>}
        </div>
      ))}
    </div>
  );
}

function PortCard({ port, showAdvanced }) {
  const { I, color } = STATUS_ICON[port.status] || STATUS_ICON.unknown;
  return (
    <div className="wc-card">
      <div className="wc-card-head">
        <div className="wc-card-icon" style={{ color }}><I size={28} /></div>
        <div className="wc-card-titles">
          <div className="wc-card-meta">{port.name}</div>
          <div className="wc-card-headline">{port.headline}</div>
          <div className="wc-card-sub">{port.subtitle}</div>
        </div>
      </div>
      {port.bullets && port.bullets.length > 0 && (
        <ul className="wc-card-bullets">
          {port.bullets.map((b, i) => <li key={i}>{b}</li>)}
        </ul>
      )}
      {port.diagnostic && (
        <div className="wc-card-indent"><DiagnosticBanner {...port.diagnostic} /></div>
      )}
      {port.pdos && (
        <div className="wc-card-indent"><PowerSourceList pdos={port.pdos} /></div>
      )}
    </div>
  );
}

function SettingsView({ showAdvanced, setShowAdvanced, onDone, settings, setSettings }) {
  const Toggle = ({ on, onChange, label, sub }) => (
    <div className="wc-tog-row">
      <div>
        <div className="wc-tog-label">{label}</div>
        {sub && <div className="wc-tog-sub">{sub}</div>}
      </div>
      <button className={"wc-switch" + (on ? " on" : "")} onClick={() => onChange(!on)} role="switch" aria-checked={on}/>
    </div>
  );
  return (
    <div className="wc-settings">
      <div className="wc-settings-header">
        <Icons.Gear size={20} />
        <div className="wc-settings-title">Settings</div>
        <div className="wc-header-spacer" />
        <button className="wc-btn wc-btn-prom" onClick={onDone}>Done</button>
      </div>
      <hr className="wc-divider" />
      <div className="wc-settings-body">
        <div className="wc-settings-section">
          <div className="wc-section-label">Display</div>
          <Toggle on={showAdvanced} onChange={setShowAdvanced} label="Show technical details" />
          <Toggle on={settings.hideEmpty} onChange={v => setSettings({ ...settings, hideEmpty: v })} label="Hide empty ports" />
        </div>
        <div className="wc-settings-section">
          <div className="wc-section-label">Behavior</div>
          <Toggle on={settings.launchAtLogin} onChange={v => setSettings({ ...settings, launchAtLogin: v })} label="Launch at login" />
          <Toggle on={settings.menuBar} onChange={v => setSettings({ ...settings, menuBar: v })} label="Show in menu bar"
            sub={settings.menuBar ? "Lives in the menu bar with no Dock icon." : "Runs as a regular Dock app with a window."} />
        </div>
        <div className="wc-settings-section">
          <div className="wc-section-label">Notifications</div>
          <Toggle on={settings.notify} onChange={v => setSettings({ ...settings, notify: v })} label="Notify on cable changes" />
        </div>
      </div>
    </div>
  );
}

window.Header = Header;
window.Footer = Footer;
window.UpdateBanner = UpdateBanner;
window.DiagnosticBanner = DiagnosticBanner;
window.PowerSourceList = PowerSourceList;
window.PortCard = PortCard;
window.SettingsView = SettingsView;
