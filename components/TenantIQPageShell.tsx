'use client';

import { useEffect, useState } from "react";
import { createPortal } from "react-dom";
import TenantIQLandingV2 from "./TenantIQLandingV2";

type PageMode = "home" | "product" | "details";
type WorkloadKind = "entra" | "exchange" | "sharepoint" | "teams" | "onedrive" | "intune" | "defender" | "purview";

const TRUST_STATS = [
  { value: "350+", label: "automated checks", icon: "shield" },
  { value: "8", label: "workloads", icon: "grid" },
  { value: "Read-only", label: "access", icon: "eye" },
  { value: "No", label: "configuration changes", icon: "lock" },
];

const WORKLOADS: { name: string; kind: WorkloadKind }[] = [
  { name: "Entra ID", kind: "entra" },
  { name: "Exchange Online", kind: "exchange" },
  { name: "SharePoint", kind: "sharepoint" },
  { name: "Teams", kind: "teams" },
  { name: "OneDrive", kind: "onedrive" },
  { name: "Intune", kind: "intune" },
  { name: "Defender", kind: "defender" },
  { name: "Purview", kind: "purview" },
];

function TrustIcon({ type }: { type: string }) {
  if (type === "grid") {
    return <svg viewBox="0 0 24 24"><rect x="3" y="3" width="7" height="7" rx="1"/><rect x="14" y="3" width="7" height="7" rx="1"/><rect x="3" y="14" width="7" height="7" rx="1"/><rect x="14" y="14" width="7" height="7" rx="1"/></svg>;
  }
  if (type === "eye") {
    return <svg viewBox="0 0 24 24"><path d="M2.5 12s3.4-5.2 9.5-5.2S21.5 12 21.5 12s-3.4 5.2-9.5 5.2S2.5 12 2.5 12Z"/><path d="M9.2 9.2a4 4 0 0 0 5.6 5.6"/><path d="M3 3l18 18"/></svg>;
  }
  if (type === "lock") {
    return <svg viewBox="0 0 24 24"><rect x="5" y="10" width="14" height="11" rx="2"/><path d="M8 10V7a4 4 0 0 1 8 0v3"/></svg>;
  }
  return <svg viewBox="0 0 24 24"><path d="M12 2.5 19 5v6.2c0 4.7-2.8 8-7 10.3-4.2-2.3-7-5.6-7-10.3V5l7-2.5Z"/><path d="m8.8 12 2 2 4.4-4.5"/></svg>;
}

function WorkloadIcon({ kind }: { kind: WorkloadKind }) {
  if (kind === "entra") {
    return <svg viewBox="0 0 48 48"><defs><linearGradient id="e1" x1="5" y1="5" x2="43" y2="43"><stop stopColor="#20A4FF"/><stop offset="1" stopColor="#58D9FF"/></linearGradient></defs><path fill="url(#e1)" d="M24 4 7 29l13 15 6-14 15 1L24 4Z"/><path fill="#2F7CFF" opacity=".72" d="m7 29 19 1-6 14L7 29Z"/></svg>;
  }
  if (kind === "exchange") {
    return <svg viewBox="0 0 48 48"><rect x="17" y="7" width="27" height="34" rx="5" fill="#168FFF"/><rect x="5" y="13" width="25" height="22" rx="4" fill="#1267D6"/><path d="M11 18h13v4h-7l8 6v5l-14-10v-5Z" fill="#fff"/></svg>;
  }
  if (kind === "sharepoint") {
    return <svg viewBox="0 0 48 48"><circle cx="18" cy="22" r="12" fill="#16877C"/><circle cx="30" cy="17" r="10" fill="#22A89D"/><circle cx="31" cy="30" r="11" fill="#2BC4B7" opacity=".85"/><path d="M14 16h9v4h-5v3h5v9h-9v-4h5v-3h-5v-9Z" fill="#fff"/></svg>;
  }
  if (kind === "teams") {
    return <svg viewBox="0 0 48 48"><circle cx="35" cy="12" r="5" fill="#8B86FF"/><rect x="19" y="12" width="23" height="25" rx="5" fill="#6F6AE8"/><rect x="6" y="16" width="25" height="20" rx="4" fill="#4D4BC2"/><path d="M12 21h13v4h-4v8h-5v-8h-4v-4Z" fill="#fff"/></svg>;
  }
  if (kind === "onedrive") {
    return <svg viewBox="0 0 48 48"><path fill="#138AF5" d="M11 31c1-6 5-10 11-10 3-7 9-11 16-9 6 1 10 5 11 11 5 0 8 4 8 9 0 6-4 10-10 10H13C7 42 3 38 3 33c0-5 3-9 8-10Z" transform="scale(.82) translate(3 1)"/><path fill="#50B7FF" d="M10 31c2-5 6-8 11-8 4 0 8 2 10 5 2-2 5-3 8-3 5 0 9 4 9 9 0 2 0 3-1 4H10Z"/></svg>;
  }
  if (kind === "intune") {
    return <svg viewBox="0 0 48 48"><rect x="7" y="9" width="34" height="25" rx="3" fill="#12A8E8"/><rect x="11" y="13" width="26" height="17" rx="2" fill="#082C4B"/><path d="M19 39h10M24 34v5" stroke="#7DDAFF" strokeWidth="3" strokeLinecap="round"/><path d="M15 19h18M15 24h12" stroke="#2CC3FF" strokeWidth="2"/></svg>;
  }
  if (kind === "defender") {
    return <svg viewBox="0 0 48 48"><defs><linearGradient id="d1" x1="7" y1="5" x2="40" y2="43"><stop stopColor="#34ADFF"/><stop offset="1" stopColor="#1267D6"/></linearGradient></defs><path d="M24 5 41 11v12c0 10-6 16-17 21C13 39 7 33 7 23V11l17-6Z" fill="url(#d1)"/><path d="M24 9v30c8-4 12-9 12-16v-9L24 9Z" fill="#287EE5" opacity=".78"/></svg>;
  }
  return <svg viewBox="0 0 48 48"><defs><linearGradient id="p1" x1="4" y1="8" x2="44" y2="40"><stop stopColor="#19D3FF"/><stop offset="1" stopColor="#386BFF"/></linearGradient></defs><path d="M6 24c5-9 12-14 20-14 7 0 12 3 16 8-5-1-10 0-14 3-4 3-7 7-8 13-6-1-11-4-14-10Z" fill="url(#p1)"/><path d="M42 24c-5 9-12 14-20 14-7 0-12-3-16-8 5 1 10 0 14-3 4-3 7-7 8-13 6 1 11 4 14 10Z" fill="#2085E8" opacity=".9"/><circle cx="24" cy="24" r="5" fill="#071726"/></svg>;
}

