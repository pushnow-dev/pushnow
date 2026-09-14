# App Store Membership Configuration Checklist

Date: 2026-09-13. App `6811365630`, bundle `com.createitv.pushnow`, subscription group `22379561`.

## Completed and Read Back

- `asc auth status`: active `landlady`, System Keychain, key ID `ZY964696UT`; no environment credentials.
- `asc auth issuer-id`: `29579aa2-436b-4f08-9e83-b554902c80dd` (nonsecret identifier).
- Both monthly subscriptions now contain all six intended locales: en-US, zh-Hans, ja, ko, es-ES, de-DE. Added the eight missing Japanese/Korean/Spanish/German localizations using `asc subscriptions localizations create`, then independently listed both subscriptions to verify persistence. Existing English/Chinese entries unchanged.
- Plus monthly `6811365720`: 500 notifications/day. Pro monthly `6811365836`: unlimited daily notifications, with fair-use/platform limits described in new translations.
- Apple rejected two initial Pro descriptions exceeding 55 characters; shortened Spanish/German text and successfully retried. No duplicate localizations were created.
- `asc subscriptions review app-store-screenshot view` for each monthly product returns an empty screenshot relationship.

## Credential Discovery: Filenames Only

- Matching active ASC candidate: `/Users/tnt/Documents/Github/100-app/landlady/AuthKey_ZY964696UT.p8`.
- Subscription key candidate: `/Users/tnt/Documents/Github/100-app/Molayer/privacy/tools/SubscriptionKey_Q5Y2346WK5.p8`.
- Another ASC key exists at `/Users/tnt/Documents/Github/100-app/baby/AuthKey_W599C2YUJ5.p8` and Downloads; not selected or reused.
- Harmony `IAPKey_...p8` files are not Apple subscription keys and must not be used for this configuration.
- No private-key contents were read or printed. The subscription candidate's team, permissions and revocation status remain unverified. A sibling repo mentioning team `677U99F8TX` does not establish this key's ownership. Coordinator must check the actual Apple portal before reuse.
- No public ASC CLI subscription-key listing command was found. Experimental `asc web auth` explicitly uses undocumented endpoints, so it was not used as an official API substitute.

## Remaining Work

- Verify candidate Apple key belongs to the intended team and is active before configuring RevenueCat.
- Upload an actual working membership screenshot after StoreKit product loading is configured. The inspected `membership-light-final.png` shows unavailable paid plans and an unconfigured-payment error; intentionally not submitted as a review screenshot.
- Keep monthly prices and annual scope unchanged. No annual price decisions, subscription-level changes, agreement acceptance, code issuance or purchase occurred in this task.
- Repeat product/status readback after screenshots and credential setup; metadata completeness alone is not sandbox transaction proof.

## Offer Code Workflow: Do Not Confuse Production and Sandbox

Inspected local CLI help:

```sh
asc subscriptions offers offer-codes create --subscription-id SUB_ID --name OFFER_NAME --offer-eligibility REPLACE_INTRO_OFFERS --customer-eligibilities NEW --offer-duration ONE_MONTH --offer-mode FREE_TRIAL --number-of-periods 1 --prices TERRITORY:PRICE_POINT_ID
asc subscriptions offers offer-codes generate --offer-code-id OFFER_ID --quantity COUNT --expiration-date YYYY-MM-DD
```

These are command templates, **not executed**. Terms, eligibility, renewal behavior, duration and territory pricing require deliberate selection. The installed `generate` command exposes no sandbox/environment flag; do not assume this command produces sandbox codes or substitute it for the sandbox UI.

