# Static discovery catalog

The Discover screen contains twelve static entries: Weibo, Zhihu, Bilibili,
GitHub, YouTube, Telegram, RSS, Reddit, Hacker News, Stack Overflow, AI daily
picks, and gold/silver. Search and category filters operate locally. No account
connection, scraping, subscription, or scheduled content delivery was added.
Entries display a localized coming-soon status instead of pretending to subscribe.

Brand colors are restricted to the 44-point icon area. Text, row backgrounds,
status and existing filter controls retain the shared adaptive theme. AI and
finance use neutral SF Symbols. New catalog labels and summaries are English-first
with English, simplified Chinese, Japanese, Korean, Spanish and German strings.

## Asset provenance

Nine marks were downloaded from the [Simple Icons repository](https://github.com/simple-icons/simple-icons)
at commit `b054428646591252023b9599defb56f6e0b32f10`, from
`icons/{sinaweibo,zhihu,bilibili,github,youtube,telegram,rss,reddit,stackoverflow}.svg`.
The repository's CC0 license and brand-source metadata accompany these upstream
assets; no platform integration or affiliation is implied. Brand hex colors match
its metadata. The exact paths can be resolved under
`https://github.com/simple-icons/simple-icons/blob/b054428646591252023b9599defb56f6e0b32f10/icons/`.

Hacker News uses its actual [official y18.svg asset](https://news.ycombinator.com/y18.svg).
It preserves original rendering because the supplied asset includes its orange
background; treating the complete bitmap as a template would erase the Y.

The source SVGs were rasterized directly with librsvg to transparent 144-pixel PNG
assets. Other than the native template foreground treatment, their paths were not
redrawn. A bitmap contact sheet was visually inspected. All ten image-set JSON
records and image files exist; the new localization entries parse and contain all
six languages. ImageMagick reported optional font/delegate warnings during contact
sheet composition, but produced the inspected sheet; original asset conversion
with librsvg completed successfully.

## Integration

New Swift file: `JiZhi/Repositories/StaticDiscoveryCatalog.swift`. The Xcode project
owner was notified to register this file. Existing `DiscoverView.swift` and
`InMemoryFeatureRepository.swift` were edited; shared FeatureItem models and
HomeViewModel were not changed. Full compile and light/dark Simulator proof are
performed by the coordinator after integrating its theme changes.