function HomeEnhancements() {
  return (
    <div className="home-enhancements" aria-label="TenantIQ platform highlights">
      <div className="home-enhancements-inner">
        <div className="trust-stat-row">
          {TRUST_STATS.map((stat) => (
            <div className="trust-stat" key={stat.value + stat.label}>
              <span className="trust-stat-icon"><TrustIcon type={stat.icon}/></span>
              <div><div className="trust-stat-value">{stat.value}</div><div className="trust-stat-label">{stat.label}</div></div>
            </div>
          ))}
        </div>
      </div>

      <div className="home-network" aria-hidden="true">
        <svg viewBox="0 0 1600 260" preserveAspectRatio="none">
          <g className="network-lines">
            <path d="M0 185 L95 150 L190 195 L300 138 L405 184 L520 128 L630 177 L745 122 L860 172 L975 112 L1090 168 L1210 116 L1330 166 L1450 108 L1600 150"/>
            <path d="M20 235 L120 202 L235 242 L350 190 L465 229 L585 182 L700 224 L820 176 L935 216 L1055 170 L1175 211 L1295 166 L1415 203 L1540 163"/>
            <path d="M95 150L120 202M190 195L235 242M300 138L350 190M405 184L465 229M520 128L585 182M630 177L700 224M745 122L820 176M860 172L935 216M975 112L1055 170M1090 168L1175 211M1210 116L1295 166M1330 166L1415 203M1450 108L1540 163"/>
            <path d="M120 202L190 195M235 242L300 138M350 190L405 184M465 229L520 128M585 182L630 177M700 224L745 122M820 176L860 172M935 216L975 112M1055 170L1090 168M1175 211L1210 116M1295 166L1330 166M1415 203L1450 108"/>
          </g>
          <g className="network-nodes">
            {[[95,150],[120,202],[190,195],[235,242],[300,138],[350,190],[405,184],[465,229],[520,128],[585,182],[630,177],[700,224],[745,122],[820,176],[860,172],[935,216],[975,112],[1055,170],[1090,168],[1175,211],[1210,116],[1295,166],[1330,166],[1415,203],[1450,108],[1540,163]].map(([x,y],i)=><circle key={i} cx={x} cy={y} r={i%4===0?5:3}/>) }
          </g>
        </svg>
        <span className="network-badge users">👥</span>
        <span className="network-badge shield">✓</span>
        <span className="network-badge lock">🔒</span>
      </div>

      <div className="home-enhancements-inner workload-area">
        <div className="workload-strip-title">Microsoft 365 workloads covered</div>
        <div className="workload-strip">
          {WORKLOADS.map((workload) => (
            <div className="workload-item" key={workload.name}>
              <div className="workload-logo"><WorkloadIcon kind={workload.kind}/></div>
              <div className="workload-name">{workload.name}</div>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}

export default function TenantIQPageShell({ mode }: { mode: PageMode }) {
  const [heroTarget, setHeroTarget] = useState<HTMLElement | null>(null);

  useEffect(() => {
    const routeMap: Record<string, string> = {
      "#top": "/",
      "#what": "/product#what",
      "#coverage": "/product#coverage",
      "#sample": "/details#sample",
      "#trust": "/details#trust",
    };

    document.querySelectorAll<HTMLAnchorElement>('a[href^="#"]').forEach((link) => {
      const nextHref = routeMap[link.getAttribute("href") || ""];
      if (nextHref) link.setAttribute("href", nextHref);
    });

    document.querySelectorAll<HTMLButtonElement>("button").forEach((button) => {
      if (button.textContent?.trim() === "View sample assessment") {
        button.onclick = () => { window.location.href = "/details#sample"; };
      }
    });

    if (mode === "home") setHeroTarget(document.getElementById("top"));
  }, [mode]);

  return (
    <>
      <style>{`
        ${mode === "home" ? `
          #what, #coverage, #how, #sample, #trust, #audience, #early-access, footer { display:none !important; }
          #top { position:relative; overflow:hidden; min-height:100vh; background:#0D1321 !important; }
          #top .hero-grid { position:relative; z-index:3; padding-bottom:10px !important; }
          #top .hero-grid > div:first-child > p:last-of-type { display:none !important; }
        ` : ""}
        ${mode === "product" ? `.hero-grid, #how, #sample, #trust, #audience, #early-access, footer { display:none !important; }` : ""}
        ${mode === "details" ? `.hero-grid, #what, #coverage { display:none !important; }` : ""}

        .home-enhancements { position:relative; z-index:2; margin-top:-2px; padding:0 0 28px; background:linear-gradient(180deg,#0D1321 0%,#081321 100%); }
        .home-enhancements-inner { width:min(1100px,calc(100% - 48px)); margin:0 auto; position:relative; z-index:2; }

        .trust-stat-row { width:min(650px,62%); display:grid; grid-template-columns:repeat(4,1fr); border-top:1px solid rgba(139,149,165,.16); border-bottom:1px solid rgba(139,149,165,.16); background:rgba(13,19,33,.22); }
        .trust-stat { min-height:68px; display:flex; align-items:center; gap:10px; padding:10px 15px; border-right:1px solid rgba(139,149,165,.14); }
        .trust-stat:last-child{border-right:0}.trust-stat-icon{width:22px;height:22px;display:inline-flex;color:#4C8DFF;flex:0 0 auto}.trust-stat-icon svg{width:22px;height:22px;fill:none;stroke:currentColor;stroke-width:1.8;stroke-linecap:round;stroke-linejoin:round}.trust-stat-value{font:700 14px 'Space Grotesk',sans-serif;color:#F5F7FA}.trust-stat-label{margin-top:3px;font:11px 'Inter',sans-serif;color:#7F899A}

        .home-network { position:relative; height:170px; margin-top:14px; overflow:visible; opacity:.72; }
        .home-network svg{width:100%;height:100%;display:block}.network-lines{fill:none;stroke:rgba(45,123,255,.34);stroke-width:1;vector-effect:non-scaling-stroke}.network-nodes{fill:#35A5FF;filter:drop-shadow(0 0 7px rgba(53,165,255,.8))}
        .network-badge{position:absolute;width:46px;height:46px;border:1px solid rgba(46,139,255,.65);border-radius:50%;display:flex;align-items:center;justify-content:center;background:rgba(6,19,35,.7);box-shadow:0 0 20px rgba(37,99,235,.12);font-size:17px}.network-badge.users{left:13%;top:66px}.network-badge.shield{left:55%;top:26px;color:#4C8DFF;font:bold 26px 'Space Grotesk'}.network-badge.lock{right:12%;top:65px;font-size:15px}

        .workload-area { margin-top:-8px; padding-top:0; border-top:1px solid rgba(76,141,255,.20); }
        .workload-strip-title { width:max-content; margin:-8px auto 16px; padding:0 16px; background:#081321; color:#4C8DFF; font:600 11px 'IBM Plex Mono',monospace; letter-spacing:.05em; text-transform:uppercase; }
        .workload-strip { display:grid; grid-template-columns:repeat(8,minmax(0,1fr)); align-items:start; gap:12px; }
        .workload-item { display:flex; flex-direction:column; align-items:center; justify-content:flex-start; gap:7px; min-width:0; text-align:center; }
        .workload-logo { width:44px; height:44px; display:flex; align-items:center; justify-content:center; flex:0 0 44px; }
        .workload-logo svg { width:44px; height:44px; display:block; }
        .workload-name { color:#E8EEF7; font:12px 'Inter',sans-serif; line-height:1.25; white-space:nowrap; }

        @media(max-width:900px){.trust-stat-row{width:100%;grid-template-columns:repeat(2,1fr)}.trust-stat:nth-child(2){border-right:0}.trust-stat:nth-child(-n+2){border-bottom:1px solid rgba(139,149,165,.14)}.workload-strip{grid-template-columns:repeat(4,1fr);row-gap:18px}.home-network{height:150px}.workload-name{font-size:11px}}
        @media(max-width:560px){.home-enhancements-inner{width:min(100% - 30px,1100px)}.trust-stat{padding:10px}.workload-strip{grid-template-columns:repeat(2,1fr)}.home-network{height:130px}.network-badge{display:none}.workload-logo,.workload-logo svg{width:38px;height:38px}.workload-name{font-size:11px}}
      `}</style>

      <TenantIQLandingV2 />
      {mode === "home" && heroTarget && createPortal(<HomeEnhancements />, heroTarget)}
    </>
  );
}
