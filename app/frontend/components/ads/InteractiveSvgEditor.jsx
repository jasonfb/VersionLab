import React, { useState, useEffect, useRef, useCallback } from 'react'
import { createPortal } from 'react-dom'

// Maps text-anchor SVG attribute to alignment label
const ANCHOR_TO_ALIGN = { start: 'left', middle: 'center', end: 'right' }
const ALIGN_TO_ANCHOR = { left: 'start', center: 'middle', right: 'end' }

// Converts client (screen) coordinates to SVG coordinate space
function screenToSvg(svg, clientX, clientY) {
  const pt = svg.createSVGPoint()
  pt.x = clientX
  pt.y = clientY
  return pt.matrixTransform(svg.getScreenCTM().inverse())
}

// Read a style property from an SVG element (attribute or computed)
function readSvgStyle(el, attr, fallback = '') {
  return el.getAttribute(attr) || window.getComputedStyle(el)[attr] || fallback
}

// Get the dominant fill color from an element or its first tspan
function readFill(el) {
  const fill = el.getAttribute('fill') || el.style.fill
  if (fill && fill !== 'none') return normalizeColor(fill)
  const tspan = el.querySelector('tspan')
  if (tspan) {
    const tf = tspan.getAttribute('fill') || tspan.style.fill
    if (tf && tf !== 'none') return normalizeColor(tf)
  }
  return '#000000'
}

