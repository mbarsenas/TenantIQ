'use client';

import { useEffect, useState } from "react";
import { createPortal } from "react-dom";
import TenantIQLandingV2 from "./TenantIQLandingV2";

type PageMode = "home" | "product" | "details";

type Workload = {
  name: string;
  kind: "entra" | "exchange" | "sharepoint" | "teams" | "onedrive" | "intune" | "defender" | "purview";
};

const TRUST_STATS = [
  { value: "350+", label: "Automated checks", icon: "shield" },
  { value: "8", label: "Workloads", icon: "grid" },
  { value: "Read-only", label: "Access", icon: "eye" },
  { value: "No", label: "Configuration changes", icon: "lock" },
];

const WORKLOADS: Workload[] = [
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
    return (
      <svg viewBox="0 0 24 24" aria-hidden="true">
        <rect x="3" y="3" width="7" height="7" rx="1" />
        <rect x="14" y="3" width="7" height="7" rx="1" />
        <rect x="3" y="14" width="7" height="7" rx="1" />
        <rect x="14" y="14" width="7" height="7" rx="1" />
      </svg>
    );
  }

  if (type === "eye") {
    return (
      <svg viewBox="0 0 24 24" aria-hidden="true">
        <path d="M2.5 12s3.4-5.2 9.5-5.2S21.5 12 21.5 12s-3.4 5.2-9.5 5.2S2.5 12 2.5 12Z" />
        <path d="M9.2 9.2a4 4 0 0 0 5.6 5.6" />
        <path d="M3 3l18 18" />
      </svg>
    );
  }

  if (type === "lock") {
    return (
      <svg viewBox="0 0 24 24" aria-hidden="true">
        <rect x="5" y="10" width="14" height="11" rx="2" />
        <path d="M8 10V7a4 4 0 0 1 8 0v3" />
      </svg>
    );
  }

  return (
    <svg viewBox="0 0 24 24" aria-hidden="true">
      <path d="M12 2.5 19 5v6.2c0 4.7-2.8 8-7 10.3-4.2-2.3-7-5.6-7-10.3V5l7-2.5Z" />
      <path d="m8.8 12 2 2 4.4-4.5" />
    </svg>
  );
}

