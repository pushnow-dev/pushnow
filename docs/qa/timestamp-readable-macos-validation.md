# AppTimestamp.readable runtime verification

2026-09-13: `python3 scripts/qa/run-timestamp-macos.py` compiled and executed the current production `AppTimestamp.swift` and `AppLocalization.swift` directly on macOS. Exit 0. No production files were edited, no Simulator/UI or whole-app build ran. Actual six-language strings were exported from the current Localizable.xcstrings into isolated test bundles; only SecureKeyStore's unused language lookup is stubbed.

Six languages passed today/yesterday labels, prior-year inclusion, current-year omission, invalid-input fallback, New Year timezone boundary, and calendar-day comparison across New York's 23-hour spring DST day. Full timestamp winter/summer GMT offsets also passed. The fixed clock is 2026-09-13 01:00 UTC; the same 2026-09-12 23:00 UTC event correctly becomes today in Shanghai and yesterday in UTC.

| Locale | Shanghai | UTC | Older year (UTC) |
|---|---|---|---|
| en | Today 7:00 AM | Yesterday 11:00 PM | Sep 12, 2025 at 11:00 PM |
| zh-Hans | 今天 07:00 | 昨天 23:00 | 2025年9月12日 23:00 |
| ja | 今日 7:00 | 昨日 23:00 | 2025年9月12日 23:00 |
| ko | 오늘 오전 7:00 | 어제 오후 11:00 | 2025년 9월 12일 오후 11:00 |
| es | Hoy 7:00 | Ayer 23:00 | 12 sept 2025, 23:00 |
| de | Heute 07:00 | Gestern 23:00 | 12. Sept. 2025, 23:00 |

Raw output: `/tmp/pushnow-timestamp-macos.log`. Compiled harness and production/catalog SHA-256 records: `/var/folders/tl/g7dv9txs2ql62nwl63m017g40000gn/T/pushnow-timestamp-macos-56levlds`.

This proves current Foundation formatting logic and bundle translations on macOS. iOS visual layout and language/zone preference controls remain physical-device integration checks.
