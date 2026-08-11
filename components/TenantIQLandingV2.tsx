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

function StatCard({ label, value, color }: { label: string; value: string | number; color?: string }) {
  return (
    <div style={{ background: COLORS.cardAlt, border: `1px solid ${COLORS.border}`, borderRadius: "10px", padding: "14px 16px", flex: 1 }}>
      <div style={{ fontFamily: FONT_BODY, fontSize: "12px", color: COLORS.textSecondary, marginBottom: "6px" }}>{label}</div>
      <div style={{ fontFamily: FONT_DISPLAY, fontWeight: 700, fontSize: "22px", color: color || COLORS.textPrimary }}>{value}</div>
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
    <div aria-label="Sanitized TenantIQ Entra ID assessment preview" style={{ background: COLORS.card, borderRadius: "12px", border: `1px solid ${COLORS.border}`, overflow: "hidden", boxShadow: "0 24px 60px -24px rgba(0,0,0,0.6)" }}>
      <div style={{ background: `linear-gradient(135deg, ${COLORS.blueDark}, #1E3A8A)`, padding: "16px 20px", display: "flex", justifyContent: "space-between", alignItems: "flex-start", gap: "18px" }}>
        <div>
          <div style={{ display: "flex", alignItems: "center", gap: "10px" }}>
            <img src="/tenantiq-mark.png" alt="" aria-hidden="true" width={34} height={34} style={{ width: "34px", height: "34px", objectFit: "contain" }} />
            <div style={{ fontFamily: FONT_DISPLAY, fontWeight: 700, fontSize: "18px", color: "#fff" }}>TenantIQ</div>
          </div>
          <div style={{ fontFamily: FONT_BODY, fontSize: "12px", color: "#B9CCFA", marginTop: "8px" }}>Entra Identity Security — sanitized assessment</div>
        </div>
        <div style={{ textAlign: "right" }}>
          <div style={{ fontFamily: FONT_BODY, fontSize: "11px", color: "#B9CCFA" }}>Assessment score</div>
          <div style={{ fontFamily: FONT_DISPLAY, fontWeight: 700, fontSize: "26px", color: "#fff" }}>73.6%</div>
          <span style={{ fontFamily: FONT_MONO, fontSize: "9px", color: "#fff", background: "rgba(255,255,255,0.14)", borderRadius: "20px", padding: "3px 8px", display: "inline-block", marginTop: "4px", letterSpacing: ".04em" }}>SAMPLE</span>
        </div>
      </div>
      <div style={{ padding: "15px 18px" }}>
        <div className="hero-stat-grid" style={{ display: "grid", gridTemplateColumns: "repeat(4, 1fr)", gap: "10px", marginBottom: "16px" }}>
          <StatCard label="Checks" value="53" />
          <StatCard label="Passed" value="39" color={COLORS.green} />
          <StatCard label="Warnings" value="0" color={COLORS.amber} />
          <StatCard label="Failed" value="14" color={COLORS.red} />
        </div>
        <div style={{ background: "rgba(248,113,113,0.10)", borderLeft: `3px solid ${COLORS.red}`, borderRadius: "8px", padding: "14px 16px" }}>
          <div style={{ fontFamily: FONT_BODY, fontSize: "11px", fontWeight: 600, color: COLORS.red, textTransform: "uppercase", letterSpacing: "0.03em", marginBottom: "6px" }}>Finding requiring attention</div>
          <div style={{ fontFamily: FONT_DISPLAY, fontWeight: 600, fontSize: "15px", color: COLORS.textPrimary, marginBottom: "4px" }}>Named location(s) exist</div>
          <div style={{ fontFamily: FONT_BODY, fontSize: "13px", color: COLORS.textSecondary, lineHeight: 1.5 }}>Evidence: 0 named locations configured.</div>
        </div>
        <div style={{ marginTop: "14px", display: "flex", flexDirection: "column", gap: "6px" }}>
          {rows.map((row) => (
            <div key={row.name} style={{ display: "flex", justifyContent: "space-between", alignItems: "center", gap: "12px", padding: "8px 10px", background: COLORS.cardAlt, borderRadius: "6px" }}>
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
    <a href="#top" aria-label="TenantIQ home" className="brand-link" style={{ display: "inline-flex", alignItems: "center", textDecoration: "none", flexShrink: 0, width: "250px", height: "64px", overflow: "hidden" }}>
      <span role="img" aria-label="TenantIQ" className="brand-logo-crop" style={{ display: "block", width: "250px", height: "64px", backgroundImage: 'url("/tenantiq-header-clean.png")', backgroundRepeat: "no-repeat", backgroundPosition: "center center", backgroundSize: "250px 250px" }} />
    </a>
  );
}

function Nav({ onRequestAccess }: { onRequestAccess: () => void }) {
  return (
    <nav aria-label="Primary navigation" className="site-nav" style={{ display: "flex", alignItems: "center", justifyContent: "space-between", padding: "6px 48px", maxWidth: "1200px", margin: "0 auto", gap: "24px" }}>
      <Brand />
      <div className="nav-links" style={{ display: "flex", alignItems: "center", gap: "28px" }}>
        <a href="#what" className="nav-link">Product</a>
        <a href="#coverage" className="nav-link">Coverage</a>
        <a href="#sample" className="nav-link">Sample Assessment</a>
        <a href="#trust" className="nav-link">Security</a>
        <button type="button" onClick={onRequestAccess} className="primary-button compact-button">Request early access</button>
      </div>
    </nav>
  );
}

const workloadItems = [
  { name: "Entra ID", kind: "entra" },
  { name: "Exchange Online", kind: "exchange" },
  { name: "SharePoint", kind: "sharepoint" },
  { name: "Teams", kind: "teams" },
  { name: "OneDrive", kind: "onedrive" },
  { name: "Intune", kind: "intune" },
  { name: "Defender", kind: "defender" },
  { name: "Purview", kind: "purview" },
] as const;

function WorkloadLogo({ kind }: { kind: typeof workloadItems[number]["kind"] }) {
  if (kind === "entra") return <svg viewBox="0 0 72 72"><defs><linearGradient id="entraA" x1="0" y1="0" x2="1" y2="1"><stop stopColor="#77D0FF"/><stop offset=".55" stopColor="#2D8CFF"/><stop offset="1" stopColor="#3457FF"/></linearGradient><linearGradient id="entraB" x1="0" y1="1" x2="1" y2="0"><stop stopColor="#0F6EDB"/><stop offset="1" stopColor="#56C8FF"/></linearGradient></defs><path fill="url(#entraA)" d="M37 5 10 46l18 20 10-23 24 1L37 5Z"/><path fill="url(#entraB)" d="m10 46 28-3-10 23-18-20Z" opacity=".95"/><path fill="#D6F3FF" d="m37 5 25 39-24-1-1-38Z" opacity=".18"/></svg>;
  if (kind === "exchange") return <svg viewBox="0 0 72 72"><defs><linearGradient id="exoBack" x1="0" y1="0" x2="1" y2="1"><stop stopColor="#1AA7FF"/><stop offset="1" stopColor="#0766D8"/></linearGradient><linearGradient id="exoFront" x1="0" y1="0" x2="1" y2="1"><stop stopColor="#2B8CFF"/><stop offset="1" stopColor="#1950C8"/></linearGradient></defs><rect x="28" y="10" width="34" height="46" rx="6" fill="url(#exoBack)"/><rect x="9" y="18" width="37" height="32" rx="6" fill="url(#exoFront)"/><path d="M18 25h20v5H27l12 9v7L18 33v-8Z" fill="#fff"/><path d="M33 22h21v5H38zM33 31h21v5H38z" fill="#78C4FF" opacity=".55"/></svg>;
  if (kind === "sharepoint") return <svg viewBox="0 0 72 72"><defs><linearGradient id="spA" x1="0" y1="0" x2="1" y2="1"><stop stopColor="#39C7B8"/><stop offset="1" stopColor="#0F756F"/></linearGradient><linearGradient id="spB" x1="0" y1="0" x2="1" y2="1"><stop stopColor="#2AB8A4"/><stop offset="1" stopColor="#0B645F"/></linearGradient></defs><circle cx="28" cy="34" r="18" fill="url(#spA)"/><circle cx="46" cy="24" r="14" fill="#2AB8A4" opacity=".92"/><circle cx="47" cy="47" r="15" fill="url(#spB)" opacity=".9"/><rect x="13" y="24" width="29" height="25" rx="6" fill="#11766F"/><path d="M21 30h13v5h-8v4h8v6H21v-5h8v-4h-8v-6Z" fill="#fff"/></svg>;
  if (kind === "teams") return <svg viewBox="0 0 72 72"><defs><linearGradient id="teamsA" x1="0" y1="0" x2="1" y2="1"><stop stopColor="#8E8BFF"/><stop offset="1" stopColor="#5752D6"/></linearGradient><linearGradient id="teamsB" x1="0" y1="0" x2="1" y2="1"><stop stopColor="#6A66EA"/><stop offset="1" stopColor="#4340B8"/></linearGradient></defs><circle cx="54" cy="17" r="8" fill="#8F8CFF"/><rect x="30" y="16" width="31" height="39" rx="7" fill="url(#teamsA)"/><rect x="9" y="23" width="38" height="31" rx="6" fill="url(#teamsB)"/><path d="M18 30h20v5h-7v13h-6V35h-7v-5Z" fill="#fff"/></svg>;
  if (kind === "onedrive") return <svg viewBox="0 0 72 72"><defs><linearGradient id="odA" x1="0" y1="0" x2="1" y2="1"><stop stopColor="#2A8BFF"/><stop offset="1" stopColor="#1769D2"/></linearGradient><linearGradient id="odB" x1="0" y1="0" x2="1" y2="1"><stop stopColor="#59BFFF"/><stop offset="1" stopColor="#2A8BFF"/></linearGradient></defs><path d="M20 45c2-8 8-13 16-13 4-10 13-15 22-12 8 2 13 8 14 16 7 0 12 5 12 12 0 8-6 13-14 13H23C14 61 8 56 8 49c0-6 5-11 12-12Z" fill="url(#odA)" transform="scale(.76) translate(5 2)"/><path d="M14 44c2-7 8-11 15-11 6 0 11 3 14 7 3-3 8-5 12-5 8 0 14 6 14 14 0 2 0 4-1 6H14Z" fill="url(#odB)"/></svg>;
  if (kind === "intune") return <svg viewBox="0 0 72 72"><defs><linearGradient id="inA" x1="0" y1="0" x2="1" y2="1"><stop stopColor="#2D92FF"/><stop offset="1" stopColor="#1763DD"/></linearGradient></defs><rect x="10" y="12" width="52" height="35" rx="5" fill="url(#inA)"/><rect x="17" y="18" width="38" height="23" rx="3" fill="#08203D"/><path d="M27 58h18M36 47v11" stroke="#8BCBFF" strokeWidth="4" strokeLinecap="round"/><path d="M22 26h28M22 33h17" stroke="#3DA8FF" strokeWidth="3"/><rect x="42" y="22" width="8" height="14" rx="2" fill="#1A73E8"/></svg>;
  if (kind === "defender") return <svg viewBox="0 0 72 72"><defs><linearGradient id="defA" x1="0" y1="0" x2="1" y2="1"><stop stopColor="#3BB8FF"/><stop offset=".55" stopColor="#2A8DFF"/><stop offset="1" stopColor="#185AC9"/></linearGradient></defs><path d="M36 6 62 15v19c0 15-9 25-26 33C19 59 10 49 10 34V15l26-9Z" fill="url(#defA)"/><path d="M36 11v47c11-6 18-14 18-24V19L36 11Z" fill="#1D6FE8" opacity=".86"/><path d="M36 11v47c-11-6-18-14-18-24V19L36 11Z" fill="#4BC0FF" opacity=".35"/></svg>;
  return <svg viewBox="0 0 72 72"><defs><linearGradient id="pvA" x1="0" y1="0" x2="1" y2="1"><stop stopColor="#21D5FF"/><stop offset=".55" stopColor="#2F9EFF"/><stop offset="1" stopColor="#3E59E8"/></linearGradient><linearGradient id="pvB" x1="1" y1="0" x2="0" y2="1"><stop stopColor="#4F86FF"/><stop offset="1" stopColor="#1CA2E8"/></linearGradient></defs><path d="M8 36c8-13 18-20 31-20 10 0 18 4 25 11-8-2-15 0-21 4-7 5-11 11-13 20-9-2-17-7-22-15Z" fill="url(#pvA)"/><path d="M64 36c-8 13-18 20-31 20-10 0-18-4-25-11 8 2 15 0 21-4 7-5 11-11 13-20 9 2 17 7 22 15Z" fill="url(#pvB)" opacity=".95"/><circle cx="36" cy="36" r="8" fill="#06182B"/></svg>;
}

function Hero({ onRequestAccess }: { onRequestAccess: () => void }) {
  return (
    <div id="top" style={{ background: COLORS.ink }}>
      <Nav onRequestAccess={onRequestAccess} />
      <div className="hero-grid" style={{ maxWidth: "1200px", margin: "0 auto", padding: "20px 48px 18px", display: "grid", gridTemplateColumns: "1fr 1.08fr", gap: "52px", alignItems: "center" }}>
        <div>
          <div style={{ display: "inline-block", fontFamily: FONT_MONO, fontSize: "12px", color: COLORS.blue, background: COLORS.blueTint, borderRadius: "20px", padding: "5px 12px", marginBottom: "18px" }}>Microsoft 365 tenant intelligence</div>
          <h1 style={{ fontFamily: FONT_DISPLAY, fontWeight: 700, fontSize: "40px", lineHeight: 1.15, color: COLORS.textPrimary, margin: "0 0 20px", letterSpacing: "-0.01em" }}>Microsoft 365 tenant intelligence, without the <span style={{ background: "linear-gradient(90deg,#4C8DFF,#5BD6FF)", WebkitBackgroundClip: "text", backgroundClip: "text", color: "transparent" }}>guesswork.</span></h1>
          <p style={{ fontFamily: FONT_BODY, fontSize: "17px", lineHeight: 1.6, color: COLORS.textSecondary, margin: "0 0 20px", maxWidth: "500px" }}>TenantIQ performs automated, read-only analysis of a Microsoft 365 environment and turns configuration data into prioritized findings, risk insights, and actionable recommendations.</p>
          <p style={{ fontFamily: FONT_BODY, fontSize: "15px", lineHeight: 1.6, color: COLORS.textMuted, margin: "0 0 24px", maxWidth: "470px" }}>Configuration data tells you what's there. TenantIQ helps you understand what matters and what to address next.</p>
          <div className="hero-actions" style={{ display: "flex", gap: "12px", flexWrap: "wrap" }}>
            <button type="button" onClick={onRequestAccess} className="primary-button">Request early access</button>
            <button type="button" onClick={() => document.getElementById("sample")?.scrollIntoView({ behavior: "smooth" })} className="secondary-button">View sample assessment</button>
          </div>
          <div className="hero-trust-row">
            <div><ShieldCheck size={25}/><span><strong>350+</strong><small>automated checks</small></span></div>
            <div><Settings size={25}/><span><strong>8</strong><small>workloads</small></span></div>
            <div><Eye size={25}/><span><strong>Read-only</strong><small>access</small></span></div>
            <div><Lock size={25}/><span><strong>No</strong><small>configuration changes</small></span></div>
          </div>
        </div>
        <ReportPreview />
      </div>

      <div className="hero-network" aria-hidden="true">
        <svg viewBox="0 0 1600 240" preserveAspectRatio="none">
          <g className="hero-network-lines">
            <path d="M0 150L70 115L150 150L230 96L330 147L430 100L540 145L650 96L760 142L880 100L990 140L1110 94L1230 138L1360 100L1480 134L1600 98"/>
            <path d="M0 190L95 162L185 198L280 150L380 191L485 148L590 188L700 146L810 186L930 145L1040 184L1160 145L1275 181L1390 144L1510 178L1600 150"/>
            <path d="M70 115L95 162M150 150L185 198M230 96L280 150M330 147L380 191M430 100L485 148M540 145L590 188M650 96L700 146M760 142L810 186M880 100L930 145M990 140L1040 184M1110 94L1160 145M1230 138L1275 181M1360 100L1390 144M1480 134L1510 178"/>
          </g>
          <g className="hero-network-nodes">{[[70,115],[95,162],[150,150],[185,198],[230,96],[280,150],[330,147],[380,191],[430,100],[485,148],[540,145],[590,188],[650,96],[700,146],[760,142],[810,186],[880,100],[930,145],[990,140],[1040,184],[1110,94],[1160,145],[1230,138],[1275,181],[1360,100],[1390,144],[1480,134],[1510,178]].map(([x,y],i)=><circle key={i} cx={x} cy={y} r={i%4===0?4.5:2.6}/>)}</g>
        </svg>
        <div className="hero-network-badge users"><Users size={25}/></div>
        <div className="hero-network-badge shield"><ShieldCheck size={25}/></div>
        <div className="hero-network-badge lock"><Lock size={25}/></div>
        <div className="hero-network-badge cloud"><Cloud size={25}/></div>
      </div>

      <div className="hero-workloads">
        <div className="hero-workload-title"><span>Microsoft 365 workloads covered</span></div>
        <div className="hero-workload-grid">
          {workloadItems.map((item) => <div className="hero-workload-item" key={item.name}><div className="hero-workload-logo"><WorkloadLogo kind={item.kind}/></div><div>{item.name}</div></div>)}
        </div>
      </div>
    </div>
  );
}

function WhatTenantIQDoes() {
  const steps = [
    { n: "01", icon: Search, title: "Assessment", body: "TenantIQ connects to a Microsoft 365 tenant with read-only, least-privilege access and pulls configuration data across the workloads it covers — identity, mail flow, device management, data protection, and collaboration settings." },
    { n: "02", icon: BarChart3, title: "Analysis", body: "Every setting is evaluated against security and operational baselines, not just recorded. TenantIQ looks for the gaps, exceptions, and drift that raw configuration data doesn't surface on its own." },
    { n: "03", icon: ListChecks, title: "Findings", body: "Each issue is captured as a discrete finding: what was checked, what was found, the evidence behind it, and its PASS, WARN, or FAIL status — so nothing is a vague “you should probably look into this.”" },
    { n: "04", icon: Wrench, title: "Recommendations", body: "Every finding ships with a specific, actionable next step — what to change, why it matters, and what the risk is if it's left alone. The recommendation is tied to the exact thing that was found." },
  ];
  return <div id="what" style={{ background: COLORS.card, padding: "58px 48px", borderTop: `1px solid ${COLORS.border}`, borderBottom: `1px solid ${COLORS.border}` }}><div style={{ maxWidth: "1200px", margin: "0 auto" }}><h2 style={{ fontFamily: FONT_DISPLAY, fontWeight: 700, fontSize: "28px", color: COLORS.textPrimary, marginBottom: "16px" }}>What TenantIQ does</h2><p style={{ fontFamily: FONT_BODY, fontSize: "15px", lineHeight: 1.7, color: COLORS.textSecondary, maxWidth: "680px", marginBottom: "48px" }}>Microsoft 365 provides a tremendous amount of configuration data. The challenge is turning that data into decisions. TenantIQ evaluates what it finds, identifies meaningful gaps and risks, and provides clear guidance on what to address next.</p><div style={{ display: "grid", gridTemplateColumns: "repeat(4, 1fr)", gap: "1px", background: COLORS.border }}>{steps.map((s,i)=>{const Icon=s.icon;return <div key={i} style={{ background: COLORS.card, padding: "28px 24px" }}><div style={{ display: "flex", alignItems: "center", gap: "10px", marginBottom: "18px" }}><span style={{ fontFamily: FONT_MONO, fontSize: "12px", color: COLORS.blue }}>{s.n}</span><div style={{ width:28,height:28,borderRadius:"7px",background:COLORS.blueTint,display:"flex",alignItems:"center",justifyContent:"center" }}><Icon size={15} color={COLORS.blue}/></div></div><h3 style={{ fontFamily:FONT_DISPLAY,fontWeight:600,fontSize:"16px",color:COLORS.textPrimary,margin:"0 0 8px" }}>{s.title}</h3><p style={{ fontFamily:FONT_BODY,fontSize:"13.5px",lineHeight:1.6,color:COLORS.textSecondary,margin:0 }}>{s.body}</p></div>})}</div></div></div>;
}

function MicrosoftCoverage(){const modules=[{icon:ShieldCheck,name:"Microsoft Entra ID",body:"Identity, authentication, privileged access, applications, and tenant security configuration."},{icon:Mail,name:"Exchange Online",body:"Messaging configuration, authentication, mail protection, domains, and transport security."},{icon:FolderOpen,name:"SharePoint Online",body:"Sharing, access, governance, tenant configuration, and collaboration controls."},{icon:Users,name:"Microsoft Teams",body:"Meetings, messaging, external access, collaboration, and governance configuration."},{icon:Cloud,name:"OneDrive",body:"Sharing, synchronization, access controls, storage, and tenant-level configuration."},{icon:Smartphone,name:"Microsoft Intune",body:"Device management, enrollment, compliance, configuration, and endpoint security controls."},{icon:ShieldAlert,name:"Microsoft Defender",body:"Threat protection, security configuration, detection capabilities, and protection policies."},{icon:Eye,name:"Microsoft Purview",body:"Information protection, data governance, retention, compliance, and auditing controls."}];return <div id="coverage" style={{background:COLORS.card,padding:"80px 48px",borderTop:`1px solid ${COLORS.border}`}}><div style={{maxWidth:"1200px",margin:"0 auto"}}><div style={{fontFamily:FONT_MONO,fontSize:"12px",color:COLORS.blue,letterSpacing:"0.06em",marginBottom:"12px"}}>MICROSOFT 365 COVERAGE</div><h2 style={{fontFamily:FONT_DISPLAY,fontWeight:700,fontSize:"28px",color:COLORS.textPrimary,marginBottom:"16px"}}>One assessment. Eight Microsoft 365 workloads.</h2><p style={{fontFamily:FONT_BODY,fontSize:"15px",lineHeight:1.7,color:COLORS.textSecondary,maxWidth:"700px",marginBottom:"40px"}}>TenantIQ evaluates identity, security, collaboration, messaging, device management, data protection, and governance across the Microsoft 365 tenant.</p><div style={{display:"grid",gridTemplateColumns:"repeat(4,1fr)",gap:"16px"}}>{modules.map((m,i)=>{const Icon=m.icon;return <div key={i} style={{background:COLORS.cardAlt,border:`1px solid ${COLORS.border}`,borderRadius:"12px",padding:"24px"}}><div style={{width:38,height:38,borderRadius:"9px",background:COLORS.blueTint,display:"flex",alignItems:"center",justifyContent:"center",marginBottom:"16px"}}><Icon size={20} color={COLORS.blue}/></div><h3 style={{fontFamily:FONT_DISPLAY,fontWeight:600,fontSize:"16px",color:COLORS.textPrimary,margin:"0 0 8px"}}>{m.name}</h3><p style={{fontFamily:FONT_BODY,fontSize:"13.5px",lineHeight:1.6,color:COLORS.textSecondary,margin:0}}>{m.body}</p></div>})}</div></div></div>}

function HowItWorks(){return null}
function SampleAssessment(){return null}
function TrustSection(){return null}
function AudienceSection(){return null}
function EarlyAccessSection(){return null}

export default function TenantIQLandingV2(){const [showModal,setShowModal]=useState(false);useEffect(()=>{},[]);return <><Hero onRequestAccess={()=>setShowModal(true)}/><WhatTenantIQDoes/><MicrosoftCoverage/>{showModal&&<div style={{position:"fixed",inset:0,background:"rgba(0,0,0,.7)",display:"flex",alignItems:"center",justifyContent:"center",zIndex:1000}}><div style={{background:COLORS.card,border:`1px solid ${COLORS.border}`,borderRadius:"14px",padding:"24px",width:"min(92vw,520px)"}}><div style={{display:"flex",justifyContent:"space-between",alignItems:"center",marginBottom:"16px"}}><h3 style={{margin:0,color:COLORS.textPrimary,fontFamily:FONT_DISPLAY}}>Request early access</h3><button onClick={()=>setShowModal(false)} style={{background:"transparent",border:0,color:COLORS.textSecondary,cursor:"pointer"}}><X size={20}/></button></div><p style={{color:COLORS.textSecondary,fontFamily:FONT_BODY}}>Early access form coming soon.</p></div></div>}</>}
