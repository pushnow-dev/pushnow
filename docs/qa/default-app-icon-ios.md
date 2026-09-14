# Default reminder icon — iOS

Implemented 2026-09-13.

- `PushNowBrand.imageset/Icon.png` is byte-identical to the existing `AppIcon.appiconset/AppIcon-1024.png` (SHA-256 `ad99d6cae2097cd4bb6d4cbe945ae4237e51a69c41e9a33be9d7330f5ede0131`).
- `PushNowAppIcon` renders this bundled artwork. Inbox messages without an icon no longer infer weather, terminal, or chat symbols from the title.
- Secure message detail displays the same fallback. Compact encrypted image loading/error states also show the app icon until a valid custom image is available.
- Custom encrypted image icons still take precedence when loaded. Explicit custom SF Symbol names are retained.
- Legacy API inbox items and reminder rows use the same app fallback when the request has no icon; source-management category symbols remain unchanged.
- iOS itself displays the installed app's icon in notification banners. The notification extension continues to decrypt content and optional image attachments; no artificial thumbnail attachment was added to override system identity.

## Verification

Ad hoc signed simulator build succeeded (`/tmp/pushnow-default-icon-final.log`). Installed and launched on **iPhone 16 Pro, iOS 18.4**, retaining the existing fixture account on port 8799. Both existing encrypted messages without an icon visibly displayed PushNow's blue app artwork in the inbox: `evidence/default-app-icon/ios18-inbox.png`.

Additional live fixture verification on the same iOS 18.4 phone:

- Browser-selected-device message `84824ed4-56f5-4331-bd44-24634e7ef57e` showed title **A note for this iPhone**, the full expected plaintext body, and the PushNow default icon (`evidence/default-app-icon/ios18-web-selected-device.png`).
- An independent TypeScript SDK session logged into the same fixture, completed automatic phone authorization, uploaded the bundled GitHub PNG as an encrypted attachment, and sent message `fe20f0d6-66bc-40e8-bdad-66fb813d95ad` with `icon_id`. The phone showed the GitHub custom icon while the adjacent no-icon message continued to show PushNow (`evidence/default-app-icon/ios18-custom-and-default.png`).

This validates custom-icon precedence with a real encrypted upload and recipient UI. No system notification banner/APNS delivery is claimed; the local fixture has no APNS credentials.

No backend or App Store publishing changes were made for this icon task.
