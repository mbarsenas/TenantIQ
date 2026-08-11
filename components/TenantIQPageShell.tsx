'use client';

import { useEffect } from "react";
import TenantIQLandingV2 from "./TenantIQLandingV2";

type PageMode = "home" | "product" | "details";

const TRUST_STATS = [
  { value: "350+", label: "automated checks" },
  { value: "8", label: "workloads" },
  { value: "Read-only", label: "access" },
  { value: "No", label: "configuration changes" },
];

const WORKLOADS = [
  "Entra ID",
  "Exchange Online",
  "SharePoint",
  "Teams",
  "OneDrive",
  "Intune",
  "Defender",
  "Purview",
];

function HomeEnhancements() {
  return (
    <section className="home-enhancements" aria-label="TenantIQ platform highlights">
      <div className="home-network" aria-hidden="true">
        <svg viewBox="0 0 1600 360" preserveAspectRatio="none">
          <g className="network-lines">
            <path d="M0 250 L150 205 L310 245 L470 185 L630 230 L790 170 L965 220 L1120 160 L1290 210 L1450 145 L1600 185" />
            <path d="M20 320 L205 270 L370 300 L535 235 L720 285 L900 230 L1065 275 L1230 215 L1390 255 L1575 205" />
            <path d="M150 205 L205 270 M310 245 L370 300 M470 185 L535 235 M630 230 L720 285 M790 170 L900 230 M965 220 L1065 275 M1120 160 L1230 215 M1290 210 L1390 255 M1450 145 L1575 205" />
            <path d="M205 270 L310 245 M370 300 L470 185 M535 235 L630 230 M720 285 L790 170 M900 230 L965 220 M1065 275 L1120 160 M1230 215 L1290 210 M1390 255 L1450 145" />
          </g>
          <g className="network-nodes">
            {[150, 205, 310, 370, 470, 535, 630, 720, 790, 900, 965, 1065, 1120, 1230, 1290, 1390, 1450, 1575].map((x, index) => {
              const yValues = [205, 270, 245, 300, 185, 235, 230, 285, 170, 230, 220, 275, 160, 215, 210, 255, 145, 205];
              return <circle key={x} cx={x} cy={yValues[index]} r={index % 4 === 0 ? 5 : 3} />;
            })}
          </g>
        </svg>
      </div>

      <div className="home-enhancements-inner">
        <div className="trust-stat-row">
          {TRUST_STATS.map((stat) => (
            <div className="trust-stat" key={`${stat.value}-${stat.label}`}>
              <span className="trust-stat-icon" aria-hidden="true" />
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
            {WORKLOADS.map((workload, index) => (
              <div className="workload-item" key={workload}>
                <span>{workload}</span>
                {index < WORKLOADS.length - 1 && <span className="workload-dot" aria-hidden="true">•</span>}
              </div>
            ))}
          </div>
        </div>
      </div>
    </section>
  );
}

export default function TenantIQPageShell({ mode }: { mode: PageMode }) {
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
        button.onclick = () => {
          window.location.href = "/details#sample";
        };
      }
    }
  }, []);

  return (
    <>
      <style>{`
        ${mode === "home" ? `
          #what, #coverage, #how, #sample, #trust, #audience, #early-access, footer {
            display: none !important;
          }

          #top {
            position: relative;
            overflow: hidden;
          }
        ` : ""}

        ${mode === "product" ? `
          .hero-grid, #how, #sample, #trust, #audience, #early-access, footer {
            display: none !important;
          }
        ` : ""}

        ${mode === "details" ? `
          .hero-grid, #what, #coverage {
            display: none !important;
          }
        ` : ""}

        .home-enhancements {
          position: relative;
          min-height: 330px;
          margin-top: -1px;
          overflow: hidden;
          background:
            radial-gradient(circle at 20% 45%, rgba(37,99,235,.10), transparent 26%),
            radial-gradient(circle at 78% 36%, rgba(76,141,255,.09), transparent 28%),
            linear-gradient(180deg, #0D1321 0%, #09111F 100%);
          border-top: 1px solid rgba(76,141,255,.08);
        }

        .home-network {
          position: absolute;
          inset: 0;
          pointer-events: none;
          opacity: .52;
          mask-image: linear-gradient(to bottom, transparent 0%, rgba(0,0,0,.92) 26%, #000 100%);
        }

        .home-network svg {
          width: 100%;
          height: 100%;
          display: block;
        }

        .network-lines {
          fill: none;
          stroke: rgba(45,123,255,.28);
          stroke-width: 1;
          vector-effect: non-scaling-stroke;
        }

        .network-nodes {
          fill: #33A1FF;
          filter: drop-shadow(0 0 7px rgba(51,161,255,.85));
        }

        .home-enhancements-inner {
          position: relative;
          z-index: 2;
          width: min(1100px, calc(100% - 48px));
          margin: 0 auto;
          padding: 18px 0 34px;
        }

        .trust-stat-row {
          display: grid;
          grid-template-columns: repeat(4, minmax(0, 1fr));
          max-width: 760px;
          gap: 0;
          margin-bottom: 126px;
          border-top: 1px solid rgba(139,149,165,.12);
          border-bottom: 1px solid rgba(139,149,165,.12);
          background: rgba(13,19,33,.32);
          backdrop-filter: blur(6px);
        }

        .trust-stat {
          display: flex;
          align-items: center;
          gap: 10px;
          min-height: 70px;
          padding: 12px 18px;
          border-right: 1px solid rgba(139,149,165,.14);
        }

        .trust-stat:last-child {
          border-right: 0;
        }

        .trust-stat-icon {
          width: 9px;
          height: 9px;
          flex: 0 0 auto;
          border: 1px solid #4C8DFF;
          border-radius: 50%;
          box-shadow: 0 0 12px rgba(76,141,255,.45);
        }

        .trust-stat-value {
          color: #F5F7FA;
          font-family: 'Space Grotesk', sans-serif;
          font-size: 14px;
          font-weight: 700;
          line-height: 1.1;
        }

        .trust-stat-label {
          margin-top: 4px;
          color: #7F899A;
          font-family: 'Inter', sans-serif;
          font-size: 11px;
          line-height: 1.25;
          text-transform: lowercase;
        }

        .workload-strip-wrap {
          position: relative;
          padding-top: 18px;
          border-top: 1px solid rgba(76,141,255,.18);
          text-align: center;
        }

        .workload-strip-title {
          display: inline-block;
          position: relative;
          top: -30px;
          padding: 0 18px;
          color: #4C8DFF;
          background: #09111F;
          font-family: 'IBM Plex Mono', monospace;
          font-size: 11px;
          letter-spacing: .06em;
          text-transform: uppercase;
        }

        .workload-strip {
          display: flex;
          align-items: center;
          justify-content: center;
          flex-wrap: wrap;
          gap: 10px 14px;
          margin-top: -10px;
          color: #C5CCDA;
          font-family: 'Inter', sans-serif;
          font-size: 13px;
        }

        .workload-item {
          display: inline-flex;
          align-items: center;
          gap: 14px;
        }

        .workload-dot {
          color: #4C8DFF;
          opacity: .65;
        }

        @media (max-width: 820px) {
          .trust-stat-row {
            grid-template-columns: repeat(2, minmax(0, 1fr));
            margin-bottom: 108px;
          }

          .trust-stat:nth-child(2) {
            border-right: 0;
          }

          .trust-stat:nth-child(-n+2) {
            border-bottom: 1px solid rgba(139,149,165,.14);
          }
        }

        @media (max-width: 560px) {
          .home-enhancements {
            min-height: 390px;
          }

          .home-enhancements-inner {
            width: min(100% - 32px, 1100px);
          }

          .trust-stat {
            padding: 11px 12px;
          }

          .workload-strip {
            gap: 8px 10px;
            font-size: 12px;
          }

          .workload-item {
            gap: 10px;
          }
        }
      `}</style>

      <TenantIQLandingV2 />
      {mode === "home" && <HomeEnhancements />}
    </>
  );
}
