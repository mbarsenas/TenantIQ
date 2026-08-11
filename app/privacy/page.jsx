const text = { maxWidth: 820, margin: "0 auto", padding: "64px 24px 96px", fontFamily: "Inter, Arial, sans-serif", color: "#182033", lineHeight: 1.7 };
export const metadata = { title: "Privacy Policy" };
export default function PrivacyPage() {
  return <main style={text}>
    <a href="/" style={{ color: "#2563EB" }}>← TenantIQ</a>
    <h1>Privacy Policy</h1>
    <p><strong>Last updated:</strong> August 11, 2026</p>
    <p>TenantIQ collects information you choose to provide through the early access form, such as your name, work email, company, role, and approximate tenant size. We use this information to respond to your request, evaluate product fit, and communicate about TenantIQ.</p>
    <h2>Microsoft 365 assessment data</h2>
    <p>The public website does not itself connect to or assess your Microsoft 365 tenant. Assessment access and data-handling practices are provided separately as part of the TenantIQ assessment workflow and customer engagement.</p>
    <h2>Service providers</h2>
    <p>We may use infrastructure, hosting, email-delivery, and security providers to operate the website and respond to requests. We do not sell personal information collected through this website.</p>
    <h2>Retention and deletion</h2>
    <p>Early access information is retained only as reasonably necessary to manage product access, business communications, and applicable legal obligations. You may request deletion of information you submitted.</p>
    <h2>Changes</h2>
    <p>This policy may be updated as TenantIQ evolves. Material changes will be reflected by the updated date on this page.</p>
  </main>;
}
