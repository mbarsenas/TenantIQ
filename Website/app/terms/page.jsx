const text = { maxWidth: 820, margin: "0 auto", padding: "64px 24px 96px", fontFamily: "Inter, Arial, sans-serif", color: "#182033", lineHeight: 1.7 };
export const metadata = { title: "Terms" };
export default function TermsPage() {
  return <main style={text}>
    <a href="/" style={{ color: "#2563EB" }}>← TenantIQ</a>
    <h1>Website & Early Access Terms</h1>
    <p><strong>Last updated:</strong> August 11, 2026</p>
    <p>TenantIQ is currently presented as an early access Microsoft 365 assessment product. Website content, sample reports, check counts, supported capabilities, and product behavior may change as the product develops.</p>
    <h2>Assessment guidance</h2>
    <p>TenantIQ findings and recommendations are technical decision-support information. They do not replace your organization’s change-management, security, compliance, legal, or operational review processes. Tenant administrators remain responsible for approving and implementing changes.</p>
    <h2>Sample content</h2>
    <p>Public samples are sanitized and abbreviated for demonstration. They should not be interpreted as an assessment of any real organization.</p>
    <h2>Microsoft trademarks</h2>
    <p>Microsoft 365 and related product names are trademarks of Microsoft Corporation. TenantIQ is an independent product and is not affiliated with or endorsed by Microsoft.</p>
    <h2>Availability</h2>
    <p>Submitting an early access request does not guarantee access, availability, pricing, or a specific delivery date.</p>
  </main>;
}
