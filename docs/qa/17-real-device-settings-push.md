# Real-device naming, settings and push verification

Date: 2026-09-12. This report supersedes the earlier production-readiness snapshot
where noted below. No APNs delivery is inferred from API or build success.

## Physical device

- Connected iPhone 15 Pro (`iPhone16,1`), iOS 18.7, system name `林逍遥`.
- CoreDevice identifier: `863FF34A-1D38-5EBF-8C8A-4F3EBFF8A6DB`.
- Signed naming build installed and launched successfully from
  `/tmp/pushnow-device-name-real/Build/Products/Debug-iphoneos/JiZhi.app`.
- The live API independently reported the new active device
  `443f3c5b-5af6-469c-bc09-1166cb00cc91`, named `iPhone 15 Pro (443F3C)`.
- App naming prefers the available system-assigned name plus hardware model.
  iOS restricts user-assigned names without Apple's approved entitlement; this
  build does not claim that entitlement. Generic names fall back to model plus
  a short installation ID. Existing explicit names are preserved.
- Six focused naming tests passed before the real-device build.

## Production repair

- Read-only inspection found migration 0004 had already been applied earlier,
  but lacked the subsequently added challenge table and quota column.
- Private database backup completed before writes. Applied only additive 0005;
  no account, session or device-binding reset was performed.
- Backend typecheck and 19 tests passed. Deployed Worker version
  `068b7de0-d9e6-4f12-9285-e46e6a1e2638`; health and readiness passed.
- Created a separate random `PUSH_TOKEN_ENCRYPTION_KEY` using Wrangler's secret
  input, without printing or committing its value. Secret-name readback confirmed
  both that key and the existing `AUTH_TOKEN_PEPPER`.
- Historical legacy push records contained token hashes but no encrypted tokens;
  those records cannot be used to send a real APNs request.

## Current external blockers

- No APNs provider configuration is present yet. The Apple Developer portal is
  at sign-in; an APNs-authorized key and matching team/key/topic configuration
  are required before an actual Apple push can be sent.
- True-device UI initially showed a logged-in account but failed push
  registration. After repair, the system notification permission prompt appeared;
  allowing it changed the app status to enabled. Production readback confirmed a
  sandbox secure push token for the exact device at `2026-09-12T13:51:38.000Z`.
  No token value was printed. Account login, device enrollment, APNs registration
  and actual message receipt remain separate milestones.
- iPhone Mirroring was temporarily interrupted by physical phone use, then
  recovered. Real-device settings verification can continue.
- No test message has yet been submitted to APNs, and no physical-device receipt
  or notification-extension decryption is claimed.

## Settings follow-up

- Account and membership are now separate second-level screens. Language offers
  system, English, Simplified Chinese, Japanese, Korean, Spanish and German;
  appearance offers system, light and dark. Both preferences persist locally.
- Final 19 native tests passed, including exact English/Chinese translations,
  preference persistence, device naming and authentication regressions.
- Signed final build succeeded and was installed and launched on the physical
  iPhone from `/tmp/pushnow-settings-real/Build/Products/Debug-iphoneos/JiZhi.app`.
- The final device-row change isolates rename/revoke buttons. Earlier physical
  inspection found tapping rename also opened revoke confirmation; the coordinator
  cancelled it and did not revoke the device.
- Mirror connection recovered after final installation. Physical UI confirmed
  compact settings, separate Account and Membership screens, full account details,
  enabled push status, membership quota and the existing paywall entry.
- English and light appearance were selected through the actual UI. Terminating
  and relaunching the app preserved both. Chinese and dark appearance were then
  selected and visibly applied. Language and appearance were restored to system
  after testing; final UI shows both system preferences.
- Live language switching exposed a cached navigation-title bug. The final
  incremental signed build was installed and launched, and physical UI confirmed
  both the language page and settings/back title immediately changed to Chinese.
- The fixed rename button opened only the rename dialog. An attempted Chinese
  text entry through Mirroring did not input correctly, so it was cancelled;
  no replacement name or device revocation was saved.
- The final physical checks used iPhone Mirroring screenshots in the tool
  transcript, not simulated screenshots. No notification receipt is inferred.
- Implementation details: `docs/qa/18-device-naming-and-preferences.md`.
