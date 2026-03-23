# Ad Upload Style Guide

This document defines the requirements for uploading ad creatives to Version Lab. The system validates all uploaded files against these rules and surfaces warnings in the UI.

---

## File Format Requirements

- Export as **SVG or PDF only**
- Do not upload PNG, JPG, EPS, or AI files
- Ensure the file contains **editable layers**
- Do not flatten the file before export

---

## Live Text Requirements

- Preserve **live text** — do not convert text to outlines
- Do not rasterize text
- Use real space characters between words
- Avoid manual letter-by-letter positioning to simulate spacing
- Avoid exporting text as vector paths

> **Important:** Text converted to outlines or vector paths cannot be edited inside Version Lab.

---

## Layer Structure Recommendations

- Keep headline, subheadline, body, and CTA text on **separate layers**
- Keep logos on their own layer
- Keep background image or background color on its own layer
- Avoid merging all elements into a single group

---

## Background Image Requirements

- Background images must meet minimum export size for selected ad dimensions
- Do not upscale images before export
- Avoid embedding low-resolution raster images
- Maintain original image resolution

---

## Spacing and Typography Best Practices

- Use standard word spacing (space bar)
- Avoid replacing spaces with tracking adjustments
- Avoid converting each word into separate positioned glyph blocks
- Ensure fonts are embedded or available

---

## Export Recommendations

### For SVG

- Preserve text as text — do not outline fonts
- Avoid flattening groups

### For PDF

- Export with editable text enabled
- Do not flatten transparency
- Do not convert text to outlines

---

## Adobe Illustrator — Export Settings

**Before exporting:**

- Keep all text as live text — do not convert text to outlines
- Keep headline, body, and CTA text on separate layers
- Keep background on its own layer

**When exporting as SVG:**

- File → Save As → SVG
- Preserve text as editable text
- Do not outline fonts
- Avoid flattening transparency
- Do not embed raster previews unless required

**When exporting as PDF:**

- File → Save As → Adobe PDF
- Do not convert text to outlines
- Do not flatten transparency
- Preserve Illustrator editing capabilities
- Avoid exporting as a flattened image-only PDF

---

## Adobe InDesign — Export Settings

**Before exporting:**

- Ensure all text remains live and editable
- Do not convert text to outlines
- Keep text frames separate for headline, body, and CTA
- Avoid merging all elements into a single grouped object

**When exporting as PDF:**

- File → Export → Adobe PDF (Print)
- Do not convert text to outlines
- Do not flatten transparency
- Preserve editable text
- Avoid rasterizing spreads

> **Note:** InDesign does not export native SVG with full layer fidelity. If SVG is required, export through Illustrator while preserving live text.

---

## Common Causes of Word Spacing Loss

Word spacing issues usually occur when text is not stored as natural text with real space characters.

**Common causes include:**

- Replacing space characters with manual tracking adjustments
- Creating separate text objects for each word
- Converting text to outlines or vector paths
- Exporting PDFs that flatten text into positioned glyphs
- Using text effects that break natural word boundaries

**Why this matters:**

Version Lab detects words based on real space characters. If words are separated using tracking or manual positioning instead of actual space characters, editing may fail or spacing may collapse.

**To prevent this:**

- Use the space bar for word spacing
- Keep full phrases inside a single text frame
- Avoid outlining fonts before export
- Do not manually adjust spacing to simulate gaps between words

---

## If Issues Are Detected

Version Lab validates all uploaded creatives.

- Files that do not contain editable layers or live text will trigger warnings.
- Files with spacing or word-boundary issues may trigger a text integrity warning and require confirmation before editing.

All warnings are surfaced in the ad editor UI and in the Style Guide modal.
