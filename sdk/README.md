# PushNow Account-Bound E2EE SDKs

Local SDK folders ready for source upload to the `pushnow-dev` GitHub
organization. Registry publication still requires the matching npm, PyPI, Maven
Central and Go module release credentials.

| SDK | Required runtime | Start here |
| --- | --- | --- |
| TypeScript / npm | Browser Web Crypto or Node.js 22+ | `pushnow-sdk` / `pushnow-js` |
| Python | Python 3.10+ and Node.js 22+ | `pushnow` / `pushnow-python` |
| Go | Go 1.22+ and Node.js 22+ | `github.com/pushnow-dev/pushnow-go` |
| Java | Java 11+ and Node.js 22+ | `dev.pushnow:pushnow-sdk` / `pushnow-java` |

The Python, Go and Java SDKs are **language bindings with a bundled Node crypto bridge**,
not native HPKE implementations. Each folder is independently usable and includes
the CLI's v2 crypto modules plus pinned `@hpke/core` dependencies. A global CLI or
another SDK folder is not required. This choice preserves the existing HPKE Auth
wire contract without handwritten cryptographic primitives.

All three support independently pinned-root authorization, verified recipients,
encrypted title/body, links, icon, image/file attachments, all-device or selected
device targeting, inbox-only messages, scheduling, expiry, durable encrypted
outbox retries and redacted local request logs. Custom sound is not in the current
wire contract and explicitly fails. Scheduled reminders remain active after reading.

Read the complete [trust, encryption and API contract](python/CONTRACT.md), also
included inside every language folder. A source token alone is insufficient:
clients require the authorized sender private key and a signed account archive.

Run each folder's documented tests before integrating. Tests use local HTTP
fixtures and actual CLI-generated HPKE vectors; they do not prove production or
device-visible push delivery. Upload source and lockfiles, excluding generated
dependencies, binaries, credentials and outboxes.
