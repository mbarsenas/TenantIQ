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
  "Entra ID",
  "Exchange Online",
  "SharePoint",
  "Teams",
  "OneDrive",
  "Intune",
  "Defender",
  "Purview",
] as const;

function Hero({ onRequestAccess }: { onRequestAccess: () => void }) {
  return (
    <div id="top" style={{ background: COLORS.ink }}>
      <style>{`
        #top .nav-link { color:#E7ECF5 !important; text-decoration:none !important; }
        #top .primary-button { background:#4C8DFF !important; color:#07111f !important; border:1px solid #4C8DFF !important; border-radius:7px; padding:13px 22px; font-weight:700; cursor:pointer; }
        #top .secondary-button { background:transparent !important; color:#F5F7FA !important; border:1px solid #344057 !important; border-radius:7px; padding:13px 22px; font-weight:700; cursor:pointer; }
        #top .hero-trust-row { display:grid; grid-template-columns:repeat(4,minmax(0,1fr)); margin-top:34px; border-top:1px solid rgba(139,149,165,.2); border-bottom:1px solid rgba(139,149,165,.2); }
        #top .hero-trust-row > div { min-height:70px; display:flex; align-items:center; gap:10px; padding:10px 14px; border-right:1px solid rgba(139,149,165,.18); color:#3E95FF; }
        #top .hero-trust-row > div:last-child { border-right:0; }
        #top .hero-trust-row span { display:flex; flex-direction:column; color:#F5F7FA; }
        #top .hero-trust-row strong { font:700 14px 'Space Grotesk',sans-serif; line-height:1.05; }
        #top .hero-trust-row small { color:#8B95A5; font:11px 'Inter',sans-serif; margin-top:4px; line-height:1.15; }
        #top .hero-network { position:relative; height:220px; margin-top:4px; overflow:hidden; }
        #top .hero-network > svg { width:100%; height:100%; display:block; }
        #top .hero-network-lines { fill:none; stroke:rgba(53,135,255,.46); stroke-width:1; vector-effect:non-scaling-stroke; }
        #top .hero-network-nodes { fill:#3AA7FF; }
        #top .hero-network-badge { position:absolute; width:48px; height:48px; border:1px solid rgba(65,145,255,.9); border-radius:50%; display:flex; align-items:center; justify-content:center; color:#58A7FF; background:rgba(6,18,34,.9); }
        #top .hero-network-badge.users { left:12%; top:72px; }
        #top .hero-network-badge.shield { left:55%; top:35px; }
        #top .hero-network-badge.lock { right:17%; top:102px; }
        #top .hero-network-badge.cloud { left:25%; top:138px; }
        #top .hero-workloads { max-width:1320px; margin:-18px auto 0; padding:0 48px 34px; color:#F5F7FA; }
        #top .hero-workload-title { display:flex; align-items:center; gap:16px; margin-bottom:18px; color:#3E98FF; font:600 12px 'Inter',sans-serif; text-align:center; }
        #top .hero-workload-title::before, #top .hero-workload-title::after { content:""; flex:1; height:1px; background:rgba(76,141,255,.28); }
        #top .hero-workload-title span { white-space:nowrap; }
        #top .hero-workload-grid { display:grid; grid-template-columns:repeat(8,minmax(0,1fr)); gap:12px; }
        #top .hero-workload-item { display:flex; align-items:center; justify-content:center; min-height:34px; color:#DCE6F4; font:500 13px 'Inter',sans-serif; text-align:center; }
        @media (max-width:900px){
          #top .hero-trust-row { grid-template-columns:repeat(2,1fr); }
          #top .hero-workload-grid { grid-template-columns:repeat(4,1fr); row-gap:12px; }
        }
      `}</style>
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
          {workloadItems.map((item) => <div className="hero-workload-item" key={item}>{item}</div>)}
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