# Encryption export-compliance implementation audit

The iOS app and notification-service extension use encryption. This audit does not claim otherwise.

Implementation:
- SecureCrypto.swift and SecureV2Crypto.swift call Apple's CryptoKit HPKE/P256/AES-GCM/SHA256 APIs. Application-specific authenticated data and message envelopes do not implement encryption primitives.
- EncryptedNotificationCache.swift calls CryptoKit AES-GCM; secure key storage uses Apple's Security Keychain APIs.
- Networking uses Foundation URLSession and HTTPS.
- Package.resolved contains RevenueCat purchases-ios 5.89.0 only. Its linked RevenueCat target has no third-party cryptography dependency. Its request signing, response signature checks and hash functions use Apple CryptoKit; Data+Extensions also imports Apple CommonCrypto. No OpenSSL, libsodium or CryptoSwift implementation is bundled by this dependency graph.

Apple's [export-compliance documentation reference](https://developer.apple.com/help/app-store-connect/reference/app-information/export-compliance-documentation-for-encryption) states that encryption limited to the Apple operating system does not require documentation in App Store Connect. The [overview](https://developer.apple.com/help/app-store-connect/manage-app-information/overview-of-export-compliance) recommends setting the corresponding Info.plist declaration to avoid repeated questions where documentation is not required.

Based on the inspected shipping iOS dependency graph, `ITSAppUsesNonExemptEncryption=false` was added to both app and extension Info.plists. This means the build does not use non-exempt encryption, not that it performs no encryption. Both source plists passed `plutil -lint`. The final archive will be checked for the declared value and linked frameworks.

This determination concerns the iOS binary, not the separately deployed server or CLI.
