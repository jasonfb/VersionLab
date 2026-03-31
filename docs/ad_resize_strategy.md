# Ad Resize Strategy

## Status: Planning (2026-03-31)

## Problem Statement

When resizing an ad from one aspect ratio to another (e.g. 1080x1080 square to 728x90 leaderboard), the current system only changes the SVG container dimensions while keeping the viewBox at the original aspect ratio. This results in either:
- Letterboxing (black bars, content stays at original aspect ratio)
- Non-uniform stretching (text and elements get squished/distorted)

Neither approach is acceptable. A human designer would **recompose** the layout: repositioning elements, adjusting font sizes, changing line breaks, and rethinking the spatial hierarchy for the new canvas shape.

## Key Insight

**This is a layout problem, not a geometric transform problem.**

Resizing an ad across aspect ratios requires re-laying out elements intelligently, not scaling or stretching them. Both external research conversations (Perplexity, Claude) converge on the same recommendation:

> Use **deterministic layout rules** for 80-95% of the work. Use **AI only as an optional assistant** for ambiguous decisions (e.g., classifying element roles, ranking candidate layouts). Do not use AI as the primary layout engine.

## Current Architecture

- `AdParseService` extracts text layers from SVG/PDF with positions, sizes, font info
- `AdResizeService` creates `AdResize` records with `resized_layers` (mathematically scaled coordinates)
- `rescale_svg` only changes SVG `width`/`height` attributes — does not recompose content
- `InteractiveSvgEditor` renders the SVG and provides drag/drop + style editing overlays
- User can manually adjust via `layer_overrides`

## Proposed Architecture: Rules-Based Layout Engine

### Phase 1: Element Role Classification (new formal step in the UI flow)

This becomes a **mandatory user-facing step** in the ad workflow, inserted **before** the platform/size selection screen. The user must confirm role classifications before proceeding to resize.

#### Roles

- `headline` — primary text, largest font
- `subhead` / `body` — secondary text
- `cta` — call-to-action button/text
- `logo` — brand mark
- `background` — full-bleed image or solid color
- `decoration` — borders, shapes, dividers

Priority order (default): headline > CTA > logo > body > decoration

#### Three-tier classification approach

1. **Heuristic auto-classification (instant, at parse time)**
   - Sort text layers by font_size descending: largest = headline, smallest = body
   - Short text near bottom of canvas with action words ("Click Here", "Shop Now", "Learn More") = CTA
   - Elements with very small bounding boxes near corners = logo candidates
   - Full-canvas rectangles or images = background
   - Assign a confidence score to each classification

2. **Human confirmation/override (required step in UI)**
   - Present the parsed ad with each element highlighted and its auto-classified role shown
   - User can accept, change any role via dropdown, or flag elements as unclassifiable
   - This step is **blocking** — the user cannot proceed to the resize screen until all elements have confirmed roles
   - If heuristic confidence is low on any element, visually flag it for the user's attention

3. **AI fallback (optional, user-triggered)**
   - If the user is unsure about a classification, they can click an "Ask AI" button per element (or for all flagged elements)
   - Sends the element's content, font size, position, and surrounding context to an LLM
   - Returns a suggested role with reasoning
   - User still confirms the final choice

#### Data model

Role classifications are stored on the `Ad` record (or as a new association) so they persist across resize operations. The resize engine reads from confirmed roles, never from raw heuristics.

#### Flow change

Current: Upload → Parse → Resize (pick platforms) → Adjust → Version
New: Upload → Parse → **Classify Elements** → Resize (pick platforms) → Adjust → Version

### Phase 2: Aspect Ratio Buckets & Layout Templates

Rather than handling every ratio continuously, define discrete layout strategies based on the target shape. These templates are **hardcoded in the codebase** — not configurable per-account or per-brand. One universal set of rules for all users in v1.

| Bucket | Ratios | Layout Strategy |
|--------|--------|----------------|
| Square | 1:1 | Original layout (minor adjustments) |
| Landscape | 4:3, 16:9 | Elements flow horizontally. Headline left/center, CTA right, logo bottom-right |
| Leaderboard | 728x90, similar ultra-wide | Single row. Headline left, body center (may be dropped), CTA right, logo far-right |
| Portrait | 4:5, 2:3 | Vertical stack with more spacing. Headline top, body middle, CTA + logo bottom |
| Story | 9:16, 1080x1920 | Full-bleed vertical. Large headline centered, body below, CTA bottom |
| Skyscraper | 160x600, 300x600 | Narrow vertical stack. Elements centered, font sizes reduced significantly |

