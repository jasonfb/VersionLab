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
 * Finds `selectedText` in `rawHtml` and replaces the correct occurrence with
 * a {{vl:varId}} placeholder token.
 *
 * `occurrenceIndex` (0-based) tells us which occurrence in the visible text
 * the user actually selected.  This is computed in the iframe from the
 * preview HTML and stays valid for the raw HTML because {{vl:…}} tokens
 * don't contain normal prose text.
 *
 * Returns { defaultValue, updatedHtml } or null when the text can't be found.
 */
export function insertTextPlaceholder(rawHtml, selectedText, varId, occurrenceIndex = 0) {
  if (!selectedText?.trim()) return null

  const placeholder = `{{vl:${varId}}}`

  // Build a map from the raw HTML's visible text back to raw positions
  const { visibleText, rawIndices } = buildTextMap(rawHtml)

  // Normalize both texts for whitespace-insensitive matching, but keep a
  // mapping from normalized positions back to the original visibleText
  // positions (which is what rawIndices is keyed by).
  const normalizedSelected = normalizeWhitespace(selectedText)
  const { normalized: normalizedVisible, indexMap: normToOrigMap } = normalizeWithMap(visibleText)

  // Collect ALL occurrences of the selected text in the normalized visible text
  const visibleMatches = []
  let searchFrom = 0
  while (searchFrom <= normalizedVisible.length - normalizedSelected.length) {
    const idx = normalizedVisible.indexOf(normalizedSelected, searchFrom)
    if (idx === -1) break
    visibleMatches.push(idx)
    searchFrom = idx + 1
  }

  if (visibleMatches.length === 0) return null

  console.log('[insertTextPlaceholder]', {
    selectedText,
    occurrenceIndex,
    totalMatches: visibleMatches.length,
    matchPositions: visibleMatches,
  })

  // Pick the occurrence the user actually selected
  const matchIdx = Math.min(occurrenceIndex, visibleMatches.length - 1)
  const bestNormIdx = visibleMatches[matchIdx]

  // Map: normalized position → original visibleText position → raw HTML position
  const origStart = normToOrigMap[bestNormIdx]
  const origEnd = normToOrigMap[bestNormIdx + normalizedSelected.length - 1]
  const rawStart = rawIndices[origStart]
  let rawEnd = rawIndices[origEnd] + 1

  // If the last matched character is an HTML entity (starts with &), include
  // the full entity so we don't leave a dangling "nbsp;" etc.
  if (rawHtml[rawIndices[origEnd]] === '&') {
    const semi = rawHtml.indexOf(';', rawIndices[origEnd])
    if (semi !== -1 && semi - rawIndices[origEnd] < 10) rawEnd = semi + 1
  }

  console.log('[insertTextPlaceholder] replacing raw range', {
    rawStart,
    rawEnd,
    rawSnippet: rawHtml.slice(Math.max(0, rawStart - 20), rawEnd + 20),
  })

  const updatedHtml =
    rawHtml.slice(0, rawStart) + placeholder + rawHtml.slice(rawEnd)

  return { defaultValue: selectedText, updatedHtml }
}

/**
 * Builds a character-by-character map from visible text positions to raw HTML
 * positions, skipping over HTML tags and decoding entities.
 *
 * Content inside <head>, <title>, <style>, and <script> tags is excluded
 * so the visible text matches what the browser renders in <body>.
 */
const BLOCK_TAGS = /^\/?(br|p|div|table|tr|td|th|li|ul|ol|h[1-6]|hr|blockquote|section|article|header|footer)\b/i
const INVISIBLE_TAGS = /^(head|title|style|script)\b/i
const INVISIBLE_CLOSE = /^\/(head|title|style|script)\b/i

function buildTextMap(html) {
  let visibleText = ''
  const rawIndices = [] // rawIndices[visiblePos] = index in html
  let i = 0
  let insideInvisible = 0 // nesting depth inside invisible tags

  while (i < html.length) {
    if (html[i] === '<') {
      // Skip entire tag
      const close = html.indexOf('>', i)
      if (close === -1) { i = html.length; continue }
      const tagInner = html.slice(i + 1, close)
      i = close + 1

      // Track invisible tag nesting
      if (INVISIBLE_TAGS.test(tagInner)) {
        insideInvisible++
        continue
      }
      if (INVISIBLE_CLOSE.test(tagInner)) {
        insideInvisible = Math.max(0, insideInvisible - 1)
        continue
      }

      if (insideInvisible > 0) continue

      // Insert a space for block-level tags so word boundaries are preserved
      if (BLOCK_TAGS.test(tagInner) && visibleText.length > 0 && !/\s$/.test(visibleText)) {
        rawIndices.push(i - 1)
        visibleText += ' '
      }
    } else if (insideInvisible > 0) {
      // Skip text content inside invisible tags
      i++
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
 * Like normalizeWhitespace but also returns an index map so that
 * normalizedResult[i] came from str[indexMap[i]].
 */
function normalizeWithMap(str) {
  let normalized = ''
  const indexMap = [] // indexMap[normalizedPos] = originalPos
  let i = 0
  while (i < str.length) {
    if (/\s/.test(str[i])) {
      // Collapse consecutive whitespace into a single space
      if (normalized.length === 0 || normalized[normalized.length - 1] !== ' ') {
        indexMap.push(i)
        normalized += ' '
      }
      i++
    } else {
      indexMap.push(i)
      normalized += str[i]
      i++
    }
  }
  return { normalized, indexMap }
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
