'use client';

import { useEffect, useState } from "react";
import { createPortal } from "react-dom";
import TenantIQLandingV2 from "./TenantIQLandingV2";

type PageMode = "home" | "product" | "details";
type WorkloadKind = "entra" | "exchange" | "sharepoint" | "teams" | "onedrive" | "intune" | "defender" | "purview";

const TRUST_STATS = [
  { value: "350+", label: "Automated checks", icon: "shield" },
  { value: "8", label: "Workloads", icon: "grid" },
  { value: "Read-only", label: "Access", icon: "eye" },
  { value: "No", label: "Configuration changes", icon: "lock" },
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
  if (type === "grid") return <svg viewBox="0 0 24 24"><rect x="3" y="3" width="7" height="7" rx="1"/><rect x="14" y="3" width="7" height="7" rx="1"/><rect x="3" y="14" width="7" height="7" rx="1"/><rect x="14" y="14" width="7" height="7" rx="1"/></svg>;
  if (type === "eye") return <svg viewBox="0 0 24 24"><path d="M2.5 12s3.4-5.2 9.5-5.2S21.5 12 21.5 12s-3.4 5.2-9.5 5.2S2.5 12 2.5 12Z"/><path d="M9.2 9.2a4 4 0 0 0 5.6 5.6"/><path d="M3 3l18 18"/></svg>;
  if (type === "lock") return <svg viewBox="0 0 24 24"><rect x="5" y="10" width="14" height="11" rx="2"/><path d="M8 10V7a4 4 0 0 1 8 0v3"/></svg>;
  return <svg viewBox="0 0 24 24"><path d="M12 2.5 19 5v6.2c0 4.7-2.8 8-7 10.3-4.2-2.3-7-5.6-7-10.3V5l7-2.5Z"/><path d="m8.8 12 2 2 4.4-4.5"/></svg>;
}

function BadgeIcon({ type }: { type: "users" | "shield" | "lock" }) {
  if (type === "users") return <svg viewBox="0 0 24 24"><circle cx="9" cy="8" r="3"/><circle cx="16" cy="9" r="2.5"/><path d="M3.5 19c0-3.2 2.4-5.2 5.5-5.2s5.5 2 5.5 5.2"/><path d="M13.5 15c.8-.9 1.9-1.3 3.1-1.3 2.4 0 4 1.7 4 4.3"/></svg>;
  if (type === "lock") return <svg viewBox="0 0 24 24"><rect x="5" y="10" width="14" height="10" rx="2"/><path d="M8 10V7a4 4 0 0 1 8 0v3"/></svg>;
  return <svg viewBox="0 0 24 24"><path d="M12 2.5 19 5v6.2c0 4.7-2.8 8-7 10.3-4.2-2.3-7-5.6-7-10.3V5l7-2.5Z"/><path d="m8.8 12 2 2 4.4-4.5"/></svg>;
}

function WorkloadIcon({ kind }: { kind: WorkloadKind }) {
  switch (kind) {
    case "entra":
      return <svg viewBox="0 0 64 64"><defs><linearGradient id="entra" x1="0" y1="0" x2="1" y2="1"><stop stopColor="#18B8FF"/><stop offset="1" stopColor="#4D72FF"/></linearGradient></defs><path fill="url(#entra)" d="M33 5 10 40l15 19 8-19 21 1L33 5Z"/><path fill="#7ED0FF" opacity=".75" d="m10 40 23 0-8 19-15-19Z"/></svg>;
    case "exchange":
      return <svg viewBox="0 0 64 64"><rect x="25" y="10" width="31" height="42" rx="6" fill="#168FFF"/><rect x="8" y="18" width="32" height="28" rx="5" fill="#1267D6"/><path d="M16 24h17v5H23l11 8v6L16 31v-7Z" fill="#fff"/></svg>;
    case "sharepoint":
      return <svg viewBox="0 0 64 64"><circle cx="24" cy="31" r="16" fill="#16877C"/><circle cx="40" cy="23" r="13" fill="#22A89D"/><circle cx="41" cy="42" r="14" fill="#2BC4B7" opacity=".88"/><path d="M19 23h12v5h-7v4h7v12H19v-5h7v-4h-7V23Z" fill="#fff"/></svg>;
    case "teams":
      return <svg viewBox="0 0 64 64"><circle cx="47" cy="17" r="7" fill="#8B86FF"/><rect x="27" y="16" width="29" height="34" rx="6" fill="#6F6AE8"/><rect x="8" y="22" width="34" height="28" rx="5" fill="#4D4BC2"/><path d="M16 28h18v5h-6v11h-6V33h-6v-5Z" fill="#fff"/></svg>;
    case "onedrive":
      return <svg viewBox="0 0 64 64"><path fill="#0E87F4" d="M18 38c2-8 8-13 16-13 4-9 12-14 21-11 8 2 13 8 14 16 6 0 11 5 11 11 0 8-6 13-13 13H20C12 54 7 49 7 42c0-6 4-11 11-12Z" transform="scale(.76) translate(4 2)"/><path fill="#4CB6FF" d="M14 39c2-6 7-10 14-10 5 0 10 3 13 7 3-3 7-4 11-4 7 0 12 5 12 12 0 2 0 4-1 5H14Z"/></svg>;
    case "intune":
      return <svg viewBox="0 0 64 64"><rect x="10" y="12" width="44" height="32" rx="4" fill="#12A8E8"/><rect x="15" y="17" width="34" height="22" rx="2" fill="#082C4B"/><path d="M25 52h14M32 44v8" stroke="#7DDAFF" strokeWidth="4" strokeLinecap="round"/><path d="M20 24h24M20 31h15" stroke="#2CC3FF" strokeWidth="3"/></svg>;
    case "defender":
      return <svg viewBox="0 0 64 64"><defs><linearGradient id="def" x1="0" y1="0" x2="1" y2="1"><stop stopColor="#35B0FF"/><stop offset="1" stopColor="#1267D6"/></linearGradient></defs><path d="M32 6 54 14v16c0 13-8 21-22 28C18 51 10 43 10 30V14l22-8Z" fill="url(#def)"/><path d="M32 11v40c10-5 15-12 15-21V18L32 11Z" fill="#287EE5" opacity=".8"/></svg>;
    default:
      return <svg viewBox="0 0 64 64"><defs><linearGradient id="pur" x1="0" y1="0" x2="1" y2="1"><stop stopColor="#18D5FF"/><stop offset="1" stopColor="#386BFF"/></linearGradient></defs><path d="M7 32c7-12 16-18 27-18 9 0 16 4 22 10-7-2-13 0-19 4-6 4-10 10-12 18-8-1-14-6-18-14Z" fill="url(#pur)"/><path d="M57 32c-7 12-16 18-27 18-9 0-16-4-22-10 7 2 13 0 19-4 6-4 10-10 12-18 8 1 14 6 18 14Z" fill="#2085E8" opacity=".92"/><circle cx="32" cy="32" r="7" fill="#071726"/></svg>;
  }
}

