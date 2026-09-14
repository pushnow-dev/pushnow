# PushNow App Store screenshot packaging

Source requirement: real-device screen captures saved from native macOS iPhone Mirroring on the connected physical iPhone 15 Pro, as explicitly requested by the user. Do not open or operate Simulator for this workflow. Simulator screenshots are QA evidence only. Do not package black/locked screen captures, invented interfaces, credentials, or secrets or unverified features as product screenshots.

Tool: built-in image_gen. Inspect each raw PNG before editing. One portrait image per real screen. Output canvas requested: 1242 x 2688 (APP_IPHONE_65). Keep original source PNGs unchanged.

Visual direction: restrained white/off-white background, charcoal type, subtle cool-gray framing, small cyan accent. A large straight-on phone screen, generous text space above, readable real UI. No invented notification cards, badges, prices, awards, ratings, feature claims, or Apple logo.

## English inbox
Use case: compositing.
Asset type: App Store screenshot, portrait 1242 x 2688.
Input image: edit target, a genuine screenshot from PushNow running on physical iPhone 15 Pro.
Preserve the exact entire app screenshot, all interface text, data, icons, status bar, and layout. Scale uniformly only. Place it straight-on in a minimal charcoal device frame, occupying the lower 76 percent of the canvas, with a clean white background and subtle shadow. Do not redraw, translate, invent, replace, hide, or add any app UI. Above the phone, add only the exact headline "Your workflows. One inbox." and the smaller line "Important results, ready to read." Use refined bold sans-serif charcoal typography, left aligned, with generous margins. Small label "PushNow" at top. No other text. No prices, logos from other companies, star ratings, decorations over the UI, or floating fake notifications.

## English detail
Use the same composition, preserve the genuine detail screenshot exactly. Headline: "More context. Less guesswork." Supporting line: "Read the details behind each notification." Small label: "PushNow". No extra capabilities or modified content.

## Member review evidence
Use the unmodified physical-device membership screenshot for subscription App Review, so reviewers can inspect real products, local prices, restore and terms. Public marketing screenshot packaging should emphasize the app's core inbox/detail experience rather than pricing.

All generated outputs require visual comparison to the raw screenshot and asc screenshots validate before upload. Do not claim pixel fidelity merely because generation succeeded.

## Final delivered compositions

- zh-Hans detail: 不止通知，还有完整详情。 / 打开消息，了解事情的来龙去脉。
- zh-Hans membership: 按需选择，清楚比较。 / 查看方案，管理你的会员。
- en-US detail: More context. Less guesswork. / Read the details behind each notification.
- en-US membership: Choose what fits. / Compare plans. Manage your membership.

All four use a pale blue/ivory background and a large front-facing device. Raw sources live in ../raw-mirror/, imagegen drafts in ../drafts/, uploaded final files in ../packaged/<ASC locale>/. The Mac pointer highlight was removed from blank UI areas by imagegen. English membership legal text was separately corrected against the real review screenshot before acceptance. Originals and rejected drafts remain preserved. Mechanical size normalization used sips; asc validated four files at 1242 x 2688, RGB without alpha. Public-upload-readback.json records all four COMPLETE asset states and matching checksums.
