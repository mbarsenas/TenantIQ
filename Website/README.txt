TenantIQ fresh-module logo fix

This intentionally uses NEW filenames so Next.js cannot resolve or reuse the old component/module/logo.

Copy these exact files:
app/page.tsx
components/TenantIQLandingV2.tsx
public/tenantiq-header-logo-v3.png

You do NOT need to edit code.

After copying:
1. Stop npm run dev
2. Delete .next
3. npm run dev
4. Ctrl+Shift+R on localhost:3000

The homepage now imports TenantIQLandingV2 directly.
