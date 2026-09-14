# Membership UI and Integration

Date: 2026-09-13

## Scope and View Boundaries

- MembershipSettingsView: settings navigation entry.
- PaywallView: modal navigation and close action.
- MembershipContentView: selected plan, status, commands, legal disclosures and native Apple code redemption.
- MembershipComparisonTable: shared-capability and daily-quota comparison.
- MembershipPlanPicker: three equally sized Free/Plus/Pro choices in one row.
- PaywallViewModel: purchase, cancellation, pending, restore and redemption-result state.
- RevenueCatService and SDK adapter: identity, catalog, transactions and verified entitlements.

The existing product boundary remains Free 50/day, Plus 500/day, Pro unlimited subject to service abuse controls. Shared capabilities are not misrepresented as paid-only. No invented discount, annual price, or premium-only feature was introduced. Monthly prices must come from the selected RevenueCat package's StoreProduct. Free is not a purchasable product.

## Code Redemption

Uses iOS StoreKit offerCodeRedemption sheet. Completion triggers RevenueCat receipt synchronization, not a local entitlement grant. It does not implement unverified custom text codes. Live audit found no configured Apple offer codes.

## Verification Boundary

Before this membership change, 39 native Simulator tests passed, covering cache, timezone, account races and encrypted-message behavior. Timezone search and selection were inspected in the iPhone 16 Pro iOS 18.4 Simulator. The prior build was installed and launched on the connected physical iPhone.

Membership-specific build, tests and rendered inspection are recorded below after execution. A build or mocked adapter test is not a sandbox transaction. Public SDK key, Apple credential configuration, backend deployment/secrets and a configured redeemable code remain separate live requirements; see audits 25 and 26.

## Executed Results

- Native iOS Simulator suite: 46 tests passed, zero failures. Final logic run: `/tmp/pushnow-membership-tests-final.log`.
- Backend full suite: 32 tests across seven files passed, including seven real local D1 membership bridge tests. Log: `/tmp/pushnow-membership-backend-tests.log`.
- Final layout-only Simulator and automatically signed physical builds passed. Logs: `/tmp/pushnow-membership-layout.log` and `/tmp/pushnow-membership-layout-real.log`.
- Final physical app installed successfully on the connected iPhone 15 Pro (installation database sequence 12208); launch result recorded in the execution transcript.
- Simulator iPhone 16 Pro iOS 18.4: inspected both appearances, selected Plus/Pro/Free, confirmed selection updates and Free cannot purchase. Missing configuration leaves paid purchase disabled and displays an error instead of inventing a price or entitlement.
- Apple redemption sheet opened; it remained loading in Simulator and was dismissed without a code or transaction. This is entry-point proof only, not successful redemption.
- Final light layout screenshot: `evidence/preferences-membership/membership-light-final.png`. Other evidence includes timezone search and Apple redemption presentation.
- All new Swift views are small, separately owned components; no giant screen or local membership grant remains.

## Remaining Live Work

No live purchase, restore or code redemption succeeded in this run. The public iOS SDK key is absent, Apple validation credentials are not configured in RevenueCat, no offer codes exist, and the newly tested backend bridge/migration/secrets have not been deployed. Anonymous-origin and transferred subscriptions intentionally fail closed pending proven ownership/manual reconciliation. Monthly plans alone are exposed; annual catalog entries have no confirmed prices and are not offered by this UI.
