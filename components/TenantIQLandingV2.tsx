'use client';

import React, { useEffect, useState } from "react";
import {
  ShieldCheck,
  Mail,
  ShieldAlert,
  Smartphone,
  Eye,
  Users,
  Cloud,
  FolderOpen,
  Search,
  BarChart3,
  ListChecks,
  Wrench,
  Lock,
  UserCheck,
  Settings,
  BriefcaseBusiness,
  Building2,
  ArrowRight,
  X,
  CheckCircle2,
} from "lucide-react";

const COLORS = {
  ink: "#0D1321",
  card: "#141B2B",
  cardAlt: "#161F33",
  border: "#232C3D",
  blue: "#4C8DFF",
  blueDark: "#2563EB",
  blueTint: "rgba(76,141,255,0.12)",
  textPrimary: "#F5F7FA",
  textSecondary: "#8B95A5",
  textMuted: "#5B6478",
  green: "#22C55E",
  amber: "#F5A524",
  red: "#F87171",
};

const FONT_DISPLAY = "'Space Grotesk', sans-serif";
const FONT_BODY = "'Inter', sans-serif";
const FONT_MONO = "'IBM Plex Mono', monospace";

function StatCard({
  label,
  value,
  color,
}: {
  label: string;
  value: string | number;
  color?: string;
}) {
  return (
    <div
      style={{
        background: COLORS.cardAlt,
        border: `1px solid ${COLORS.border}`,
        borderRadius: "10px",
        padding: "14px 16px",
        flex: 1,
      }}
    >
      <div style={{ fontFamily: FONT_BODY, fontSize: "12px", color: COLORS.textSecondary, marginBottom: "6px" }}>
        {label}
      </div>
      <div style={{ fontFamily: FONT_DISPLAY, fontWeight: 700, fontSize: "22px", color: color || COLORS.textPrimary }}>
        {value}
      </div>
    </div>
  );
}

