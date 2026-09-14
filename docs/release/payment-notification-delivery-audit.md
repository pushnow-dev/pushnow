# Review-message delivery check

2026-09-13. Read-only production check; no messages resent, deleted, or rewritten. No device/Simulator/UI operation by this agent.

## Verified server evidence

The four English message IDs are:

- b131931c-c3ca-4be7-8200-b843baf52f2d
- c1dc75f4-4bfd-4c07-94af-a9dce9557093
- 177fa6d1-bb3e-42b3-8893-5929f718c8f7
- c76719e2-9ca1-46fe-8534-74c19f81d0ce

All four were inserted at04:06:04–04:06:07 UTC and had APNs accepted status at04:06:05–04:06:08 UTC, one attempt each, no last error. They target the same active iOS device as the four Chinese messages. Device last-seen and push-token update timestamps continued advancing after the English send. Each encrypted outbox uses the same expected account/device and its own message UUID. Messages have future expiry and no future delivery schedule.

The detailed, secret-free SQL readback is `payment-notification-delivery-readback.json`. APNs acceptance alone was not treated as proof of visible delivery. No cryptographic mismatch was established; private device keys were neither retrieved nor printed.

## Final device outcome

During investigation, the coordinator directly verified that all four English messages became visible in the physical iPhone inbox, with correct time ordering, and captured the screen. Investigation stopped on that evidence. The observation is consistent with delayed inbox loading/refresh completion, but no exact latency cause was proved. No resend was necessary.

For subsequent capture, allow the inbox load to complete and verify the latest message titles before taking the screenshot; do not generate duplicate notifications to compensate for a temporary stale list.
