'use client';

import { useEffect, useState } from "react";
import { createPortal } from "react-dom";
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
    <div className="home-enhancements" aria-label="TenantIQ platform highlights">
      <div className="home-network" aria-hidden="true">
        <svg viewBox="0 0 1600 330" preserveAspectRatio="none">
          <g className="network-lines">
            <path d="M0 220 L150 175 L310 215 L470 155 L630 200 L790 140 L965 190 L1120 130 L1290 180 L1450 115 L1600 155" />
            <path d="M20 300 L205 250 L370 280 L535 215 L720 265 L900 210 L1065 255 L1230 195 L1390 235 L1575 185" />
            <path d="M150 175 L205 250 M310 215 L370 280 M470 155 L535 215 M630 200 L720 265 M790 140 L900 210 M965 190 L1065 255 M1120 130 L1230 195 M1290 180 L1390 235 M1450 115 L1575 185" />
            <path d="M205 250 L310 215 M370 280 L470 155 M535 215 L630 200 M720 265 L790 140 M900 210 L965 190 M1065 255 L1120 130 M1230 195 L1290 180 M1390 235 L1450 115" />
          </g>
          <g className="network-nodes">
            {[150, 205, 310, 370, 470, 535, 630, 720, 790, 900, 965, 1065, 1120, 1230, 1290, 1390, 1450, 1575].map((x, index) => {
              const yValues = [175, 250, 215, 280, 155, 215, 200, 265, 140, 210, 190, 255, 130, 195, 180, 235, 115, 185];
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
                {index < WORKLOADS.length - 1 && (
                  <span className="workload-dot" aria-hidden="true">•</span>
                )}
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
        button.onclick = () => {
          window.location.href = "/details#sample";
        };
      }
    }

    if (mode === "home") {
      setHeroTarget(document.getElementById("top"));
    }
  }, [mode]);

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
            min-height: 100vh;
            padding-bottom: 292px;
            background:
              radial-gradient(circle at 20% 78%, rgba(37,99,235,.10), transparent 27%),
              radial-gradient(circle at 82% 72%, rgba(76,141,255,.08), transparent 30%),
              #0D1321 !important;
          }

          #top .hero-grid {
            position: relative;
            z-index: 3;
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
          position: absolute;
          left: 0;
          right: 0;
          bottom: 0;
          height: 305px;
          overflow: hidden;
          z-index: 1;
          pointer-events: none;
        }

        .home-network {
          position: absolute;
          inset: 30px 0 0;
          opacity: .46;
          mask-image: linear-gradient(to bottom, transparent 0%, rgba(0,0,0,.78) 20%, #000 55%, rgba(0,0,0,.90) 100%);
        }

        .home-network svg {
          width: 100%;
          height: 100%;
          display: block;
        }

        .network-lines {
          fill: none;
          stroke: rgba(45,123,255,.27);
          stroke-width: 1;
          vector-effect: non-scaling-stroke;
        }

        .network-nodes {
          fill: #33A1FF;
          filter: drop-shadow(0 0 7px rgba(51,161,255,.8));
        }

        .home-enhancements-inner {
          position: relative;
          z-index: 2;
          width: min(1100px, calc(100% - 48px));
          height: 100%;
          margin: 0 auto;
        }

        .trust-stat-row {
          position: absolute;
          top: 0;
          left: 0;
          display: grid;
          grid-template-columns: repeat(4, minmax(0, 1fr));
          width: min(700px, 64%);
          border-top: 1px solid rgba(139,149,165,.13);
          border-bottom: 1px solid rgba(139,149,165,.13);
          background: rgba(13,19,33,.16);
          backdrop-filter: blur(4px);
        }

        .trust-stat {
          display: flex;
          align-items: center;
          gap: 9px;
          min-height: 64px;
          padding: 10px 16px;
          border-right: 1px solid rgba(139,149,165,.14);
        }

        .trust-stat:last-child {
          border-right: 0;
        }

        .trust-stat-icon {
          width: 8px;
          height: 8px;
          flex: 0 0 auto;
          border: 1px solid #4C8DFF;
          border-radius: 50%;
          box-shadow: 0 0 11px rgba(76,141,255,.45);
        }

        .trust-stat-value {
          color: #F5F7FA;
          font-family: 'Space Grotesk', sans-serif;
          font-size: 14px;
          font-weight: 700;
          line-height: 1.1;
        }

        .trust-stat-label {
          margin-top: 3px;
          color: #7F899A;
          font-family: 'Inter', sans-serif;
          font-size: 10px;
          line-height: 1.2;
        }

        .workload-strip-wrap {
          position: absolute;
          left: 0;
          right: 0;
          bottom: 26px;
          padding-top: 17px;
          border-top: 1px solid rgba(76,141,255,.17);
          text-align: center;
          pointer-events: auto;
        }

        .workload-strip-title {
          display: inline-block;
          position: relative;
          top: -29px;
          padding: 0 16px;
          color: #4C8DFF;
          background: #0D1321;
          font-family: 'IBM Plex Mono', monospace;
          font-size: 10px;
          letter-spacing: .07em;
          text-transform: uppercase;
        }

        .workload-strip {
          display: flex;
          align-items: center;
          justify-content: center;
          flex-wrap: wrap;
          gap: 8px 13px;
          margin-top: -11px;
          color: #C5CCDA;
          font-family: 'Inter', sans-serif;
          font-size: 12px;
        }

        .workload-item {
          display: inline-flex;
          align-items: center;
          gap: 13px;
        }

        .workload-dot {
          color: #4C8DFF;
          opacity: .7;
        }

        @media (max-width: 900px) {
          #top {
            padding-bottom: 330px;
          }

          .home-enhancements {
            height: 340px;
          }

          .trust-stat-row {
            width: 100%;
            grid-template-columns: repeat(2, minmax(0, 1fr));
          }

          .trust-stat:nth-child(2) {
            border-right: 0;
          }

          .trust-stat:nth-child(-n+2) {
            border-bottom: 1px solid rgba(139,149,165,.14);
          }
        }

        @media (max-width: 560px) {
          #top {
            padding-bottom: 400px;
          }

          .home-enhancements {
            height: 410px;
          }

          .home-enhancements-inner {
            width: min(100% - 30px, 1100px);
          }

          .trust-stat {
            padding: 10px 11px;
          }

          .workload-strip-wrap {
            bottom: 22px;
          }

          .workload-strip {
            gap: 7px 9px;
            font-size: 11px;
          }

          .workload-item {
            gap: 9px;
          }
        }
      `}</style>

      <TenantIQLandingV2 />
      {mode === "home" && heroTarget && createPortal(<HomeEnhancements />, heroTarget)}
    </>
  );
}