Each bucket defines:
- **Anchor regions** for each element role (e.g., headline anchors to top-left in landscape)
- **Font scaling rules** per role (headlines scale aggressively, body scales conservatively)
- **Text reflow behavior** (new maxWidth, natural line breaks instead of squishing)
- **Element priority** (what to drop if there's not enough space)
- **Spacing/margin proportions** relative to canvas size

### Phase 2b: Background Handling Strategy

#### Solid color backgrounds

Detect if the background is a solid color (or near-solid). If so, simply fill the new canvas with that color. This covers most current sample ads (solid black, etc.) and is trivial.

#### Photo/image backgrounds — intelligent crop to fill

Default behavior is **crop to fill** (scale uniformly until the image covers the target canvas, then crop the overflow). However, cropping must be **intelligent**:

- **Subject-aware cropping**: Use AI (vision model) to identify the focal point / hero subject in the background image. Position the crop to keep the subject visible and avoid placing text elements over faces or key visual areas.
- **Text-overlay collision detection**: After the layout engine places text elements, verify that no text overlaps the hero subject. If collision is detected, shift the crop offset or adjust text placement.

#### Background image swapping (future feature)

For cases where cropping the original background produces poor results for a given aspect ratio, the system will support **background image swapping**:

- The account/client maintains an **image catalog** (managed Assets)
- When resizing to a new aspect ratio, the system can suggest or auto-select a background image from the catalog that is a better fit — either already the correct aspect ratio, or a better candidate for cropping
- User can manually pick an alternative background from the catalog during the interactive adjustment step
- This pairs well with the existing Asset management system and the planned move away from external image URLs

### Phase 2c: Font Extraction & Text Measurement

#### Proven pipeline (TTFunk + pdf-reader)

Tested and confirmed working with sample ads:

1. **At parse time** (`AdParseService#parse_pdf`): extract embedded TrueType font binaries from the PDF via `pdf-reader`. Fonts live in the PDF's `FontDescriptor` → `FontFile2` stream. Store each font as an attachment on the Ad (e.g., `AdFont` model or Active Storage `has_many_attached :font_files`).

2. **At resize time**: load the stored font binary into `TTFunk::File.new(raw_data)`. Use `ttf.cmap.unicode` for character-to-glyph mapping, `ttf.horizontal_metrics.for(glyph_id).advance_width` for glyph widths, and `ttf.header.units_per_em` for unit conversion.

3. **Text width calculation**: For a given string at a given font size:
   ```
   width_in_points = (sum of advance_widths) / units_per_em * font_size
   ```

4. **Line break computation**: Given a target max width, measure words and break lines when cumulative width exceeds the target. This gives accurate, font-aware reflow in pure Ruby — no browser or external tools needed.

#### Embedded font requirement

PDFs **must** have embedded fonts. During `AdParseService#parse_pdf`, after extracting fonts, validate that every font referenced by the document has an embedded `FontFile2` stream. If any font is missing:

- **Reject the upload** with a clear user-facing error: e.g., "This PDF is missing embedded fonts (FontName). Please re-export with fonts embedded and re-upload."
- Do not proceed to the classification or resize steps — font data is required for accurate text measurement and reflow

This ensures the layout engine always has the actual font metrics it needs. PDFs exported from standard design tools (Illustrator, InDesign, Figma, Canva) embed fonts by default, so this should rarely be an issue in practice.

#### Key details

- Both `ttfunk` (1.7.0) and `pdf-reader` (2.15.1) are already in the bundle
- Subset fonts (only glyphs used in the ad) work fine for measurement
- For SVG uploads: fonts are typically not embedded — SVG support for text reflow will use approximate metrics or require a separate font upload (future consideration, not blocking v1)
- Font data is associated with parsed layers so the layout engine knows which font to use for each text element

### Phase 3: Layout Computation (resize time)

The layout engine runs these steps:

1. **Classify target** into an aspect ratio bucket
2. **Handle background** per the strategy above (solid fill, intelligent crop, or swap)
3. **Compute available regions** based on the bucket's layout template
4. **Place elements by priority** into their anchor regions:
   - Scale font size proportionally with `min(scaleX, scaleY)`, with per-role floors/ceilings
   - Set new text maxWidth and reflow (different line breaks, not squishing)
   - Position relative to anchor point, not absolute pixel coordinates
5. **Adjust spacing** to maintain optical balance
6. **Generate the new SVG** with elements at their computed positions

### Phase 4: SVG Generation

Instead of the current approach (changing SVG container dims), the new `rescale_svg` should:

1. Create a new SVG document at the target dimensions
2. Render the background (scaled/cropped to fill)
3. Place each text element at its computed position with its computed font size
4. Place non-text elements (logo, CTA button) at their computed positions
5. Output a clean SVG that is natively the target dimensions

### Phase 5: Interactive Adjustment (existing)

The existing `InteractiveSvgEditor` with drag/drop and style editing handles the remaining edge cases. Users click "Click to adjust" and fine-tune.

## What AI Should NOT Do

- AI should NOT be the primary layout engine
- AI should NOT produce pixel coordinates for element placement
- AI should NOT directly generate or modify SVG markup

## What AI CAN Do (Optional, Future)

- Classify element roles at parse time if heuristics are ambiguous
- Subject detection in background images for intelligent crop positioning
- Text-overlay collision detection (avoid placing text over hero subject faces)
- Background image selection from catalog based on target aspect ratio fit
- Rank candidate layouts if multiple valid compositions exist
- Suggest hierarchy changes for extreme aspect ratio shifts
- Score "visual quality" of generated layouts

## Implementation Plan

7 phases, each independently deployable and testable. Existing ads are never broken — all new columns have defaults, and the layout engine only activates when `classified_layers` is confirmed.

### Phase 1: Database Schema (no behavior change)

**Migrations:**
- Create `element_role` Postgres enum (`headline`, `subhead`, `body`, `cta`, `logo`, `background`, `decoration`)
- Add `classified_layers` (JSONB, default `[]`) to `ads` — stores parsed layers enriched with `role` and `confidence` fields
- Add `classifications_confirmed` (boolean, default `false`) to `ads` — gates access to the resize step

**Backwards compatible:** existing ads get empty `classified_layers` and `false` for confirmed.

### Phase 2: Heuristic Auto-Classification Service

**New file:** `app/services/ad_classify_service.rb`

Reads `parsed_layers`, applies heuristics, writes `classified_layers`:
- Sort text layers by `font_size` descending → largest = `headline`
- Short text (<=5 words) with action words ("Shop Now", "Click Here") = `cta`
- Full-canvas elements = `background`
- Remaining text ranked by size → `subhead`, `body`
- Each classification gets a confidence score (0.0–1.0)

**Integration:** Called from `AdParseService` immediately after parse. `parsed_layers` is never mutated — `classified_layers` is a separate field.

**Spec:** `spec/services/ad_classify_service_spec.rb`

### Phase 3: Font Extraction & Storage

**New migration:** Create `ad_fonts` table (UUID PK, `ad_id`, `font_name`, `postscript_name`, `has_one_attached :font_file`)

**New model:** `app/models/ad_font.rb`
- `belongs_to :ad`
- `measure_text_width(text, font_size)` — uses TTFunk glyph metrics
- `word_wrap(text, font_size, max_width)` — measures words, breaks lines at max width

**Modify:** `app/services/ad_parse_service.rb`
- Extract embedded TrueType fonts from PDF `FontDescriptor → FontFile2` streams
- Store as `AdFont` records with attached font binary
- **Reject PDFs without embedded fonts** — user-facing error, do not proceed

**Modify:** `app/models/ad.rb` — add `has_many :ad_fonts, dependent: :destroy`

**Spec:** `spec/models/ad_font_spec.rb`

### Phase 4: Classify Elements UI (Frontend)

**New API endpoints** on `Api::AdsController`:
- `GET /api/clients/:client_id/ads/:id/classifications` — returns classified layers
- `POST /api/clients/:client_id/ads/:id/confirm_classifications` — saves user-confirmed roles, sets `classifications_confirmed: true`

**Guard:** `Api::AdsController#resize` returns 422 unless `classifications_confirmed?`

**New React component:** `app/frontend/components/ads/AdElementClassifier.jsx`
- SVG preview on left with highlighted elements
- Role dropdown per element on right
- Confidence indicators (color-coded)
- "Ask AI" button per element (stubbed/disabled in v1)
- "Confirm & Continue" button — calls confirm endpoint, advances to resize step

**Modify:** `app/frontend/components/ads/AdEdit.jsx`
- 3-step → 4-step flow: **Classify → Resize → Style → Version**
- Start at Classify step if `classifications_confirmed` is false

**Data migration:** Backfill existing ads — run `AdClassifyService` and set `classifications_confirmed: true` so existing ads aren't blocked.

### Phase 5: Aspect Ratio Buckets & Layout Templates

**New file:** `app/services/ad_layout/aspect_ratio_bucket.rb`
- Classifies width/height into bucket: `square`, `landscape`, `leaderboard`, `portrait`, `story`, `skyscraper`
- Based on width:height ratio ranges

**New file:** `app/services/ad_layout/layout_template.rb`
- Percentage-based anchor regions per role per bucket (converted to pixels at computation time)
- Font scaling factors per role per bucket
- Element priority order per bucket
- Drop rules (e.g., leaderboard drops `subhead`, `body`, `decoration`)

Templates are **hardcoded in the codebase**.

**Specs:** `spec/services/ad_layout/aspect_ratio_bucket_spec.rb`, `spec/services/ad_layout/layout_template_spec.rb`

### Phase 6: Layout Engine & SVG Composer

**New file:** `app/services/ad_layout/layout_engine.rb`
- Reads `classified_layers` from ad
- Classifies target dimensions into bucket
- Applies layout template: places elements by priority into anchor regions
- Scales font sizes using bucket-specific factors + dimension ratio
- Uses `AdFont#word_wrap` for accurate TTFunk-powered line breaks
- Falls back to legacy proportional scaling for ads without classifications

**New file:** `app/services/ad_layout/svg_composer.rb`
- Builds a **new SVG from scratch** at target dimensions (not mutating original)
- Renders background (solid color fill, or crop-to-fill for images)
- Places each text element at computed position with computed font size and wrapped lines
- Outputs clean SVG with `viewBox` matching target dimensions

**Modify:** `app/services/ad_resize_service.rb`
- `resize_layers` → delegates to `AdLayout::LayoutEngine#compute_layout`
- `build_resized_svg` → uses `AdLayout::SvgComposer` for classified ads, legacy `rescale_svg` fallback for old ads

**Modify:** `app/services/ad_render_service.rb` — use `classified_layers` and `wrapped_lines` when available

**Specs:** `spec/services/ad_layout/layout_engine_spec.rb`, `spec/services/ad_layout/svg_composer_spec.rb`

### Phase 7: Integration & Polish

- Update `ad_json` in controller to include `classified_layers`, `classifications_confirmed`, font names
- Update `InteractiveSvgEditor` to show role labels in hover tooltips
- End-to-end integration spec: upload → classify → confirm → resize → verify SVG structure
- Backwards compatibility spec: old ads without classifications use legacy path
- Manual verification with sample PDFs across all 6 bucket types

### File Manifest

**New files:**

| File | Phase |
|------|-------|
| `app/services/ad_classify_service.rb` | 2 |
| `app/models/ad_font.rb` | 3 |
| `app/services/ad_layout/aspect_ratio_bucket.rb` | 5 |
| `app/services/ad_layout/layout_template.rb` | 5 |
| `app/services/ad_layout/layout_engine.rb` | 6 |
| `app/services/ad_layout/svg_composer.rb` | 6 |
| `app/frontend/components/ads/AdElementClassifier.jsx` | 4 |

**Modified files:**

| File | Phase | Change |
|------|-------|--------|
| `app/models/ad.rb` | 1, 3 | `has_many :ad_fonts` |
| `app/services/ad_parse_service.rb` | 2, 3 | Call classify service + font extraction + rejection |
| `app/services/ad_resize_service.rb` | 6 | Use layout engine, keep legacy fallback |
| `app/services/ad_render_service.rb` | 6 | Use classified layers + wrapped lines |
| `app/controllers/api/ads_controller.rb` | 4, 7 | New endpoints, guard resize, update JSON |
| `config/routes.rb` | 4 | New member routes |
| `app/frontend/components/ads/AdEdit.jsx` | 4 | 4-step flow |
| `app/frontend/components/ads/InteractiveSvgEditor.jsx` | 7 | Role labels in tooltips |

### Key Design Decisions

1. **`classified_layers` is separate from `parsed_layers`** — raw parse output is never mutated
2. **Layout templates use percentage-based regions** — same template works for any pixel dimensions within a bucket
3. **Legacy fallback preserved** — `classifications_confirmed` boolean is the branch point
4. **`AdFont` model** (not `has_many_attached`) — provides metadata + measurement methods
5. **`SvgComposer` builds from scratch** — clean, predictable output rather than mutating complex original SVGs
6. **`AdLayout` namespace** — groups layout services under `app/services/ad_layout/`
