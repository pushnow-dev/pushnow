# Notification icon preview and system-icon investigation

The web form now renders the bundled PushNow App icon before choosing a file, previews a selected supported image locally, and restores the default on reset. The web icon is byte-identical to the iOS AppIcon source (SHA-256 ad99d6cae2097cd4bb6d4cbe945ae4237e51a69c41e9a33be9d7330f5ede0131).

Astro check passed (53 files, no errors/warnings/hints), build passed (127 pages). Deployed web version `49027198-45ea-461e-853f-6ca9d1f7830f`. Live browser screenshot confirmed the blue PushNow icon in the Notification icon field. No real-user notification was sent.

The supplied blank system icon includes an iPhone badge, matching macOS forwarded iPhone notifications as documented at https://support.apple.com/en-ca/120684. Native notification headers use the installed app icon, independently of the web message's custom icon attachment: https://developer.apple.com/documentation/usernotificationsui/customizing-the-appearance-of-notifications.

The native QA agent verified the current installed iOS 18.4 app's CFBundleIcons and generated icon resources, and a real simulated system notification banner showed the correct PushNow icon. No unsupported AppIcon configuration changes were made. This does not verify the user's physical iPhone installation or macOS mirroring cache. The Mac-forwarded blank icon remains unresolved pending confirmation of the same notification's appearance on the physical iPhone; no cache reset or reinstall was performed.