// Best-effort: convert any color string to a #rrggbb hex value for color inputs
function normalizeColor(color) {
  if (!color) return '#000000'
  if (/^#[0-9a-f]{6}$/i.test(color)) return color
  if (/^#[0-9a-f]{3}$/i.test(color)) {
    const [, r, g, b] = color.match(/^#([0-9a-f])([0-9a-f])([0-9a-f])$/i)
    return `#${r}${r}${g}${g}${b}${b}`
  }
  // Use a temporary element for browser color parsing
  const tmp = document.createElement('div')
  tmp.style.color = color
  document.body.appendChild(tmp)
  const computed = window.getComputedStyle(tmp).color
  document.body.removeChild(tmp)
  const m = computed.match(/\d+/g)
  if (!m || m.length < 3) return '#000000'
  return '#' + m.slice(0, 3).map((n) => parseInt(n).toString(16).padStart(2, '0')).join('')
}

// Extract bounding rect from a clipPath element by parsing its path/rect children
function getClipBounds(svg, clipPathRef) {
  // clipPathRef is like "url(#clip-0)"
  const match = clipPathRef?.match(/url\(#(.+?)\)/)
  if (!match) return null
  const clipEl = svg.querySelector(`#${match[1]}`)
  if (!clipEl) return null

  // Try <rect> children first
  const rect = clipEl.querySelector('rect')
  if (rect) {
    return {
      x: parseFloat(rect.getAttribute('x')) || 0,
      y: parseFloat(rect.getAttribute('y')) || 0,
      width: parseFloat(rect.getAttribute('width')) || 0,
      height: parseFloat(rect.getAttribute('height')) || 0,
    }
  }

  // Try <path> children — extract bounds from M/L commands (rectangular clip paths)
  const path = clipEl.querySelector('path')
  if (path) {
    const d = path.getAttribute('d') || ''
    const coords = d.match(/[\d.]+/g)?.map(Number)
    if (coords && coords.length >= 8) {
      const xs = [coords[0], coords[2], coords[4], coords[6]]
      const ys = [coords[1], coords[3], coords[5], coords[7]]
      const minX = Math.min(...xs), minY = Math.min(...ys)
      const maxX = Math.max(...xs), maxY = Math.max(...ys)
      return { x: minX, y: minY, width: maxX - minX, height: maxY - minY }
    }
  }

  return null
}

// ─── Main component ──────────────────────────────────────────────────────────

export default function InteractiveSvgEditor({ svgUrl, layers, classifiedLayers, onLayerOverridesChange, initialOverrides, transparentBackground }) {
  const containerRef = useRef(null)
  const dragRef = useRef(null) // current drag state (non-reactive for perf)
  const layerOffsets = useRef({}) // { layerId: { x, y } }
  const deletedIds = useRef(new Set()) // layers hidden by the user in this resize
  const outlineColorRef = useRef('#dd0000') // current outline stroke color (ref so buildInteractiveLayer can read it)
  const [outlineColor, setOutlineColor] = useState('red') // 'red' | 'white' — controls toggle button state
  const [showGrid, setShowGrid] = useState(false)
  const [hoveredId, setHoveredId] = useState(null)
  const [selectedId, setSelectedId] = useState(null)
  const [editingLayer, setEditingLayer] = useState(null)
  const [editorClickPos, setEditorClickPos] = useState(null) // { x, y } screen coords of dblclick
  const [ready, setReady] = useState(false)

  const buildInteractiveLayer = useCallback(() => {
    const svg = containerRef.current?.querySelector('svg')
    if (!svg) return

    // Ensure SVG is sized responsively
    svg.setAttribute('width', '100%')
    svg.removeAttribute('height') // let aspect ratio flow from viewBox

    // Remove old interactive overlay
    svg.querySelector('#vl-interactive')?.remove()

    const g = document.createElementNS('http://www.w3.org/2000/svg', 'g')
    g.id = 'vl-interactive'
    svg.appendChild(g)

    // Collect interactive elements: native <text> elements OR clipped groups (PDF-converted SVGs)
    const interactiveEls = []

    // Native SVG text elements
    Array.from(svg.querySelectorAll('text')).forEach((textEl, i) => {
      if (!textEl.getAttribute('id')) textEl.setAttribute('id', `vl-text-${i}`)
      interactiveEls.push({ el: textEl, layerId: textEl.getAttribute('id'), type: 'text' })
    })

    // Native SVG image elements (logos, icons, etc.)
    Array.from(svg.querySelectorAll('image')).forEach((imgEl, i) => {
      const layerId = imgEl.getAttribute('id') || `image_${i}`
      if (!imgEl.getAttribute('id')) imgEl.setAttribute('id', layerId)
      // Skip full-canvas background images
      const imgW = parseFloat(imgEl.getAttribute('width')) || 0
      const imgH = parseFloat(imgEl.getAttribute('height')) || 0
      const vb = svg.getAttribute('viewBox')?.split(/\s+/).map(Number)
      if (vb && vb.length === 4 && imgW >= vb[2] * 0.95 && imgH >= vb[3] * 0.95) return
      interactiveEls.push({ el: imgEl, layerId, type: 'image' })
    })

    // Clipped groups from PDF conversion (outer <g clip-path="..."> wrapping <g><use></g>)
    if (interactiveEls.filter(e => e.type === 'text').length === 0) {
      const topGroups = Array.from(svg.children).filter(
        (n) => n.tagName === 'g' && n.getAttribute('clip-path')
      )
      topGroups.forEach((groupEl, i) => {
        const layerId = `region_${i}`
        groupEl.setAttribute('data-vl-region', layerId)
        interactiveEls.push({ el: groupEl, layerId, type: 'region' })
      })
    }

    interactiveEls.forEach(({ el, layerId, type }) => {
      if (deletedIds.current.has(layerId)) return

      let bbox

      // For clipped regions (PDF-converted), use clip-path bounds instead of getBBox
      // because getBBox returns the full unclipped area (entire canvas)
      if (type === 'region') {
        const clipRef = el.getAttribute('clip-path')
        const clipBounds = getClipBounds(svg, clipRef)
        if (clipBounds && clipBounds.width > 0 && clipBounds.height > 0) {
          bbox = clipBounds
        }
      }

      if (!bbox) {
        try {
          bbox = el.getBBox()
        } catch (_) {
          return
        }
      }
      if (!bbox || (bbox.width === 0 && bbox.height === 0)) return

      const pad = 6
      const offset = layerOffsets.current[layerId] || { x: 0, y: 0 }
      const rx = bbox.x - pad + offset.x
      const ry = bbox.y - pad + offset.y
      const rw = bbox.width + pad * 2
      const rh = bbox.height + pad * 2

      const stroke = outlineColorRef.current
      const fillAlpha = stroke === '#ffffff' ? 'rgba(255,255,255,0.06)' : 'rgba(220,0,0,0.06)'

      const rect = document.createElementNS('http://www.w3.org/2000/svg', 'rect')
      rect.setAttribute('x', rx)
      rect.setAttribute('y', ry)
      rect.setAttribute('width', rw)
      rect.setAttribute('height', rh)
      rect.setAttribute('fill', fillAlpha)
      rect.setAttribute('stroke', stroke)
      rect.setAttribute('stroke-width', '4')
      rect.setAttribute('stroke-dasharray', '10,5')
      rect.setAttribute('rx', '4')
      rect.setAttribute('data-layer-id', layerId)
      rect.style.cursor = 'move'

      // Add role tooltip from classified layers
      const classifiedLayer = classifiedLayers?.find((l) => l.id === layerId)
      if (classifiedLayer?.role) {
        const title = document.createElementNS('http://www.w3.org/2000/svg', 'title')
        const content = classifiedLayer.content ? ` — ${classifiedLayer.content}` : ''
        title.textContent = `${classifiedLayer.role.toUpperCase()}${content}`
        rect.appendChild(title)
      }

      g.appendChild(rect)

      // Hover events
      rect.addEventListener('mouseenter', () => setHoveredId(layerId))
      rect.addEventListener('mouseleave', () => {
        if (!dragRef.current) setHoveredId(null)
      })

      // Drag start
      rect.addEventListener('mousedown', (e) => {
        e.preventDefault()
        e.stopPropagation()
        const svgPt = screenToSvg(svg, e.clientX, e.clientY)
        const cur = layerOffsets.current[layerId] || { x: 0, y: 0 }
        dragRef.current = {
          svg,
          textEl: el,
          rect,
          layerId,
          startSvgX: svgPt.x,
          startSvgY: svgPt.y,
          startOffsetX: cur.x,
          startOffsetY: cur.y,
          origBbox: bbox,
        }
      })

      // Double-click to edit (not for image layers — those are visual only)
      rect.addEventListener('dblclick', (e) => {
        e.preventDefault()
        e.stopPropagation()
        if (type === 'image') return // Images can be dragged but not text-edited
        setEditorClickPos({ x: e.clientX, y: e.clientY })
        if (type === 'text') {
          openEditor(el, layerId, svg)
        } else {
          // Region (PDF-converted): open full editor with layer data
          const layerData = layers?.find((l) => l.id === layerId) || {}

          // Estimate font size from region bounds if not already known.
          // Iteratively solve: find the font size where the text fits the region.
          let fontSize = layerData.font_size
          if (!fontSize) {
            const clipRef = el.getAttribute('clip-path')
            const clipBounds = getClipBounds(svg, clipRef)
            const regionH = clipBounds?.height || parseFloat(layerData.height) || 100
            const regionW = clipBounds?.width || parseFloat(layerData.width) || 400
            const content = layerData.content || ''
            const charCount = content.length || 1

            // Try sizes from large to small; first one that fits wins
            let bestSize = 12
            for (let size = Math.round(regionH * 0.8); size >= 10; size -= 1) {
              const charW = size * 0.55
              const charsPerLine = Math.max(1, Math.floor(regionW / charW))
              const lines = Math.ceil(charCount / charsPerLine)
              const totalH = lines * size * 1.3
              if (totalH <= regionH * 1.05) { // 5% tolerance
                bestSize = size
                break
              }
            }
            fontSize = String(bestSize)
          }

          // Detect bold/italic from font family name or overrides
          const fontName = (layerData.font_family || '').toLowerCase()
          const isBold = layerData.is_bold || /bold|black|heavy/i.test(fontName)
          const isItalic = layerData.is_italic || /italic|oblique/i.test(fontName)

          setEditingLayer({
            id: layerId,
            element: el,
            content: layerData.content || '',
            font_family: layerData.font_family || 'sans-serif',
            font_size: fontSize,
            is_bold: isBold,
            is_italic: isItalic,
            is_underline: false,
            fill: layerData.fill || layerData.color || '#FFFFFF',
            letter_spacing: '0',
            line_height: '1.3',
            text_align: layerData.text_align || layerData.align || 'left',
          })
        }
      })
    })

    setReady(true)
  }, [])

  // Load SVG
  useEffect(() => {
    if (!svgUrl) return
    setReady(false)
    deletedIds.current = new Set()
    // Seed offsets and deletions from persisted overrides
    if (initialOverrides) {
      Object.entries(initialOverrides).forEach(([id, ov]) => {
        if (ov.x_offset !== undefined || ov.y_offset !== undefined) {
          layerOffsets.current[id] = { x: ov.x_offset || 0, y: ov.y_offset || 0 }
        }
        if (ov.deleted) deletedIds.current.add(id)
      })
    }
    fetch(svgUrl, { credentials: 'same-origin' })
      .then((r) => r.text())
      .then((text) => {
        if (!containerRef.current) return
        containerRef.current.innerHTML = text
        // Apply persisted transforms before building interactive layer
        const svg = containerRef.current.querySelector('svg')
        // Make SVG background transparent so CSS background shows through
        if (svg && transparentBackground) {
          const firstRect = svg.querySelector(':scope > rect')
          if (firstRect) firstRect.setAttribute('fill', 'transparent')
          // Also handle PDF-converted SVGs with a background <use> element
          const bgUse = svg.querySelector(':scope > use')
          if (bgUse) bgUse.style.opacity = '0'
        }
        if (svg) {
          Object.entries(layerOffsets.current).forEach(([id, { x, y }]) => {
            const el = svg.getElementById(id)
            if (el && (x || y)) el.setAttribute('transform', `translate(${x}, ${y})`)
          })

          // Hide elements that were previously deleted
          deletedIds.current.forEach((id) => {
            const el = svg.getElementById(id) || svg.querySelector(`[data-vl-region="${id}"]`)
            if (el) el.style.display = 'none'
          })

          // Inject uploaded logo as an <image> element if not already in the SVG
          const uploadedLogo = layers?.find((l) => l.id === 'uploaded_logo' && l.type === 'image')
          if (uploadedLogo && !svg.getElementById('uploaded_logo')) {
            const imgEl = document.createElementNS('http://www.w3.org/2000/svg', 'image')
            imgEl.setAttribute('id', 'uploaded_logo')
            imgEl.setAttribute('href', uploadedLogo.href)
            imgEl.setAttribute('x', uploadedLogo.x || '50')
            imgEl.setAttribute('y', uploadedLogo.y || '850')
            imgEl.setAttribute('width', uploadedLogo.width || '250')
            imgEl.setAttribute('height', uploadedLogo.height || '100')
            imgEl.setAttribute('preserveAspectRatio', 'xMidYMid meet')
            const offset = layerOffsets.current['uploaded_logo']
            if (offset) imgEl.setAttribute('transform', `translate(${offset.x}, ${offset.y})`)
            svg.appendChild(imgEl)
          }
        }
        buildInteractiveLayer()
      })
      .catch(() => {})
  }, [svgUrl, buildInteractiveLayer])

  // Global mouse move + up for drag
  useEffect(() => {
    const onMove = (e) => {
      if (!dragRef.current) return
      const { svg, textEl, rect, layerId, startSvgX, startSvgY, startOffsetX, startOffsetY, origBbox } = dragRef.current
      const pt = screenToSvg(svg, e.clientX, e.clientY)
      const dx = pt.x - startSvgX
      const dy = pt.y - startSvgY
      const nx = startOffsetX + dx
      const ny = startOffsetY + dy

      // Move the text element via transform
      textEl.setAttribute('transform', `translate(${nx}, ${ny})`)

      // Move the overlay rect
      rect.setAttribute('x', origBbox.x - 4 + nx)
      rect.setAttribute('y', origBbox.y - 4 + ny)
    }

    const onUp = (e) => {
      if (!dragRef.current) return
      const { svg, textEl, layerId, startSvgX, startSvgY, startOffsetX, startOffsetY } = dragRef.current
      let nx = startOffsetX, ny = startOffsetY
      if (e.clientX !== undefined) {
        const pt = screenToSvg(svg, e.clientX, e.clientY)
        nx = startOffsetX + (pt.x - startSvgX)
        ny = startOffsetY + (pt.y - startSvgY)
      }
      const moved = Math.abs(nx - startOffsetX) > 3 || Math.abs(ny - startOffsetY) > 3
      layerOffsets.current[layerId] = { x: nx, y: ny }
      textEl.setAttribute('transform', `translate(${nx}, ${ny})`)
      dragRef.current = null
      setHoveredId(null)
      if (moved) {
        onLayerOverridesChange?.(layerId, { x_offset: nx, y_offset: ny })
      } else {
        // It was a click without meaningful drag — toggle selection
        setSelectedId((prev) => (prev === layerId ? null : layerId))
      }
    }

    window.addEventListener('mousemove', onMove)
    window.addEventListener('mouseup', onUp)
    return () => {
      window.removeEventListener('mousemove', onMove)
      window.removeEventListener('mouseup', onUp)
    }
  }, [onLayerOverridesChange])

  // Update overlay rect appearance when selection or outline color changes
  useEffect(() => {
    if (!ready) return
    const svg = containerRef.current?.querySelector('svg')
    if (!svg) return
    const stroke = outlineColor === 'white' ? '#ffffff' : '#dd0000'
    const fill = outlineColor === 'white' ? 'rgba(255,255,255,0.06)' : 'rgba(220,0,0,0.06)'
    svg.querySelectorAll('#vl-interactive rect[data-layer-id]').forEach((rect) => {
      const lid = rect.getAttribute('data-layer-id')
      if (lid === selectedId) {
        rect.setAttribute('stroke', '#0d6efd')
        rect.setAttribute('stroke-dasharray', 'none')
        rect.setAttribute('fill', 'rgba(13,110,253,0.1)')
      } else {
        rect.setAttribute('stroke', stroke)
        rect.setAttribute('stroke-dasharray', '10,5')
        rect.setAttribute('fill', fill)
      }
    })
  }, [selectedId, ready, outlineColor])

  // Delete selected element with the Delete key
  useEffect(() => {
    const onKeyDown = (e) => {
      if (e.key !== 'Delete' && e.key !== 'Backspace') return
      if (!selectedId) return
      if (editingLayer) return
      const active = document.activeElement
      if (active?.tagName === 'INPUT' || active?.tagName === 'TEXTAREA' || active?.isContentEditable) return

      e.preventDefault()

      const svg = containerRef.current?.querySelector('svg')
      if (svg) {
        const target = svg.getElementById(selectedId) || svg.querySelector(`[data-vl-region="${selectedId}"]`)
        if (target) target.style.display = 'none'
        svg.querySelector(`#vl-interactive rect[data-layer-id="${selectedId}"]`)?.remove()
      }

      deletedIds.current.add(selectedId)
      onLayerOverridesChange?.(selectedId, { deleted: true })
      setSelectedId(null)
    }

    window.addEventListener('keydown', onKeyDown)
    return () => window.removeEventListener('keydown', onKeyDown)
  }, [selectedId, editingLayer, onLayerOverridesChange])

  const openEditor = (textEl, layerId, svg) => {
    const bbox = textEl.getBBox()
    // Get SVG -> screen scale for popup positioning
    const svgRect = svg.getBoundingClientRect()
    const containerRect = containerRef.current.getBoundingClientRect()
    const ctm = svg.getScreenCTM()
    const scale = ctm ? ctm.a : 1

    // Read existing styles
    const rawSize = readSvgStyle(textEl, 'font-size', '16').replace(/[^0-9.]/g, '')
    const weight = readSvgStyle(textEl, 'font-weight', 'normal')
    const style = readSvgStyle(textEl, 'font-style', 'normal')
    const anchor = textEl.getAttribute('text-anchor') || 'start'
    const letterSpacing = readSvgStyle(textEl, 'letter-spacing', '0').replace(/[^0-9.-]/g, '')

    // Collect text content (collapse tspans)
    const content = Array.from(textEl.querySelectorAll('tspan')).length > 0
      ? Array.from(textEl.querySelectorAll('tspan')).map((t) => t.textContent).join(' ')
      : textEl.textContent

    setEditingLayer({
      id: layerId,
      element: textEl,
      content,
      font_family: readSvgStyle(textEl, 'font-family', ''),
      font_size: rawSize || '16',
      is_bold: weight === 'bold' || parseInt(weight) >= 700,
      is_italic: style === 'italic',
      is_underline: (textEl.getAttribute('text-decoration') || '').includes('underline'),
      fill: readFill(textEl),
      letter_spacing: letterSpacing || '0',
      line_height: textEl.getAttribute('line-height') || '1.3',
      text_align: ANCHOR_TO_ALIGN[anchor] || 'left',
    })
  }

  const saveEdit = (newStyles) => {
    const { element, id } = editingLayer
    const isNativeText = element.tagName === 'text'

    if (isNativeText) {
      // Native <text> — mutate directly for live preview
      if (newStyles.font_size) element.setAttribute('font-size', newStyles.font_size)
      if (newStyles.font_family) element.setAttribute('font-family', newStyles.font_family)
      element.setAttribute('fill', newStyles.fill)
      element.setAttribute('font-weight', newStyles.is_bold ? 'bold' : 'normal')
      element.setAttribute('font-style', newStyles.is_italic ? 'italic' : 'normal')
      element.setAttribute('text-decoration', newStyles.is_underline ? 'underline' : 'none')
      element.setAttribute('letter-spacing', newStyles.letter_spacing)
      element.setAttribute('text-anchor', ALIGN_TO_ANCHOR[newStyles.text_align] || 'start')

      element.querySelectorAll('tspan').forEach((t) => {
        if (t.getAttribute('fill') && t.getAttribute('fill') !== 'none') {
          t.setAttribute('fill', newStyles.fill)
        }
      })

      const tspans = element.querySelectorAll('tspan')
      if (tspans.length > 0) {
        tspans[0].textContent = newStyles.content
        Array.from(tspans).slice(1).forEach((t) => t.remove())
      } else {
        element.textContent = newStyles.content
      }

      buildInteractiveLayer()
    } else {
      // PDF region — hide original glyph paths, overlay a live <text> element
      const svg = containerRef.current?.querySelector('svg')
      if (svg) {
        element.style.opacity = '0'

        // Remove any previous overlay for this region
        svg.querySelector(`[data-vl-overlay="${id}"]`)?.remove()

        // Get region bounds from clip-path
        const clipRef = element.getAttribute('clip-path')
        const clipBounds = getClipBounds(svg, clipRef)
        const bbox = clipBounds || element.getBBox()

        const fontSize = parseFloat(newStyles.font_size) || 16
        const anchor = ALIGN_TO_ANCHOR[newStyles.text_align] || 'start'
        let textX = bbox.x
        if (anchor === 'middle') textX = bbox.x + bbox.width / 2
        else if (anchor === 'end') textX = bbox.x + bbox.width

        const textEl = document.createElementNS('http://www.w3.org/2000/svg', 'text')
        textEl.setAttribute('data-vl-overlay', id)
        textEl.setAttribute('x', textX)
        textEl.setAttribute('y', bbox.y + fontSize)
        textEl.setAttribute('fill', newStyles.fill)
        textEl.setAttribute('font-size', fontSize)
        textEl.setAttribute('font-family', newStyles.font_family || 'sans-serif')
        textEl.setAttribute('font-weight', newStyles.is_bold ? 'bold' : 'normal')
        textEl.setAttribute('font-style', newStyles.is_italic ? 'italic' : 'normal')
        textEl.setAttribute('text-anchor', anchor)
        textEl.setAttribute('letter-spacing', newStyles.letter_spacing || '0')
        textEl.style.pointerEvents = 'none'

        // Word-wrap content into tspans
        const lineHeight = fontSize * (parseFloat(newStyles.line_height) || 1.3)
        const approxCharsPerLine = Math.max(1, Math.floor(bbox.width / (fontSize * 0.55)))
        const words = (newStyles.content || '').split(/\s+/)
        const lines = []
        let current = []
        let currentLen = 0
        words.forEach((w) => {
          if (current.length === 0 || currentLen + 1 + w.length <= approxCharsPerLine) {
            current.push(w)
            currentLen += (current.length === 1 ? 0 : 1) + w.length
          } else {
            lines.push(current.join(' '))
            current = [w]
            currentLen = w.length
          }
        })
        if (current.length) lines.push(current.join(' '))

        lines.forEach((line, i) => {
          const tspan = document.createElementNS('http://www.w3.org/2000/svg', 'tspan')
          tspan.setAttribute('x', textX)
          if (i > 0) tspan.setAttribute('dy', lineHeight)
          tspan.textContent = line
          textEl.appendChild(tspan)
        })

        // Insert before the interactive overlay group
        const interactiveG = svg.querySelector('#vl-interactive')
        if (interactiveG) svg.insertBefore(textEl, interactiveG)
        else svg.appendChild(textEl)
      }
    }

    // Always persist overrides (for both native text and PDF regions)
    onLayerOverridesChange?.(id, newStyles)
  }

  return (
    <div
      style={{ position: 'relative', maxWidth: '100%', lineHeight: 0 }}
      onClick={(e) => {
        // Deselect when clicking SVG background (not an interactive overlay rect)
        if (!(e.target instanceof SVGElement) || !e.target.hasAttribute('data-layer-id')) {
          setSelectedId(null)
        }
      }}
    >

      {/* Inline SVG container */}
      <div ref={containerRef} style={{ maxWidth: '100%', display: 'block' }} />

      {/* Graph-paper grid overlay */}
      {showGrid && (
        <div
          style={{
            position: 'absolute',
            inset: 0,
            pointerEvents: 'none',
            zIndex: 4,
            backgroundImage: [
              'linear-gradient(to right,  rgba(255,255,255,0.30) 1px, transparent 1px)',
              'linear-gradient(to bottom, rgba(255,255,255,0.30) 1px, transparent 1px)',
              'linear-gradient(to right,  rgba(255,255,255,0.10) 1px, transparent 1px)',
              'linear-gradient(to bottom, rgba(255,255,255,0.10) 1px, transparent 1px)',
            ].join(','),
            backgroundSize: '25% 25%, 25% 25%, 5% 5%, 5% 5%',
          }}
        />
      )}

      {/* Editor toolbar: grid toggle + outline color toggle */}
      <div
        style={{ position: 'absolute', top: 8, right: 8, zIndex: 10, lineHeight: 'normal', display: 'flex', gap: 4 }}
        onClick={(e) => e.stopPropagation()}
      >
        <button
          className={`btn btn-sm ${showGrid ? 'btn-info' : 'btn-outline-secondary'}`}
          title="Toggle gridlines"
          onClick={() => setShowGrid((g) => !g)}
        >
          <i className="bi bi-grid-3x3" />
        </button>
        <button
          className={`btn btn-sm ${outlineColor === 'white' ? 'btn-light' : 'btn-danger'}`}
          title="Toggle outline color (red / white)"
          onClick={() => {
            const next = outlineColor === 'red' ? 'white' : 'red'
            outlineColorRef.current = next === 'white' ? '#ffffff' : '#dd0000'
            setOutlineColor(next)
          }}
        >
          <i className="bi bi-border-outer" />
        </button>
      </div>

      {/* Delete hint — shown when an element is selected */}
      {selectedId && (
        <div
          style={{
            position: 'absolute',
            top: 8,
            left: '50%',
            transform: 'translateX(-50%)',
            background: 'rgba(0,0,0,0.72)',
            color: '#fff',
            fontSize: '0.7rem',
            padding: '3px 12px',
            borderRadius: 12,
            pointerEvents: 'none',
            whiteSpace: 'nowrap',
            zIndex: 10,
            lineHeight: 'normal',
          }}
        >
          Press Delete to remove element
        </div>
      )}

      {/* Style editor — rendered via portal to break free of overflow containers */}
      {editingLayer && createPortal(
        <LayerStyleEditor
          layer={editingLayer}
          clickPos={editorClickPos}
          onChange={saveEdit}
          onClose={() => setEditingLayer(null)}
        />,
        document.body
      )}

    </div>
  )
}

// ─── Hover tooltip ────────────────────────────────────────────────────────────

function HoverTooltip({ layerId, containerRef }) {
  const svg = containerRef.current?.querySelector('svg')
  if (!svg) return null

  const el = svg.querySelector(`[data-layer-id="${layerId}"]`)
  if (!el) return null

  const rect = el.getBoundingClientRect()
  const containerRect = containerRef.current.getBoundingClientRect()

  const top = rect.top - containerRect.top - 30
  const left = rect.left - containerRect.left + rect.width / 2

  return (
    <div
      style={{
        position: 'absolute',
        top,
        left,
        transform: 'translateX(-50%)',
        background: 'rgba(0,0,0,0.8)',
        color: '#fff',
        fontSize: '0.7rem',
        padding: '2px 8px',
        borderRadius: 4,
        pointerEvents: 'none',
        whiteSpace: 'nowrap',
        zIndex: 10,
      }}
    >
      ⊕ Drag or double-click to edit
    </div>
  )
}

// ─── Layer Style Editor ───────────────────────────────────────────────────────

function LayerStyleEditor({ layer, clickPos, onChange, onClose }) {
  const formRef = useRef({
    content: layer.content || '',
    font_family: layer.font_family || '',
    font_size: layer.font_size || '16',
    is_bold: layer.is_bold || false,
    is_italic: layer.is_italic || false,
    is_underline: layer.is_underline || false,
    fill: layer.fill || '#000000',
    letter_spacing: layer.letter_spacing || '0',
    line_height: layer.line_height || '1.3',
    text_align: layer.text_align || 'left',
  })
  const [form, setForm] = useState(formRef.current)

  const emit = (updated) => {
    formRef.current = updated
    setForm(updated)
    onChange?.(updated)
  }

  // Draggable position
  const panelW = 340
  const initialLeft = (() => {
    if (!clickPos) return 100
    // Place to the right of click if room, otherwise left
    const rightSpace = window.innerWidth - clickPos.x - 20
    if (rightSpace >= panelW + 10) return clickPos.x + 20
    return Math.max(10, clickPos.x - panelW - 20)
  })()
  const initialTop = clickPos ? Math.max(10, Math.min(clickPos.y - 40, window.innerHeight - 500)) : 100

  const [pos, setPos] = useState({ x: initialLeft, y: initialTop })
  const dragRef = useRef(null)

  const onDragStart = (e) => {
    e.preventDefault()
    dragRef.current = { startX: e.clientX, startY: e.clientY, origX: pos.x, origY: pos.y }
    const onMove = (ev) => {
      const dx = ev.clientX - dragRef.current.startX
      const dy = ev.clientY - dragRef.current.startY
      setPos({ x: dragRef.current.origX + dx, y: dragRef.current.origY + dy })
    }
    const onUp = () => {
      document.removeEventListener('mousemove', onMove)
      document.removeEventListener('mouseup', onUp)
      dragRef.current = null
    }
    document.addEventListener('mousemove', onMove)
    document.addEventListener('mouseup', onUp)
  }

  const set = (key, val) => emit({ ...formRef.current, [key]: val })
  const toggle = (key) => emit({ ...formRef.current, [key]: !formRef.current[key] })

  return (
    <div
      className="bg-white shadow-lg rounded border"
      style={{ position: 'fixed', left: pos.x, top: pos.y, zIndex: 9999, width: panelW, maxHeight: '80vh', overflowY: 'auto', lineHeight: 'normal' }}
      onMouseDown={(e) => e.stopPropagation()}
    >
      <div
        className="d-flex align-items-center justify-content-between px-3 py-2 border-bottom bg-light"
        style={{ cursor: 'grab' }}
        onMouseDown={onDragStart}
      >
        <span className="fw-semibold small text-uppercase" style={{ letterSpacing: '0.06em' }}>Edit Text</span>
        <button className="btn btn-sm btn-link p-0 text-muted" onClick={onClose} onMouseDown={(e) => e.stopPropagation()}>
          <i className="bi bi-x-lg"></i>
        </button>
      </div>

      <div className="p-3" style={{ fontSize: '0.82rem' }}>
        {/* Font family */}
        <div className="mb-3">
          <label className="form-label text-uppercase text-muted fw-semibold mb-1" style={{ fontSize: '0.68rem', letterSpacing: '0.08em' }}>
            Font Family
          </label>
          <input
            type="text"
            className="form-control form-control-sm"
            value={form.font_family}
            onChange={(e) => set('font_family', e.target.value)}
            placeholder="Font name…"
          />
        </div>

        {/* Size + Style */}
        <div className="row g-2 mb-3">
          <div className="col-5">
            <label className="form-label text-uppercase text-muted fw-semibold mb-1" style={{ fontSize: '0.68rem', letterSpacing: '0.08em' }}>
              Size
            </label>
            <input
              type="number"
              className="form-control form-control-sm"
              value={form.font_size}
              onChange={(e) => set('font_size', e.target.value)}
              min={1}
            />
          </div>
          <div className="col-7">
            <label className="form-label text-uppercase text-muted fw-semibold mb-1" style={{ fontSize: '0.68rem', letterSpacing: '0.08em' }}>
              Style
            </label>
            <div className="btn-group btn-group-sm w-100">
              <button
                className={`btn ${form.is_bold ? 'btn-danger' : 'btn-outline-secondary'}`}
                onClick={() => toggle('is_bold')}
                title="Bold"
                style={{ fontWeight: 'bold' }}
              >B</button>
              <button
                className={`btn ${form.is_italic ? 'btn-danger' : 'btn-outline-secondary'}`}
                onClick={() => toggle('is_italic')}
                title="Italic"
                style={{ fontStyle: 'italic' }}
              >I</button>
              <button
                className={`btn ${form.is_underline ? 'btn-danger' : 'btn-outline-secondary'}`}
                onClick={() => toggle('is_underline')}
                title="Underline"
                style={{ textDecoration: 'underline' }}
              >U</button>
            </div>
          </div>
        </div>

        {/* Color */}
        <div className="mb-3">
          <label className="form-label text-uppercase text-muted fw-semibold mb-1" style={{ fontSize: '0.68rem', letterSpacing: '0.08em' }}>
            Color
          </label>
          <div className="d-flex align-items-center gap-2">
            <input
              type="color"
              className="form-control form-control-color form-control-sm"
              style={{ width: 36, height: 32, padding: 2 }}
              value={form.fill}
              onChange={(e) => set('fill', e.target.value)}
            />
            <input
              type="text"
              className="form-control form-control-sm"
              value={form.fill}
              onChange={(e) => set('fill', e.target.value)}
            />
          </div>
        </div>

        {/* Character spacing + Leading */}
        <div className="row g-2 mb-3">
          <div className="col-6">
            <label className="form-label text-uppercase text-muted fw-semibold mb-1" style={{ fontSize: '0.68rem', letterSpacing: '0.08em' }}>
              Character Spacing
            </label>
            <input
              type="number"
              className="form-control form-control-sm"
              value={form.letter_spacing}
              onChange={(e) => set('letter_spacing', e.target.value)}
              step={0.1}
            />
          </div>
          <div className="col-6">
            <label className="form-label text-uppercase text-muted fw-semibold mb-1" style={{ fontSize: '0.68rem', letterSpacing: '0.08em' }}>
              Leading
            </label>
            <input
              type="number"
              className="form-control form-control-sm"
              value={form.line_height}
              onChange={(e) => set('line_height', e.target.value)}
              step={0.1}
            />
          </div>
        </div>

        {/* Alignment */}
        <div className="mb-3">
          <label className="form-label text-uppercase text-muted fw-semibold mb-1" style={{ fontSize: '0.68rem', letterSpacing: '0.08em' }}>
            Alignment
          </label>
          <div className="btn-group btn-group-sm w-100">
            {[
              { val: 'left',    icon: 'bi-text-left' },
              { val: 'center',  icon: 'bi-text-center' },
              { val: 'right',   icon: 'bi-text-right' },
              { val: 'justify', icon: 'bi-justify' },
            ].map(({ val, icon }) => (
              <button
                key={val}
                className={`btn ${form.text_align === val ? 'btn-danger' : 'btn-outline-secondary'}`}
                onClick={() => set('text_align', val)}
                title={val.charAt(0).toUpperCase() + val.slice(1)}
              >
                <i className={`bi ${icon}`}></i>
              </button>
            ))}
          </div>
        </div>

        {/* Content */}
        <div className="mb-3">
          <label className="form-label text-uppercase text-muted fw-semibold mb-1" style={{ fontSize: '0.68rem', letterSpacing: '0.08em' }}>
            Content
          </label>
          <textarea
            className="form-control form-control-sm"
            rows={3}
            value={form.content}
            onChange={(e) => set('content', e.target.value)}
          />
        </div>

      </div>
    </div>
  )
}

