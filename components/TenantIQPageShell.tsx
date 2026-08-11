'use client';

import { useEffect } from "react";
import TenantIQLandingV2 from "./TenantIQLandingV2";

type PageMode = "home" | "product" | "details";

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
      const href = link.getAttribute("href") || "";
      const nextHref = routeMap[href];
      if (nextHref) link.setAttribute("href", nextHref);
    });

    document.querySelectorAll<HTMLButtonElement>("button").forEach((button) => {
      if (button.textContent?.trim() === "View sample assessment") {
        button.onclick = () => {
          window.location.href = "/details#sample";
        };
      }
    });
  }, []);

  return (
    <>
      <style>{`
        ${mode === "home" ? `
          #what, #coverage, #how, #sample, #trust, #audience, #early-access, footer {
            display: none !important;
          }

          #top {
            min-height: 100vh !important;
            overflow: hidden;
            background:
              radial-gradient(circle at 14% 18%, rgba(37,99,235,.12), transparent 26%),
              radial-gradient(circle at 76% 32%, rgba(76,141,255,.08), transparent 30%),
              linear-gradient(180deg,#07111f 0%,#0D1321 100%) !important;
          }

          #top .site-nav {
            max-width: 1320px !important;
            padding: 10px 48px !important;
          }

          #top .hero-grid {
            max-width: 1320px !important;
            min-height: 0 !important;
            align-items: start !important;
            grid-template-columns: 0.92fr 1.08fr !important;
            gap: 70px !important;
            padding: 18px 48px 8px !important;
          }

          #top .hero-grid > div:first-child {
            padding-top: 8px;
          }

          #top .hero-grid h1 {
            font-size: 46px !important;
            line-height: 1.06 !important;
            max-width: 560px;
          }

          #top .hero-grid > div:first-child > p:nth-of-type(1) {
            font-size: 17px !important;
            line-height: 1.58 !important;
            max-width: 520px !important;
          }

          #top .hero-grid > div:first-child > p:nth-of-type(2) {
            max-width: 500px !important;
          }

          #top .hero-trust-row {
            margin-top: 34px !important;
            width: 100% !important;
            max-width: 620px !important;
          }

          #top .hero-network {
            margin-top: 4px !important;
            height: 220px !important;
          }

          #top .hero-workloads {
            max-width: 1320px !important;
            margin: -18px auto 0 !important;
            padding: 0 48px 32px !important;
          }

          #top .hero-workload-title {
            margin-bottom: 14px !important;
          }

          #top .hero-workload-grid {
            gap: 12px !important;
          }

          #top .hero-workload-logo,
          #top .hero-workload-logo svg {
            width: 54px !important;
            height: 54px !important;
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
      `}</style>

      <TenantIQLandingV2 />
    </>
  );
}