function HomeEnhancements() {
  return (
    <div className="home-enhancements" aria-label="TenantIQ platform highlights">
      <div className="home-inner trust-wrap">
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
        <svg viewBox="0 0 1600 300" preserveAspectRatio="none">
          <g className="network-lines">
            <path d="M0 210 L90 170 L200 215 L310 158 L430 205 L545 145 L665 198 L785 140 L905 195 L1025 133 L1145 190 L1270 142 L1390 188 L1505 132 L1600 165"/>
            <path d="M15 268 L120 232 L240 274 L355 220 L475 258 L595 208 L715 250 L835 204 L955 246 L1075 202 L1195 242 L1315 198 L1435 234 L1560 196"/>
            <path d="M90 170L120 232M200 215L240 274M310 158L355 220M430 205L475 258M545 145L595 208M665 198L715 250M785 140L835 204M905 195L955 246M1025 133L1075 202M1145 190L1195 242M1270 142L1315 198M1390 188L1435 234M1505 132L1560 196"/>
            <path d="M120 232L200 215M240 274L310 158M355 220L430 205M475 258L545 145M595 208L665 198M715 250L785 140M835 204L905 195M955 246L1025 133M1075 202L1145 190M1195 242L1270 142M1315 198L1390 188M1435 234L1505 132"/>
          </g>
          <g className="network-nodes">
            {[[90,170],[120,232],[200,215],[240,274],[310,158],[355,220],[430,205],[475,258],[545,145],[595,208],[665,198],[715,250],[785,140],[835,204],[905,195],[955,246],[1025,133],[1075,202],[1145,190],[1195,242],[1270,142],[1315,198],[1390,188],[1435,234],[1505,132],[1560,196]].map(([x,y],i)=><circle key={i} cx={x} cy={y} r={i%4===0?5:3}/>) }
          </g>
        </svg>
        <span className="network-badge badge-users"><BadgeIcon type="users"/></span>
        <span className="network-badge badge-shield"><BadgeIcon type="shield"/></span>
        <span className="network-badge badge-lock"><BadgeIcon type="lock"/></span>
      </div>

      <div className="home-inner workload-area">
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
      if (button.textContent?.trim() === "View sample assessment") button.onclick = () => { window.location.href = "/details#sample"; };
    });

    if (mode === "home") {
      const target = document.getElementById("top");
      setHeroTarget(target);
      const h1 = target?.querySelector("h1");
      if (h1) h1.innerHTML = 'Microsoft 365 tenant intelligence, without the <span class="gradient-word">guesswork.</span>';
      target?.querySelectorAll("div").forEach((node) => {
        if (node.textContent?.includes("Entra Identity Security â€” sanitized assessment")) {
          node.textContent = "Entra Identity Security — sanitized assessment";
        }
      });
    }
  }, [mode]);

  return (
    <>
      <style>{`
        ${mode === "home" ? `
          #what, #coverage, #how, #sample, #trust, #audience, #early-access, footer { display:none !important; }
          #top { position:relative; overflow:hidden; min-height:900px; background:linear-gradient(180deg,#07111f 0%,#081321 100%) !important; }
          #top .hero-grid { position:relative; z-index:4; padding-bottom:6px !important; }
          #top .hero-grid > div:first-child > p:last-of-type { display:none !important; }
          #top h1 .gradient-word { background:linear-gradient(90deg,#4C8DFF 0%,#25C7FF 100%); -webkit-background-clip:text; background-clip:text; color:transparent; }
        ` : ""}
        ${mode === "product" ? `.hero-grid, #how, #sample, #trust, #audience, #early-access, footer { display:none !important; }` : ""}
        ${mode === "details" ? `.hero-grid, #what, #coverage { display:none !important; }` : ""}

        .home-enhancements { position:absolute; left:0; right:0; top:545px; bottom:0; z-index:2; pointer-events:none; }
        .home-inner { width:min(1100px,calc(100% - 48px)); margin:0 auto; position:relative; z-index:3; }

        .trust-wrap { height:72px; }
        .trust-stat-row { width:650px; max-width:62%; display:grid; grid-template-columns:repeat(4,1fr); border-top:1px solid rgba(139,149,165,.14); border-bottom:1px solid rgba(139,149,165,.14); background:rgba(8,19,33,.14); }
        .trust-stat { min-height:70px; display:flex; align-items:center; gap:10px; padding:10px 16px; border-right:1px solid rgba(139,149,165,.14); }
        .trust-stat:last-child{border-right:0}.trust-stat-icon{width:25px;height:25px;display:inline-flex;color:#3E95FF;flex:0 0 auto}.trust-stat-icon svg{width:100%;height:100%;fill:none;stroke:currentColor;stroke-width:1.8;stroke-linecap:round;stroke-linejoin:round}.trust-stat-value{font:700 15px 'Space Grotesk',sans-serif;color:#F5F7FA;line-height:1.05}.trust-stat-label{margin-top:4px;font:11px 'Inter',sans-serif;color:#8290A4;line-height:1.15}

        .home-network { position:absolute; left:0; right:0; top:80px; height:205px; opacity:.9; pointer-events:none; }
        .home-network svg{width:100%;height:100%;display:block}.network-lines{fill:none;stroke:rgba(45,123,255,.38);stroke-width:1;vector-effect:non-scaling-stroke}.network-nodes{fill:#32A0FF;filter:drop-shadow(0 0 7px rgba(50,160,255,.9))}
        .network-badge{position:absolute;width:48px;height:48px;border:1px solid rgba(47,137,255,.8);border-radius:50%;display:flex;align-items:center;justify-content:center;color:#58A7FF;background:rgba(5,18,34,.8);box-shadow:0 0 28px rgba(36,112,255,.12)}.network-badge svg{width:24px;height:24px;fill:none;stroke:currentColor;stroke-width:1.8;stroke-linecap:round;stroke-linejoin:round}.badge-users{left:13%;top:58px}.badge-shield{left:55%;top:18px}.badge-lock{right:14%;top:70px}

        .workload-area { position:absolute; left:0; right:0; bottom:10px; height:126px; border-top:1px solid rgba(76,141,255,.24); text-align:center; pointer-events:auto; }
        .workload-strip-title { display:inline-block; transform:translateY(-9px); padding:0 18px; background:#07111f; color:#3E98FF; font:600 12px 'Inter',sans-serif; }
        .workload-strip { display:grid; grid-template-columns:repeat(8,1fr); gap:18px; margin-top:2px; align-items:end; }
        .workload-item { min-width:0; display:flex; flex-direction:column; align-items:center; justify-content:flex-end; gap:7px; color:#F5F7FA; }
        .workload-logo { width:48px; height:48px; display:flex; align-items:center; justify-content:center; }
        .workload-logo svg { width:48px; height:48px; display:block; }
        .workload-name { font:12px 'Inter',sans-serif; color:#E7ECF5; white-space:nowrap; }

        @media (max-width:900px){
          #top{min-height:1100px}.home-enhancements{top:650px}.trust-stat-row{max-width:100%;width:100%;grid-template-columns:repeat(2,1fr)}.trust-wrap{height:145px}.home-network{top:155px}.workload-area{height:230px}.workload-strip{grid-template-columns:repeat(4,1fr);row-gap:18px}.workload-logo,.workload-logo svg{width:44px;height:44px}
        }
        @media (max-width:560px){
          #top{min-height:1420px}.home-enhancements{top:790px}.home-inner{width:min(100% - 28px,1100px)}.trust-stat{padding:10px}.home-network{top:155px}.workload-area{height:410px}.workload-strip{grid-template-columns:repeat(2,1fr);row-gap:16px}.workload-name{font-size:11px}
        }
      `}</style>

      <TenantIQLandingV2 />
      {mode === "home" && heroTarget && createPortal(<HomeEnhancements />, heroTarget)}
    </>
  );
}
