# Sender autofill 401

The live browser showed a successful `GET /v2/recipients` followed by a 401 with `invalid_source_key`. The sender password field matched `:autofill` and the title contained the account email. `SenderConnection.ready()` was rebuilding credentials from that editable password input, allowing password-manager autofill to replace an otherwise valid authorized sender key.

Removed the sender credential input and its connection-time DOM assignment. `ready()` now validates a copy of the authorized in-memory config. Import/export and the independent key-management UI remain available. The message form and title additionally opt out of autocomplete, but correctness no longer depends on the browser honoring that hint.

Astro check passed: 53 files, zero errors/warnings/hints. Production build: 127 pages. No message submission is required for verification; refreshing the encrypted recipient directory exercises the same credential path used before sending.

Live browser after the fix: token input count 0; both initial and explicit refresh GET /v2/recipients returned 200 (601 ms and 843 ms). Original message draft restored; no message submitted. Final web version `87ba8190-cca5-4e7f-a636-034872b6b5fc` also gives an explicit completion message after recipient refresh.
