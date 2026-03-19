import React, { useState, useEffect, useRef, useCallback, useMemo } from 'react'
import { useParams, useNavigate } from 'react-router-dom'
import { apiFetch } from '~/lib/api'
import {
  insertTextPlaceholder,
  removeTextPlaceholder,
  insertImageMarker,
  removeImageMarker,
  buildPreviewHtml,
  snapToStandardRatio,
} from '~/lib/variableSelection'
import VariablePopover, { SLOT_ROLES, IMAGE_LOCATION_TYPES } from './VariablePopover'

// ─── Constants ────────────────────────────────────────────────────────────────

const IFRAME_NATURAL_WIDTH = 680

// ─── Section editor helpers (module-level, pure DOM) ─────────────────────────

/**
 * Find the "section candidate" elements in an email document —
 * the full-width rows that represent logical email sections.
 *
 * Strategy: find <tr> elements at the shallowest table-nesting depth,
 * preferring a depth that yields more than one candidate (skips single
 * wrapper rows). Falls back to direct <body> children for div-based emails.
 */
function getSectionCandidates(doc) {
  const allTrs = Array.from(doc.querySelectorAll('tr'))

  if (allTrs.length === 0) {
    // Div-based email: top-level body children
    return Array.from(doc.body?.children || []).filter(
      (el) => !['SCRIPT', 'STYLE', 'META', 'HEAD'].includes(el.tagName),
    )
  }

  // Compute table-nesting depth for each <tr>
  const depths = new Map()
  for (const tr of allTrs) {
    let depth = 0
    let el = tr.parentElement
    while (el && el !== doc.body) {
      if (el.tagName === 'TABLE') depth++
      el = el.parentElement
    }
    depths.set(tr, depth)
  }

  // Walk from shallowest depth upward; pick first depth with >1 candidate
  const sortedDepths = [...new Set([...depths.values()])].sort((a, b) => a - b)
  for (const depth of sortedDepths) {
    const candidates = allTrs.filter((tr) => depths.get(tr) === depth)
    if (candidates.length > 1) return candidates
  }

  // Fallback: shallowest depth even if just one
  const minDepth = sortedDepths[0] ?? 0
  return allTrs.filter((tr) => depths.get(tr) === minDepth)
}

/** Mark candidate elements that correspond to saved sections (green outline). */
function markDefinedSections(sections, candidates) {
  if (!candidates?.length) return
  candidates.forEach((c) => c.removeAttribute('data-vl-section-defined'))
  sections.filter((s) => s.parent_id == null).forEach((s) => {
    if (s.element_selector != null) {
      const idx = parseInt(s.element_selector, 10)
      if (!isNaN(idx) && candidates[idx]) {
        candidates[idx].setAttribute('data-vl-section-defined', s.id)
      }
    }
  })
}

/** Highlight the active section (selected from left panel) with a red outline. */
function applyActiveHighlight(sections, candidates, activeSectionId) {
  if (!candidates?.length) return
  candidates.forEach((c) => c.removeAttribute('data-vl-section-active'))
  if (!activeSectionId) return
  const s = sections.find((sec) => sec.id === activeSectionId)
  if (!s?.element_selector || s.parent_id != null) return
  const idx = parseInt(s.element_selector, 10)
  if (!isNaN(idx) && candidates[idx]) {
    candidates[idx].setAttribute('data-vl-section-active', '1')
  }
}

/** Extract a short preview string from a section candidate element. */
function extractSectionPreview(element) {
  const text = (element.textContent || '').replace(/\s+/g, ' ').trim()
  if (!text) return ''
  return text.length > 55 ? `${text.slice(0, 55)}…` : text
}

/** Generate a CSS selector path (body > ... > el) for any element. */
function getCssSelector(el, doc) {
  const segments = []
  let current = el
  const body = doc.body
  while (current && current !== body) {
    const tag = current.tagName?.toLowerCase()
    if (!tag) break
    const parent = current.parentElement
    if (!parent) break
    const sameTags = Array.from(parent.children).filter((c) => c.tagName === current.tagName)
    let seg = tag
    if (sameTags.length > 1) {
      const idx = sameTags.indexOf(current) + 1
      seg += `:nth-of-type(${idx})`
    }
    segments.unshift(seg)
    current = parent
  }
  return segments.join(' > ')
}

const BLOCK_TAGS = new Set([
  'TD', 'TH', 'TR', 'TABLE', 'DIV', 'SECTION', 'ARTICLE', 'ASIDE',
  'HEADER', 'FOOTER', 'FIGURE', 'BLOCKQUOTE', 'LI', 'UL', 'OL',
  'P', 'H1', 'H2', 'H3', 'H4', 'H5', 'H6',
])

/**
 * Walk up from el to find the nearest block-level element that is
 * inside sectionCandidate (but not the candidate itself).
 */
function findSubsectionTarget(el, sectionCandidate) {
  let current = el
  while (current && current !== sectionCandidate) {
    if (current.nodeType === 1 && BLOCK_TAGS.has(current.tagName)) {
      return current
    }
    current = current.parentElement
  }
  return null
}

/** Apply active highlight to the selected subsection element. */
function applySubsectionHighlight(sections, doc, activeSubsectionId) {
  if (!doc) return
  doc.querySelectorAll('[data-vl-subsection-active]').forEach((el) =>
    el.removeAttribute('data-vl-subsection-active')
  )
  if (!activeSubsectionId) return
  const sub = sections.find((s) => s.id === activeSubsectionId)
  if (!sub?.element_selector) return
  try {
    const el = doc.querySelector(sub.element_selector)
    if (el) el.setAttribute('data-vl-subsection-active', '1')
  } catch (_) {}
}

/** Mark defined subsections in the iframe using their stored CSS selectors. */
function markDefinedSubsections(sections, doc) {
  if (!doc) return
  doc.querySelectorAll('[data-vl-subsection-defined]').forEach((el) =>
    el.removeAttribute('data-vl-subsection-defined')
  )
  sections.filter((s) => s.parent_id != null).forEach((sub) => {
    if (!sub.element_selector) return
    try {
      const el = doc.querySelector(sub.element_selector)
      if (el) el.setAttribute('data-vl-subsection-defined', sub.id)
    } catch (_) {}
  })
}

/** Flatten nested sections from the API response into a flat array for state. */
function flattenSections(nestedSections) {
  return (nestedSections || []).flatMap((s) => {
    const { subsections, ...section } = s
    return [
      { ...section, variables: section.variables || [] },
      ...(subsections || []).map((sub) => ({ ...sub, variables: sub.variables || [] })),
    ]
  })
}

// ─── Component ────────────────────────────────────────────────────────────────

