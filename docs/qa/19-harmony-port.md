# HarmonyOS Port Verification

Date: 2026-09-12

## Scope

Implemented a separate HarmonyOS project for JiZhi under `harmony/`, aligned with the current iOS information architecture: Inbox, Sources, Reminders, Devices, and Settings.

## Backend

- Added Harmony as a first-class push platform beside iOS.
- Secure message ingestion already supports single-device delivery by sending one envelope and multi-device delivery by sending multiple envelopes.
- Added Huawei Push Kit V3 sender wiring for Harmony deliveries.
- Added tests covering Harmony push platform binding, pending-device push binding rejection, Harmony-only secure delivery, iOS + Harmony multi-device delivery, source-side iOS + Harmony recipient discovery, disabled-device push suppression, and the Huawei V3 sender request shape.

Verification:

```bash
npm --prefix backend run check
npm --prefix backend test
```

Result: passed, 22 tests.

## HarmonyOS

- Built a standalone Harmony project in `harmony/`.
- Added ArkTS services for auth, inbox/source/reminder loading, secure inbox listing/acknowledgement, device listing, secure device enrollment, PushKit token retrieval, secure push-token registration, notification preference updates, and device revocation.
- Added a GitHub-like neutral iOS-style UI with the existing JiZhi app icon.

Verification:

```bash
cd harmony
ohpm install
DEVECO_SDK_HOME="/Applications/DevEco-Studio.app/Contents/sdk" \
PATH="/Applications/DevEco-Studio.app/Contents/tools/ohpm/bin:/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin:$PATH" \
hvigorw --mode module -p module=entry assembleHap
```

Result: build successful. Output:

```text
harmony/entry/build/default/outputs/default/entry-default-unsigned.hap
```

## Remaining Verification

- `hdc list targets` returned no connected Harmony device or emulator, so runtime visual QA and install testing are not completed.
- The HAP is unsigned because this project does not yet have a signing config.
- Harmony secure device enrollment now compiles with CryptoFramework-based P-256 key generation, registration challenge signing, and first-device identity certificate generation. Runtime verification still needs a real HarmonyOS device or emulator.
- Harmony device IDs are generated and persisted as UUIDs; older local non-UUID values are replaced before secure enrollment.
- Harmony secure inbox can list and acknowledge current-device encrypted deliveries, but Harmony-side HPKE plaintext decryption still needs implementation.
- Live Harmony push requires AppGallery Push Kit credentials and a real device token.
