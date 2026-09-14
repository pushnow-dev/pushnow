# App Store Payment Readiness Re-Audit

Date: 2026-09-13, approximately 00:23 UTC. Read-only; no products, prices, agreements, screenshots or URLs changed.

## Live Monthly Product State

| Check | Plus monthly | Pro monthly |
| --- | --- | --- |
| ASC subscription | 6811365720 | 6811365836 |
| Store identifier | com.createitv.pushnow.plus.monthly | com.createitv.pushnow.pro.monthly |
| Period | ONE_MONTH | ONE_MONTH |
| China current price | CNY 8 | CNY 18 |
| Group / level | 22379561 / 2 | 22379561 / 1 |
| State | MISSING_METADATA | MISSING_METADATA |
| Available territories | 175, including CHN and USA | 175, including CHN and USA |
| New territories | Enabled | Enabled |
| Review screenshot | Empty relationship | Empty relationship |
| Localizations | en-US, zh-Hans, ja, ko, es-ES, de-DE | en-US, zh-Hans, ja, ko, es-ES, de-DE |
| Localization state | All PREPARE_FOR_SUBMISSION | All PREPARE_FOR_SUBMISSION |

Evidence: official `asc subscriptions pricing summary`, `list`, `pricing availability view`, `pricing availability available-territories --paginate`, `review app-store-screenshot view`, and `localizations list --paginate`. Monthly hierarchy is correct: Pro is above Plus. Yearly products remain unpriced and their existing hierarchy differs; they are not part of the current monthly purchase UI.

## Credentials and Agreements

- RevenueCat MCP `get_app` now confirms both `app_store_connect_api_key_configured=true` and `subscription_key_configured=true` for `appfdd73d89a1` / `proj4269c63c` / `com.createitv.pushnow`. These earlier credential blockers are resolved at saved-configuration level.
- `asc account status --app 6811365630` reports authentication and API access OK. Agreement status is **unavailable**, explicitly because the current public ASC API surface does not expose account-level agreements. Do not equate successful ASC API calls with an active Paid Apps Agreement or verified banking/tax status.
- `asc agreements` exposes EULA territory queries, not Paid Apps Agreement status or acceptance. No agreement acceptance was attempted.

## Apple-to-RevenueCat Notifications

Explicit official ASC GET requesting the four app fields returned:

```json
{"subscriptionStatusUrl":null,"subscriptionStatusUrlVersion":null,"subscriptionStatusUrlForSandbox":null,"subscriptionStatusUrlVersionForSandbox":null}
```

The official ASC PATCH schema supports all four settings. The missing piece is the actual app-specific RevenueCat destination URL, not an inability to update ASC programmatically.

Current exposed RevenueCat MCP `get_app` does not return it, and no dedicated S2S URL tool is exposed. The installed official CLI's `apps --help` offers show/update/keys/apple/storekit-config, with no S2S URL command. Its command metadata was searched for server-notification/S2S/incoming-webhook operations; none were found. Public SDK keys are not a basis for guessing the URL. No undocumented endpoint, browser UI, browser cookies, or arbitrary credential extraction was used.

RevenueCat's current official instructions direct users to obtain the complete URL from the app's dashboard and apply it to both environments, with V2 recommended. This audit found no documented CLI/MCP app-specific URL getter. **Important:** RevenueCat also explicitly states App Store notifications are not required for most subscription updates; their absence is a notification-latency/refund-handling readiness gap, not proof that SDK purchase or restore cannot work. [RevenueCat Apple notification documentation](https://www.revenuecat.com/docs/platform-resources/server-notifications/apple-server-notifications)

## Precise Remaining Gates

1. **Submission blocker:** both monthly review screenshots are absent and product states remain MISSING_METADATA. Capture the actual functioning membership screen, then upload and read back screenshot processing status before submission. Do not use the prior unconfigured-payment screenshot.
2. **Unverified account prerequisite:** Paid Apps Agreement, banking and tax readiness cannot be established with the available public ASC CLI surface. No claim they are missing or inactive; only unverified.
3. **Event-delivery configuration gap:** obtain RevenueCat's actual Apple notification URL through a supported authorized surface, set both ASC URLs and V2 versions, then request/verify an Apple test notification. This is distinct from RevenueCat-to-Pushnow webhook configuration.
4. **Actual payment proof still required:** device/TestFlight sandbox StoreKit product loading, purchase, restore, pending/cancel paths and correct signed-in-account entitlement synchronization. Catalog and credential readback do not replace transaction evidence.
5. **Sandbox code proof:** prior sandbox batches exist, but issuance is not redemption. No code was redeemed in this re-audit.

No financial configuration changes are recommended merely to fix screenshot metadata. Keep current monthly prices and annual exclusion intact.
