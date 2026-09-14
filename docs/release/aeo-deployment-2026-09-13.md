# PushNow AEO production deployment and readback

Deployed 2026-09-13 after the coordinator confirmed physical-device QA. No simulator, iOS, App Store Connect, Git commit, or other-process operation was performed in this deployment task.

## Deployment

- Existing authorized Cloudflare Worker: `jizhi-web`.
- Version: `734fcff9-a3e7-4eb1-b277-5358175e3717`.
- Command, from `web/`: `npx wrangler deploy --config wrangler.jsonc`.
- Worker endpoint: https://jizhi-web.xfy150150.workers.dev .
- Public production domain actually verified: https://pushnow.dev .
- `npm run check`: 0 errors, 0 warnings, 0 hints (53 files).
- `npm run build`: 127 pages generated successfully.
- Wrangler deployment exited 0. The final deployment uploaded 129 changed files after canonical normalization and activated the new Worker version.
- Evidence logs: `/tmp/pushnow-aeo-canonical-build.log`, `/tmp/pushnow-aeo-canonical-deploy.log`.

## Actual production readback

Verified at 2026-09-13 04:31:37 UTC (12:31:37 Asia/Shanghai).

| Locale | Public guide | FAQ answers | Result |
| --- | --- | --- | --- |
| English | https://pushnow.dev/guide/ | 6 | HTTP 200; visible text and metadata match build |
| 简体中文 | https://pushnow.dev/zh-Hans/guide/ | 6 | HTTP 200; visible text and metadata match build |
| 日本語 | https://pushnow.dev/ja/guide/ | 6 | HTTP 200; visible text and metadata match build |
| 한국어 | https://pushnow.dev/ko/guide/ | 6 | HTTP 200; visible text and metadata match build |
| Español | https://pushnow.dev/es/guide/ | 6 | HTTP 200; visible text and metadata match build |
| Deutsch | https://pushnow.dev/de/guide/ | 6 | HTTP 200; visible text and metadata match build |

All six FAQPage objects contain the same question and answer text rendered for readers. Each page has its language attribute, one canonical, and seven hreflang alternates including x-default. Compared normalized visible text, JSON-LD, canonical and alternates against local generated HTML. Cloudflare injects its analytics beacon, so byte-for-byte whole-HTML equality is not expected.

`/robots.txt`, `/sitemap.xml`, and `/llms.txt` all returned HTTP 200 with expected text/plain or application/xml content types and exactly matched generated files. robots.txt permits crawling and advertises the production sitemap. llms.txt links all six guides. The sitemap contains 121 unique URLs, excludes account dashboards, and all 121 return HTTP 200 directly, with no redirect.

Machine-readable evidence: `aeo-live-readback-2026-09-13.json`.

## Crawler access and practical limits

Header probes on the guide returned HTTP 200 with no challenge header for a normal browser, Googlebot user-agent, and OAI-SearchBot user-agent. These probes originate from this machine, not verified search-engine IPs, so they do not prove actual Google/OpenAI crawling, indexing, or citation. Evidence: `aeo-crawler-header-probes-2026-09-13.json`.

A default Python-urllib user-agent returned Cloudflare 403 / error 1010. The browser and search-header requests above succeeded. The separate web-retrieval connector declined these URLs internally; production HTTP verification therefore uses direct HTTPS readback, not that connector. No search ranking or AI-visibility improvement is claimed.

Canonical normalization is complete: shared `pathFor` now emits the trailing-slash directory URLs actually served by Workers. Canonical, hreflang, sitemap, first-party navigation and llms.txt agree. All six canonical URLs return 200 directly. Legacy slashless guide URLs still make exactly one existing redirect to their corresponding canonical URL; no new redirect rules were added and no redirect loop was introduced. External URLs were not changed. Evidence: `aeo-redirect-readback-2026-09-13.json`.

Search Console sitemap submission, URL Inspection, actual indexing, and AI answer citations require separate authenticated measurement. llms.txt is a content index, not a guarantee of inclusion in AI answers.
