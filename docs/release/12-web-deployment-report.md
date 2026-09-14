# JiZhi Web Deployment Report

Date: 2026-09-12

## Scope

Built and deployed the public JiZhi website required for App Store review support URLs. The site is Cloudflare-only, matching the current product infrastructure decision.

## Implementation

- Framework: Astro static site with native CSS
- Deployment: Cloudflare Workers Static Assets
- Worker name: `jizhi-web`
- Production domain: `https://pushnow.dev`
- Current deployed version ID: `da337fc4-8719-46eb-8f5a-26f2b890a6aa`
- Source directory: `web/`
- Built asset directory: `web/dist/`
- Primary visual asset: `web/public/assets/jizhi-app-design-board.png`
- Download QR asset: `web/public/assets/download-qr.svg`

Workers Static Assets was used instead of Railway so the product website, legal pages, and backend remain on Cloudflare. It was also preferred over Pages for this pass because the Wrangler CLI flow can deploy the custom domain directly.

## Production URLs

- Home: `https://pushnow.dev/`
- Privacy Policy: `https://pushnow.dev/privacy`
- Terms of Use: `https://pushnow.dev/terms`
- Support: `https://pushnow.dev/support`
- Sitemap: `https://pushnow.dev/sitemap.xml`
- Robots: `https://pushnow.dev/robots.txt`

Localized paths were generated for:

- `zh-Hans`
- `ja`
- `ko`
- `es`
- `de`

## SEO And GEO

Implemented:

- Per-page title and description
- Canonical URLs
- `hreflang` alternates and `x-default`
- Open Graph tags
- Twitter Card tags
- JSON-LD for the iOS app and legal/support pages
- `sitemap.xml`
- `robots.txt`
- Homepage FAQ structure for generative-search summaries

## Verification

Local verification:

```bash
npm run check
npm run build
npm audit --audit-level=moderate
```

Results:

- Astro check: 0 errors, 0 warnings, 0 hints
- Astro build: 24 pages generated
- npm audit: 0 vulnerabilities at moderate level or above

Cloudflare deployment:

```bash
npx wrangler deploy --dry-run --domain pushnow.dev
npx wrangler deploy --domain pushnow.dev
npx wrangler deployments list
```

Production readback:

- `https://pushnow.dev/` returned 200
- `https://pushnow.dev/privacy` returned 200 after following the static directory redirect
- `https://pushnow.dev/terms` returned 200 after following the static directory redirect
- `https://pushnow.dev/support` returned 200 after following the static directory redirect
- `https://pushnow.dev/zh-Hans/privacy` returned 200 after following the static directory redirect
- `https://pushnow.dev/ja/privacy` returned 200 after following the static directory redirect
- `https://pushnow.dev/ko/privacy` returned 200 after following the static directory redirect
- `https://pushnow.dev/es/privacy` returned 200 after following the static directory redirect
- `https://pushnow.dev/de/privacy` returned 200 after following the static directory redirect
- `https://pushnow.dev/assets/download-qr.svg` returned 200
- `https://pushnow.dev/assets/jizhi-app-design-board.png` returned 200

HTML readback confirmed title, description, canonical, hreflang, Open Graph, Twitter Card, JSON-LD, App push copy, email-login copy, and privacy-policy text.

## App Store URL Status

The App Store download link is intentionally marked as pending because the App Store Connect app record has not been created yet. Once the ASC app record exists and the public App Store URL is known, update `site.appStoreURL` in `web/src/data/site.ts`, rebuild, and redeploy.

## Remaining Release Blockers

- App Store Connect app record is still missing.
- App Store download URL is still pending.
- RevenueCat products, entitlement, offering, and App Store Connect product mapping still need live configuration.
- APNs delivery still needs signed physical-device proof.
