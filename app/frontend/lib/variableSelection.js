/**
 * Wraps the current text selection inside the iframe in a <span data-vl-var="varId">.
 * Returns { defaultValue } with the selected text.
 */
export function wrapTextSelection(iframeDoc, varId) {
  const selection = iframeDoc.getSelection()
  if (!selection || selection.isCollapsed || !selection.rangeCount) return null

  const range = selection.getRangeAt(0)
  const defaultValue = range.toString()
  if (!defaultValue.trim()) return null

  const span = iframeDoc.createElement('span')
  span.setAttribute('data-vl-var', varId)
  range.surroundContents(span)
  selection.removeAllRanges()

  return { defaultValue }
}

/**
 * Marks an <img> element with data-vl-var attribute.
 * Returns { defaultValue } with the image src.
 */
export function markImageVariable(imgEl, varId) {
  imgEl.setAttribute('data-vl-var', varId)
  return { defaultValue: imgEl.getAttribute('src') || '' }
}

/**
 * Removes a variable marker from the iframe DOM.
 * For spans: unwraps children. For images: removes the attribute.
 */
export function removeVariableMarker(iframeDoc, varId) {
  const el = iframeDoc.querySelector(`[data-vl-var="${varId}"]`)
  if (!el) return

  if (el.tagName === 'SPAN') {
    const parent = el.parentNode
    while (el.firstChild) {
      parent.insertBefore(el.firstChild, el)
    }
    parent.removeChild(el)
  } else {
    el.removeAttribute('data-vl-var')
  }
}

/**
 * Serializes the full HTML content of the iframe document.
 */
export function serializeIframeHtml(iframeDoc) {
  return iframeDoc.documentElement.outerHTML
}
