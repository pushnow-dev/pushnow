# iOS v2 Notification Sound

## Chosen wire contract

The optional **top-level** v2 `sound` field is `default | silent | chime`.
The coordinating backend maps absent/default to `aps.sound = "default"`, silent to
an omitted `aps.sound`, and chime to `aps.sound = "pushnow-chime.wav"`.
No sound field is added to the encrypted preview. Silent means a visible notification
without requested audio, not an inbox-only message or a background silent push.

## iOS implementation boundary

`NotificationServiceExtension/NotificationService.swift` copies incoming notification
content and preserves sound in success, validation-failure and timeout fallback paths.
`SecurePreviewLoader.swift` changes title/body/image only. Both remain unchanged.
The app currently has no local UNNotificationRequest scheduler and its v2 history UI
does not consume sound metadata. No unused Swift model field, selector, decoder or
mapping layer was added. Existing foreground presentation policy remains unchanged.

## Original resource and reproduction

- Asset: `JiZhi/Resources/pushnow-chime.wav`.
- Generator: `JiZhi/Support/generate-notification-chime.mjs`.
- Original synthesized two-note tone with attack, exponential decay and final fade.
  No third-party samples, proprietary recordings, network inputs or random data.
- WAV/RIFF, uncompressed signed 16-bit little-endian linear PCM, mono, 44,100 Hz.
- 55,125 frames, 1.25 seconds, 110,294 bytes; nonzero audio without clipping.
- Regenerate: `node JiZhi/Support/generate-notification-chime.mjs`.
- Verify bytes without writing: `node JiZhi/Support/generate-notification-chime.mjs --check`.
- Independently inspect on macOS: `afinfo JiZhi/Resources/pushnow-chime.wav`.

## Exact parent Xcode integration

Add one PBXFileReference for `JiZhi/Resources/pushnow-chime.wav`, type `audio.wav`.
Add one PBXBuildFile referencing it to the **JiZhi application target** Copy Bundle
Resources phase, currently `A10000000000000000000050`.
Use a normal file reference; the built destination must be
`Pushnow.app/pushnow-chime.wav` (or the actual application product name), at the main
bundle root, not inside an opaque Sounds folder reference or Assets.xcassets.

No new Swift Compile Sources entries. The generator and this document are tooling,
not bundle resources. Do not add the WAV only to the NSE target: Apple resolves alert
sounds from the containing application's main bundle or its Library/Sounds directory.
No pbxproj changes are made by this task. The asset is unavailable in shipped builds
until the parent integrates the resource and builds/installs that app.

## Apple platform limits

- Apple supports linear PCM for custom alert sounds, with WAV, AIFF or CAF containers.
  Sounds must be shorter than 30 seconds; unsupported/overlong or missing resources
  can result in default audio. This task uses a 1.25-second linear PCM WAV.
  [Apple custom alert sound requirements](https://developer.apple.com/library/archive/documentation/NetworkingInternet/Conceptual/RemoteNotificationsPG/SupportingNotificationsinYourApp.html)
- APNs uses a bundled sound filename, not an arbitrary path, URL, uploaded attachment
  or a user's system ringtone identifier. An absent sound key does not request audio.
  [Apple payload keys](https://developer.apple.com/library/archive/documentation/NetworkingInternet/Conceptual/RemoteNotificationsPG/PayloadKeyReference.html)
- NSE execution is conditional and time-limited. Preserving server-selected sound
  covers the generic fallback without requiring successful decryption or image download.
  [Modifying notification content](https://developer.apple.com/documentation/usernotifications/modifying-content-in-newly-delivered-notifications)
- Normal notification audio remains subject to the user's notification/sound settings
  and system interruption policy. This is not a critical-alert implementation and does
  not request privileges to bypass mute or Focus. No promise of audible delivery follows
  from APNs acceptance.
  [Requesting notification authorization](https://developer.apple.com/documentation/usernotifications/asking-permission-to-use-notifications)

## Validation and coordinator-owned device checks

Completed: generator `--check` reproduced the checked-in bytes exactly; macOS `afinfo`
independently reported WAVE, mono 44,100 Hz Int16, 1.250000 seconds and 55,125 packets.
Peak sample magnitude is 14,184 out of 32,767, with nonzero RMS and no clipping.
SHA-256: `f1bd45c4ba286c892329bbd1252ffeab8c75e2c864cf727b44ec77927ba5cf5d`.

No Xcode build, unit/UI
tests, Simulator, or device installation is run by this task. Audio listening and
recipient-visible/audible delivery are not verified by examining a WAV header.

On a physical device, after parent integration:

1. Confirm the installed app bundle contains `pushnow-chime.wav` at its root.
2. Enable normal notification sounds; send omitted/default, silent and chime cases.
   Confirm generic system sound, no sound, and the original chime respectively.
3. Repeat while the app is backgrounded/locked. Check foreground behavior separately
   against the app's current presentation policy; do not infer it from background tests.
4. Exercise decryption failure and NSE timeout: generic fallback retains the APNs choice.
5. Check sound-disabled/mute/Focus settings without claiming the chime bypasses them.
6. Verify an old build lacking the WAV falls back to default audio rather than claiming
   that custom sound is installed. Reject unsupported sound values at the API boundary.