function WorkloadIcon({ kind }: { kind: Workload["kind"] }) {
  switch (kind) {
    case "entra":
      return (
        <svg viewBox="0 0 48 48" aria-hidden="true">
          <defs>
            <linearGradient id="entraA" x1="0" y1="0" x2="1" y2="1">
              <stop offset="0" stopColor="#2A7BFF" />
              <stop offset="1" stopColor="#54D8FF" />
            </linearGradient>
          </defs>
          <path fill="url(#entraA)" d="M25 4 8 29l12 15 6-14 14 1L25 4Z" />
          <path fill="#76BFFF" opacity=".75" d="m8 29 18 1-6 14-12-15Z" />
        </svg>
      );
    case "exchange":
      return (
        <svg viewBox="0 0 48 48" aria-hidden="true">
          <rect x="18" y="8" width="25" height="32" rx="4" fill="#1D8CFF" />
          <rect x="6" y="13" width="24" height="22" rx="4" fill="#1267D6" />
          <path d="M11 20h14v3H15l10 7v4L11 24v-4Z" fill="#fff" opacity=".95" />
        </svg>
      );
    case "sharepoint":
      return (
        <svg viewBox="0 0 48 48" aria-hidden="true">
          <circle cx="18" cy="22" r="12" fill="#16877C" />
          <circle cx="30" cy="17" r="10" fill="#22A89D" opacity=".88" />
          <circle cx="31" cy="30" r="11" fill="#2BC4B7" opacity=".75" />
          <path d="M14 16h9v4h-5v3h5v9h-9v-4h5v-3h-5v-9Z" fill="#fff" />
        </svg>
      );
    case "teams":
      return (
        <svg viewBox="0 0 48 48" aria-hidden="true">
          <circle cx="35" cy="13" r="5" fill="#837EFF" />
          <rect x="19" y="12" width="22" height="25" rx="5" fill="#6F6AE8" />
          <rect x="7" y="16" width="24" height="20" rx="4" fill="#4D4BC2" />
          <path d="M13 21h12v4h-4v8h-4v-8h-4v-4Z" fill="#fff" />
        </svg>
      );
    case "onedrive":
      return (
        <svg viewBox="0 0 48 48" aria-hidden="true">
          <path fill="#1998FF" d="M18 18c2-6 7-9 13-9 7 0 12 4 14 10 5 0 9 4 9 9s-4 9-9 9H13C7 37 3 33 3 28s4-10 10-10c2 0 3 0 5 1Z" transform="scale(.85) translate(4 4)" />
          <path fill="#48B8FF" d="M11 30c1-5 5-8 10-8 4 0 7 2 9 5 2-2 5-3 8-3 5 0 9 4 9 9 0 1 0 2-1 3H11Z" opacity=".8" />
        </svg>
      );
    case "intune":
      return (
        <svg viewBox="0 0 48 48" aria-hidden="true">
          <rect x="7" y="10" width="34" height="24" rx="3" fill="#0AA6E8" />
          <rect x="11" y="14" width="26" height="16" rx="2" fill="#082C4B" />
          <path d="M20 39h8M24 34v5" stroke="#78D7FF" strokeWidth="3" strokeLinecap="round" />
          <path d="M15 20h18M15 24h10" stroke="#35C4FF" strokeWidth="2" />
        </svg>
      );
    case "defender":
      return (
        <svg viewBox="0 0 48 48" aria-hidden="true">
          <defs>
            <linearGradient id="defA" x1="0" y1="0" x2="1" y2="1">
              <stop offset="0" stopColor="#31A8FF" />
              <stop offset="1" stopColor="#1267D6" />
            </linearGradient>
          </defs>
          <path d="M24 5 41 11v12c0 10-6 16-17 21C13 39 7 33 7 23V11l17-6Z" fill="url(#defA)" />
          <path d="M24 9v30c8-4 12-9 12-16v-9L24 9Z" fill="#267FE6" opacity=".8" />
        </svg>
      );
    case "purview":
      return (
        <svg viewBox="0 0 48 48" aria-hidden="true">
          <defs>
            <linearGradient id="purA" x1="0" y1="0" x2="1" y2="1">
              <stop offset="0" stopColor="#17D2FF" />
              <stop offset="1" stopColor="#386BFF" />
            </linearGradient>
          </defs>
          <path d="M6 24c5-9 12-14 20-14 7 0 12 3 16 8-4-1-9 0-13 3-4 3-7 7-9 13-6-1-11-4-14-10Z" fill="url(#purA)" />
          <path d="M42 24c-5 9-12 14-20 14-7 0-12-3-16-8 4 1 9 0 13-3 4-3 7-7 9-13 6 1 11 4 14 10Z" fill="#2085E8" opacity=".9" />
          <circle cx="24" cy="24" r="5" fill="#08182A" />
        </svg>
      );
  }
}

