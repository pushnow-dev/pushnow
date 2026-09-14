PushNow is an account-based inbox for user-configured scripts, agents and API notifications. It does not execute agents or promise emergency delivery.

REVIEW ACCESS
Use the dedicated credentials supplied in the App Review login fields. Before signing in, select the Sandbox service on the sign-in screen; this account belongs to https://sandbox-api.pushnow.dev and is isolated from production data. Email inbox access is not required. Selecting this service does not change Apple's purchase environment; App Review purchases use Apple's sandbox. If already signed in to another server environment, sign out before selecting Sandbox.

CORE FLOW
1. Sign in using the supplied review credentials in the documented server environment.
2. Open Home to view received messages and their details. The Subscriptions tab contains user-configured sources. Compatible v2 messages and attachments are encrypted by the sender and decrypted locally using Apple's CryptoKit.
3. Use Devices to inspect authorized devices and sender keys. A first device enrolls during sign-in. Additional devices may require approval from an existing trusted device before encrypted history can be read.
4. Senders support immediate notification, scheduling and save-only. Notification display also depends on iOS permissions, Focus and APNs.
5. Settings includes language, appearance, account management and account deletion. Discovery channel preferences are explicitly local/pending activation; third-party channel content delivery is not represented as active.

IN-APP PURCHASES
Settings > Membership displays the free plan and Plus/Pro monthly options. Plus: 500 notification items per day. Pro: no daily item-count cap, subject to service and abuse-prevention limits. Free: 50 per day. The App Store sheet shows the local price. Only the two monthly products are offered in this release; existing annual catalog records are not sold by the app.
Restore Purchases is available on the same membership screen. The app uses RevenueCat and reconciles the resulting account entitlement with the matching server environment. A synchronization warning is distinct from a failed store transaction.

PRIVACY
Email/account and device identifiers, purchase history, service interactions and operational metadata are used to provide the service. No advertising or cross-app tracking is implemented. Content encryption does not hide required account/routing metadata.
Privacy: https://pushnow.dev/privacy/
Terms: https://pushnow.dev/terms/
Support: https://pushnow.dev/support/
