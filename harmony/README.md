# Pushnow for HarmonyOS

Native ArkTS client using the same account, trusted device directory, sender authorization and encrypted history protocol as the iOS app.

## Implemented

- Verified email-code/password login, secure credential persistence, single-flight refresh and server logout with account-change guards.
- Account-scoped P-256 device keys, signed registration challenge, first-device identity, pinned-root pairing and encrypted approval, archive transfer/grants and legacy private-key migration.
- Sender authorization with full sender/account fingerprint comparison and credential revocation.
- Shared iOS/Harmony device management, rename, notification toggles, system permission, Push Kit registration and token updates.
- v2 HPKE-authenticated encrypted history, read/delete synchronization, legacy v1 decrypt/ack, encrypted attachment integrity checks and in-memory image/text previews or explicit file export.
- English, Simplified Chinese, Japanese, Korean, Spanish and German resources; system light/dark appearance.
- Native Huawei V3 provider in `backend/`, alongside existing APNs routing.

The app is split into panels, a UI model and dedicated auth/device/crypto/archive/sender/content services. Failed requests surface errors, with no sample-data fallback.

## Build and tests

From the repository root:

```sh
bash harmony/scripts/build-debug.sh
node --test harmony/tests/*.test.mjs harmony/test/*.test.mjs
npm --prefix backend run check
npm --prefix backend test -- --maxWorkers=2 --testTimeout=30000
```

DevEco Studio SDK/tool paths default to `/Applications/DevEco-Studio.app/Contents/`. Set `DEVECO_SDK_HOME` if necessary. Current output:

`harmony/entry/build/default/outputs/default/entry-default-unsigned.hap`

## Integration and runtime status

See [multi-device integration](docs/multi-device-push.md) for pairing, HTTP/CLI target selection, Huawei setup and security details; [QA report](../docs/qa/harmony-client.md) for verification evidence.

The HAP builds, but no signing configuration or connected Harmony target was available in this session. Provider tests mock Huawei/APNs and cannot prove physical delivery. Production still requires the updated Worker deployment, matching Huawei service-account/app configuration, signed HAP and real-device verification. Harmony standard notifications currently show a generic encrypted reminder; plaintext is decrypted after opening the app. Markdown is shown as text, links can be copied, and file export uses the system picker.
