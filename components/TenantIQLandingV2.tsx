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
  if (kind === "entra") return <svg viewBox="0 0 64 64"><defs><linearGradient id="ea" x1="0" y1="0" x2="1" y2="1"><stop stopColor="#4fc3ff"/><stop offset="1" stopColor="#315dff"/></linearGradient></defs><path fill="url(#ea)" d="M32 5 8 43l18 15 8-18 22 1L32 5Z"/><path fill="#76d5ff" opacity=".8" d="m8 43 26-3-8 18L8 43Z"/></svg>;
  if (kind === "exchange") return <svg viewBox="0 0 64 64"><rect x="24" y="11" width="32" height="40" rx="5" fill="#208dff"/><rect x="7" y="18" width="34" height="27" rx="5" fill="#1767d8"/><path d="M14 24h20v5H23l12 8v6L14 31v-7Z" fill="#fff"/></svg>;
  if (kind === "sharepoint") return <svg viewBox="0 0 64 64"><circle cx="23" cy="31" r="16" fill="#178579"/><circle cx="40" cy="22" r="13" fill="#20a695"/><circle cx="42" cy="42" r="14" fill="#2bc0ac" opacity=".88"/><path d="M18 23h13v5h-7v4h7v12H18v-5h8v-4h-8V23Z" fill="#fff"/></svg>;
  if (kind === "teams") return <svg viewBox="0 0 64 64"><circle cx="47" cy="16" r="7" fill="#8b87ff"/><rect x="27" y="15" width="29" height="35" rx="6" fill="#6d68e8"/><rect x="8" y="22" width="34" height="28" rx="5" fill="#4f4bc7"/><path d="M16 28h18v5h-6v11h-6V33h-6v-5Z" fill="#fff"/></svg>;
  if (kind === "onedrive") return <svg viewBox="0 0 64 64"><path d="M14 42c2-8 8-13 16-13 5-10 13-15 23-12 8 2 13 8 14 16 7 0 12 5 12 12 0 8-6 13-14 13H17C9 58 4 53 4 46c0-6 4-11 10-12Z" fill="#1989f5" transform="scale(.75) translate(7 0)"/><path d="M13 42c2-6 7-10 14-10 6 0 10 3 13 7 3-3 7-4 11-4 7 0 12 5 12 12 0 2 0 4-1 5H13Z" fill="#4db6ff"/></svg>;
  if (kind === "intune") return <svg viewBox="0 0 64 64"><rect x="9" y="11" width="46" height="32" rx="4" fill="#1c77ff"/><rect x="15" y="17" width="34" height="20" rx="2" fill="#07182f"/><path d="M24 51h16M32 43v8" stroke="#75b9ff" strokeWidth="4" strokeLinecap="round"/><path d="M19 25h26M19 31h16" stroke="#3da2ff" strokeWidth="3"/></svg>;
  if (kind === "defender") return <svg viewBox="0 0 64 64"><defs><linearGradient id="df" x1="0" y1="0" x2="1" y2="1"><stop stopColor="#31b5ff"/><stop offset="1" stopColor="#1a64e5"/></linearGradient></defs><path d="M32 5 55 13v17c0 14-8 22-23 29C17 52 9 44 9 30V13l23-8Z" fill="url(#df)"/><path d="M32 10v42c10-5 16-13 16-22V17L32 10Z" fill="#2a7be5" opacity=".8"/></svg>;
  return <svg viewBox="0 0 64 64"><defs><linearGradient id="pv" x1="0" y1="0" x2="1" y2="1"><stop stopColor="#16d8ff"/><stop offset="1" stopColor="#386bff"/></linearGradient></defs><path d="M7 32c7-12 16-18 27-18 9 0 16 4 22 10-7-2-13 0-19 4-6 4-10 10-12 18-8-1-14-6-18-14Z" fill="url(#pv)"/><path d="M57 32c-7 12-16 18-27 18-9 0-16-4-22-10 7 2 13 0 19-4 6-4 10-10 12-18 8 1 14 6 18 14Z" fill="#2085e8" opacity=".92"/><circle cx="32" cy="32" r="7" fill="#071726"/></svg>;
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

