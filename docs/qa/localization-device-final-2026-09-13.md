# Final localization verification — physical device

Device: paired iPhone 15 Pro / iOS 18.7. All visual interaction and captures used the native macOS iPhone Mirroring app as explicitly requested. No Simulator was opened or operated for this verification.

## Completed
- 396 string catalog keys populated across en, zh-Hans, ja, ko, es, de; development language en.
- Signed generic iOS build succeeded; final app installed successfully on the physical device at 12:21 on 2026-09-13.
- Chinese and English Home tabs, filters, relative timestamps, settings, membership products and decrypted notification details verified visually.
- Continuous language switching through Japanese, Korean, Spanish, German, English and Chinese verified after correcting system Back and cached Follow system picker labels. Screenshots saved as metadata/screenshots/raw-mirror/qa-*-language.png.
- Back buttons return from language selection to settings and then Home. Current App preference restored to Simplified Chinese.
- Eight meaningful encrypted notifications (4 Chinese / 4 English) visibly received, with latest messages first across message protocols. Earlier messages preserved.
- Actual monthly membership prices loaded; purchase/restore controls and legal links visible. Purchase and restore execution are not asserted by this check.
- Direct macOS Swift checks for actual localization bundle lookup, relative dates and DST offsets passed. String catalog compiler and git diff --check passed.

## Corrections included
Unified explicit App locale for tabs, filters, time, dynamic settings labels, auth/payment errors, device/detail errors and attachment size. Localized native-style Back replaces system-language fallback. Language picker is recreated on language selection so cached rows update. Cross-protocol inbox ordering is stable by receivedAt.

## Evidence limits
This is source coverage plus physical-device checks, not an exhaustive runtime traversal of every view/error state in every language. App Store review approval, purchase/restore transactions, TestFlight and search indexing require their own evidence.