function ReportPreview() {
  const rows = [
    { name: "Privileged roles assigned via groups", status: "PASS", color: COLORS.green },
    { name: "Admin portal restricted", status: "FAIL", color: COLORS.red },
    { name: "Authentication Methods: FIDO2 enabled", status: "PASS", color: COLORS.green },
  ];

  return (
    <div
      aria-label="Sanitized TenantIQ Entra ID assessment preview"
      style={{
        background: COLORS.card,
        borderRadius: "12px",
        border: `1px solid ${COLORS.border}`,
        overflow: "hidden",
        boxShadow: "0 24px 60px -24px rgba(0,0,0,0.6)",
      }}
    >
      <div
        style={{
          background: `linear-gradient(135deg, ${COLORS.blueDark}, #1E3A8A)`,
          padding: "16px 20px",
          display: "flex",
          justifyContent: "space-between",
          alignItems: "flex-start",
          gap: "18px",
        }}
      >
        <div>
          <div style={{ display: "flex", alignItems: "center", gap: "10px" }}>
            <img
              src="/tenantiq-mark.png"
              alt=""
              aria-hidden="true"
              width={34}
              height={34}
              style={{
                width: "34px",
                height: "34px",
                objectFit: "contain",
              }}
            />
            <div style={{ fontFamily: FONT_DISPLAY, fontWeight: 700, fontSize: "18px", color: "#fff" }}>
              TenantIQ
            </div>
          </div>
          <div style={{ fontFamily: FONT_BODY, fontSize: "12px", color: "#B9CCFA", marginTop: "8px" }}>
            Entra Identity Security â€” sanitized assessment
          </div>
        </div>

        <div style={{ textAlign: "right" }}>
          <div style={{ fontFamily: FONT_BODY, fontSize: "11px", color: "#B9CCFA" }}>Assessment score</div>
          <div style={{ fontFamily: FONT_DISPLAY, fontWeight: 700, fontSize: "26px", color: "#fff" }}>
            73.6%
          </div>
          <span
            style={{
              fontFamily: FONT_MONO,
              fontSize: "9px",
              color: "#fff",
              background: "rgba(255,255,255,0.14)",
              borderRadius: "20px",
              padding: "3px 8px",
              display: "inline-block",
              marginTop: "4px",
              letterSpacing: ".04em",
            }}
          >
            SAMPLE
          </span>
        </div>
      </div>

      <div style={{ padding: "15px 18px" }}>
        <div className="hero-stat-grid" style={{ display: "grid", gridTemplateColumns: "repeat(4, 1fr)", gap: "10px", marginBottom: "16px" }}>
          <StatCard label="Checks" value="53" />
          <StatCard label="Passed" value="39" color={COLORS.green} />
          <StatCard label="Warnings" value="0" color={COLORS.amber} />
          <StatCard label="Failed" value="14" color={COLORS.red} />
        </div>

        <div
          style={{
            background: "rgba(248,113,113,0.10)",
            borderLeft: `3px solid ${COLORS.red}`,
            borderRadius: "8px",
            padding: "14px 16px",
          }}
        >
          <div style={{ fontFamily: FONT_BODY, fontSize: "11px", fontWeight: 600, color: COLORS.red, textTransform: "uppercase", letterSpacing: "0.03em", marginBottom: "6px" }}>
            Finding requiring attention
          </div>
          <div style={{ fontFamily: FONT_DISPLAY, fontWeight: 600, fontSize: "15px", color: COLORS.textPrimary, marginBottom: "4px" }}>
            Named location(s) exist
          </div>
          <div style={{ fontFamily: FONT_BODY, fontSize: "13px", color: COLORS.textSecondary, lineHeight: 1.5 }}>
            Evidence: 0 named locations configured.
          </div>
        </div>

        <div style={{ marginTop: "14px", display: "flex", flexDirection: "column", gap: "6px" }}>
          {rows.map((row) => (
            <div
              key={row.name}
              style={{
                display: "flex",
                justifyContent: "space-between",
                alignItems: "center",
                gap: "12px",
                padding: "8px 10px",
                background: COLORS.cardAlt,
                borderRadius: "6px",
              }}
            >
              <span style={{ fontFamily: FONT_BODY, fontSize: "12.5px", color: COLORS.textPrimary }}>{row.name}</span>
              <span style={{ fontFamily: FONT_MONO, fontSize: "11px", fontWeight: 600, color: row.color }}>{row.status}</span>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}

function Brand() {
  return (
    <a
      href="#top"
      aria-label="TenantIQ home"
      className="brand-link"
      style={{
        display: "inline-flex",
        alignItems: "center",
        textDecoration: "none",
        flexShrink: 0,
        width: "250px",
        height: "64px",
        overflow: "hidden",
      }}
    >
      <span
        role="img"
        aria-label="TenantIQ"
        className="brand-logo-crop"
        style={{
          display: "block",
          width: "250px",
          height: "64px",
          backgroundImage: 'url("/tenantiq-header-clean.png")',
          backgroundRepeat: "no-repeat",
          backgroundPosition: "center center",
          backgroundSize: "250px 250px",
        }}
      />
    </a>
  );
}
function Nav({ onRequestAccess }: { onRequestAccess: () => void }) {
  return (
    <nav
      aria-label="Primary navigation"
      className="site-nav"
      style={{
        display: "flex",
        alignItems: "center",
        justifyContent: "space-between",
        padding: "6px 48px",
        maxWidth: "1200px",
        margin: "0 auto",
        gap: "24px",
      }}
    >
      <Brand />
      <div className="nav-links" style={{ display: "flex", alignItems: "center", gap: "28px" }}>
        <a href="#what" className="nav-link">Product</a>
        <a href="#coverage" className="nav-link">Coverage</a>
        <a href="#sample" className="nav-link">Sample Assessment</a>
        <a href="#trust" className="nav-link">Security</a>
        <button type="button" onClick={onRequestAccess} className="primary-button compact-button">
          Request early access
        </button>
      </div>
    </nav>
  );
}

function Hero({ onRequestAccess }: { onRequestAccess: () => void }) {
  return (
    <div id="top" style={{ background: COLORS.ink }}>
      <Nav onRequestAccess={onRequestAccess} />
      <div
        className="hero-grid"
        style={{
          maxWidth: "1200px",
          margin: "0 auto",
          padding: "8px 48px 42px",
          display: "grid",
          gridTemplateColumns: "1fr 1fr",
          gap: "52px",
          alignItems: "center",
        }}
      >
        <div>
          <div
            style={{
              display: "inline-block",
              fontFamily: FONT_MONO,
              fontSize: "12px",
              color: COLORS.blue,
              background: COLORS.blueTint,
              borderRadius: "20px",
              padding: "5px 12px",
              marginBottom: "18px",
            }}
          >
            Microsoft 365 tenant intelligence
          </div>

          <h1
            style={{
              fontFamily: FONT_DISPLAY,
              fontWeight: 700,
              fontSize: "40px",
              lineHeight: 1.15,
              color: COLORS.textPrimary,
              margin: "0 0 20px",
              letterSpacing: "-0.01em",
            }}
          >
            Microsoft 365 tenant intelligence, without the guesswork.
          </h1>

          <p
            style={{
              fontFamily: FONT_BODY,
              fontSize: "17px",
              lineHeight: 1.6,
              color: COLORS.textSecondary,
              margin: "0 0 20px",
              maxWidth: "500px",
            }}
          >
            TenantIQ performs automated, read-only analysis of a Microsoft 365
            environment and turns configuration data into prioritized
            findings, risk insights, and actionable recommendations.
          </p>

          <p
            style={{
              fontFamily: FONT_BODY,
              fontSize: "15px",
              lineHeight: 1.6,
              color: COLORS.textMuted,
              margin: "0 0 24px",
              maxWidth: "470px",
            }}
          >
            Configuration data tells you what's there. TenantIQ helps you
            understand what matters and what to address next.
          </p>

          <div className="hero-actions" style={{ display: "flex", gap: "12px", flexWrap: "wrap" }}>
            <button type="button" onClick={onRequestAccess} className="primary-button">
              Request early access
            </button>
            <button
              type="button"
              onClick={() => document.getElementById("sample")?.scrollIntoView({ behavior: "smooth" })}
              className="secondary-button"
            >
              View sample assessment
            </button>
          </div>

          <p style={{ fontFamily: FONT_BODY, fontSize: "13px", color: COLORS.textMuted, marginTop: "16px" }}>
            Read-only, least-privilege access. No changes made to your tenant.
          </p>
        </div>

        <ReportPreview />
      </div>
    </div>
  );
}

function WhatTenantIQDoes() {
  const steps = [
    {
      n: "01",
      icon: Search,
      title: "Assessment",
      body: "TenantIQ connects to a Microsoft 365 tenant with read-only, least-privilege access and pulls configuration data across the workloads it covers â€” identity, mail flow, device management, data protection, and collaboration settings.",
    },
    {
      n: "02",
      icon: BarChart3,
      title: "Analysis",
      body: "Every setting is evaluated against security and operational baselines, not just recorded. TenantIQ looks for the gaps, exceptions, and drift that raw configuration data doesn't surface on its own.",
    },
    {
      n: "03",
      icon: ListChecks,
      title: "Findings",
      body: "Each issue is captured as a discrete finding: what was checked, what was found, the evidence behind it, and its PASS, WARN, or FAIL status â€” so nothing is a vague \u201cyou should probably look into this.\u201d",
    },
    {
      n: "04",
      icon: Wrench,
      title: "Recommendations",
      body: "Every finding ships with a specific, actionable next step â€” what to change, why it matters, and what the risk is if it's left alone. The recommendation is tied to the exact thing that was found.",
    },
  ];

  return (
    <div id="what" style={{ background: COLORS.card, padding: "58px 48px", borderTop: `1px solid ${COLORS.border}`, borderBottom: `1px solid ${COLORS.border}` }}>
      <div style={{ maxWidth: "1200px", margin: "0 auto" }}>
        <h2
          style={{
            fontFamily: FONT_DISPLAY,
            fontWeight: 700,
            fontSize: "28px",
            color: COLORS.textPrimary,
            marginBottom: "16px",
          }}
        >
          What TenantIQ does
        </h2>
        <p
          style={{
            fontFamily: FONT_BODY,
            fontSize: "15px",
            lineHeight: 1.7,
            color: COLORS.textSecondary,
            maxWidth: "680px",
            marginBottom: "48px",
          }}
        >
          Microsoft 365 provides a tremendous amount of configuration data.
          The challenge is turning that data into decisions. TenantIQ evaluates
          what it finds, identifies meaningful gaps and risks, and provides
          clear guidance on what to address next.
        </p>

        <div style={{ display: "grid", gridTemplateColumns: "repeat(4, 1fr)", gap: "1px", background: COLORS.border }}>
          {steps.map((s, i) => {
            const Icon = s.icon;
            return (
              <div key={i} style={{ background: COLORS.card, padding: "28px 24px" }}>
                <div style={{ display: "flex", alignItems: "center", gap: "10px", marginBottom: "18px" }}>
                  <span style={{ fontFamily: FONT_MONO, fontSize: "12px", color: COLORS.blue }}>{s.n}</span>
                  <div
                    style={{
                      width: 28,
                      height: 28,
                      borderRadius: "7px",
                      background: COLORS.blueTint,
                      display: "flex",
                      alignItems: "center",
                      justifyContent: "center",
                    }}
                  >
                    <Icon size={15} color={COLORS.blue} />
                  </div>
                </div>
                <h3
                  style={{
                    fontFamily: FONT_DISPLAY,
                    fontWeight: 600,
                    fontSize: "16px",
                    color: COLORS.textPrimary,
                    margin: "0 0 8px",
                  }}
                >
                  {s.title}
                </h3>
                <p
                  style={{
                    fontFamily: FONT_BODY,
                    fontSize: "13.5px",
                    lineHeight: 1.6,
                    color: COLORS.textSecondary,
                    margin: 0,
                  }}
                >
                  {s.body}
                </p>
              </div>
            );
          })}
        </div>
      </div>
    </div>
  );
}

function MicrosoftCoverage() {
  const modules = [
    { icon: ShieldCheck, name: "Microsoft Entra ID", body: "Identity, authentication, privileged access, applications, and tenant security configuration." },
    { icon: Mail, name: "Exchange Online", body: "Messaging configuration, authentication, mail protection, domains, and transport security." },
    { icon: FolderOpen, name: "SharePoint Online", body: "Sharing, access, governance, tenant configuration, and collaboration controls." },
    { icon: Users, name: "Microsoft Teams", body: "Meetings, messaging, external access, collaboration, and governance configuration." },
    { icon: Cloud, name: "OneDrive", body: "Sharing, synchronization, access controls, storage, and tenant-level configuration." },
    { icon: Smartphone, name: "Microsoft Intune", body: "Device management, enrollment, compliance, configuration, and endpoint security controls." },
    { icon: ShieldAlert, name: "Microsoft Defender", body: "Threat protection, security configuration, detection capabilities, and protection policies." },
    { icon: Eye, name: "Microsoft Purview", body: "Information protection, data governance, retention, compliance, and auditing controls." },
  ];

  return (
    <div id="coverage" style={{ background: COLORS.card, padding: "80px 48px", borderTop: `1px solid ${COLORS.border}` }}>
      <div style={{ maxWidth: "1200px", margin: "0 auto" }}>
        <div
          style={{
            fontFamily: FONT_MONO,
            fontSize: "12px",
            color: COLORS.blue,
            letterSpacing: "0.06em",
            marginBottom: "12px",
          }}
        >
          MICROSOFT 365 COVERAGE
        </div>
        <h2
          style={{
            fontFamily: FONT_DISPLAY,
            fontWeight: 700,
            fontSize: "28px",
            color: COLORS.textPrimary,
            marginBottom: "16px",
          }}
        >
          One assessment. Eight Microsoft 365 workloads.
        </h2>
        <p
          style={{
            fontFamily: FONT_BODY,
            fontSize: "15px",
            lineHeight: 1.7,
            color: COLORS.textSecondary,
            maxWidth: "700px",
            marginBottom: "40px",
          }}
        >
          TenantIQ evaluates identity, security, collaboration, messaging,
          device management, data protection, and governance across the
          Microsoft 365 environment â€” bringing findings together into a
          consistent assessment experience.
        </p>

        <div style={{ display: "grid", gridTemplateColumns: "repeat(4, 1fr)", gap: "16px", marginBottom: "32px" }}>
          {modules.map((m, i) => {
            const Icon = m.icon;
            return (
              <div
                key={i}
                style={{
                  background: COLORS.cardAlt,
                  border: `1px solid ${COLORS.border}`,
                  borderRadius: "10px",
                  padding: "20px",
                }}
              >
                <div
                  style={{
                    width: 32,
                    height: 32,
                    borderRadius: "8px",
                    background: COLORS.blueTint,
                    display: "flex",
                    alignItems: "center",
                    justifyContent: "center",
                    marginBottom: "14px",
                  }}
                >
                  <Icon size={17} color={COLORS.blue} />
                </div>
                <h3 style={{ fontFamily: FONT_DISPLAY, fontWeight: 600, fontSize: "15px", color: COLORS.textPrimary, margin: "0 0 6px" }}>
                  {m.name}
                </h3>
                <p style={{ fontFamily: FONT_BODY, fontSize: "13px", lineHeight: 1.5, color: COLORS.textSecondary, margin: 0 }}>
                  {m.body}
                </p>
              </div>
            );
          })}
        </div>

        <div
          style={{
            display: "flex",
            alignItems: "center",
            gap: "10px",
            paddingTop: "24px",
            borderTop: `1px solid ${COLORS.border}`,
          }}
        >
          <span style={{ fontFamily: FONT_DISPLAY, fontWeight: 600, fontSize: "14px", color: COLORS.textPrimary }}>
            8 Microsoft 365 workloads
          </span>
          <span style={{ color: COLORS.textMuted }}>Â·</span>
          <span style={{ fontFamily: FONT_DISPLAY, fontWeight: 600, fontSize: "14px", color: COLORS.textPrimary }}>
            350+ automated checks
          </span>
        </div>
      </div>
    </div>
  );
}

function SampleAssessment() {
  const sampleFindings = [
    {
      name: "Named location(s) exist",
      status: "FAIL",
      color: COLORS.red,
      detail: "0 named locations",
    },
    {
      name: "Privileged roles assigned via groups",
      status: "PASS",
      color: COLORS.green,
      detail: "No groups have privileged role assignments",
    },
    {
      name: "Security Defaults disabled",
      status: "PASS",
      color: COLORS.green,
      detail: "Security Defaults disabled",
    },
    {
      name: "Admin portal restricted",
      status: "FAIL",
      color: COLORS.red,
      detail: "No policy blocks admin portals for non-admins",
    },
    {
      name: "Authentication Methods: FIDO2 enabled",
      status: "PASS",
      color: COLORS.green,
      detail: "FIDO2 enabled",
    },
    {
      name: "Authentication Methods: TAP enabled",
      status: "FAIL",
      color: COLORS.red,
      detail: "TAP disabled",
    },
  ];

  return (
    <div id="sample" style={{ background: COLORS.ink, padding: "80px 48px" }}>
      <div style={{ maxWidth: "1080px", margin: "0 auto" }}>
        <div
          style={{
            fontFamily: FONT_MONO,
            fontSize: "12px",
            color: COLORS.blue,
            letterSpacing: "0.06em",
            marginBottom: "12px",
            textAlign: "center",
          }}
        >
          SEE TENANTIQ IN ACTION
        </div>

        <h2
          style={{
            fontFamily: FONT_DISPLAY,
            fontWeight: 700,
            fontSize: "28px",
            color: COLORS.textPrimary,
            marginBottom: "16px",
            textAlign: "center",
          }}
        >
          See the assessment the way an administrator sees it.
        </h2>

        <p
          style={{
            fontFamily: FONT_BODY,
            fontSize: "15px",
            lineHeight: 1.7,
            color: COLORS.textSecondary,
            maxWidth: "700px",
            margin: "0 auto 42px",
            textAlign: "center",
          }}
        >
          This sanitized sample mirrors real TenantIQ assessment output:
          workload score, PASS/WARN/FAIL totals, and the exact checks and
          evidence behind each result.
        </p>

        <div
          style={{
            background: "#F5F7FB",
            border: "1px solid #D7DEEA",
            borderRadius: "14px",
            overflow: "hidden",
            boxShadow: "0 30px 80px -34px rgba(0,0,0,0.75)",
          }}
        >
          {/* Product header */}
          <div
            style={{
              background: "linear-gradient(135deg, #17233B, #24385D)",
              padding: "18px 24px",
              display: "flex",
              justifyContent: "space-between",
              alignItems: "center",
              gap: "18px",
            }}
          >
            <div style={{ display: "flex", alignItems: "center", gap: "12px" }}>
              <img
                src="/tenantiq-mark.png"
                alt=""
                aria-hidden="true"
                width={42}
                height={42}
                style={{
                  width: "42px",
                  height: "42px",
                  objectFit: "contain",
                }}
              />
              <div>
                <div
                  style={{
                    fontFamily: FONT_DISPLAY,
                    fontWeight: 700,
                    fontSize: "16px",
                    color: "#fff",
                  }}
                >
                  TenantIQ
                </div>
                <div
                  style={{
                    fontFamily: FONT_BODY,
                    fontSize: "11px",
                    color: "#AFC0DF",
                    marginTop: "2px",
                  }}
                >
                  Tenant Intelligence & Assessment
                </div>
              </div>
            </div>

            <span
              style={{
                fontFamily: FONT_MONO,
                fontSize: "10px",
                color: "#D7E3FF",
                background: "rgba(255,255,255,0.10)",
                border: "1px solid rgba(255,255,255,0.12)",
                borderRadius: "999px",
                padding: "5px 10px",
              }}
            >
              SANITIZED SAMPLE
            </span>
          </div>

          {/* Report title */}
          <div
            style={{
              padding: "22px 24px 18px",
              background: "#FFFFFF",
              borderBottom: "1px solid #E3E8F0",
            }}
          >
            <div
              style={{
                fontFamily: FONT_DISPLAY,
                fontWeight: 700,
                fontSize: "20px",
                color: "#26354F",
              }}
            >
              Entra Identity Security
            </div>
            <div
              style={{
                fontFamily: FONT_BODY,
                fontSize: "12px",
                color: "#6F7C90",
                marginTop: "5px",
              }}
            >
              Tenant: contoso01.onmicrosoft.com
            </div>
          </div>

          {/* Actual summary values from the sample assessment */}
          <div
            style={{
              padding: "18px 24px",
              background: "#FFFFFF",
              display: "grid",
              gridTemplateColumns: "repeat(5, 1fr)",
              gap: "10px",
              borderBottom: "1px solid #E3E8F0",
            }}
          >
            {[
              { label: "Checks", value: "53", color: "#26354F" },
              { label: "Pass", value: "39", color: "#16A34A" },
              { label: "Warn", value: "0", color: "#D97706" },
              { label: "Fail", value: "14", color: "#DC2626" },
              { label: "Score", value: "73.6%", color: "#2563EB" },
            ].map((s) => (
              <div
                key={s.label}
                style={{
                  background: "#F8FAFD",
                  border: "1px solid #E1E7F0",
                  borderRadius: "7px",
                  padding: "12px 14px",
                }}
              >
                <div
                  style={{
                    fontFamily: FONT_BODY,
                    fontSize: "10.5px",
                    color: "#7B8798",
                    textTransform: "uppercase",
                    letterSpacing: "0.04em",
                  }}
                >
                  {s.label}
                </div>
                <div
                  style={{
                    fontFamily: FONT_DISPLAY,
                    fontWeight: 700,
                    fontSize: "20px",
                    color: s.color,
                    marginTop: "3px",
                  }}
                >
                  {s.value}
                </div>
              </div>
            ))}
          </div>

          {/* Table */}
          <div style={{ padding: "0 24px 24px", background: "#FFFFFF" }}>
            <div
              style={{
                display: "grid",
                gridTemplateColumns: "60px 1.1fr 1.7fr",
                gap: "12px",
                padding: "12px 10px",
                borderBottom: "1px solid #E3E8F0",
                fontFamily: FONT_BODY,
                fontSize: "10.5px",
                fontWeight: 700,
                color: "#657287",
                textTransform: "uppercase",
                letterSpacing: "0.04em",
              }}
            >
              <span>Status</span>
              <span>Check</span>
              <span>Evidence</span>
            </div>

            {sampleFindings.map((finding) => (
              <div
                key={finding.name}
                style={{
                  display: "grid",
                  gridTemplateColumns: "60px 1.1fr 1.7fr",
                  gap: "12px",
                  padding: "13px 10px",
                  borderBottom: "1px solid #EDF1F6",
                  alignItems: "center",
                }}
              >
                <span
                  style={{
                    display: "inline-flex",
                    alignItems: "center",
                    justifyContent: "center",
                    width: "24px",
                    height: "24px",
                    borderRadius: "50%",
                    background:
                      finding.status === "PASS"
                        ? "#DCFCE7"
                        : finding.status === "WARN"
                        ? "#FEF3C7"
                        : "#FEE2E2",
                    color: finding.color,
                    fontFamily: FONT_BODY,
                    fontSize: "13px",
                    fontWeight: 700,
                  }}
                >
                  {finding.status === "PASS" ? "âœ“" : finding.status === "WARN" ? "!" : "Ã—"}
                </span>

                <span
                  style={{
                    fontFamily: FONT_BODY,
                    fontSize: "12.5px",
                    fontWeight: 600,
                    color: "#334155",
                    lineHeight: 1.45,
                  }}
                >
                  {finding.name}
                </span>

                <span
                  style={{
                    fontFamily: FONT_BODY,
                    fontSize: "12px",
                    color: "#69768A",
                    lineHeight: 1.45,
                  }}
                >
                  {finding.detail}
                </span>
              </div>
            ))}

            <div
              style={{
                padding: "14px 10px 0",
                fontFamily: FONT_BODY,
                fontSize: "11px",
                color: "#8A95A5",
              }}
            >
              Showing 6 of 53 checks in this sanitized preview.
            </div>
          </div>
        </div>

        <div
          style={{
            marginTop: "22px",
            display: "flex",
            justifyContent: "center",
            gap: "12px",
            flexWrap: "wrap",
          }}
        >
          <span
            style={{
              fontFamily: FONT_MONO,
              fontSize: "11px",
              color: COLORS.textMuted,
            }}
          >
            SCORE
          </span>
          <span style={{ color: COLORS.textMuted }}>â†’</span>
          <span
            style={{
              fontFamily: FONT_MONO,
              fontSize: "11px",
              color: COLORS.textMuted,
            }}
          >
            CHECK
          </span>
          <span style={{ color: COLORS.textMuted }}>â†’</span>
          <span
            style={{
              fontFamily: FONT_MONO,
              fontSize: "11px",
              color: COLORS.textMuted,
            }}
          >
            EVIDENCE
          </span>
          <span style={{ color: COLORS.textMuted }}>â†’</span>
          <span
            style={{
              fontFamily: FONT_MONO,
              fontSize: "11px",
              color: COLORS.textMuted,
            }}
          >
            ACTION
          </span>
        </div>

        <div style={{ textAlign: "center", marginTop: "28px" }}>
          <a
            href="/TenantIQ-Sample-Assessment.pdf"
            target="_blank"
            rel="noopener noreferrer"
            aria-label="Open the full TenantIQ sample assessment PDF in a new tab"
            style={{
              display: "inline-block",
              fontFamily: FONT_BODY,
              fontWeight: 600,
              fontSize: "14px",
              color: COLORS.ink,
              background: COLORS.blue,
              borderRadius: "6px",
              padding: "13px 24px",
              cursor: "pointer",
              textDecoration: "none",
            }}
          >
            View full sample assessment
          </a>
        </div>
      </div>
    </div>
  );
}

function SecurityTrust() {
  const points = [
    {
      icon: Eye,
      title: "Read-only assessment",
      body: "TenantIQ evaluates configuration and security data without making changes to the Microsoft 365 environment.",
    },
    {
      icon: Lock,
      title: "Least-privilege access",
      body: "Access is limited to the permissions required to perform supported assessment checks.",
    },
    {
      icon: ShieldCheck,
      title: "Transparent findings",
      body: "Every result is tied to the configuration or condition that triggered it, helping administrators understand why a finding exists.",
    },
    {
      icon: UserCheck,
      title: "You stay in control",
      body: "TenantIQ provides recommendations and remediation guidance. Changes remain the responsibility of the tenant administrator.",
    },
  ];

  return (
    <div id="trust" style={{ background: COLORS.card, padding: "80px 48px", borderTop: `1px solid ${COLORS.border}` }}>
      <div style={{ maxWidth: "1200px", margin: "0 auto" }}>
        <div
          style={{
            fontFamily: FONT_MONO,
            fontSize: "12px",
            color: COLORS.textMuted,
            letterSpacing: "0.06em",
            marginBottom: "12px",
          }}
        >
          SECURITY & TRUST
        </div>
        <h2
          style={{
            fontFamily: FONT_DISPLAY,
            fontWeight: 700,
            fontSize: "28px",
            color: COLORS.textPrimary,
            marginBottom: "16px",
          }}
        >
          Built to assess your tenant â€” not change it.
        </h2>
        <p
          style={{
            fontFamily: FONT_BODY,
            fontSize: "15px",
            lineHeight: 1.7,
            color: COLORS.textSecondary,
            maxWidth: "680px",
            marginBottom: "40px",
          }}
        >
          TenantIQ is designed around read-only access and least-privilege
          principles. It collects the Microsoft 365 configuration data
          required for assessment, evaluates that data, and returns findings
          without modifying tenant settings.
        </p>

        <div style={{ display: "grid", gridTemplateColumns: "repeat(4, 1fr)", gap: "16px", marginBottom: "32px" }}>
          {points.map((p, i) => {
            const Icon = p.icon;
            return (
              <div key={i} style={{ padding: "4px 0" }}>
                <Icon size={18} color={COLORS.textMuted} style={{ marginBottom: "12px" }} />
                <h3 style={{ fontFamily: FONT_DISPLAY, fontWeight: 600, fontSize: "14.5px", color: COLORS.textPrimary, margin: "0 0 6px" }}>
                  {p.title}
                </h3>
                <p style={{ fontFamily: FONT_BODY, fontSize: "13px", lineHeight: 1.55, color: COLORS.textSecondary, margin: 0 }}>
                  {p.body}
                </p>
              </div>
            );
          })}
        </div>

        <div style={{ textAlign: "center", paddingTop: "24px", borderTop: `1px solid ${COLORS.border}` }}>
          <span style={{ fontFamily: FONT_BODY, fontSize: "13.5px", color: COLORS.textMuted, fontStyle: "italic" }}>
            No automated remediation. No silent configuration changes.
          </span>
        </div>
      </div>
    </div>
  );
}

function HowTenantIQWorks() {
  const steps = [
    {
      n: "01",
      title: "Connect the tenant",
      body: "Securely connect to Microsoft 365 using approved, read-only permissions. TenantIQ collects the configuration and security data required for the assessment without making changes to the environment.",
    },
    {
      n: "02",
      title: "Run the assessment",
      body: "TenantIQ evaluates Microsoft 365 configuration across supported workloads, running automated checks to identify security risks, configuration gaps, and opportunities for improvement.",
    },
    {
      n: "03",
      title: "Review the findings",
      body: "Results are organized into clear PASS, WARN, and FAIL findings with supporting evidence and actionable recommendations, helping teams understand what matters and what to address next.",
    },
  ];

  return (
    <div id="how" style={{ background: COLORS.ink, padding: "80px 48px" }}>
      <div style={{ maxWidth: "1200px", margin: "0 auto" }}>
        <div
          style={{
            fontFamily: FONT_MONO,
            fontSize: "12px",
            color: COLORS.amber,
            letterSpacing: "0.06em",
            marginBottom: "12px",
          }}
        >
          HOW TENANTIQ WORKS
        </div>
        <h2
          style={{
            fontFamily: FONT_DISPLAY,
            fontWeight: 700,
            fontSize: "28px",
            color: COLORS.textPrimary,
            marginBottom: "48px",
          }}
        >
          From tenant data to actionable insights
        </h2>
        <div style={{ display: "grid", gridTemplateColumns: "repeat(3, 1fr)", gap: "40px", marginBottom: "40px" }}>
          {steps.map((s, i) => (
            <div key={i}>
              <div style={{ fontFamily: FONT_MONO, fontSize: "13px", color: COLORS.amber, marginBottom: "12px" }}>
                {s.n}
              </div>
              <h3
                style={{
                  fontFamily: FONT_DISPLAY,
                  fontWeight: 600,
                  fontSize: "18px",
                  color: COLORS.textPrimary,
                  margin: "0 0 8px",
                }}
              >
                {s.title}
              </h3>
              <p style={{ fontFamily: FONT_BODY, fontSize: "14.5px", lineHeight: 1.6, color: COLORS.textSecondary, margin: 0 }}>
                {s.body}
              </p>
            </div>
          ))}
        </div>

        <div
          style={{
            display: "flex",
            alignItems: "center",
            gap: "14px",
            paddingTop: "32px",
            borderTop: `1px solid ${COLORS.border}`,
          }}
        >
          {["Connect", "Assess", "Act"].map((word, i) => (
            <React.Fragment key={word}>
              <span
                style={{
                  fontFamily: FONT_MONO,
                  fontSize: "12px",
                  letterSpacing: "0.08em",
                  color: COLORS.textMuted,
                }}
              >
                {word.toUpperCase()}
              </span>
              {i < 2 && (
                <span style={{ color: COLORS.amber, fontFamily: FONT_MONO, fontSize: "12px" }}>â†’</span>
              )}
            </React.Fragment>
          ))}
        </div>
      </div>
    </div>
  );
}


function WhoItsFor() {
  const audiences = [
    {
      label: "ADMINISTRATION",
      icon: Settings,
      title: "Microsoft 365 Administrators",
      body: "Get a structured view of tenant configuration, identify gaps faster, and prioritize what needs attention without manually reviewing settings across multiple admin portals.",
    },
    {
      label: "SECURITY",
      icon: ShieldCheck,
      title: "IT & Security Teams",
      body: "Bring identity, security, device, collaboration, and data-protection findings into one assessment so teams can focus remediation efforts where they matter most.",
    },
    {
      label: "CONSULTING",
      icon: BriefcaseBusiness,
      title: "MSPs & Microsoft 365 Consultants",
      body: "Assess client environments consistently and turn technical findings into clear, actionable recommendations that are easier to review with customers.",
    },
    {
      label: "LEADERSHIP",
      icon: Building2,
      title: "IT Leaders & Decision Makers",
      body: "Get a clearer view of Microsoft 365 configuration health and risk without having to interpret hundreds of individual settings or raw technical output.",
    },
  ];

  return (
    <div id="audience" style={{ background: COLORS.ink, padding: "80px 48px", borderTop: `1px solid ${COLORS.border}` }}>
      <div style={{ maxWidth: "1200px", margin: "0 auto" }}>
        <div style={{ fontFamily: FONT_MONO, fontSize: "12px", color: COLORS.blue, letterSpacing: "0.06em", marginBottom: "12px" }}>
          WHO TENANTIQ IS FOR
        </div>
        <h2 style={{ fontFamily: FONT_DISPLAY, fontWeight: 700, fontSize: "28px", color: COLORS.textPrimary, marginBottom: "16px" }}>
          Built for the people responsible for Microsoft 365.
        </h2>
        <p style={{ fontFamily: FONT_BODY, fontSize: "15px", lineHeight: 1.7, color: COLORS.textSecondary, maxWidth: "760px", marginBottom: "40px" }}>
          Whether you manage a single tenant, advise multiple clients, or oversee Microsoft 365 security and governance, TenantIQ helps turn complex configuration data into a clear picture of what needs attention.
        </p>

        <div style={{ display: "grid", gridTemplateColumns: "repeat(2, 1fr)", gap: "16px" }}>
          {audiences.map((a) => {
            const Icon = a.icon;
            return (
              <div key={a.label} style={{ background: COLORS.card, border: `1px solid ${COLORS.border}`, borderRadius: "10px", padding: "26px" }}>
                <div style={{ display: "flex", alignItems: "center", gap: "10px", marginBottom: "16px" }}>
                  <div style={{ width: 32, height: 32, borderRadius: "8px", background: COLORS.blueTint, display: "flex", alignItems: "center", justifyContent: "center" }}>
                    <Icon size={17} color={COLORS.blue} />
                  </div>
                  <span style={{ fontFamily: FONT_MONO, fontSize: "11px", letterSpacing: "0.07em", color: COLORS.textMuted }}>{a.label}</span>
                </div>
                <h3 style={{ fontFamily: FONT_DISPLAY, fontWeight: 600, fontSize: "17px", color: COLORS.textPrimary, margin: "0 0 8px" }}>
                  {a.title}
                </h3>
                <p style={{ fontFamily: FONT_BODY, fontSize: "13.5px", lineHeight: 1.65, color: COLORS.textSecondary, margin: 0 }}>
                  {a.body}
                </p>
              </div>
            );
          })}
        </div>
      </div>
    </div>
  );
}

function ClosingCTA({ onRequestAccess }: { onRequestAccess: () => void }) {
  return (
    <div id="early-access" style={{ background: COLORS.card, padding: "88px 48px", borderTop: `1px solid ${COLORS.border}` }}>
      <div style={{ maxWidth: "820px", margin: "0 auto", textAlign: "center" }}>
        <div style={{ fontFamily: FONT_MONO, fontSize: "12px", color: COLORS.blue, letterSpacing: "0.06em", marginBottom: "14px" }}>
          EARLY ACCESS
        </div>
        <h2 style={{ fontFamily: FONT_DISPLAY, fontWeight: 700, fontSize: "34px", lineHeight: 1.2, color: COLORS.textPrimary, margin: "0 0 16px" }}>
          See your Microsoft 365 tenant more clearly.
        </h2>
        <p style={{ fontFamily: FONT_BODY, fontSize: "16px", lineHeight: 1.7, color: COLORS.textSecondary, maxWidth: "650px", margin: "0 auto 28px" }}>
          Request early access to TenantIQ and see how automated assessment can turn Microsoft 365 configuration data into prioritized findings and actionable recommendations.
        </p>
        <div style={{ display: "flex", justifyContent: "center", gap: "12px", flexWrap: "wrap" }}>
          <button type="button" onClick={onRequestAccess} className="primary-button">
            Request early access
          </button>
          <button
            type="button"
            onClick={() => document.getElementById("sample")?.scrollIntoView({ behavior: "smooth" })}
            className="secondary-button"
            style={{ display: "inline-flex", alignItems: "center", gap: "8px" }}
          >
            View sample assessment <ArrowRight size={15} aria-hidden="true" />
          </button>
        </div>
        <p style={{ fontFamily: FONT_BODY, fontSize: "12.5px", color: COLORS.textMuted, marginTop: "18px" }}>
          Read-only assessment. No automated remediation or silent configuration changes.
        </p>
      </div>
    </div>
  );
}

function Footer() {
  return (
    <footer style={{ background: COLORS.ink, borderTop: `1px solid ${COLORS.border}`, padding: "28px 48px" }}>
      <div
        className="footer-inner"
        style={{
          maxWidth: "1200px",
          margin: "0 auto",
          display: "flex",
          justifyContent: "space-between",
          alignItems: "center",
          gap: "24px",
          flexWrap: "wrap",
        }}
      >
        <Brand />
        <div style={{ display: "flex", alignItems: "center", gap: "18px", flexWrap: "wrap", justifyContent: "flex-end" }}>
          <a href="/privacy" className="footer-link">Privacy</a>
          <a href="/terms" className="footer-link">Terms</a>
          <a href="/security" className="footer-link">Security</a>
          <span style={{ fontFamily: FONT_BODY, fontSize: "12px", color: COLORS.textMuted }}>
            Microsoft 365 tenant assessment and intelligence.
          </span>
        </div>
      </div>
    </footer>
  );
}

function EarlyAccessModal({ open, onClose }: { open: boolean; onClose: () => void }) {
  const [status, setStatus] = useState("idle");
  const [message, setMessage] = useState("");

  useEffect(() => {
    if (!open) return;

    const previousOverflow = document.body.style.overflow;
    document.body.style.overflow = "hidden";

    const handleKeyDown = (event: KeyboardEvent) => {
      if (event.key === "Escape") onClose();
    };

    window.addEventListener("keydown", handleKeyDown);
    return () => {
      document.body.style.overflow = previousOverflow;
      window.removeEventListener("keydown", handleKeyDown);
    };
  }, [open, onClose]);

  async function handleSubmit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setStatus("submitting");
    setMessage("");

    const form = event.currentTarget;
    const formData = new FormData(form);
    const payload = Object.fromEntries(formData.entries());

    try {
      const response = await fetch("/api/early-access", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(payload),
      });

      const result = await response.json().catch(() => ({}));

      if (!response.ok) {
        throw new Error(result.error || "We couldn't submit your request.");
      }

      setStatus("success");
      setMessage("Thanks â€” your early access request has been received.");
      form.reset();
    } catch (error) {
      setStatus("error");
      setMessage(error instanceof Error ? error.message : "We couldn't submit your request.");
    }
  }

  if (!open) return null;

  return (
    <div
      className="modal-backdrop"
      role="presentation"
      onMouseDown={(event: React.MouseEvent<HTMLDivElement>) => {
        if (event.target === event.currentTarget) onClose();
      }}
    >
      <div
        role="dialog"
        aria-modal="true"
        aria-labelledby="early-access-title"
        aria-describedby="early-access-description"
        className="early-access-modal"
      >
        <div style={{ display: "flex", justifyContent: "space-between", alignItems: "flex-start", gap: "20px", marginBottom: "22px" }}>
          <div>
            <div style={{ fontFamily: FONT_MONO, fontSize: "11px", color: COLORS.blue, letterSpacing: ".07em", marginBottom: "8px" }}>
              TENANTIQ EARLY ACCESS
            </div>
            <h2 id="early-access-title" style={{ fontFamily: FONT_DISPLAY, fontSize: "26px", lineHeight: 1.2, color: COLORS.textPrimary, margin: "0 0 8px" }}>
              Request early access
            </h2>
            <p id="early-access-description" style={{ fontFamily: FONT_BODY, fontSize: "14px", lineHeight: 1.6, color: COLORS.textSecondary, margin: 0, maxWidth: "560px" }}>
              Tell us a little about your Microsoft 365 environment. We'll follow up with information about assessment availability and early access.
            </p>
          </div>

          <button type="button" onClick={onClose} className="icon-button" aria-label="Close early access form">
            <X size={18} aria-hidden="true" />
          </button>
        </div>

        {status === "success" ? (
          <div
            style={{
              border: `1px solid rgba(34,197,94,.25)`,
              background: "rgba(34,197,94,.08)",
              borderRadius: "10px",
              padding: "24px",
              textAlign: "center",
            }}
          >
            <CheckCircle2 size={34} color={COLORS.green} aria-hidden="true" />
            <h3 style={{ fontFamily: FONT_DISPLAY, fontSize: "18px", color: COLORS.textPrimary, margin: "12px 0 6px" }}>
              Request received
            </h3>
            <p style={{ fontFamily: FONT_BODY, fontSize: "14px", color: COLORS.textSecondary, lineHeight: 1.6, margin: "0 0 18px" }}>
              {message}
            </p>
            <button type="button" onClick={onClose} className="primary-button">Done</button>
          </div>
        ) : (
          <form onSubmit={handleSubmit}>
            <div className="form-grid">
              <label className="field-label">
                Name
                <input className="field-input" name="name" type="text" autoComplete="name" required />
              </label>

              <label className="field-label">
                Work email
                <input className="field-input" name="email" type="email" autoComplete="email" required />
              </label>

              <label className="field-label">
                Company
                <input className="field-input" name="company" type="text" autoComplete="organization" required />
              </label>

              <label className="field-label">
                Role
                <select className="field-input" name="role" defaultValue="" required>
                  <option value="" disabled>Select a role</option>
                  <option>Microsoft 365 Administrator</option>
                  <option>IT / Security</option>
                  <option>MSP / Consultant</option>
                  <option>IT Leadership</option>
                  <option>Other</option>
                </select>
              </label>

              <label className="field-label">
                Approximate Microsoft 365 users
                <select className="field-input" name="tenantSize" defaultValue="" required>
                  <option value="" disabled>Select a range</option>
                  <option>1â€“100</option>
                  <option>101â€“500</option>
                  <option>501â€“2,500</option>
                  <option>2,501â€“10,000</option>
                  <option>10,001+</option>
                  <option>Multiple client tenants</option>
                </select>
              </label>

              <label className="field-label">
                Primary interest
                <select className="field-input" name="interest" defaultValue="" required>
                  <option value="" disabled>Select an option</option>
                  <option>Tenant health assessment</option>
                  <option>Security posture review</option>
                  <option>Client / MSP assessments</option>
                  <option>Governance and compliance review</option>
                  <option>General early access</option>
                </select>
              </label>
            </div>

            <label className="field-label" style={{ marginTop: "16px" }}>
              What would you like TenantIQ to help you assess? <span style={{ color: COLORS.textMuted }}>(optional)</span>
              <textarea className="field-input" name="notes" rows={4} style={{ resize: "vertical" }} />
            </label>

            {status === "error" && (
              <div role="alert" style={{ marginTop: "14px", fontFamily: FONT_BODY, fontSize: "13px", color: COLORS.red }}>
                {message}
              </div>
            )}

            <div style={{ display: "flex", justifyContent: "flex-end", gap: "10px", marginTop: "22px", flexWrap: "wrap" }}>
              <button type="button" onClick={onClose} className="secondary-button">Cancel</button>
              <button type="submit" className="primary-button" disabled={status === "submitting"}>
                {status === "submitting" ? "Submitting..." : "Request early access"}
              </button>
            </div>

            <p style={{ fontFamily: FONT_BODY, fontSize: "11.5px", lineHeight: 1.55, color: COLORS.textMuted, margin: "16px 0 0" }}>
              By submitting this form, you agree that TenantIQ may contact you about early access. See our <a href="/privacy" style={{ color: COLORS.blue }}>Privacy notice</a>.
            </p>
          </form>
        )}
      </div>
    </div>
  );
}

export default function TenantIQLandingV2() {
  const [earlyAccessOpen, setEarlyAccessOpen] = useState(false);

  return (
    <div style={{ fontFamily: FONT_BODY }}>
      <style>{`
        @import url('https://fonts.googleapis.com/css2?family=Space+Grotesk:wght@500;600;700&family=Inter:wght@400;500;600&family=IBM+Plex+Mono:wght@400;500&display=swap');

        * { box-sizing: border-box; }
        html { scroll-behavior: smooth; }
        body { margin: 0; background: #0D1321; }
        button, input, select, textarea { font: inherit; }

        a, button { transition: opacity .18s ease, transform .18s ease, border-color .18s ease, background-color .18s ease; }
        button:not(:disabled), a { cursor: pointer; }
        button:disabled { opacity: .6; cursor: wait; }

        a:focus-visible, button:focus-visible, input:focus-visible, select:focus-visible, textarea:focus-visible {
          outline: 2px solid #4C8DFF;
          outline-offset: 3px;
        }

        .brand-logo { width: 310px !important; height: auto !important; }
.nav-link, .footer-link {
          font-family: ${FONT_BODY};
          font-size: 14px;
          color: ${COLORS.textSecondary};
          text-decoration: none;
        }
        .footer-link { font-size: 12px; }
        .nav-link:hover, .footer-link:hover { color: ${COLORS.textPrimary}; }

        .primary-button, .secondary-button, .icon-button {
          border-radius: 6px;
          font-family: ${FONT_BODY};
          font-weight: 600;
          font-size: 14px;
        }
        .primary-button {
          color: ${COLORS.ink};
          background: ${COLORS.blue};
          border: 1px solid ${COLORS.blue};
          padding: 13px 22px;
        }
        .primary-button:hover:not(:disabled) { transform: translateY(-1px); opacity: .94; }
        .compact-button { padding: 9px 18px; }

        .secondary-button {
          color: ${COLORS.textPrimary};
          background: transparent;
          border: 1px solid ${COLORS.border};
          padding: 13px 22px;
        }
        .secondary-button:hover { border-color: #3A465C; background: rgba(255,255,255,.025); }

        .icon-button {
          width: 36px;
          height: 36px;
          display: grid;
          place-items: center;
          padding: 0;
          color: ${COLORS.textSecondary};
          background: transparent;
          border: 1px solid ${COLORS.border};
        }

        .modal-backdrop {
          position: fixed;
          inset: 0;
          z-index: 1000;
          display: grid;
          place-items: center;
          padding: 24px;
          background: rgba(5,9,17,.78);
          backdrop-filter: blur(8px);
        }

        .early-access-modal {
          width: min(720px, 100%);
          max-height: calc(100vh - 48px);
          overflow-y: auto;
          background: ${COLORS.card};
          border: 1px solid ${COLORS.border};
          border-radius: 14px;
          padding: 28px;
          box-shadow: 0 30px 90px -30px rgba(0,0,0,.9);
        }

        .form-grid {
          display: grid;
          grid-template-columns: 1fr 1fr;
          gap: 16px;
        }

        .field-label {
          display: flex;
          flex-direction: column;
          gap: 7px;
          font-family: ${FONT_BODY};
          font-size: 12.5px;
          font-weight: 600;
          color: ${COLORS.textPrimary};
        }

        .field-input {
          width: 100%;
          color: ${COLORS.textPrimary};
          background: ${COLORS.ink};
          border: 1px solid ${COLORS.border};
          border-radius: 7px;
          padding: 11px 12px;
          font-family: ${FONT_BODY};
          font-size: 13.5px;
          font-weight: 400;
        }
        .field-input::placeholder { color: ${COLORS.textMuted}; }
        select.field-input option { background: ${COLORS.ink}; color: ${COLORS.textPrimary}; }

        @media (max-width: 900px) {
          .hero-grid { grid-template-columns: 1fr !important; gap: 44px !important; }
          [style*="grid-template-columns: repeat(4, 1fr)"] { grid-template-columns: repeat(2, 1fr) !important; }
          [style*="grid-template-columns: repeat(3, 1fr)"] { grid-template-columns: 1fr !important; }
          [style*="grid-template-columns: 1fr 1fr"] { grid-template-columns: 1fr !important; }
          .nav-links { gap: 16px !important; flex-wrap: wrap; justify-content: flex-end; }
        }

        @media (max-width: 720px) {
          .brand-link, .brand-logo-crop { width: 220px !important; height: 58px !important; }
          .brand-logo-crop { background-size: 220px 220px !important; }
.brand-logo { width: 240px !important; }
          .site-nav { padding: 18px 22px !important; align-items: flex-start !important; }
          .nav-links .nav-link { display: none; }
          .form-grid { grid-template-columns: 1fr; }
          .hero-stat-grid { grid-template-columns: repeat(2, 1fr) !important; }
        }

        @media (max-width: 640px) {
          .brand-link, .brand-logo-crop { width: 190px !important; height: 52px !important; }
          .brand-logo-crop { background-size: 190px 190px !important; }
.brand-logo { width: 210px !important; }
          [style*="padding: 80px 48px"] { padding: 36px 22px 46px !important; }
          [style*="padding: 88px 48px"] { padding: 36px 22px 46px !important; }
          [style*="padding: 40px 48px 90px"] { padding: 28px 22px 64px !important; }
          [style*="padding: 20px 48px"] { padding: 18px 22px !important; }
          [style*="grid-template-columns: repeat(4, 1fr)"],
          [style*="grid-template-columns: repeat(2, 1fr)"] { grid-template-columns: 1fr !important; }
          h1 { font-size: 36px !important; }
          .hero-actions > * { width: 100%; text-align: center; }
          .modal-backdrop { padding: 12px; }
          .early-access-modal { padding: 22px; max-height: calc(100vh - 24px); }
          .footer-inner { align-items: flex-start !important; }
        }

        @media (prefers-reduced-motion: reduce) {
          html { scroll-behavior: auto; }
          *, *::before, *::after { transition-duration: .01ms !important; animation-duration: .01ms !important; animation-iteration-count: 1 !important; }
        }
      `}</style>

      <Hero onRequestAccess={() => setEarlyAccessOpen(true)} />
      <WhatTenantIQDoes />
      <MicrosoftCoverage />
      <HowTenantIQWorks />
      <SampleAssessment />
      <SecurityTrust />
      <WhoItsFor />
      <ClosingCTA onRequestAccess={() => setEarlyAccessOpen(true)} />
      <Footer />

      <EarlyAccessModal open={earlyAccessOpen} onClose={() => setEarlyAccessOpen(false)} />
    </div>
  );
}
