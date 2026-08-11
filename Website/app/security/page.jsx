const text = { maxWidth: 820, margin: "0 auto", padding: "64px 24px 96px", fontFamily: "Inter, Arial, sans-serif", color: "#182033", lineHeight: 1.7 };
export const metadata = { title: "Security" };
export default function SecurityPage() {
  return <main style={text}>
    <a href="/" style={{ color: "#2563EB" }}>← TenantIQ</a>
    <h1>TenantIQ Security</h1>
    <p>TenantIQ is designed around a simple operating principle: assess Microsoft 365 configuration without silently changing it.</p>
    <h2>Read-only assessment</h2>
    <p>Supported assessment workflows use read-only permissions intended to collect configuration and security information required by TenantIQ checks. TenantIQ does not perform automated remediation as part of the assessment.</p>
    <h2>Least privilege</h2>
    <p>Permissions should be limited to those required by supported checks. Permission requirements are expected to evolve as workloads and assessments change.</p>
    <h2>Transparent results</h2>
    <p>TenantIQ is designed to connect findings to the condition or configuration that produced them and to provide a recommended next action for administrator review.</p>
    <h2>Early access status</h2>
    <p>TenantIQ is still evolving. Formal certifications or compliance attestations should not be assumed unless they are explicitly published by TenantIQ.</p>
  </main>;
}