export default function TemplateEdit() {
  const { clientId, id } = useParams()
  const navigate = useNavigate()

  // ── Core template state ──────────────────────────────────────────────────
  const iframeRef = useRef(null)
  const [template, setTemplate] = useState(null)
  const [loading, setLoading] = useState(true)
  const [saving, setSaving] = useState(false)
  const [name, setName] = useState('')
  const [rawSourceHtml, setRawSourceHtml] = useState('')
  const [originalRawSourceHtml, setOriginalRawSourceHtml] = useState(null)
  const [sections, setSections] = useState([])
  const [expandedSection, setExpandedSection] = useState(null)
  const [activeTab, setActiveTab] = useState('sections')
  const [error, setError] = useState(null)
  const [popover, setPopover] = useState(null)
  const [hoveredVarId, setHoveredVarId] = useState(null)
  const [editingVar, setEditingVar] = useState(null)
  const [resetting, setResetting] = useState(false)
  const [assetUrls, setAssetUrls] = useState({})

  // ── Editor mode state ────────────────────────────────────────────────────
  // 'section' = section-definition mode (miniaturized email, hover/dblclick)
  // 'variable' = variable-creation mode (full-size, text selection)
  const [editorMode, setEditorMode] = useState('section')
  const [highlightedSectionId, setHighlightedSectionId] = useState(null)
  const [sectionScale, setSectionScale] = useState(0.5)
  const [previewNaturalHeight, setPreviewNaturalHeight] = useState(3000)
  const [hoveredCandidateIndex, setHoveredCandidateIndex] = useState(null)
  const [candidatePreviewTexts, setCandidatePreviewTexts] = useState([]) // indexed by candidate index
  const [editingSectionName, setEditingSectionName] = useState(null) // { sectionId, value }
  const [subsectionPreviewTexts, setSubsectionPreviewTexts] = useState({}) // keyed by subsection id
  const [hoveredSubSelector, setHoveredSubSelector] = useState(null) // CSS selector of sub-hover target
  const [highlightedSubsectionId, setHighlightedSubsectionId] = useState(null)
  const [varZoom, setVarZoom] = useState(null) // { scale, naturalHeight } when zoomed in variable mode

  // ── Refs ─────────────────────────────────────────────────────────────────
  const expandedSectionRef = useRef(null)
  const overlayRef = useRef(null)
  const previewPanelRef = useRef(null)
  const scrollablePanelRef = useRef(null) // inner scrollable div (for zoom scroll)
  const sectionCandidatesRef = useRef([])
  const fitScaleRef = useRef(0.5) // baseline "fit whole email" scale
  // Always-current sections snapshot for use inside effects without adding
  // sections to their dependency arrays (avoids spurious iframe re-writes).
  const sectionsRef = useRef(sections)
  const hoveredSubElRef = useRef(null) // DOM element ref for subsection hover
  const hoveredSubSelectorRef = useRef(null) // CSS selector of hovered sub-element

  // ── Derived ──────────────────────────────────────────────────────────────
  const allVariables = useMemo(
    () => sections.flatMap((s) => s.variables || []),
    [sections],
  )

  const topLevelSections = useMemo(
    () => sections.filter((s) => !s.parent_id),
    [sections],
  )

  // ── Keep refs in sync ────────────────────────────────────────────────────
  useEffect(() => { expandedSectionRef.current = expandedSection }, [expandedSection])
  useEffect(() => { sectionsRef.current = sections }, [sections])

  // Clear subsection selection when parent section changes (either mode)
  useEffect(() => { setHighlightedSubsectionId(null) }, [highlightedSectionId])
  useEffect(() => { setHighlightedSubsectionId(null); setVarZoom(null) }, [expandedSection])
  useEffect(() => { if (editorMode !== 'variable') setVarZoom(null) }, [editorMode])

  // ── Load template ────────────────────────────────────────────────────────
  useEffect(() => {
    apiFetch(`/api/clients/${clientId}/email_templates/${id}`)
      .then((data) => {
        setTemplate(data)
        setName(data.name)
        setRawSourceHtml(data.raw_source_html || '')
        setOriginalRawSourceHtml(data.original_raw_source_html || null)
        setSections(flattenSections(data.sections))
        setAssetUrls(data.asset_urls || {})
      })
      .finally(() => setLoading(false))
  }, [id])

  // ── Write iframe & attach mode-specific handlers ─────────────────────────
  useEffect(() => {
    const iframe = iframeRef.current
    if (!iframe || !rawSourceHtml) return

    const preview = buildPreviewHtml(rawSourceHtml, allVariables, assetUrls)
    let removeListeners = null

    const writeAndAttach = () => {
      const doc = iframe.contentDocument
      if (!doc) return

      doc.open()
      doc.write(preview)
      doc.close()

      if (editorMode === 'section') {
        // ── Section editor mode ──────────────────────────────────────────
        const style = doc.createElement('style')
        style.textContent = `
          [data-vl-hover], [data-vl-hover] td {
            outline: 2px solid rgba(59, 130, 246, 0.65) !important;
            background-color: rgba(59, 130, 246, 0.07) !important;
          }
          [data-vl-section-defined], [data-vl-section-defined] td {
            outline: 2px solid #198754 !important;
            background-color: rgba(25, 135, 84, 0.05) !important;
          }
          [data-vl-section-active], [data-vl-section-active] td {
            outline: 3px solid #dc3545 !important;
            background-color: rgba(220, 53, 69, 0.07) !important;
          }
          [data-vl-sub-hover] {
            outline: 2px solid rgba(234, 88, 12, 0.65) !important;
            background-color: rgba(234, 88, 12, 0.07) !important;
          }
          [data-vl-subsection-defined] {
            outline: 2px dashed #6f42c1 !important;
            background-color: rgba(111, 66, 193, 0.05) !important;
          }
          [data-vl-section-active] [data-vl-subsection-active],
          [data-vl-section-active] [data-vl-subsection-active] td {
            outline: 15px solid #cc8800 !important;
            background-color: transparent !important;
          }
        `
        ;(doc.head || doc.body)?.appendChild(style)

        // Measure natural height then compute scale
        requestAnimationFrame(() => {
          const naturalH = Math.max(doc.body.scrollHeight, 400)
          const panelH = previewPanelRef.current?.clientHeight ?? window.innerHeight
          const newScale = Math.min(1, Math.max(0.15, (panelH - 56) / naturalH))

          fitScaleRef.current = newScale
          setSectionScale(newScale)
          setPreviewNaturalHeight(naturalH)

          const candidates = getSectionCandidates(doc)
          sectionCandidatesRef.current = candidates
          setCandidatePreviewTexts(candidates.map(extractSectionPreview))

          // Build subsection preview texts from CSS selectors
          const subPreviews = {}
          sectionsRef.current.filter((s) => s.parent_id != null).forEach((sub) => {
            if (!sub.element_selector) return
            try {
              const el = doc.querySelector(sub.element_selector)
              if (el) subPreviews[sub.id] = extractSectionPreview(el)
            } catch (_) {}
          })
          setSubsectionPreviewTexts(subPreviews)

          // Restore section indicators with latest sections
          markDefinedSections(sectionsRef.current, candidates)
          markDefinedSubsections(sectionsRef.current, doc)
          applyActiveHighlight(sectionsRef.current, candidates, highlightedSectionId)
          applySubsectionHighlight(sectionsRef.current, doc, highlightedSubsectionId)
        })
      } else {
        // ── Variable editor mode ─────────────────────────────────────────
        const injectedStyle = doc.createElement('style')
        injectedStyle.textContent = [
          'a { cursor: text !important; -webkit-user-drag: none; user-drag: none; }',
          'a, a * { -webkit-user-select: text !important; user-select: text !important; }',
        ].join('\n')
        ;(doc.head || doc.body)?.appendChild(injectedStyle)

        doc.addEventListener('dragstart', (e) => {
          if (e.target.closest('a')) e.preventDefault()
        })

        // Find candidates so we can auto-detect which section a selection belongs to
        requestAnimationFrame(() => {
          const candidates = getSectionCandidates(doc)
          sectionCandidatesRef.current = candidates
          setCandidatePreviewTexts(candidates.map(extractSectionPreview))
        })

        // Given a DOM element inside the iframe, return the section id whose
        // element_selector candidate contains that element (or null).
        const detectSectionForElement = (el) => {
          const candidates = sectionCandidatesRef.current
          const idx = candidates.findIndex((c) => c === el || c.contains(el))
          if (idx < 0) return null
          const matched = sectionsRef.current.find((s) => !s.parent_id && s.element_selector === String(idx))
          return matched?.id ?? null
        }

        // Auto-expand the section that owns the given element, falling back to
        // whatever is already expanded. Returns the target section id (or null).
        const autoExpandSection = (el) => {
          const autoId = detectSectionForElement(el)
          const targetId = autoId || expandedSectionRef.current
          if (autoId && autoId !== expandedSectionRef.current) {
            // Update both state (for UI) and ref (for synchronous use below)
            setExpandedSection(autoId)
            expandedSectionRef.current = autoId
            console.log('[autoExpand] auto-expanding section:', autoId)
          }
          return targetId
        }

        const handleMouseUp = () => {
          const selection = doc.getSelection()
          const selStr = selection?.toString() ?? ''
          console.log('[handleMouseUp] FIRED', {
            hasSelection: !!selection,
            isCollapsed: selection?.isCollapsed,
            selectionText: JSON.stringify(selStr),
            expandedSection: expandedSectionRef.current,
          })

          if (!selection || selection.isCollapsed || !selStr.trim()) {
            console.log('[handleMouseUp] BAIL: no/collapsed/empty selection')
            return
          }

          const anchor = selection.anchorNode?.parentElement
          const anchorInVar = anchor?.closest('[data-vl-var]')
          console.log('[handleMouseUp] anchor element:', anchor?.tagName, anchor?.className, 'inVar:', !!anchorInVar)
          if (anchorInVar) {
            console.log('[handleMouseUp] BAIL: anchor inside existing variable span')
            return
          }

          // Auto-detect section from where the selection lives
          const targetSectionId = autoExpandSection(anchor)
          if (!targetSectionId) {
            console.log('[handleMouseUp] BAIL: no section covers this area')
            return
          }

          const range = selection.getRangeAt(0)
          const container = range.commonAncestorContainer
          const containerEl = container.nodeType === 3 ? container.parentElement : container
          console.log('[handleMouseUp] commonAncestorContainer:', {
            nodeType: container.nodeType,
            tagName: containerEl?.tagName,
            className: containerEl?.className,
            id: containerEl?.id,
          })

          if (containerEl) {
            const fragment = range.cloneContents()
            const fragmentHtml = (() => { const d = doc.createElement('div'); d.appendChild(fragment.cloneNode(true)); return d.innerHTML })()
            console.log('[handleMouseUp] fragment HTML:', fragmentHtml)
            const blockMatch = fragment.querySelector('a, p, h1, h2, h3, h4, h5, h6, div, td, tr, table, li, ul, ol')
            console.log('[handleMouseUp] hasBlockOrLink:', blockMatch ? blockMatch.tagName : 'none')
            if (blockMatch) {
              console.log('[handleMouseUp] BAIL: fragment contains block/link element:', blockMatch.tagName, blockMatch.outerHTML?.slice(0, 100))
              return
            }
          }

          let occurrenceIndex = 0
          try {
            const preRange = doc.createRange()
            preRange.setStart(doc.body, 0)
            preRange.setEnd(range.startContainer, range.startOffset)
            const preText = preRange.toString()
            const bodyText = doc.body.textContent || ''
            const selText = selection.toString()
            const norm = (s) => s.replace(/\s+/g, ' ')
            const normBody = norm(bodyText)
            const normSel = norm(selText)
            const normPreLen = norm(preText).length
            let pos = 0
            while (true) {
              const idx = normBody.indexOf(normSel, pos)
              if (idx === -1 || idx >= normPreLen) break
              occurrenceIndex++
              pos = idx + 1
            }
          } catch (e) {
            console.warn('[handleMouseUp] occurrence calc error:', e)
          }

          const selText = selection.toString()
          const wordCount = selText.trim().split(/\s+/).filter(Boolean).length

          console.log('[handleMouseUp] SHOWING POPOVER', {
            selectedText: selText,
            occurrenceIndex,
            wordCount,
          })

          setPopover({
            type: 'text',
            selectedText: selText,
            occurrenceIndex,
            wordCount,
          })
        }

        const handleClick = (e) => {
          const img = e.target.closest('img')
          if (!img || img.hasAttribute('data-vl-var')) return

          e.preventDefault()

          const targetSectionId = autoExpandSection(img)
          if (!targetSectionId) {
            console.log('[handleClick] BAIL: no section covers this image')
            return
          }

          const assetId = img.getAttribute('data-vl-asset-id') || null
          const ratioEntry = assetId
            ? snapToStandardRatio(img.naturalWidth, img.naturalHeight)
            : null

          setPopover({
            type: 'image',
            imgSrc: img.getAttribute('src') || '',
            assetId,
            standardizedRatio: ratioEntry?.key || null,
          })
        }

        doc.addEventListener('mouseup', handleMouseUp)
        doc.addEventListener('click', handleClick)

        removeListeners = () => {
          doc.removeEventListener('mouseup', handleMouseUp)
          doc.removeEventListener('click', handleClick)
        }
      }
    }

    if (iframe.contentDocument?.readyState === 'complete') {
      writeAndAttach()
    } else {
      iframe.addEventListener('load', writeAndAttach, { once: true })
    }

    return () => {
      if (removeListeners) removeListeners()
    }
  }, [rawSourceHtml, allVariables, editorMode]) // eslint-disable-line react-hooks/exhaustive-deps

  // ── Refresh section indicators when sections list changes ────────────────
  useEffect(() => {
    if (editorMode !== 'section') return
    markDefinedSections(sections, sectionCandidatesRef.current)
    const doc = iframeRef.current?.contentDocument
    if (doc) markDefinedSubsections(sections, doc)
  }, [sections, editorMode])

  // ── Apply subsection active highlight ────────────────────────────────────
  useEffect(() => {
    if (editorMode !== 'section') return
    const doc = iframeRef.current?.contentDocument
    applySubsectionHighlight(sections, doc, highlightedSubsectionId)
  }, [highlightedSubsectionId, sections, editorMode])

  // ── Refresh active highlight + zoom when selection changes ───────────────
  useEffect(() => {
    if (editorMode !== 'section') return

    applyActiveHighlight(sections, sectionCandidatesRef.current, highlightedSectionId)

    const scrollable = scrollablePanelRef.current

    if (!highlightedSectionId) {
      // Zoom back out to fit-all scale
      setSectionScale(fitScaleRef.current)
      scrollable?.scrollTo({ top: 0, behavior: 'smooth' })
      return
    }

    const section = sections.find((s) => s.id === highlightedSectionId)
    if (!section?.element_selector) return

    const idx = parseInt(section.element_selector, 10)
    const candidate = sectionCandidatesRef.current[idx]
    if (!candidate) return

    // getBoundingClientRect() inside the iframe is at the iframe's natural
    // scale (scale-1), so these are the element's true pixel dimensions.
    const rect = candidate.getBoundingClientRect()
    if (!rect.height) return

    const panelW = scrollable ? scrollable.clientWidth : window.innerWidth
    const panelH = scrollable ? scrollable.clientHeight : window.innerHeight
    const padding = 32 // p-3 on each side

    // Largest scale that makes the section fill 85% of panel height
    // without the email becoming wider than the panel.
    const scaleByH = (panelH * 0.85) / rect.height
    const scaleByW = (panelW - padding) / IFRAME_NATURAL_WIDTH
    const newScale = Math.min(scaleByH, scaleByW)

    setSectionScale(newScale)

    // After React re-renders with the new scale, scroll to center the section.
    requestAnimationFrame(() => {
      if (!scrollable) return
      const sectionTopScaled = rect.top * newScale
      const sectionHScaled = rect.height * newScale
      const scrollY = sectionTopScaled - (panelH - sectionHScaled) / 2
      scrollable.scrollTo({ top: Math.max(0, scrollY), behavior: 'smooth' })
    })
  }, [highlightedSectionId, sections, editorMode, candidatePreviewTexts]) // eslint-disable-line react-hooks/exhaustive-deps

  // ── Scroll preview to expanded section in variable editor mode ─────────
  useEffect(() => {
    if (editorMode !== 'variable' || !expandedSection) return
    const section = sections.find((s) => s.id === expandedSection)
    if (!section?.element_selector) return
    const idx = parseInt(section.element_selector, 10)
    if (isNaN(idx)) return
    const candidate = sectionCandidatesRef.current[idx]
    if (!candidate) return
    const iframe = iframeRef.current
    const scrollable = scrollablePanelRef.current
    if (!iframe || !scrollable) return
    requestAnimationFrame(() => {
      const iframeRect = iframe.getBoundingClientRect()
      const scrollableRect = scrollable.getBoundingClientRect()
      const rect = candidate.getBoundingClientRect()
      const candidateTopRelToScrollable = iframeRect.top - scrollableRect.top + rect.top
      const targetScrollTop = scrollable.scrollTop + candidateTopRelToScrollable - 16
      scrollable.scrollTo({ top: Math.max(0, targetScrollTop), behavior: 'smooth' })
    })
  }, [expandedSection, editorMode]) // eslint-disable-line react-hooks/exhaustive-deps

  // ── Zoom to parent + highlight subsection in variable editor mode ────────
  useEffect(() => {
    if (editorMode !== 'variable') return
    const doc = iframeRef.current?.contentDocument
    if (!doc) return

    // Clear previous subsection highlight
    doc.querySelectorAll('[data-vl-subsection-active]').forEach((el) => {
      el.style.outline = ''
      el.style.outlineOffset = ''
      el.removeAttribute('data-vl-subsection-active')
    })

    if (!highlightedSubsectionId) {
      setVarZoom(null)
      return
    }

    const sub = sectionsRef.current.find((s) => s.id === highlightedSubsectionId)
    if (!sub?.element_selector) return

    // Zoom to the parent section
    const parent = sectionsRef.current.find((s) => s.id === sub.parent_id)
    const candidates = sectionCandidatesRef.current
    const parentCandidate = parent?.element_selector != null
      ? candidates[parseInt(parent.element_selector, 10)]
      : null

    const scrollable = scrollablePanelRef.current
    const iframe = iframeRef.current

    if (parentCandidate && scrollable && iframe) {
      const naturalH = Math.max(doc.body.scrollHeight, 400)
      const panelW = scrollable.clientWidth
      const panelH = scrollable.clientHeight
      const padding = 32
      const rect = parentCandidate.getBoundingClientRect()
      const scaleByH = (panelH * 0.85) / rect.height
      const scaleByW = (panelW - padding) / IFRAME_NATURAL_WIDTH
      const scale = Math.min(scaleByH, scaleByW)
      setVarZoom({ scale, naturalHeight: naturalH })

      // Scroll to center the parent section after React re-renders with new scale
      requestAnimationFrame(() => {
        requestAnimationFrame(() => {
          const sectionTopScaled = rect.top * scale
          const sectionHScaled = rect.height * scale
          const scrollY = sectionTopScaled - (panelH - sectionHScaled) / 2
          scrollable.scrollTo({ top: Math.max(0, scrollY), behavior: 'smooth' })
        })
      })
    }

    // Apply yellow highlight to subsection element
    try {
      const el = doc.querySelector(sub.element_selector)
      if (el) {
        el.setAttribute('data-vl-subsection-active', '1')
        el.style.outline = '3px solid #cc8800'
        el.style.outlineOffset = '-2px'
      }
    } catch (_) {}
  }, [highlightedSubsectionId, editorMode])

  // ── Highlight hovered variable in variable editor mode ───────────────────
  useEffect(() => {
    if (editorMode !== 'variable') return
    const doc = iframeRef.current?.contentDocument
    if (!doc) return

    doc.querySelectorAll('[data-vl-var]').forEach((el) => {
      el.style.outline = ''
    })

    if (hoveredVarId) {
      const el = doc.querySelector(`[data-vl-var="${hoveredVarId}"]`)
      if (el) el.style.outline = '2px solid #dc3545'
    }
  }, [hoveredVarId, editorMode])

  // ─────────────────────────────────────────────────────────────────────────
  // Handlers
  // ─────────────────────────────────────────────────────────────────────────

  const handleSave = async () => {
    setSaving(true)
    setError(null)
    try {
      const payload = { name, raw_source_html: rawSourceHtml }
      if (!originalRawSourceHtml && rawSourceHtml) {
        payload.original_raw_source_html = rawSourceHtml
      }
      const data = await apiFetch(`/api/clients/${clientId}/email_templates/${id}`, {
        method: 'PATCH',
        body: JSON.stringify({ email_template: payload }),
      })
      setTemplate((prev) => ({ ...prev, name, raw_source_html: rawSourceHtml }))
      if (data.original_raw_source_html) {
        setOriginalRawSourceHtml(data.original_raw_source_html)
      }
    } catch (err) {
      setError(err.message)
    } finally {
      setSaving(false)
    }
  }

  const handleReset = async (mode) => {
    const message = mode === 'blank'
      ? 'Reset to blank? This will delete all HTML, variables, and sections.'
      : 'Reset to original HTML? This will delete all variables and sections.'
    if (!window.confirm(message)) return
    setResetting(true)
    setError(null)
    try {
      const data = await apiFetch(`/api/clients/${clientId}/email_templates/${id}/reset`, {
        method: 'POST',
        body: JSON.stringify({ mode }),
      })
      setRawSourceHtml(data.raw_source_html || '')
      setOriginalRawSourceHtml(data.original_raw_source_html || null)
      setSections(data.sections || [])
      setExpandedSection(null)
      setHighlightedSectionId(null)
      setTemplate((prev) => ({ ...prev, raw_source_html: data.raw_source_html }))
    } catch (err) {
      setError(err.message)
    } finally {
      setResetting(false)
    }
  }

  const handleAddSection = async ({ elementSelector = null, parentId = null } = {}) => {
    try {
      const data = await apiFetch(`/api/clients/${clientId}/email_templates/${id}/sections`, {
        method: 'POST',
        body: JSON.stringify({ section: { element_selector: elementSelector, parent_id: parentId } }),
      })
      setSections((prev) => [...prev, { ...data, variables: [] }])
      if (!parentId) {
        if (editorMode === 'section') {
          setHighlightedSectionId(data.id)
        } else {
          setExpandedSection(data.id)
        }
      }
    } catch (err) {
      setError(err.message)
    }
  }

  const handleDeleteSection = async (sectionId) => {
    const section = sections.find((s) => s.id === sectionId)
    const subsections = sections.filter((s) => s.parent_id === sectionId)
    let updatedHtml = rawSourceHtml

    // Clean up variables from this section
    for (const v of (section?.variables || [])) {
      updatedHtml = v.variable_type === 'image'
        ? removeImageMarker(updatedHtml, v.id)
        : removeTextPlaceholder(updatedHtml, v.id, v.default_value)
    }

    // Clean up variables from subsections (server cascades delete, but HTML needs cleanup)
    for (const sub of subsections) {
      for (const v of (sub.variables || [])) {
        updatedHtml = v.variable_type === 'image'
          ? removeImageMarker(updatedHtml, v.id)
          : removeTextPlaceholder(updatedHtml, v.id, v.default_value)
      }
    }

    try {
      await apiFetch(`/api/clients/${clientId}/email_templates/${id}/sections/${sectionId}`, {
        method: 'DELETE',
        body: JSON.stringify({ raw_source_html: updatedHtml }),
      })
      setRawSourceHtml(updatedHtml)
      setSections((prev) => {
        const subsectionIds = subsections.map((s) => s.id)
        const filtered = prev.filter((s) => s.id !== sectionId && !subsectionIds.includes(s.id))
        // Re-number top-level sections only
        let pos = 0
        return filtered.map((s) => (!s.parent_id ? { ...s, position: ++pos } : s))
      })
      if (expandedSection === sectionId) setExpandedSection(null)
      if (highlightedSectionId === sectionId) setHighlightedSectionId(null)
      if (highlightedSubsectionId === sectionId || subsections.some((s) => s.id === highlightedSubsectionId)) {
        setHighlightedSubsectionId(null)
      }
    } catch (err) {
      setError(err.message)
    }
  }

  const handleCreateVariable = useCallback(
    async ({ slotRole, wordCount, imageLocation } = {}) => {
      console.log('[createVar] called', { expandedSection, popover, rawSourceHtmlLen: rawSourceHtml?.length, slotRole, wordCount })
      if (!expandedSection) {
        console.log('[createVar] BAIL: no expanded section')
        return
      }

      const varId = crypto.randomUUID()
      let defaultValue, updatedHtml

      if (popover.type === 'image') {
        console.log('[createVar] image type, imgSrc:', popover.imgSrc, 'assetId:', popover.assetId, 'ratio:', popover.standardizedRatio)
        const result = insertImageMarker(rawSourceHtml, popover.imgSrc, varId, popover.standardizedRatio)
        defaultValue = result.defaultValue
        updatedHtml = result.updatedHtml
      } else {
        const selectedText = popover.selectedText
        console.log('[createVar] text type, selectedText:', JSON.stringify(selectedText))
        if (!selectedText) {
          console.log('[createVar] BAIL: no selectedText in popover')
          setPopover(null)
          return
        }
        const result = insertTextPlaceholder(rawSourceHtml, selectedText, varId, popover.occurrenceIndex)
        console.log('[createVar] insertTextPlaceholder result:', result ? 'found match' : 'null (no match in raw HTML)')
        if (!result) {
          setPopover(null)
          return
        }
        defaultValue = result.defaultValue
        updatedHtml = result.updatedHtml
      }

      console.log('[createVar] sending API request, varId:', varId, 'defaultValue:', defaultValue)
      try {
        const data = await apiFetch(
          `/api/clients/${clientId}/email_templates/${id}/sections/${expandedSection}/variables`,
          {
            method: 'POST',
            body: JSON.stringify({
              variable: {
                id: varId,
                name: defaultValue,
                variable_type: popover.type,
                default_value: defaultValue,
                slot_role: slotRole || undefined,
                word_count: wordCount || undefined,
                image_location: imageLocation || undefined,
                asset_id: popover.assetId || undefined,
                standardized_ratio: popover.standardizedRatio || undefined,
              },
              raw_source_html: updatedHtml,
            }),
          }
        )
        console.log('[createVar] API success, response:', data)

        setRawSourceHtml(updatedHtml)
        setSections((prev) =>
          prev.map((s) =>
            s.id === expandedSection
              ? { ...s, variables: [...(s.variables || []), data] }
              : s
          )
        )
      } catch (err) {
        console.error('[createVar] API error:', err)
        setError(err.message)
      }

      setPopover(null)
    },
    [clientId, id, expandedSection, popover, rawSourceHtml]
  )

  const handleDeleteVariable = useCallback(
    async (sectionId, varId) => {
      const section = sections.find((s) => s.id === sectionId)
      const variable = section?.variables?.find((v) => v.id === varId)
      if (!variable) return

      let updatedHtml
      if (variable.variable_type === 'image') {
        updatedHtml = removeImageMarker(rawSourceHtml, varId)
      } else {
        updatedHtml = removeTextPlaceholder(rawSourceHtml, varId, variable.default_value)
      }

      try {
        await apiFetch(
          `/api/clients/${clientId}/email_templates/${id}/sections/${sectionId}/variables/${varId}`,
          {
            method: 'DELETE',
            body: JSON.stringify({ raw_source_html: updatedHtml }),
          }
        )

        setRawSourceHtml(updatedHtml)
        setSections((prev) =>
          prev.map((s) =>
            s.id === sectionId
              ? { ...s, variables: (s.variables || []).filter((v) => v.id !== varId) }
              : s
          )
        )
      } catch (err) {
        setError(err.message)
      }
    },
    [clientId, id, rawSourceHtml, sections]
  )

  const handleUpdateVariable = useCallback(
    async () => {
      if (!editingVar) return
      const { sectionId, varId, slotRole, wordCount, defaultValue, imageLocation } = editingVar
      try {
        const data = await apiFetch(
          `/api/clients/${clientId}/email_templates/${id}/sections/${sectionId}/variables/${varId}`,
          {
            method: 'PATCH',
            body: JSON.stringify({
              variable: {
                slot_role: slotRole || null,
                word_count: wordCount || null,
                default_value: defaultValue,
                image_location: imageLocation || null,
              },
            }),
          }
        )
        setSections((prev) =>
          prev.map((s) =>
            s.id === sectionId
              ? { ...s, variables: (s.variables || []).map((v) => (v.id === varId ? { ...v, ...data } : v)) }
              : s
          )
        )
        setEditingVar(null)
      } catch (err) {
        setError(err.message)
      }
    },
    [clientId, id, editingVar]
  )

  const cancelPopover = useCallback(() => setPopover(null), [])

  // ── Section name editing ─────────────────────────────────────────────────

  const handleSaveSectionName = async () => {
    if (!editingSectionName) return
    const { sectionId, value } = editingSectionName
    setEditingSectionName(null)
    const trimmed = value.trim()
    if (!trimmed) return
    try {
      const data = await apiFetch(
        `/api/clients/${clientId}/email_templates/${id}/sections/${sectionId}`,
        {
          method: 'PATCH',
          body: JSON.stringify({ section: { name: trimmed } }),
        }
      )
      setSections((prev) => prev.map((s) => (s.id === sectionId ? { ...s, ...data } : s)))
    } catch (err) {
      setError(err.message)
    }
  }

  // ── Section editor overlay handlers ──────────────────────────────────────

  const handleOverlayMove = (e) => {
    const overlay = overlayRef.current
    const iframe = iframeRef.current
    if (!overlay || !iframe) return

    const rect = overlay.getBoundingClientRect()
    const iframeX = (e.clientX - rect.left) / sectionScale
    const iframeY = (e.clientY - rect.top) / sectionScale

    const doc = iframe.contentDocument
    if (!doc) return

    const el = doc.elementFromPoint(iframeX, iframeY)
    const candidates = sectionCandidatesRef.current

    if (highlightedSectionId) {
      // ── Subsection hover mode ──────────────────────────────────────────
      candidates.forEach((c) => c.removeAttribute('data-vl-hover'))
      setHoveredCandidateIndex(null)

      // Clear previous sub-hover
      if (hoveredSubElRef.current) {
        hoveredSubElRef.current.removeAttribute('data-vl-sub-hover')
      }

      const activeSection = sectionsRef.current.find((s) => s.id === highlightedSectionId)
      const sectionIdx = activeSection?.element_selector != null ? parseInt(activeSection.element_selector, 10) : -1
      const sectionCandidate = sectionIdx >= 0 ? candidates[sectionIdx] : null

      if (sectionCandidate && el && (sectionCandidate === el || sectionCandidate.contains(el))) {
        const subEl = findSubsectionTarget(el, sectionCandidate)
        if (subEl && subEl !== sectionCandidate) {
          subEl.setAttribute('data-vl-sub-hover', '1')
          hoveredSubElRef.current = subEl
          const selector = getCssSelector(subEl, doc)
          hoveredSubSelectorRef.current = selector
          setHoveredSubSelector(selector)
        } else {
          hoveredSubElRef.current = null
          hoveredSubSelectorRef.current = null
          setHoveredSubSelector(null)
        }
      } else {
        hoveredSubElRef.current = null
        hoveredSubSelectorRef.current = null
        setHoveredSubSelector(null)
      }
    } else {
      // ── Top-level section hover mode ───────────────────────────────────
      if (hoveredSubElRef.current) {
        hoveredSubElRef.current.removeAttribute('data-vl-sub-hover')
        hoveredSubElRef.current = null
        hoveredSubSelectorRef.current = null
        setHoveredSubSelector(null)
      }

      candidates.forEach((c) => c.removeAttribute('data-vl-hover'))

      if (!el) {
        setHoveredCandidateIndex(null)
        return
      }

      const idx = candidates.findIndex((c) => c === el || c.contains(el))
      if (idx >= 0) {
        candidates[idx].setAttribute('data-vl-hover', '1')
        setHoveredCandidateIndex(idx)
      } else {
        setHoveredCandidateIndex(null)
      }
    }
  }

  const handleOverlayLeave = () => {
    sectionCandidatesRef.current.forEach((c) => c.removeAttribute('data-vl-hover'))
    setHoveredCandidateIndex(null)
    if (hoveredSubElRef.current) {
      hoveredSubElRef.current.removeAttribute('data-vl-sub-hover')
      hoveredSubElRef.current = null
      hoveredSubSelectorRef.current = null
      setHoveredSubSelector(null)
    }
  }

  // Single-click: if hovering a defined section, select it in left panel
  const handleOverlayClick = () => {
    if (highlightedSectionId) return // single-click does nothing in subsection mode
    if (hoveredCandidateIndex === null) return
    const section = sections.find((s) => !s.parent_id && s.element_selector === String(hoveredCandidateIndex))
    if (section) {
      setHighlightedSectionId((prev) => (prev === section.id ? null : section.id))
    }
  }

  // Double-click: create subsection (if zoomed in) or top-level section
  const handleOverlayDblClick = async () => {
    if (highlightedSectionId) {
      // ── Subsection creation ──────────────────────────────────────────
      const selector = hoveredSubSelectorRef.current
      if (!selector) return
      const existing = sections.find(
        (s) => s.parent_id === highlightedSectionId && s.element_selector === selector
      )
      if (existing) return // already defined
      await handleAddSection({ elementSelector: selector, parentId: highlightedSectionId })
      return
    }

    // ── Top-level section creation ────────────────────────────────────
    if (hoveredCandidateIndex === null) return
    const existing = sections.find((s) => !s.parent_id && s.element_selector === String(hoveredCandidateIndex))
    if (existing) {
      setHighlightedSectionId(existing.id)
      return
    }
    await handleAddSection({ elementSelector: String(hoveredCandidateIndex) })
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Render
  // ─────────────────────────────────────────────────────────────────────────

  if (loading) {
    return (
      <div className="p-4">
        <div className="spinner-border spinner-border-sm" role="status" />
      </div>
    )
  }

  if (!template) {
    return <div className="p-4 text-danger">Template not found.</div>
  }

  // Computed iframe styles based on editor mode
  const iframeStyle = editorMode === 'section'
    ? {
        width: IFRAME_NATURAL_WIDTH,
        height: previewNaturalHeight,
        border: 'none',
        transform: `scale(${sectionScale})`,
        transformOrigin: 'top left',
        pointerEvents: 'none',
        display: 'block',
      }
    : varZoom
    ? {
        width: IFRAME_NATURAL_WIDTH,
        height: varZoom.naturalHeight,
        border: 'none',
        transform: `scale(${varZoom.scale})`,
        transformOrigin: 'top left',
        display: 'block',
      }
    : {
        width: '100%',
        height: 'auto',
        minHeight: 'calc(100vh - 140px)',
        border: 'none',
      }

  return (
    <div className="d-flex h-100">
      {/* ── Left sidebar ─────────────────────────────────────────────── */}
      <div
        className="border-end bg-light d-flex flex-column flex-shrink-0"
        style={{ width: 280 }}
      >
        <div className="p-3 border-bottom d-flex align-items-center gap-2">
          <button
            className="btn btn-sm btn-link text-dark p-0"
            onClick={() => navigate(`/clients/${clientId}/templates`)}
          >
            <i className="bi bi-arrow-left"></i>
          </button>
          <h6 className="mb-0 text-truncate flex-grow-1">{name}</h6>
        </div>

        {/* Subtabs */}
        <div className="d-flex border-bottom">
          <button
            className={`btn btn-sm flex-fill rounded-0 border-0 py-2 ${activeTab === 'sections' ? 'fw-semibold border-bottom border-2 border-danger' : 'text-muted'}`}
            onClick={() => setActiveTab('sections')}
          >
            Sections
          </button>
          <button
            className={`btn btn-sm flex-fill rounded-0 border-0 py-2 ${activeTab === 'details' ? 'fw-semibold border-bottom border-2 border-danger' : 'text-muted'}`}
            onClick={() => setActiveTab('details')}
          >
            Details
          </button>
        </div>

        <div className="p-3 flex-grow-1 overflow-auto">
          {/* ── Details tab ─────────────────────────────────────────── */}
          {activeTab === 'details' && (
            <>
              <div className="mb-3">
                <label className="form-label small fw-semibold">Template Name</label>
                <input
                  type="text"
                  className="form-control form-control-sm"
                  value={name}
                  onChange={(e) => setName(e.target.value)}
                />
              </div>

              <div className="mb-3">
                <label className="form-label small fw-semibold">Source HTML</label>
                {originalRawSourceHtml ? (
                  <textarea
                    className="form-control form-control-sm font-monospace bg-light"
                    rows={10}
                    value={originalRawSourceHtml}
                    readOnly
                  />
                ) : (
                  <textarea
                    className="form-control form-control-sm font-monospace"
                    rows={10}
                    value={rawSourceHtml}
                    onChange={(e) => setRawSourceHtml(e.target.value)}
                    placeholder="Paste your email HTML here..."
                  />
                )}
              </div>

              {originalRawSourceHtml && (
                <div className="d-flex gap-2">
                  <button
                    className="btn btn-sm btn-outline-danger flex-fill"
                    onClick={() => handleReset('original')}
                    disabled={resetting}
                  >
                    {resetting ? 'Resetting...' : 'Reset to Original'}
                  </button>
                  <button
                    className="btn btn-sm btn-outline-secondary flex-fill"
                    onClick={() => handleReset('blank')}
                    disabled={resetting}
                  >
                    {resetting ? 'Resetting...' : 'Reset to Blank'}
                  </button>
                </div>
              )}
            </>
          )}

          {/* ── Sections tab ────────────────────────────────────────── */}
          {activeTab === 'sections' && (
            <>
              <div className="d-flex align-items-center justify-content-between mb-2">
                <span className="small fw-semibold text-muted text-uppercase">Sections</span>
                <button
                  className="btn btn-sm btn-outline-secondary d-flex align-items-center gap-1"
                  onClick={() => handleAddSection({})}
                  title="Add section"
                >
                  <i className="bi bi-plus"></i>
                </button>
              </div>

              {/* Mode-specific hint */}
              {editorMode === 'section' ? (
                <p className="text-muted small mb-3">
                  Hover over the email preview to highlight rows. Double-click a row to define it as a section.
                </p>
              ) : (
                <p className="text-muted small mb-3">
                  Select text or click an image in the preview. The right section will be selected automatically.
                </p>
              )}

              {topLevelSections.length === 0 && (
                <div className="text-muted small text-center py-3">
                  <i className="bi bi-layers d-block fs-4 mb-2"></i>
                  No sections yet.
                </div>
              )}

              {/* ── Section editor mode: sections list ──────────────── */}
              {editorMode === 'section' && topLevelSections.map((section) => {
                const isHighlighted = highlightedSectionId === section.id
                const isDefined = section.element_selector != null
                const isEditingName = editingSectionName?.sectionId === section.id
                const previewText = isDefined
                  ? candidatePreviewTexts[parseInt(section.element_selector, 10)] || ''
                  : ''
                const displayName = section.name || `Section ${section.position}`
                const subs = sections.filter((s) => s.parent_id === section.id)
                return (
                  <div key={section.id} className="mb-2">
                    <div
                      className={`border rounded bg-white d-flex align-items-center px-3 py-2 ${isHighlighted ? 'border-danger' : ''}`}
                      style={{ cursor: 'pointer', minWidth: 0 }}
                      onClick={() =>
                        setHighlightedSectionId((prev) => (prev === section.id ? null : section.id))
                      }
                    >
                      {/* Chevron */}
                      <i className={`bi me-2 small flex-shrink-0 ${isHighlighted ? 'bi-chevron-down' : subs.length > 0 ? 'bi-chevron-right' : 'bi-dash'}`}></i>

                      {/* Name + preview */}
                      <div className="flex-grow-1 me-2" style={{ minWidth: 0 }}>
                        {isEditingName ? (
                          <input
                            autoFocus
                            className="form-control form-control-sm border-0 p-0 bg-transparent fw-medium"
                            style={{ fontSize: '0.875rem' }}
                            value={editingSectionName.value}
                            onChange={(e) =>
                              setEditingSectionName((prev) => ({ ...prev, value: e.target.value }))
                            }
                            onBlur={handleSaveSectionName}
                            onKeyDown={(e) => {
                              if (e.key === 'Enter') handleSaveSectionName()
                              if (e.key === 'Escape') setEditingSectionName(null)
                            }}
                            onClick={(e) => e.stopPropagation()}
                          />
                        ) : (
                          <div
                            className="small fw-medium text-truncate"
                            title="Click to rename"
                            onClick={(e) => {
                              e.stopPropagation()
                              setEditingSectionName({ sectionId: section.id, value: displayName })
                            }}
                          >
                            {displayName}
                          </div>
                        )}
                        {!isEditingName && previewText && (
                          <div className="text-truncate" style={{ fontSize: '0.7rem', color: '#adb5bd' }}>
                            {previewText}
                          </div>
                        )}
                      </div>

                      {isDefined ? (
                        <span className="badge bg-success-subtle text-success border border-success-subtle small me-2 flex-shrink-0">
                          Defined
                        </span>
                      ) : (
                        <span className="badge bg-secondary-subtle text-secondary border border-secondary-subtle small me-2 flex-shrink-0">
                          No area
                        </span>
                      )}
                      <button
                        className="btn btn-sm btn-link text-danger p-0 flex-shrink-0"
                        onClick={(e) => {
                          e.stopPropagation()
                          handleDeleteSection(section.id)
                        }}
                        title="Remove section"
                      >
                        <i className="bi bi-trash small"></i>
                      </button>
                    </div>

                    {/* Subsections */}
                    {subs.length > 0 && (
                      <div className="ms-3 mt-1">
                        {subs.map((sub) => {
                          const subDisplay = sub.name || `${section.position}${String.fromCharCode(64 + sub.position)}`
                          const subPreview = subsectionPreviewTexts[sub.id] || ''
                          const subDefined = sub.element_selector != null
                          const isEditingSubName = editingSectionName?.sectionId === sub.id
                          return (
                            <div
                              key={sub.id}
                              className={`mb-1 border rounded bg-white d-flex align-items-center px-2 py-1 ${highlightedSubsectionId === sub.id ? 'border-danger' : ''}`}
                              style={{ minWidth: 0, cursor: 'pointer', borderColor: highlightedSubsectionId === sub.id ? undefined : subDefined ? 'rgba(111,66,193,0.35)' : undefined }}
                              onClick={() => {
                                const next = highlightedSubsectionId === sub.id ? null : sub.id
                                setHighlightedSubsectionId(next)
                                if (next) setHighlightedSectionId(section.id)
                              }}
                            >
                              <i className="bi bi-diagram-2 me-2 flex-shrink-0" style={{ fontSize: '0.7rem', color: '#6f42c1' }}></i>
                              <div className="flex-grow-1 me-1" style={{ minWidth: 0 }}>
                                {isEditingSubName ? (
                                  <input
                                    autoFocus
                                    className="form-control form-control-sm border-0 p-0 bg-transparent fw-medium"
                                    style={{ fontSize: '0.8rem' }}
                                    value={editingSectionName.value}
                                    onChange={(e) =>
                                      setEditingSectionName((prev) => ({ ...prev, value: e.target.value }))
                                    }
                                    onBlur={handleSaveSectionName}
                                    onKeyDown={(e) => {
                                      if (e.key === 'Enter') handleSaveSectionName()
                                      if (e.key === 'Escape') setEditingSectionName(null)
                                    }}
                                    onClick={(e) => e.stopPropagation()}
                                  />
                                ) : (
                                  <div
                                    className="fw-medium text-truncate"
                                    style={{ fontSize: '0.8rem', cursor: 'text' }}
                                    title="Click to rename"
                                    onClick={(e) => { e.stopPropagation(); setEditingSectionName({ sectionId: sub.id, value: subDisplay }) }}
                                  >
                                    {subDisplay}
                                  </div>
                                )}
                                {!isEditingSubName && subPreview && (
                                  <div className="text-truncate" style={{ fontSize: '0.68rem', color: '#adb5bd' }}>
                                    {subPreview}
                                  </div>
                                )}
                              </div>
                              <button
                                className="btn btn-link text-danger p-0 flex-shrink-0"
                                style={{ fontSize: '0.7rem' }}
                                onClick={(e) => { e.stopPropagation(); handleDeleteSection(sub.id) }}
                                title="Remove subsection"
                              >
                                <i className="bi bi-trash"></i>
                              </button>
                            </div>
                          )
                        })}
                      </div>
                    )}

                    {/* Hint when zoomed into a defined section */}
                    {isHighlighted && isDefined && (
                      <div className="ms-3 mt-1 text-muted" style={{ fontSize: '0.68rem' }}>
                        Hover elements in the preview · double-click to add a subsection
                      </div>
                    )}
                  </div>
                )
              })}

              {/* ── Variable editor mode: expandable sections with vars ─ */}
              {editorMode === 'variable' && topLevelSections.map((section) => {
                const previewText = section.element_selector != null
                  ? candidatePreviewTexts[parseInt(section.element_selector, 10)] || ''
                  : ''
                const displayName = section.name || `Section ${section.position}`
                return (
                <div key={section.id} className="mb-2 border rounded bg-white">
                  <div
                    className="d-flex align-items-center px-3 py-2"
                    style={{ cursor: 'pointer' }}
                    onClick={() =>
                      setExpandedSection(expandedSection === section.id ? null : section.id)
                    }
                  >
                    <i
                      className={`bi me-2 small flex-shrink-0 ${expandedSection === section.id ? 'bi-chevron-down' : 'bi-chevron-right'}`}
                    ></i>
                    <div className="flex-grow-1 me-2" style={{ minWidth: 0 }}>
                      <div className="small fw-medium text-truncate">
                        {displayName}
                      </div>
                      {previewText && (
                        <div className="text-truncate" style={{ fontSize: '0.7rem', color: '#adb5bd' }}>
                          {previewText}
                        </div>
                      )}
                    </div>
                    <button
                      className="btn btn-sm btn-link text-danger p-0 flex-shrink-0"
                      onClick={(e) => {
                        e.stopPropagation()
                        handleDeleteSection(section.id)
                      }}
                      title="Remove section"
                    >
                      <i className="bi bi-trash small"></i>
                    </button>
                  </div>

                  {expandedSection === section.id && (
                    <div className="px-3 pb-3 pt-1 border-top">
                      {popover && (
                        <div className="mb-3 pb-3 border-bottom">
                          <VariablePopover
                            variableType={popover.type}
                            selectedText={popover.selectedText}
                            initialWordCount={popover.wordCount ?? null}
                            onConfirm={handleCreateVariable}
                            onCancel={cancelPopover}
                          />
                        </div>
                      )}
                      {(!section.variables || section.variables.length === 0) ? (
                        <p className="text-muted small mb-0">
                          {popover ? null : 'Select text or click an image in the preview to create a variable.'}
                        </p>
                      ) : (
                        <ul className="list-unstyled mb-0">
                          {section.variables.map((v) => {
                            const isEditing = editingVar?.varId === v.id
                            return (
                              <li
                                key={v.id}
                                className="mb-2"
                                onMouseEnter={() => setHoveredVarId(v.id)}
                                onMouseLeave={() => setHoveredVarId(null)}
                              >
                                {isEditing ? (
                                  <div className="border rounded p-2 bg-white">
                                    <p className="small fw-semibold mb-2">Edit Variable</p>

                                    {v.variable_type === 'image' ? (
                                      <div className="mb-2">
                                        <label className="form-label small fw-semibold mb-1">Image Location</label>
                                        <select
                                          className="form-select form-select-sm"
                                          value={editingVar.imageLocation || ''}
                                          onChange={(e) => setEditingVar((prev) => ({ ...prev, imageLocation: e.target.value }))}
                                        >
                                          <option value="">Select location</option>
                                          {IMAGE_LOCATION_TYPES.map((l) => (
                                            <option key={l.value} value={l.value}>{l.label} — {l.description.slice(0, 35)}…</option>
                                          ))}
                                        </select>
                                      </div>
                                    ) : (
                                      <>
                                        <div className="mb-2">
                                          <label className="form-label small fw-semibold mb-1">
                                            Slot Role <span className="text-danger">*</span>
                                          </label>
                                          <select
                                            className="form-select form-select-sm"
                                            value={editingVar.slotRole || ''}
                                            onChange={(e) => setEditingVar((prev) => ({ ...prev, slotRole: e.target.value }))}
                                          >
                                            <option value="">Select role</option>
                                            {SLOT_ROLES.map((r) => (
                                              <option key={r.value} value={r.value}>{r.label} — {r.description.slice(0, 30)}…</option>
                                            ))}
                                          </select>
                                        </div>
                                        <div className="mb-2">
                                          <label className="form-label small fw-semibold mb-1">
                                            Word Count <span className="text-danger">*</span>
                                          </label>
                                          <input
                                            type="number"
                                            className="form-control form-control-sm"
                                            value={editingVar.wordCount ?? ''}
                                            min={1}
                                            onChange={(e) => setEditingVar((prev) => ({ ...prev, wordCount: e.target.value }))}
                                            style={{ width: 90 }}
                                          />
                                        </div>
                                      </>
                                    )}

                                    <div className="mb-2">
                                      <label className="form-label small fw-semibold mb-1">
                                        {v.variable_type === 'image' ? 'Image URL' : 'Original Text'}
                                      </label>
                                      <input
                                        type="text"
                                        className="form-control form-control-sm"
                                        value={editingVar.defaultValue ?? ''}
                                        onChange={(e) => setEditingVar((prev) => ({ ...prev, defaultValue: e.target.value }))}
                                      />
                                    </div>
                                    <div className="d-flex gap-2">
                                      <button
                                        className="btn btn-sm btn-danger"
                                        onClick={handleUpdateVariable}
                                        disabled={v.variable_type !== 'image' && !editingVar.slotRole}
                                      >
                                        <i className="bi bi-check me-1"></i>Save
                                      </button>
                                      <button
                                        className="btn btn-sm btn-outline-secondary"
                                        onClick={() => setEditingVar(null)}
                                      >
                                        Cancel
                                      </button>
                                    </div>
                                  </div>
                                ) : (
                                  <div
                                    className="border rounded p-2 bg-white"
                                    style={{ cursor: 'pointer' }}
                                    onClick={() => setEditingVar({
                                      sectionId: section.id,
                                      varId: v.id,
                                      slotRole: v.slot_role || '',
                                      wordCount: v.word_count ?? '',
                                      defaultValue: v.default_value,
                                      imageLocation: v.image_location || '',
                                    })}
                                  >
                                    <div className="d-flex align-items-center gap-2 mb-1">
                                      {v.variable_type === 'image' ? (() => {
                                        const locObj = IMAGE_LOCATION_TYPES.find((l) => l.value === v.image_location)
                                        return (
                                          <span className="badge rounded-pill bg-light text-dark border small fw-normal">
                                            <i className="bi bi-image me-1"></i>
                                            {locObj ? locObj.label : 'No location'}
                                          </span>
                                        )
                                      })() : (() => {
                                        const roleObj = SLOT_ROLES.find((r) => r.value === v.slot_role)
                                        return roleObj ? (
                                          <span className="badge rounded-pill bg-light text-dark border small fw-normal">
                                            {roleObj.label}
                                          </span>
                                        ) : (
                                          <span className="badge rounded-pill bg-light text-muted border small fw-normal">
                                            <i className="bi bi-type me-1"></i>
                                            No role
                                          </span>
                                        )
                                      })()}
                                      <span className="ms-auto text-muted small">
                                        {v.variable_type !== 'image' && v.word_count != null
                                          ? `${v.word_count} Words`
                                          : null}
                                      </span>
                                      <button
                                        className="btn btn-link text-danger p-0"
                                        style={{ fontSize: '0.75rem' }}
                                        onClick={(e) => { e.stopPropagation(); handleDeleteVariable(section.id, v.id) }}
                                        title="Delete variable"
                                      >
                                        <i className="bi bi-trash"></i>
                                      </button>
                                    </div>
                                    <div className="text-muted small text-truncate">
                                      &ldquo;{v.default_value}&rdquo;
                                    </div>
                                  </div>
                                )}
                              </li>
                            )
                          })}
                        </ul>
                      )}

                      {/* Subsections list */}
                      {(() => {
                        const subs = sections.filter((s) => s.parent_id === section.id)
                        if (!subs.length) return null
                        return (
                          <div className="mt-2 pt-2 border-top">
                            <div className="small text-muted mb-1 fw-semibold">Subsections</div>
                            {subs.map((sub) => {
                              const subDisplay = sub.name || `${section.position}${String.fromCharCode(64 + sub.position)}`
                              const subPreview = subsectionPreviewTexts[sub.id] || ''
                              const isActiveSubsection = highlightedSubsectionId === sub.id
                              return (
                                <div
                                  key={sub.id}
                                  className="d-flex align-items-center px-2 py-1 rounded mb-1"
                                  style={{
                                    background: isActiveSubsection ? 'rgba(111,66,193,0.12)' : 'rgba(111,66,193,0.05)',
                                    border: isActiveSubsection ? '1px solid #6f42c1' : '1px solid rgba(111,66,193,0.2)',
                                    cursor: 'pointer',
                                  }}
                                  onClick={() => setHighlightedSubsectionId(isActiveSubsection ? null : sub.id)}
                                >
                                  <i className="bi bi-diagram-2 me-2 flex-shrink-0" style={{ fontSize: '0.7rem', color: '#6f42c1' }}></i>
                                  <div style={{ minWidth: 0 }}>
                                    <div className="small fw-medium text-truncate">{subDisplay}</div>
                                    {subPreview && (
                                      <div className="text-truncate" style={{ fontSize: '0.68rem', color: '#adb5bd' }}>{subPreview}</div>
                                    )}
                                  </div>
                                </div>
                              )
                            })}
                          </div>
                        )
                      })()}
                    </div>
                  )}
                </div>
              )})}
            </>
          )}
        </div>

        <div className="p-3 border-top">
          {error && <div className="alert alert-danger py-1 px-2 small">{error}</div>}
          <button
            className="btn btn-danger btn-sm w-100"
            onClick={handleSave}
            disabled={saving}
          >
            {saving ? 'Saving...' : 'Save Template'}
          </button>
        </div>
      </div>

      {/* ── Right panel: preview ──────────────────────────────────────────── */}
      <div className="flex-grow-1 d-flex flex-column overflow-hidden" ref={previewPanelRef}>
        {/* Header with mode toggle */}
        <div className="d-flex align-items-center gap-3 px-3 py-2 border-bottom bg-white flex-shrink-0">
          <span className="fw-semibold">Template Preview</span>

          <div className="btn-group btn-group-sm" role="group">
            <button
              className={`btn ${editorMode === 'section' ? 'btn-dark' : 'btn-outline-secondary'}`}
              onClick={() => setEditorMode('section')}
            >
              Section Editor
            </button>
            <button
              className={`btn ${editorMode === 'variable' ? 'btn-dark' : 'btn-outline-secondary'}`}
              onClick={() => setEditorMode('variable')}
            >
              Variable Editor
            </button>
          </div>

          <small className="text-muted ms-auto">
            {editorMode === 'section'
              ? highlightedSectionId
                ? hoveredSubSelector
                  ? sections.find((s) => s.parent_id === highlightedSectionId && s.element_selector === hoveredSubSelector)
                    ? 'Subsection already defined'
                    : 'Double-click to add as subsection'
                  : 'Hover over any element · double-click to add a subsection'
                : hoveredCandidateIndex !== null
                  ? sections.find((s) => !s.parent_id && s.element_selector === String(hoveredCandidateIndex))
                    ? 'Section already defined — click to select'
                    : 'Double-click to define this as a section'
                  : 'Hover to highlight · double-click to define a section'
              : 'Select text or click an image to create a variable'
            }
          </small>
        </div>

        {/* Preview content */}
        <div
          ref={scrollablePanelRef}
          className={`flex-grow-1 overflow-auto p-3 ${(editorMode === 'section' || varZoom) ? 'd-flex justify-content-center align-items-start' : ''}`}
        >
          {rawSourceHtml ? (
            <div
              style={editorMode === 'section'
                ? {
                    position: 'relative',
                    width: IFRAME_NATURAL_WIDTH * sectionScale,
                    height: previewNaturalHeight * sectionScale,
                    flexShrink: 0,
                    transition: 'width 0.35s ease, height 0.35s ease',
                  }
                : varZoom
                ? {
                    position: 'relative',
                    width: IFRAME_NATURAL_WIDTH * varZoom.scale,
                    height: varZoom.naturalHeight * varZoom.scale,
                    flexShrink: 0,
                    transition: 'width 0.35s ease, height 0.35s ease',
                  }
                : {
                    maxWidth: IFRAME_NATURAL_WIDTH,
                    margin: '0 auto',
                    background: 'white',
                    boxShadow: '0 1px 4px rgba(0,0,0,0.12)',
                  }
              }
            >
              <iframe
                ref={iframeRef}
                title="Template Preview"
                style={{
                  ...iframeStyle,
                  ...((editorMode === 'section' || varZoom) ? { transition: 'transform 0.35s ease' } : {}),
                }}
                sandbox="allow-same-origin"
              />
              {editorMode === 'section' && (
                <div
                  ref={overlayRef}
                  style={{ position: 'absolute', inset: 0, cursor: 'crosshair', zIndex: 1 }}
                  onMouseMove={handleOverlayMove}
                  onMouseLeave={handleOverlayLeave}
                  onClick={handleOverlayClick}
                  onDoubleClick={handleOverlayDblClick}
                />
              )}
            </div>
          ) : (
            <div className="text-center text-muted py-5">
              <i className="bi bi-code-square fs-1 d-block mb-3"></i>
              <p>Paste HTML source in the sidebar to see a preview.</p>
            </div>
          )}
        </div>
      </div>
    </div>
  )
}
