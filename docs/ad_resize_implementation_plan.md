# Ad Resize Layout Engine — Implementation Plan

## Context

The current ad resize system only changes SVG container dimensions, producing letterboxing or distortion. We're rebuilding it as a rules-based layout engine that repositions elements intelligently based on aspect ratio bucket templates, with TTFunk-powered text reflow and a new "Classify Elements" UI step.

## 7 Phases (each independently deployable)

### Phase 1: Database Schema
- Create `element_role` Postgres enum
- Add `classified_layers` (JSONB) and `classifications_confirmed` (boolean) to `ads`
- Backwards compatible: defaults to `[]` and `false`

### Phase 2: Heuristic Auto-Classification Service
- New `AdClassifyService` — reads `parsed_layers`, applies font-size/content/position heuristics, writes `classified_layers`
- Called from `AdParseService` after parse
- Spec coverage

### Phase 3: Font Extraction & Storage
- New `AdFont` model with `has_one_attached :font_file`
- Extract embedded TrueType fonts during `AdParseService#parse_pdf`
- Reject PDFs without embedded fonts
- `measure_text_width` and `word_wrap` methods using TTFunk
- Spec coverage

### Phase 4: Classify Elements UI
- New React component `AdElementClassifier.jsx`
- New API endpoints: `GET classifications`, `POST confirm_classifications`
- Guard resize endpoint: require `classifications_confirmed`
- AdEdit.jsx: 3-step → 4-step flow
- Data migration to backfill existing ads
- "Ask AI" button stubbed for future

### Phase 5: Aspect Ratio Buckets & Layout Templates
- `AdLayout::AspectRatioBucket` — classifies dimensions into square/landscape/leaderboard/portrait/story/skyscraper
- `AdLayout::LayoutTemplate` — percentage-based anchor regions, font scaling rules, element priority, drop rules per bucket
- Hardcoded, not configurable
- Spec coverage

### Phase 6: Layout Engine & SVG Composer
- `AdLayout::LayoutEngine` — reads classified layers, applies bucket template, computes positions, uses TTFunk for line breaks
- `AdLayout::SvgComposer` — builds new SVG from scratch at target dimensions (not mutating original)
- Wire into `AdResizeService` — new path for classified ads, legacy fallback preserved
- Update `AdRenderService` to use new layout data
- Spec coverage

### Phase 7: Integration & Polish
- Update `ad_json` response with new fields
- Update `InteractiveSvgEditor` for new SVG structure (role labels in tooltips)
- End-to-end integration specs
- Backwards compatibility verification

## Key Files

### New files
- `app/services/ad_classify_service.rb`
- `app/models/ad_font.rb`
- `app/services/ad_layout/aspect_ratio_bucket.rb`
- `app/services/ad_layout/layout_template.rb`
- `app/services/ad_layout/layout_engine.rb`
- `app/services/ad_layout/svg_composer.rb`
- `app/frontend/components/ads/AdElementClassifier.jsx`
- Migrations, data migration, specs for each

### Modified files
- `app/models/ad.rb` — `has_many :ad_fonts`
- `app/services/ad_parse_service.rb` — call classify + font extraction
- `app/services/ad_resize_service.rb` — use layout engine, keep legacy fallback
- `app/services/ad_render_service.rb` — use classified layers + wrapped lines
- `app/controllers/api/ads_controller.rb` — new endpoints, guard resize
- `config/routes.rb` — new member routes
- `app/frontend/components/ads/AdEdit.jsx` — 4-step flow

## Design Decisions
1. `classified_layers` separate from `parsed_layers` — raw parse never mutated
2. Layout templates use percentage-based regions, converted to pixels at computation time
3. Legacy fallback preserved via `classifications_confirmed` boolean branch
4. `AdFont` model (not `has_many_attached`) for metadata + measurement methods
5. `SvgComposer` builds SVG from scratch rather than mutating original
6. `AdLayout` namespace groups layout services

## Verification
- Each phase has its own spec coverage
- Phase 7 includes end-to-end integration test covering full flow
- Manual testing: upload PDF → classify → resize to multiple platforms → verify SVGs show proper layout per bucket
