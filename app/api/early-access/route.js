import { NextResponse } from "next/server";

export const runtime = "nodejs";

function clean(value, max = 1000) {
  return String(value ?? "").trim().slice(0, max);
}

export async function POST(request) {
  try {
    const body = await request.json();

    const lead = {
      name: clean(body.name, 120),
      email: clean(body.email, 180),
      company: clean(body.company, 180),
      role: clean(body.role, 120),
      tenantSize: clean(body.tenantSize, 120),
      interest: clean(body.interest, 160),
      notes: clean(body.notes, 2000),
      submittedAt: new Date().toISOString(),
    };

    if (!lead.name || !lead.email || !lead.company || !lead.role || !lead.tenantSize || !lead.interest) {
      return NextResponse.json({ error: "Please complete all required fields." }, { status: 400 });
    }

    if (!/^[^\\s@]+@[^\\s@]+\\.[^\\s@]+$/.test(lead.email)) {
      return NextResponse.json({ error: "Please enter a valid work email." }, { status: 400 });
    }

    const apiKey = process.env.RESEND_API_KEY;
    const toEmail = process.env.EARLY_ACCESS_TO_EMAIL;
    const fromEmail = process.env.EARLY_ACCESS_FROM_EMAIL;

    if (!apiKey || !toEmail || !fromEmail) {
      console.log("[TenantIQ early access]", lead);
      return NextResponse.json({ ok: true, delivery: "development" });
    }

    const emailText = [
      "New TenantIQ early access request",
      "",
      `Name: ${lead.name}`,
      `Work email: ${lead.email}`,
      `Company: ${lead.company}`,
      `Role: ${lead.role}`,
      `Tenant size: ${lead.tenantSize}`,
      `Primary interest: ${lead.interest}`,
      "",
      "Notes:",
      lead.notes || "(none)",
      "",
      `Submitted: ${lead.submittedAt}`,
    ].join("\\n");

    const resendResponse = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${apiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        from: fromEmail,
        to: [toEmail],
        reply_to: lead.email,
        subject: `TenantIQ early access — ${lead.company}`,
        text: emailText,
      }),
    });

    if (!resendResponse.ok) {
      console.error("[TenantIQ early access] Resend error:", await resendResponse.text());
      return NextResponse.json({ error: "Your request could not be delivered. Please try again." }, { status: 502 });
    }

    return NextResponse.json({ ok: true, delivery: "email" });
  } catch (error) {
    console.error("[TenantIQ early access] route error:", error);
    return NextResponse.json({ error: "Your request could not be submitted. Please try again." }, { status: 500 });
  }
}
