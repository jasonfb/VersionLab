/**
 * Variable selection utilities.
 *
 * Text variables use placeholder tokens  {{vl:<uuid>}}  stored in the raw HTML.
 * Image variables keep  data-vl-var="<uuid>"  on the <img> element.
 *
 * The iframe preview replaces text placeholders with <span data-vl-var>
 * wrappers so hovering / highlighting still works visually.
 */

// ── Text variables ──────────────────────────────────────────────────────────

/**
 * Finds `selectedText` in `rawHtml` and replaces the first occurrence with
 * a {{vl:varId}} placeholder token.
 * Returns { defaultValue, updatedHtml } or null when the text can't be found.
 */
export function insertTextPlaceholder(rawHtml, selectedText, varId) {
  if (!selectedText?.trim()) return null

  const placeholder = `{{vl:${varId}}}`

  // Try a direct match first (works when selected text has no tags in between)
  let index = rawHtml.indexOf(selectedText)
  if (index !== -1) {
    const updatedHtml =
      rawHtml.slice(0, index) + placeholder + rawHtml.slice(index + selectedText.length)
    return { defaultValue: selectedText, updatedHtml }
  }

  // Fall back to an HTML-encoded version
  const encoded = selectedText
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
  index = rawHtml.indexOf(encoded)
  if (index !== -1) {
    const updatedHtml =
      rawHtml.slice(0, index) + placeholder + rawHtml.slice(index + encoded.length)
    return { defaultValue: selectedText, updatedHtml }
  }

  // The selected text likely spans across HTML tags. Build a mapping from
  // the visible (tag-stripped) text back to positions in the raw HTML, then
  // find the selected text in the visible version and replace the
  // corresponding raw HTML range.
  const { visibleText, rawIndices } = buildTextMap(rawHtml)
  const normalizedSelected = normalizeWhitespace(selectedText)
  const normalizedVisible = normalizeWhitespace(visibleText)
  const visibleIndex = normalizedVisible.indexOf(normalizedSelected)
  if (visibleIndex === -1) return null

  // Map visible start/end back to raw HTML positions
  const rawStart = rawIndices[visibleIndex]
  const rawEnd = rawIndices[visibleIndex + normalizedSelected.length - 1] + 1

  const updatedHtml =
    rawHtml.slice(0, rawStart) + placeholder + rawHtml.slice(rawEnd)

  return { defaultValue: selectedText, updatedHtml }
}

/**
 * Builds a character-by-character map from visible text positions to raw HTML
 * positions, skipping over HTML tags and decoding entities.
 */
const BLOCK_TAGS = /^\/?(br|p|div|table|tr|td|th|li|ul|ol|h[1-6]|hr|blockquote|section|article|header|footer)\b/i

function buildTextMap(html) {
  let visibleText = ''
  const rawIndices = [] // rawIndices[visiblePos] = index in html
  let i = 0

  while (i < html.length) {
    if (html[i] === '<') {
      // Skip entire tag
      const close = html.indexOf('>', i)
      if (close === -1) { i = html.length; continue }
      const tagInner = html.slice(i + 1, close)
      i = close + 1
      // Insert a space for block-level tags so word boundaries are preserved
      if (BLOCK_TAGS.test(tagInner) && visibleText.length > 0 && !/\s$/.test(visibleText)) {
        rawIndices.push(i - 1)
        visibleText += ' '
      }
    } else if (html[i] === '&') {
      // Decode HTML entity
      const semi = html.indexOf(';', i)
      if (semi !== -1 && semi - i < 10) {
        const entity = html.slice(i, semi + 1)
        const decoded = decodeEntity(entity)
        for (let c = 0; c < decoded.length; c++) {
          rawIndices.push(i)
          visibleText += decoded[c]
        }
        i = semi + 1
      } else {
        rawIndices.push(i)
        visibleText += html[i]
        i++
      }
    } else {
      rawIndices.push(i)
      visibleText += html[i]
      i++
    }
  }

  return { visibleText, rawIndices }
}

function decodeEntity(entity) {
  const map = {
    '&amp;': '&', '&lt;': '<', '&gt;': '>', '&quot;': '"',
    '&apos;': "'", '&nbsp;': ' ', '&#160;': ' ', '&#8203;': '',
  }
  if (map[entity]) return map[entity]
  // Numeric entities
  const m = entity.match(/^&#(\d+);$/)
  if (m) return String.fromCodePoint(Number(m[1]))
  const mx = entity.match(/^&#x([0-9a-fA-F]+);$/)
  if (mx) return String.fromCodePoint(parseInt(mx[1], 16))
  return entity // unknown entity, keep as-is
}

function normalizeWhitespace(str) {
  return str.replace(/\s+/g, ' ')
}

/**
 * Replaces a {{vl:varId}} placeholder with the variable's default text.
 */
export function removeTextPlaceholder(html, varId, defaultValue) {
  const placeholder = `{{vl:${varId}}}`
  return html.replaceAll(placeholder, defaultValue || '')
}

// ── Image variables ─────────────────────────────────────────────────────────

/**
 * Adds  data-vl-var="varId"  to the <img> tag whose src matches `imgSrc`
 * inside the raw HTML string.  Returns { defaultValue, updatedHtml }.
 */
export function insertImageMarker(rawHtml, imgSrc, varId) {
  const escapedSrc = imgSrc.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')
  const re = new RegExp(
    `(<img\\b[^>]*?src=["']${escapedSrc}["'][^>]*?)(\\s*/?>)`,
    'i',
  )
  const updatedHtml = rawHtml.replace(re, `$1 data-vl-var="${varId}"$2`)
  return { defaultValue: imgSrc, updatedHtml }
}

/**
 * Removes a  data-vl-var="varId"  attribute from the raw HTML string.
 */
export function removeImageMarker(html, varId) {
  return html.replace(new RegExp(`\\s*data-vl-var="${varId}"`, 'g'), '')
}

// ── Preview ─────────────────────────────────────────────────────────────────

/**
 * Converts stored HTML (with {{vl:uuid}} tokens) into preview HTML by
 * replacing each token with a visible <span data-vl-var="uuid"> wrapper.
 * Image markers are left as-is (already in the markup).
 */
export function buildPreviewHtml(html, allVariables) {
  if (!html) return html
  let result = html
  for (const v of allVariables) {
    if (v.variable_type !== 'text') continue
    const placeholder = `{{vl:${v.id}}}`
    const span = `<span data-vl-var="${v.id}">${escapeHtml(v.default_value)}</span>`
    result = result.replaceAll(placeholder, span)
  }
  // Strip any orphaned tokens (e.g. variable's section was deleted)
  result = result.replace(/\{\{vl:[0-9a-f-]+\}\}/g, '')
  return result
}

function escapeHtml(str) {
  return str
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
}
