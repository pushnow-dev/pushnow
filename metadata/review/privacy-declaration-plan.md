# PushNow App Privacy declaration plan

Status: not published or verified in the current browser session. The public ASC API cannot publish these labels, and `asc web auth status` currently reports unauthenticated. The browser automation surface currently exposes Chrome profile selection rather than a usable authenticated App Store Connect page.

| Data type | Purpose | Linked to user | Tracking |
|---|---|---|---|
| Email address | App functionality: account sign-in and support | Yes | No |
| Other user content | App functionality: user-submitted notifications and stored content | Yes | No |
| User ID | App functionality: account/session and entitlement mapping | Yes | No |
| Device ID | App functionality: trusted-device registration and notification delivery | Yes | No |
| Purchase history | App functionality: subscription purchase/restore and entitlements | Yes | No |
| Product interaction | App functionality: read/acknowledgement state, reminders and delivery actions | Yes | No |
| Other diagnostic data | App functionality: delivery status and operational failures | Yes | No |

Evidence: account/device APIs, notification state and delivery-log models, and RevenueCat identity mapping. RevenueCat uses an app-supplied account-derived identifier, so the app-level purchase linkage is declared linked even though the SDK generic privacy manifest defaults its purchase-history row to unlinked. No ads, attribution SDK or cross-app tracking implementation was found in the shipping iOS source. DEBUG PaymentDiagnostics writes local stdout only and is excluded from Release.

Complete the purpose/linkage/tracking steps for the seven existing selected data types, preview the result, publish and read back the published state. Do not mark this complete based only on a valid privacy manifest or an ASC validate result.
