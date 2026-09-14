# Monthly subscription review screenshots

2026-09-13. These are genuine physical-device mirror captures supplied by the coordinator, not generated app interfaces. Original PNG files remain unchanged under `../raw-mirror/`.

Both sources were inspected: Plus/Pro selection, loaded CNY8/CNY18 monthly prices, Continue, Restore purchases, Redeem code, automatic-renewal disclosure, Privacy Policy and Terms of Use are visible.

ASC rejected the first Plus upload at820x1796 with IMAGE_INCORRECT_DIMENSIONS. Its newly created failed placeholder was removed. Both originals were then proportionally scaled to2688px height and padded only at the left/right edges with white to1242x2688, converted to72dpi RGB JPEG without alpha. No UI, wording, prices or selection states were altered. This canvas is listed in Apple's [screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications); Apple's [In-App Purchase information](https://developer.apple.com/help/app-store-connect/reference/in-app-purchases-and-subscriptions/in-app-purchase-information) explains that review screenshots show the offered item/service and are not public App Store screenshots.

| Monthly product | ASC ID | Uploaded review file | Review screenshot ID | Readback |
| --- | --- | --- | --- | --- |
| Plus | 6811365720 | en-US-plus-monthly.jpg | 62587ecc-fad7-44ef-b09c-e66c356850e0 | COMPLETE,1242x2688 |
| Pro | 6811365836 | en-US-pro-monthly.jpg | 6c4f53ab-d4f6-4936-a56e-74dd45d5336a | COMPLETE,1242x2688 |

`readback.json` records independently fetched saved screenshot relationships and processing state. `monthly-product-readback.json` records aggregate product state after upload. Temporary signed upload operations are omitted from saved metadata. No subscription was submitted for review by this task.
