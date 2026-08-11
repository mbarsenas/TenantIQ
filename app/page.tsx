'use client';

import TenantIQPageShell from "../components/TenantIQPageShell";

export default function Page() {
  return (
    <>
      <style jsx global>{`
        /* Home-page polish to match the approved reference composition. */
        #top {
          min-height: 900px !important;
          padding-bottom: 320px !important;
        }

        #top .hero-grid {
          max-width: 1280px !important;
          gap: 58px !important;
        }

        .home-enhancements {
          height: 340px !important;
        }

        .home-enhancements-inner {
          width: min(1280px, calc(100% - 80px)) !important;
        }

        .trust-stat-row {
          width: 650px !important;
          top: 6px !important;
        }

        .home-network {
          inset: 55px 0 92px !important;
          opacity: .9 !important;
        }

        .network-lines {
          stroke: rgba(42, 126, 255, .46) !important;
          stroke-width: 1.15 !important;
        }

        .network-nodes {
          fill: #35a8ff !important;
          filter: drop-shadow(0 0 10px rgba(53,168,255,.95)) !important;
        }

        /* Remove emoji-style floating badges; keep clean UI circles only. */
        .network-badge {
          font-size: 0 !important;
          width: 50px !important;
          height: 50px !important;
          border-color: rgba(50,140,255,.72) !important;
          background: rgba(4,18,38,.86) !important;
        }

        .network-badge::after {
          content: "";
          width: 18px;
          height: 18px;
          display: block;
          border: 2px solid #4c9cff;
          border-radius: 5px;
          opacity: .9;
        }

        .badge-shield::after {
          border-radius: 50% 50% 44% 44%;
          transform: rotate(45deg);
        }

        .badge-lock::after {
          border-radius: 4px;
        }

        .workload-strip-wrap {
          bottom: 10px !important;
          padding-top: 18px !important;
        }

        .workload-strip-title {
          top: -30px !important;
          font-size: 12px !important;
          font-weight: 700 !important;
          letter-spacing: .035em !important;
          text-transform: none !important;
        }

        .workload-strip {
          display: grid !important;
          grid-template-columns: repeat(8, minmax(92px, 1fr)) !important;
          gap: 18px !important;
          align-items: start !important;
          margin-top: -8px !important;
        }

        .workload-item {
          display: flex !important;
          flex-direction: column !important;
          align-items: center !important;
          justify-content: flex-start !important;
          gap: 10px !important;
          min-width: 0 !important;
          white-space: nowrap !important;
        }

        .workload-logo {
          width: 46px !important;
          height: 46px !important;
          display: flex !important;
          align-items: center !important;
          justify-content: center !important;
          transform: none !important;
        }

        .workload-logo svg {
          width: 46px !important;
          height: 46px !important;
          display: block !important;
          transform: none !important;
        }

        .workload-name {
          font-size: 12px !important;
          line-height: 1.15 !important;
          color: #f3f6fb !important;
          overflow: visible !important;
          max-width: none !important;
        }

        /* The earlier hand-drawn Entra/Exchange SVGs read as tilted.
           Replace just those two with upright, neutral workload glyphs. */
        .workload-item:nth-child(1) .workload-logo svg,
        .workload-item:nth-child(2) .workload-logo svg {
          display: none !important;
        }

        .workload-item:nth-child(1) .workload-logo::before {
          content: "ID";
          width: 34px;
          height: 34px;
          display: flex;
          align-items: center;
          justify-content: center;
          color: #d9f2ff;
          font: 700 11px/1 'Space Grotesk', sans-serif;
          background: linear-gradient(145deg, #1e6fff, #24c6ef);
          clip-path: polygon(50% 0, 100% 50%, 50% 100%, 0 50%);
          filter: drop-shadow(0 0 8px rgba(36,198,239,.32));
        }

        .workload-item:nth-child(2) .workload-logo::before {
          content: "✉";
          width: 36px;
          height: 32px;
          display: flex;
          align-items: center;
          justify-content: center;
          color: white;
          font: 700 18px/1 Arial, sans-serif;
          border-radius: 6px;
          background: linear-gradient(145deg, #0c6bdc, #2a9cff);
          box-shadow: 8px -5px 0 -2px rgba(40,151,255,.42);
        }

        @media (max-width: 1100px) {
          #top {
            min-height: 980px !important;
            padding-bottom: 420px !important;
          }

          .home-enhancements {
            height: 430px !important;
          }

          .workload-strip {
            grid-template-columns: repeat(4, minmax(110px, 1fr)) !important;
            row-gap: 20px !important;
          }
        }

        @media (max-width: 620px) {
          #top {
            min-height: 1240px !important;
            padding-bottom: 600px !important;
          }

          .home-enhancements {
            height: 610px !important;
          }

          .home-enhancements-inner {
            width: calc(100% - 30px) !important;
          }

          .trust-stat-row {
            width: 100% !important;
          }

          .workload-strip {
            grid-template-columns: repeat(2, minmax(110px, 1fr)) !important;
          }
        }
      `}</style>
      <TenantIQPageShell mode="home" />
    </>
  );
}
