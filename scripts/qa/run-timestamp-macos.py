#!/usr/bin/env python3
from pathlib import Path
import tempfile, json, plistlib, subprocess, hashlib
root=Path(__file__).resolve().parents[2]
work=Path(tempfile.mkdtemp(prefix='pushnow-timestamp-macos-'))
catpath=root/'JiZhi/Resources/Localizable.xcstrings'
cat=json.loads(catpath.read_text())['strings']
for locale in ['en','zh-Hans','ja','ko','es','de']:
    directory=work/(locale+'.lproj');directory.mkdir()
    values={key:item.get('localizations',{}).get(locale,{}).get('stringUnit',{}).get('value',key) for key,item in cat.items()}
    (directory/'Localizable.strings').write_bytes(plistlib.dumps(values))
(work/'main.swift').write_text('''import Foundation
struct SecureKeyStore { func read(_ key: String) throws -> Data? { nil } }
let now = AppTimestamp.parse("2026-09-13T01:00:00Z")!
let labels = [("en", "Today", "Yesterday"), ("zh-Hans", "今天", "昨天"), ("ja", "今日", "昨日"), ("ko", "오늘", "어제"), ("es", "Hoy", "Ayer"), ("de", "Heute", "Gestern")]
for (id, todayLabel, yesterdayLabel) in labels {
    let locale = Locale(identifier: id)
    func read(_ value: String, _ zone: String = "UTC", _ clock: Date = now) -> String {
        AppTimestamp.readable(value, timezoneIdentifier: zone, now: clock, locale: locale)
    }
    let today = read("2026-09-12T23:00:00Z", "Asia/Shanghai")
    let yesterday = read("2026-09-12T23:00:00Z")
    let older = read("2025-09-12T23:00:00Z")
    precondition(today.hasPrefix(todayLabel + " "), today)
    precondition(yesterday.hasPrefix(yesterdayLabel + " "), yesterday)
    precondition(older.contains("2025"), older)
    precondition(!read("2026-08-12T23:00:00Z").contains("2026"))
    precondition(!today.contains("GMT") && !today.contains("Asia/Shanghai"))
    precondition(read("invalid") == "—")
    let newYear = AppTimestamp.parse("2026-01-01T01:00:00Z")!
    precondition(read("2025-12-31T23:00:00Z", "UTC", newYear).hasPrefix(yesterdayLabel + " "))
    precondition(read("2025-12-31T23:00:00Z", "Asia/Shanghai", newYear).hasPrefix(todayLabel + " "))
    // Calendar-day comparison must survive a 23-hour DST day.
    let spring = AppTimestamp.parse("2026-03-09T04:30:00Z")!
    precondition(read("2026-03-08T05:30:00Z", "America/New_York", spring).hasPrefix(yesterdayLabel + " "))
    print("\\(id): today=\\(today) | yesterday=\\(yesterday) | past-year=\\(older)")
}
precondition(AppTimestamp.full("2026-01-01T12:00:00Z", timezoneIdentifier: "America/New_York").contains("GMT-05:00"))
precondition(AppTimestamp.full("2026-07-01T12:00:00Z", timezoneIdentifier: "America/New_York").contains("GMT-04:00"))
print("PASS: six languages, today/yesterday, same/past year, New Year timezone boundary, DST calendar-day boundary, invalid input")
''')
paths=[root/'JiZhi/Services/Localization/AppLocalization.swift',root/'JiZhi/Services/Localization/AppTimestamp.swift']
(work/'source-hashes.json').write_text(json.dumps({str(p.relative_to(root)):hashlib.sha256(p.read_bytes()).hexdigest() for p in paths+[catpath]},indent=2))
print('Harness:',work,flush=True)
subprocess.run(['swiftc',*[str(p) for p in paths],str(work/'main.swift'),'-o',str(work/'timestamp-check')],check=True)
subprocess.run([str(work/'timestamp-check')],check=True)