function MicrosoftCoverage(){const modules=[{icon:ShieldCheck,name:"Microsoft Entra ID",body:"Identity, authentication, privileged access, applications, and tenant security configuration."},{icon:Mail,name:"Exchange Online",body:"Messaging configuration, authentication, mail protection, domains, and transport security."},{icon:FolderOpen,name:"SharePoint Online",body:"Sharing, access, governance, tenant configuration, and collaboration controls."},{icon:Users,name:"Microsoft Teams",body:"Meetings, messaging, external access, collaboration, and governance configuration."},{icon:Cloud,name:"OneDrive",body:"Sharing, synchronization, access controls, storage, and tenant-level configuration."},{icon:Smartphone,name:"Microsoft Intune",body:"Device management, enrollment, compliance, configuration, and endpoint security controls."},{icon:ShieldAlert,name:"Microsoft Defender",body:"Threat protection, security configuration, detection capabilities, and protection policies."},{icon:Eye,name:"Microsoft Purview",body:"Information protection, data governance, retention, compliance, and auditing controls."}];return <div id="coverage" style={{background:COLORS.card,padding:"80px 48px",borderTop:`1px solid ${COLORS.border}`}}><div style={{maxWidth:"1200px",margin:"0 auto"}}><div style={{fontFamily:FONT_MONO,fontSize:"12px",color:COLORS.blue,letterSpacing:"0.06em",marginBottom:"12px"}}>MICROSOFT 365 COVERAGE</div><h2 style={{fontFamily:FONT_DISPLAY,fontWeight:700,fontSize:"28px",color:COLORS.textPrimary,marginBottom:"16px"}}>One assessment. Eight Microsoft 365 workloads.</h2><p style={{fontFamily:FONT_BODY,fontSize:"15px",lineHeight:1.7,color:COLORS.textSecondary,maxWidth:"700px",marginBottom:"40px"}}>TenantIQ evaluates identity, security, collaboration, messaging, device management, data protection, and governance across the Microsoft 365 tenant.</p><div style={{display:"grid",gridTemplateColumns:"repeat(4,1fr)",gap:"16px"}}>{modules.map(({icon:Icon,name,body})=><div key={name} style={{background:COLORS.cardAlt,border:`1px solid ${COLORS.border}`,borderRadius:"12px",padding:"22px"}}><Icon size={24} color={COLORS.blue}/><h3 style={{fontFamily:FONT_DISPLAY,fontSize:"16px",color:COLORS.textPrimary,margin:"14px 0 8px"}}>{name}</h3><p style={{fontFamily:FONT_BODY,fontSize:"13px",lineHeight:1.6,color:COLORS.textSecondary,margin:0}}>{body}</p></div>)}</div></div></div>}

function TenantIQLandingV2(){const [showAccess,setShowAccess]=useState(false);useEffect(()=>{},[]);return <><style>{`
body{margin:0;background:${COLORS.ink};color:${COLORS.textPrimary}}*{box-sizing:border-box}.nav-link{color:#9fb0c8;text-decoration:none;font-family:${FONT_BODY};font-size:14px}.primary-button,.secondary-button{border-radius:7px;padding:14px 22px;font-family:${FONT_BODY};font-weight:600;font-size:14px;cursor:pointer}.primary-button{background:${COLORS.blue};border:1px solid ${COLORS.blue};color:#07111f}.secondary-button{background:transparent;border:1px solid #2a3548;color:${COLORS.textPrimary}}.compact-button{padding:11px 18px}.hero-trust-row{display:grid;grid-template-columns:repeat(4,1fr);margin-top:30px;border-top:1px solid rgba(139,149,165,.18);border-bottom:1px solid rgba(139,149,165,.18);max-width:620px}.hero-trust-row>div{display:flex;gap:10px;align-items:center;min-height:66px;padding:10px 14px;border-right:1px solid rgba(139,149,165,.16);color:#3f92ff}.hero-trust-row>div:last-child{border-right:0}.hero-trust-row span{display:flex;flex-direction:column}.hero-trust-row strong{font-family:${FONT_DISPLAY};font-size:15px;color:#fff;line-height:1.05}.hero-trust-row small{font-family:${FONT_BODY};font-size:11px;color:#8b95a5;margin-top:4px;line-height:1.2}.hero-network{position:relative;height:220px;margin-top:-14px;overflow:hidden}.hero-network svg{width:100%;height:100%;display:block}.hero-network-lines{fill:none;stroke:rgba(46,124,255,.34);stroke-width:1}.hero-network-nodes{fill:#4ca7ff;filter:drop-shadow(0 0 8px rgba(76,167,255,.95))}.hero-network-badge{position:absolute;width:50px;height:50px;border:1px solid rgba(43,132,255,.85);border-radius:50%;display:flex;align-items:center;justify-content:center;color:#4fa3ff;background:rgba(6,19,34,.84)}.hero-network-badge.users{left:11%;top:88px}.hero-network-badge.shield{left:55%;top:42px}.hero-network-badge.lock{right:16%;top:110px}.hero-network-badge.cloud{left:25%;top:134px}.hero-workloads{max-width:1200px;margin:-14px auto 0;padding:0 48px 34px}.hero-workload-title{display:flex;align-items:center;gap:18px;color:#3d92ff;font-family:${FONT_BODY};font-weight:600;font-size:13px;margin-bottom:22px}.hero-workload-title:before,.hero-workload-title:after{content:"";height:1px;background:rgba(76,141,255,.3);flex:1}.hero-workload-title span{white-space:nowrap}.hero-workload-grid{display:grid;grid-template-columns:repeat(8,1fr);gap:22px}.hero-workload-item{text-align:center;font-family:${FONT_BODY};font-size:13px;color:#f5f7fa}.hero-workload-logo{width:54px;height:54px;margin:0 auto 8px}.hero-workload-logo svg{width:54px;height:54px;display:block}@media(max-width:900px){.site-nav{padding:8px 24px!important}.nav-links{gap:14px!important}.hero-grid{grid-template-columns:1fr!important;padding:20px 24px 18px!important}.hero-trust-row{grid-template-columns:repeat(2,1fr);max-width:none}.hero-workload-grid{grid-template-columns:repeat(4,1fr)}.hero-workloads{padding:0 24px 34px}.hero-network{height:190px}}@media(max-width:560px){.nav-links a{display:none}.hero-workload-grid{grid-template-columns:repeat(2,1fr)}.hero-trust-row{grid-template-columns:1fr 1fr}.hero-network-badge{display:none}}
`}</style><Hero onRequestAccess={()=>setShowAccess(true)}/><WhatTenantIQDoes/><MicrosoftCoverage/></>}

export default TenantIQLandingV2;