Apple's documented sandbox workflow: select the subscription's existing offer, use **Create Sandbox Codes**, choose 10-10,000 codes and an expiration no more than six months away. Codes expire at midnight Pacific Time on the chosen day. Test via a Sandbox Apple Account on supported OS versions; iOS 16.3+ satisfies the stated sandbox account requirement. Production one-time-code issuance is a different operation and requires the app to be ready for sale. [Apple subscription offer-code instructions](https://developer.apple.com/help/app-store-connect/manage-subscriptions/set-up-subscription-offer-codes)

After explicit offer setup and sandbox issuance, redeem with the native sheet/account settings, then verify the RevenueCat sandbox CustomerInfo and backend sandbox-isolated entitlement. Do not accept sheet dismissal as purchase proof. Root owns browser work; this task did not open or operate browser/Simulator surfaces.

## CLI-Only Follow-Up

- `asc web auth status` returned `authenticated: false`. Active official ASC API-key authentication remains separate and valid. No browser cookies or credential stores were extracted.
- `asc schema apiKeys` returned no matching public endpoints; `asc actors` is an audit-actor lookup, not subscription-key verification. No supported official ASC command was found to establish the candidate subscription key's team or revocation state.
- **Sandbox API path found:** `asc schema subscriptionOfferCodeOneTimeUseCodes` confirms official `POST /v1/subscriptionOfferCodeOneTimeUseCodes` accepts `environment`, `expirationDate`, and `numberOfCodes`. Therefore the earlier installed CLI flag gap is not an Apple API capability gap. An authenticated official API request can explicitly choose the sandbox environment after an offer is authorized, without issuing a production batch. Keep the ASC JWT in memory, never terminal output or command arguments. No such write has been performed.
- The official RevenueCat CLI exists at [RevenueCat/cli](https://github.com/RevenueCat/cli), but `rc` is not installed on PATH here. It documents `rc apps apple check APP_ID` (read-only Apple sign-in/team/key-access check), `rc setup apple APP_ID` (creates/uploads missing Apple keys), `rc apps update`, and authenticated `rc api` calls. These are alternatives to dashboard operation, not a way to inherit MCP credentials automatically.
- RevenueCat CLI requires its own OAuth/API-key authentication. Official docs allow a provided v2 key via `RC_API_KEY`; Apple setup additionally needs Apple login and potentially 2FA. Neither authenticated `asc` nor connected MCP implies those credentials are available to the CLI. Do not create a duplicate RevenueCat account to work around this. [Official authentication guidance](https://www.revenuecat.com/docs/tools/cli/setup)
- RevenueCat's official API provides app updates and public-key reads under `/v2/projects/{project_id}/apps/{app_id}` and its `/public_api_keys` child. Missing exposed MCP functions are tooling limitations, not proof those API operations do not exist. Their use still requires a legitimate authorized CLI/API credential; no arbitrary extraction was attempted. [Official App API](https://www.revenuecat.com/docs/api-v2/app)

## Authorized Sandbox Offer Attempt and Credential Verification

The coordinator subsequently authorized two named validation offers: `PUSHNOW_SANDBOX_PLUS_20260913` and `PUSHNOW_SANDBOX_PRO_20260913`. Intended terms: one month free, one period, no auto-renew, replace introductory offers, eligible new/existing/expired subscribers, China storefront only. Intended batches: ten explicitly SANDBOX codes per offer expiring 2026-10-13. No production code issuance or purchase was authorized.

- Pre-write offer lists were empty. Installed `asc` requires `--prices` even for FREE_TRIAL; Apple rejects a non-null price point for that mode. An official API request with a null price point and explicit CHN territory then returned HTTP 500 UNEXPECTED_ERROR for Plus, again on one bounded retry, and for Pro. Each attempt rechecked the offer name before creation. Plus subsequent list remained empty; no batch creation was reached.
- `scripts/asc-sandbox-codes.mjs` captures an ASC-generated JWT in memory, passes authentication to curl on stdin, pins `environment: SANDBOX`, validates batch environment/count before downloading code values, and stores values only in mode-0600 `.secrets` files. No code files were created because offer creation failed. Stop rather than switch to paid/autorenewing/production terms.
- Candidate `Q5Y2346WK5` was tested through the official read-only StoreKit sandbox transaction endpoint using issuer `29579aa2-436b-4f08-9e83-b554902c80dd` and bundle `com.createitv.pushnow`, with a five-minute JWT signed in memory. Requesting synthetic transaction `0` returned HTTP 400 / `4000006` (invalid transaction ID). A negative control with identical claims and key ID but a random private-key signature returned HTTP 401 Unauthenticated. This is live evidence that the candidate key and issuer pass Apple's authentication for the request; the endpoint does not return a human-readable team ID. No real transaction was requested, and no private key or JWT was logged.

Apple documents transaction lookup's distinct unauthorized and invalid-transaction responses. This authentication check is not a purchase/receipt verification test. [Get Transaction Info](https://developer.apple.com/documentation/appstoreserverapi/get-transaction-info)

### Sandbox Offer Creation Resolved

An additional targeted retry was authorized after checking Apple's official schema: `SubscriptionOfferCodePriceInlineCreate.Relationships.subscriptionPricePoint` is optional. Omitting the entire relationship, rather than sending `data: null`, resolved the HTTP 500. [Apple relationship schema](https://developer.apple.com/documentation/appstoreconnectapi/subscriptionoffercodepriceinlinecreate/relationships-data.dictionary)

| Tier | Offer ID | Batch ID | Readback environment | Count | Expiry |
| --- | --- | --- | --- | --- | --- |
| Plus | 11d80026-3399-4fde-92ca-bcfd6fd153ef | 586382 | SANDBOX | 10 | 2026-10-13 |
| Pro | 52b4650f-e432-442d-b045-9cb64135174f | 586288 | SANDBOX | 10 | 2026-10-13 |

Both offers retain the authorized ONE_MONTH, one period, FREE_TRIAL, autoRenewEnabled=false terms and CHN territory. Eligibility includes NEW, EXISTING and EXPIRED; introductory offers are replaced, not stacked. Both batches were independently fetched through Apple's API and verified SANDBOX before code download. Values reside only in `.secrets/asc-sandbox-plus-20260913.json` and `.secrets/asc-sandbox-pro-20260913.json`, verified file mode 0600. Each download contains 190 bytes; code values are intentionally absent from this report. No production batch or redemption was performed.

### Apple Server Notification URL API

The installed CLI does not expose these flags on app updates, but `asc schema 'PATCH /v1/apps/{id}'` confirms the official API accepts `subscriptionStatusUrl`, `subscriptionStatusUrlForSandbox`, `subscriptionStatusUrlVersion`, and `subscriptionStatusUrlVersionForSandbox`. Thus no browser is necessary once the actual RevenueCat-provided URLs and expected versions are known. Do not derive or guess a webhook URL. These Apple-to-RevenueCat settings are distinct from the RevenueCat-to-Pushnow webhook.

Explicit official GET with those four fields selected returned null for all four: production and sandbox Apple server notification URLs are currently unconfigured. No URL write was performed by this agent.
