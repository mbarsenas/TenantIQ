'use client';

import { ShieldCheck, ExternalLink, FileText, Lock, Eye, ArrowLeft } from "lucide-react";

const sampleReportPath = "/TenantIQ-Sample-Assessment.pdf";

export default function DetailsPage() {
  return (
    <main className="details-page">
      <style jsx global>{`
        html { scroll-behavior: smooth; }
        body { margin: 0; background: #0d1321; color: #f5f7fa; }
        * { box-sizing: border-box; }
        a, button { -webkit-tap-highlight-color: transparent; }
        .details-page { min-height: 100vh; background: linear-gradient(180deg,#07111f 0%,#0d1321 100%); font-family: Inter, Arial, sans-serif; }
        .details-nav { position: sticky; top: 0; z-index: 50; display: flex; align-items: center; justify-content: space-between; gap: 18px; padding: 14px 28px; border-bottom: 1px solid #232c3d; background: rgba(7,17,31,.96); backdrop-filter: blur(12px); }
        .details-brand { color: #f5f7fa; text-decoration: none; font: 700 22px 'Space Grotesk', Inter, sans-serif; }
        .details-links { display: flex; align-items: center; gap: 18px; flex-wrap: wrap; }
        .details-links a { color: #dbe6f7; text-decoration: none; font-size: 14px; padding: 8px 2px; }
        .details-links a:hover { color: #6aa7ff; }
        .details-wrap { width: min(1080px, calc(100% - 40px)); margin: 0 auto; }
        .details-hero { padding: 70px 0 42px; }
        .eyebrow { color: #6aa7ff; font: 600 12px 'IBM Plex Mono', monospace; letter-spacing: .08em; text-transform: uppercase; }
        .details-hero h1 { margin: 12px 0 16px; font: 700 clamp(32px,6vw,52px)/1.08 'Space Grotesk', Inter, sans-serif; }
        .details-hero p { max-width: 720px; margin: 0; color: #8b95a5; font-size: 17px; line-height: 1.65; }
        .sample-card { display: grid; grid-template-columns: 1.15fr .85fr; gap: 24px; padding: 28px; border: 1px solid #232c3d; border-radius: 16px; background: #141b2b; }
        .sample-card h2 { margin: 0 0 12px; font: 700 28px 'Space Grotesk', Inter, sans-serif; }
        .sample-card p { color: #8b95a5; line-height: 1.65; }
        .sample-actions { display: flex; gap: 12px; flex-wrap: wrap; margin-top: 22px; }
        .sample-button { display: inline-flex; align-items: center; justify-content: center; gap: 9px; min-height: 48px; padding: 12px 18px; border-radius: 8px; text-decoration: none; font-weight: 700; touch-action: manipulation; }
        .sample-button.primary { background: #4c8dff; color: #07111f; border: 1px solid #4c8dff; }
        .sample-button.secondary { color: #f5f7fa; border: 1px solid #344057; background: transparent; }
        .sample-preview { display: flex; flex-direction: column; justify-content: center; min-height: 260px; padding: 22px; border-radius: 12px; border: 1px solid #2c3850; background: #0f1728; }
        .sample-preview-icon { width: 50px; height: 50px; display: grid; place-items: center; margin-bottom: 16px; border-radius: 12px; background: rgba(76,141,255,.12); color: #6aa7ff; }
        .sample-preview strong { font: 700 20px 'Space Grotesk', Inter, sans-serif; }
        .sample-preview span { margin-top: 8px; color: #8b95a5; line-height: 1.5; }
        .trust-section { padding: 60px 0 80px; }
        .trust-section h2 { margin: 0 0 24px; font: 700 28px 'Space Grotesk', Inter, sans-serif; }
        .trust-grid { display: grid; grid-template-columns: repeat(3, 1fr); gap: 16px; }
        .trust-card { padding: 22px; border: 1px solid #232c3d; border-radius: 12px; background: #141b2b; }
        .trust-card svg { color: #6aa7ff; margin-bottom: 14px; }
        .trust-card h3 { margin: 0 0 8px; font: 600 17px 'Space Grotesk', Inter, sans-serif; }
        .trust-card p { margin: 0; color: #8b95a5; font-size: 14px; line-height: 1.6; }
        .back-link { display: inline-flex; align-items: center; gap: 7px; color: #9fc0ff; text-decoration: none; margin-top: 26px; }
        @media (max-width: 760px) {
          .details-nav { align-items: flex-start; padding: 12px 16px; flex-direction: column; }
          .details-links { width: 100%; gap: 8px 14px; }
          .details-links a { min-height: 40px; display: inline-flex; align-items: center; }
          .details-wrap { width: min(100% - 28px, 1080px); }
          .details-hero { padding: 44px 0 28px; }
          .details-hero p { font-size: 15px; }
          .sample-card { grid-template-columns: 1fr; padding: 20px; }
          .sample-actions { flex-direction: column; }
          .sample-button { width: 100%; }
          .sample-preview { min-height: 190px; }
          .trust-grid { grid-template-columns: 1fr; }
        }
      `}</style>

      <nav className="details-nav" aria-label="Primary navigation">
        <a className="details-brand" href="/">TenantIQ</a>
        <div className="details-links">
          <a href="/product#what">Product</a>
          <a href="/product#coverage">Coverage</a>
          <a href="#sample">Sample Assessment</a>
          <a href="#trust">Security</a>
        </div>
      </nav>

      <div className="details-wrap">
        <section className="details-hero">
          <div className="eyebrow">TenantIQ assessment output</div>
          <h1>See what a TenantIQ finding looks like.</h1>
          <p>The sample report is a sanitized example of the evidence, status, and recommendation structure TenantIQ produces during a Microsoft 365 assessment.</p>
        </section>

        <section id="sample" className="sample-card" aria-labelledby="sample-title">
          <div>
            <h2 id="sample-title">Sample Assessment</h2>
            <p>Open the sample PDF to review a sanitized TenantIQ assessment. The link uses a normal browser document URL so it works consistently on iPhone, iPad, Android, and desktop browsers.</p>
            <div className="sample-actions">
              <a className="sample-button primary" href={sampleReportPath} target="_blank" rel="noopener noreferrer">
                <FileText size={19} /> Open sample report <ExternalLink size={16} />
              </a>
              <a className="sample-button secondary" href={sampleReportPath} download="TenantIQ-Sample-Assessment.pdf">
                Download PDF
              </a>
            </div>
          </div>
          <div className="sample-preview">
            <div className="sample-preview-icon"><ShieldCheck size={27} /></div>
            <strong>Sanitized Microsoft 365 assessment</strong>
            <span>Evidence-backed findings, status classification, and actionable recommendations in a portable PDF.</span>
          </div>
        </section>

        <section id="trust" className="trust-section" aria-labelledby="trust-title">
          <h2 id="trust-title">Security &amp; Trust</h2>
          <div className="trust-grid">
            <div className="trust-card"><Eye size={24}/><h3>Read-only assessment</h3><p>TenantIQ is designed to inspect tenant configuration and evidence without applying configuration changes.</p></div>
            <div className="trust-card"><Lock size={24}/><h3>Least-privilege approach</h3><p>Assessment access is scoped to the permissions required to retrieve supported Microsoft 365 configuration data.</p></div>
            <div className="trust-card"><ShieldCheck size={24}/><h3>Evidence-backed findings</h3><p>Findings are tied to the configuration data returned by the supported Microsoft 365 management surfaces.</p></div>
          </div>
          <a className="back-link" href="/"><ArrowLeft size={16}/> Back to TenantIQ</a>
        </section>
      </div>
    </main>
  );
}
