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
        html, body {
          max-width: 100%;
          overflow-x: hidden;
        }

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

          @media (max-width: 900px) {
            #top .site-nav {
              padding: 10px 20px !important;
              flex-wrap: wrap !important;
              gap: 10px !important;
            }

            #top .brand-link {
              width: 190px !important;
              height: 54px !important;
            }

            #top .brand-logo-crop {
              width: 190px !important;
              height: 54px !important;
              background-size: 190px 190px !important;
            }

            #top .nav-links {
              width: 100% !important;
              gap: 12px !important;
              flex-wrap: wrap !important;
              justify-content: flex-start !important;
            }

            #top .hero-grid {
              grid-template-columns: 1fr !important;
              gap: 28px !important;
              padding: 18px 20px 10px !important;
            }

            #top .hero-grid h1 {
              font-size: 36px !important;
              line-height: 1.08 !important;
              max-width: none !important;
            }

            #top .hero-grid > div:first-child > p:nth-of-type(1),
            #top .hero-grid > div:first-child > p:nth-of-type(2) {
              max-width: none !important;
            }

            #top .hero-actions {
              width: 100% !important;
            }

            #top .hero-actions .primary-button,
            #top .hero-actions .secondary-button {
              flex: 1 1 220px !important;
              text-align: center !important;
            }

            #top .hero-trust-row {
              max-width: none !important;
              grid-template-columns: repeat(2, minmax(0, 1fr)) !important;
            }

            #top .hero-network {
              height: 170px !important;
            }

            #top .hero-workloads {
              margin: -8px auto 0 !important;
              padding: 0 20px 28px !important;
            }

            #top .hero-workload-title span {
              white-space: normal !important;
            }
          }

          @media (max-width: 600px) {
            #top .site-nav {
              padding: 8px 16px !important;
            }

            #top .nav-links a {
              font-size: 13px !important;
            }

            #top .nav-links .compact-button {
              width: 100% !important;
              padding: 11px 14px !important;
            }

            #top .hero-grid {
              padding: 14px 16px 6px !important;
              gap: 22px !important;
            }

            #top .hero-grid h1 {
              font-size: clamp(31px, 10vw, 38px) !important;
              overflow-wrap: anywhere !important;
            }

            #top .hero-grid p {
              font-size: 15px !important;
              overflow-wrap: anywhere !important;
            }

            #top .hero-actions {
              flex-direction: column !important;
            }

            #top .hero-actions .primary-button,
            #top .hero-actions .secondary-button {
              width: 100% !important;
              flex: 0 0 auto !important;
            }

            #top .hero-trust-row {
              grid-template-columns: 1fr !important;
              margin-top: 24px !important;
            }

            #top .hero-trust-row > div {
              border-right: 0 !important;
              border-bottom: 1px solid rgba(139,149,165,.18) !important;
              min-width: 0 !important;
            }

            #top .hero-trust-row > div:last-child {
              border-bottom: 0 !important;
            }

            #top .hero-stat-grid {
              grid-template-columns: repeat(2, minmax(0, 1fr)) !important;
            }

            #top .hero-network {
              height: 145px !important;
            }

            #top .hero-network-badge {
              width: 40px !important;
              height: 40px !important;
            }

            #top .hero-workloads {
              padding: 0 16px 24px !important;
            }

            #top .hero-workload-grid {
              display: grid !important;
              grid-template-columns: repeat(2, minmax(0, 1fr)) !important;
              gap: 8px !important;
            }

            #top .hero-workload-item {
              width: 100% !important;
              min-width: 0 !important;
              white-space: normal !important;
              line-height: 1.25 !important;
            }
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
