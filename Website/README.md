# TenantIQ website launch update

This package completes the six requested website items:

1. Hero report preview uses the real OneDrive sample values (50 checks / 23 pass / 8 warn / 0 fail / 46%).
2. Early Access buttons open a validated lead form. `/api/early-access` delivers the request through Resend in production and logs it in local development when email environment variables are not configured.
3. The full sample assessment opens `public/TenantIQ-Sample-Assessment.pdf`.
4. Privacy, Terms, and Security pages are included and linked in the footer.
5. Next.js metadata, robots, sitemap, keyboard focus states, reduced-motion support, responsive navigation, mobile form layout, labels, and dialog semantics are included.
6. The generic blue square has been replaced by a consistent TenantIQ CSS brand mark and wordmark treatment.

## Install

Copy the folders into the root of a Next.js App Router project. If your project already has `app/layout.jsx` or `app/page.jsx`, merge the metadata/page import rather than overwriting project-specific logic.

## Early access email

Copy `.env.example` to `.env.local` and set your production values. The route uses the Resend REST API directly, so no additional npm package is required.

## Sample PDF

The public PDF is sanitized and intentionally abbreviated. Replace it later with the final customer-facing sample report while keeping the same filename if you want the website link to continue working without code changes.

## Before production

Have the Privacy Policy and Terms reviewed for your actual business practices and legal requirements before accepting public traffic. Set `NEXT_PUBLIC_SITE_URL` to the real production domain.
