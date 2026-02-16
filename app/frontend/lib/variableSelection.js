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

  // Try a direct match first
  let index = rawHtml.indexOf(selectedText)
  let matchLength = selectedText.length

  // Fall back to an HTML-encoded version of the selected text
  if (index === -1) {
    const encoded = selectedText
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;')
    index = rawHtml.indexOf(encoded)
    matchLength = encoded.length
  }

  if (index === -1) return null

  const updatedHtml =
    rawHtml.slice(0, index) + placeholder + rawHtml.slice(index + matchLength)

  return { defaultValue: selectedText, updatedHtml }
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
  return result
}

function escapeHtml(str) {
  return str
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
}
