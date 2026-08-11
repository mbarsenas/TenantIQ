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
            background:
              radial-gradient(circle at 14% 18%, rgba(37,99,235,.12), transparent 26%),
              radial-gradient(circle at 76% 32%, rgba(76,141,255,.08), transparent 30%),
              linear-gradient(180deg,#07111f 0%,#0D1321 100%) !important;
          }

          #top .hero-grid {
            min-height: calc(100vh - 76px);
            align-items: center !important;
            padding-bottom: 72px !important;
          }

          #top .hero-grid > div:first-child > p:last-of-type {
            display: block !important;
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
