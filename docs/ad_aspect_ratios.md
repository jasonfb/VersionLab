# Ad Aspect Ratios — Platform Reference

Version Lab detects the aspect ratio of uploaded ad creatives and displays matching platforms in the editor UI.

Aspect ratios are computed by reducing the pixel dimensions to their lowest common denominator (GCD).

---

## Platform Aspect Ratio Table

| Ratio | Typical Dimensions | Platforms |
|---|---|---|
| 1:1 | 1080×1080 | Facebook Feed, Instagram Square, LinkedIn Square, Pinterest Square, Reddit Feed, Threads Feed, X Square |
| 4:5 | 1080×1350 | Instagram Portrait |
| 9:16 | 1080×1920 | Instagram Story, Facebook Story, Snapchat Full Screen, TikTok In-Feed |
| 16:9 | 1200×675 | X Single Image |
| 300:157 | 1200×628 | Facebook Landscape, Reddit Feed |
| 400:209 | 1200×627 | LinkedIn Single Image |
| 2:3 | 1000×1500 | Pinterest Standard Pin |
| 364:45 | 728×90 | Google Leaderboard |
| 6:5 | 300×250 / 336×280 | Google Medium Rectangle, Google Large Rectangle, YouTube Display Banner |
| 1:2 | 300×600 | Google Half Page |
| 4:15 | 160×600 | Google Wide Skyscraper |
| 48:7 | 480×70 | YouTube Overlay |

---

## Platform Details

### Facebook (Meta)
| Format | Dimensions | Ratio |
|---|---|---|
| Feed Image | 1080×1080 | 1:1 |
| Story | 1080×1920 | 9:16 |
| Landscape | 1200×628 | 300:157 |

### Google Display
| Format | Dimensions | Ratio |
|---|---|---|
| Leaderboard | 728×90 | 364:45 |
| Medium Rectangle | 300×250 | 6:5 |
| Large Rectangle | 336×280 | 6:5 |
| Half Page | 300×600 | 1:2 |
| Wide Skyscraper | 160×600 | 4:15 |

### Instagram
| Format | Dimensions | Ratio |
|---|---|---|
| Feed Square | 1080×1080 | 1:1 |
| Feed Portrait | 1080×1350 | 4:5 |
| Story | 1080×1920 | 9:16 |

### LinkedIn
| Format | Dimensions | Ratio |
|---|---|---|
| Single Image | 1200×627 | 400:209 |
| Square | 1080×1080 | 1:1 |

### Pinterest
| Format | Dimensions | Ratio |
|---|---|---|
| Standard Pin | 1000×1500 | 2:3 |
| Square Pin | 1000×1000 | 1:1 |

### Other Platforms
| Platform | Format | Dimensions | Ratio |
|---|---|---|---|
| Reddit | Feed Image | 1200×628 | 300:157 |
| Snapchat | Full Screen | 1080×1920 | 9:16 |
| Threads | Feed Image | 1080×1080 | 1:1 |
| TikTok | In-Feed | 1080×1920 | 9:16 |
| X | Single Image | 1200×675 | 16:9 |
| X | Square | 1080×1080 | 1:1 |
| YouTube | Display Banner | 300×250 | 6:5 |
| YouTube | Overlay | 480×70 | 48:7 |

---

## Notes for Development

- Aspect ratio is computed from the uploaded file's pixel/point dimensions.
- PDF dimensions are in points (1pt = 1/72 inch); they are stored as-is in the `width`/`height` columns.
- SVG dimensions are parsed from the `viewBox` attribute or `width`/`height` root attributes.
- The `aspect_ratio` column stores a human-readable string like `"4:5"` or `"1:1"`.
- Platform hints are shown in the ad editor header and are informational only — they do not restrict where an ad can be used.