function HomeEnhancements() {
  return (
    <div className="home-enhancements" aria-label="TenantIQ platform highlights">
      <div className="home-network" aria-hidden="true">
        <svg viewBox="0 0 1600 330" preserveAspectRatio="none">
          <g className="network-lines">
            <path d="M0 228 L90 194 L190 242 L300 188 L410 232 L520 174 L630 226 L745 168 L860 220 L980 158 L1100 216 L1220 158 L1340 211 L1460 150 L1600 190" />
            <path d="M15 292 L120 254 L235 298 L350 236 L465 282 L585 226 L700 276 L820 218 L935 266 L1055 211 L1175 260 L1295 208 L1415 248 L1540 202" />
            <path d="M90 194 L120 254 M190 242 L235 298 M300 188 L350 236 M410 232 L465 282 M520 174 L585 226 M630 226 L700 276 M745 168 L820 218 M860 220 L935 266 M980 158 L1055 211 M1100 216 L1175 260 M1220 158 L1295 208 M1340 211 L1415 248 M1460 150 L1540 202" />
            <path d="M120 254 L190 242 M235 298 L300 188 M350 236 L410 232 M465 282 L520 174 M585 226 L630 226 M700 276 L745 168 M820 218 L860 220 M935 266 L980 158 M1055 211 L1100 216 M1175 260 L1220 158 M1295 208 L1340 211 M1415 248 L1460 150" />
          </g>
          <g className="network-nodes">
            {[
              [90,194,5],[120,254,3],[190,242,4],[235,298,3],[300,188,5],[350,236,3],[410,232,3],[465,282,3],
              [520,174,5],[585,226,3],[630,226,3],[700,276,3],[745,168,5],[820,218,3],[860,220,3],[935,266,3],
              [980,158,5],[1055,211,3],[1100,216,3],[1175,260,3],[1220,158,5],[1295,208,3],[1340,211,3],[1415,248,3],
              [1460,150,5],[1540,202,3]
            ].map(([cx,cy,r], i) => <circle key={i} cx={cx} cy={cy} r={r} />)}
          </g>
        </svg>
      </div>

      <div className="network-badge badge-users" aria-hidden="true">👥</div>
      <div className="network-badge badge-shield" aria-hidden="true">✓</div>
      <div className="network-badge badge-lock" aria-hidden="true">🔒</div>

      <div className="home-enhancements-inner">
        <div className="trust-stat-row">
          {TRUST_STATS.map((stat) => (
            <div className="trust-stat" key={`${stat.value}-${stat.label}`}>
              <span className="trust-stat-icon"><TrustIcon type={stat.icon} /></span>
              <div>
                <div className="trust-stat-value">{stat.value}</div>
                <div className="trust-stat-label">{stat.label}</div>
              </div>
            </div>
          ))}
        </div>

        <div className="workload-strip-wrap">
          <div className="workload-strip-title">Microsoft 365 workloads covered</div>
          <div className="workload-strip">
            {WORKLOADS.map((workload) => (
              <div className="workload-item" key={workload.name}>
                <span className="workload-logo"><WorkloadIcon kind={workload.kind} /></span>
                <span className="workload-name">{workload.name}</span>
              </div>
            ))}
          </div>
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

    const buttons = Array.from(document.querySelectorAll<HTMLButtonElement>("button"));
    for (const button of buttons) {
      if (button.textContent?.trim() === "View sample assessment") {
        button.onclick = () => { window.location.href = "/details#sample"; };
      }
    }

    if (mode === "home") setHeroTarget(document.getElementById("top"));
  }, [mode]);

  return (
    <>
      <style>{`
        ${mode === "home" ? `
          #what, #coverage, #how, #sample, #trust, #audience, #early-access, footer { display: none !important; }
          #top {
            position: relative;
            overflow: hidden;
            min-height: 760px;
            padding-bottom: 285px;
            background:
              radial-gradient(circle at 15% 12%, rgba(13,89,170,.12), transparent 25%),
              radial-gradient(circle at 74% 32%, rgba(36,111,255,.08), transparent 28%),
              linear-gradient(180deg, #07111f 0%, #07121f 58%, #06111f 100%) !important;
          }
          #top .hero-grid {
            position: relative;
            z-index: 4;
            padding-top: 10px !important;
            padding-bottom: 12px !important;
            align-items: start !important;
          }
          #top .hero-actions + p { margin-top: 12px !important; }
        ` : ""}

        ${mode === "product" ? `.hero-grid, #how, #sample, #trust, #audience, #early-access, footer { display: none !important; }` : ""}
        ${mode === "details" ? `.hero-grid, #what, #coverage { display: none !important; }` : ""}

        .home-enhancements {
          position: absolute;
          left: 0;
          right: 0;
          bottom: 0;
          height: 315px;
          overflow: hidden;
          z-index: 2;
          pointer-events: none;
        }

        .home-network {
          position: absolute;
          inset: 48px 0 76px;
          opacity: .72;
          mask-image: linear-gradient(to bottom, transparent 0%, rgba(0,0,0,.9) 20%, #000 68%, rgba(0,0,0,.75) 100%);
        }
        .home-network svg { width: 100%; height: 100%; display: block; }
        .network-lines { fill: none; stroke: rgba(37,114,255,.34); stroke-width: 1; vector-effect: non-scaling-stroke; }
        .network-nodes { fill: #2F9FFF; filter: drop-shadow(0 0 8px rgba(47,159,255,.92)); }

        .network-badge {
          position: absolute;
          z-index: 2;
          width: 44px;
          height: 44px;
          border: 1px solid rgba(38,127,255,.8);
          border-radius: 50%;
          display: flex;
          align-items: center;
          justify-content: center;
          color: #5EA7FF;
          background: rgba(5,20,40,.72);
          box-shadow: 0 0 24px rgba(27,104,255,.10);
          font-size: 18px;
        }
        .badge-users { left: 13%; top: 118px; }
        .badge-shield { left: 56%; top: 96px; font-weight: 800; }
        .badge-lock { right: 14%; top: 132px; font-size: 16px; }

        .home-enhancements-inner {
          position: relative;
          z-index: 3;
          width: min(1200px, calc(100% - 96px));
          height: 100%;
          margin: 0 auto;
        }

        .trust-stat-row {
          position: absolute;
          top: 0;
          left: 0;
          display: grid;
          grid-template-columns: repeat(4, minmax(0, 1fr));
          width: min(560px, 51%);
          background: transparent;
        }
        .trust-stat {
          display: flex;
          align-items: center;
          gap: 10px;
          min-height: 58px;
          padding: 8px 14px 8px 0;
          margin-right: 14px;
          border-right: 1px solid rgba(139,149,165,.18);
        }
        .trust-stat:last-child { border-right: 0; margin-right: 0; }
        .trust-stat-icon { width: 23px; height: 23px; flex: 0 0 auto; color: #2F8CFF; }
        .trust-stat-icon svg { width: 100%; height: 100%; fill: none; stroke: currentColor; stroke-width: 1.8; stroke-linecap: round; stroke-linejoin: round; }
        .trust-stat-value { color: #F5F7FA; font-family: 'Space Grotesk', sans-serif; font-size: 14px; font-weight: 700; line-height: 1.05; }
        .trust-stat-label { margin-top: 4px; color: #8B95A5; font-family: 'Inter', sans-serif; font-size: 9px; line-height: 1.15; }

        .workload-strip-wrap {
          position: absolute;
          left: 0;
          right: 0;
          bottom: 14px;
          padding-top: 14px;
          border-top: 1px solid rgba(76,141,255,.28);
          text-align: center;
          pointer-events: auto;
        }
        .workload-strip-title {
          display: inline-block;
          position: relative;
          top: -26px;
          padding: 0 16px;
          color: #2F91FF;
          background: #06111f;
          font-family: 'Inter', sans-serif;
          font-size: 11px;
          font-weight: 600;
        }
        .workload-strip {
          display: grid;
          grid-template-columns: repeat(8, minmax(0, 1fr));
          gap: 12px;
          margin-top: -12px;
        }
        .workload-item {
          position: relative;
          display: flex;
          flex-direction: column;
          align-items: center;
          justify-content: center;
          gap: 6px;
          min-width: 0;
          color: #E4E9F3;
          font-family: 'Inter', sans-serif;
          font-size: 10px;
          white-space: nowrap;
        }
        .workload-item:not(:last-child)::after {
          content: "";
          position: absolute;
          right: -7px;
          top: 21px;
          width: 4px;
          height: 4px;
          border-radius: 50%;
          background: #678BFF;
          opacity: .75;
        }
        .workload-logo { width: 40px; height: 40px; display: inline-flex; align-items: center; justify-content: center; }
        .workload-logo svg { width: 100%; height: 100%; display: block; filter: drop-shadow(0 6px 10px rgba(0,0,0,.18)); }
        .workload-name { max-width: 100%; overflow: hidden; text-overflow: ellipsis; }

        @media (max-width: 1000px) {
          #top { min-height: 840px; padding-bottom: 350px; }
          .home-enhancements { height: 380px; }
          .home-enhancements-inner { width: min(100% - 40px, 1200px); }
          .trust-stat-row { width: min(650px, 100%); }
          .workload-strip { grid-template-columns: repeat(4, minmax(0, 1fr)); row-gap: 14px; }
          .workload-item:nth-child(4)::after { display: none; }
          .network-badge { opacity: .65; }
        }

        @media (max-width: 620px) {
          #top { min-height: 1080px; padding-bottom: 500px; }
          .home-enhancements { height: 530px; }
          .home-enhancements-inner { width: min(100% - 28px, 1200px); }
          .trust-stat-row { grid-template-columns: repeat(2, minmax(0,1fr)); }
          .trust-stat { border-right: 0; margin-right: 0; }
          .workload-strip { grid-template-columns: repeat(2, minmax(0,1fr)); row-gap: 16px; }
          .workload-item::after { display: none !important; }
          .network-badge { display: none; }
        }
      `}</style>

      <TenantIQLandingV2 />
      {mode === "home" && heroTarget && createPortal(<HomeEnhancements />, heroTarget)}
    </>
  );
}
