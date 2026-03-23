import React, { useState, useEffect, useRef, useCallback } from 'react'

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

// ─── Main component ──────────────────────────────────────────────────────────

export default function InteractiveSvgEditor({ svgUrl, layers, onLayerOverridesChange, initialOverrides }) {
  const containerRef = useRef(null)
  const dragRef = useRef(null) // current drag state (non-reactive for perf)
  const layerOffsets = useRef({}) // { layerId: { x, y } }
  const [hoveredId, setHoveredId] = useState(null)
  const [editingLayer, setEditingLayer] = useState(null)
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

    // Clipped groups from PDF conversion (outer <g clip-path="..."> wrapping <g><use></g>)
    if (interactiveEls.length === 0) {
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
      let bbox
      try {
        bbox = el.getBBox()
      } catch (_) {
        return
      }
      if (!bbox || (bbox.width === 0 && bbox.height === 0)) return

      const offset = layerOffsets.current[layerId] || { x: 0, y: 0 }
      const rx = bbox.x - 4 + offset.x
      const ry = bbox.y - 4 + offset.y
      const rw = bbox.width + 8
      const rh = bbox.height + 8

      const rect = document.createElementNS('http://www.w3.org/2000/svg', 'rect')
      rect.setAttribute('x', rx)
      rect.setAttribute('y', ry)
      rect.setAttribute('width', rw)
      rect.setAttribute('height', rh)
      rect.setAttribute('fill', 'rgba(220,0,0,0.04)')
      rect.setAttribute('stroke', '#dd0000')
      rect.setAttribute('stroke-width', '1.5')
      rect.setAttribute('stroke-dasharray', '5,3')
      rect.setAttribute('rx', '2')
      rect.setAttribute('data-layer-id', layerId)
      rect.style.cursor = 'move'

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

      // Double-click to edit (only for native text elements)
      if (type === 'text') {
        rect.addEventListener('dblclick', (e) => {
          e.preventDefault()
          e.stopPropagation()
          openEditor(el, layerId, svg)
        })
      }
    })

    setReady(true)
  }, [])

  // Load SVG
  useEffect(() => {
    if (!svgUrl) return
    setReady(false)
    // Seed offsets from persisted overrides
    if (initialOverrides) {
      Object.entries(initialOverrides).forEach(([id, ov]) => {
        if (ov.x_offset !== undefined || ov.y_offset !== undefined) {
          layerOffsets.current[id] = { x: ov.x_offset || 0, y: ov.y_offset || 0 }
        }
      })
    }
    fetch(svgUrl, { credentials: 'same-origin' })
      .then((r) => r.text())
      .then((text) => {
        if (!containerRef.current) return
        containerRef.current.innerHTML = text
        // Apply persisted transforms before building interactive layer
        const svg = containerRef.current.querySelector('svg')
        if (svg) {
          Object.entries(layerOffsets.current).forEach(([id, { x, y }]) => {
            const el = svg.getElementById(id)
            if (el && (x || y)) el.setAttribute('transform', `translate(${x}, ${y})`)
          })
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
      layerOffsets.current[layerId] = { x: nx, y: ny }
      textEl.setAttribute('transform', `translate(${nx}, ${ny})`)
      dragRef.current = null
      setHoveredId(null)
      onLayerOverridesChange?.(layerId, { x_offset: nx, y_offset: ny })
    }

    window.addEventListener('mousemove', onMove)
    window.addEventListener('mouseup', onUp)
    return () => {
      window.removeEventListener('mousemove', onMove)
      window.removeEventListener('mouseup', onUp)
    }
  }, [onLayerOverridesChange])

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

    if (newStyles.font_size) element.setAttribute('font-size', newStyles.font_size)
    if (newStyles.font_family) element.setAttribute('font-family', newStyles.font_family)
    element.setAttribute('fill', newStyles.fill)
    element.setAttribute('font-weight', newStyles.is_bold ? 'bold' : 'normal')
    element.setAttribute('font-style', newStyles.is_italic ? 'italic' : 'normal')
    element.setAttribute('text-decoration', newStyles.is_underline ? 'underline' : 'none')
    element.setAttribute('letter-spacing', newStyles.letter_spacing)
    element.setAttribute('text-anchor', ALIGN_TO_ANCHOR[newStyles.text_align] || 'start')

    // Update fill on tspans too
    element.querySelectorAll('tspan').forEach((t) => {
      if (t.getAttribute('fill') && t.getAttribute('fill') !== 'none') {
        t.setAttribute('fill', newStyles.fill)
      }
    })

    // Update content — preserve first tspan structure if present
    const tspans = element.querySelectorAll('tspan')
    if (tspans.length > 0) {
      tspans[0].textContent = newStyles.content
      // Remove extra tspans if text was simplified
      Array.from(tspans).slice(1).forEach((t) => t.remove())
    } else {
      element.textContent = newStyles.content
    }

    // Rebuild interactive layer to pick up new bounding box
    buildInteractiveLayer()

    onLayerOverridesChange?.(id, newStyles)
    setEditingLayer(null)
  }

  return (
    <div style={{ position: 'relative', maxWidth: '100%', lineHeight: 0 }}>
      {/* Hover tooltip */}
      {hoveredId && ready && (
        <HoverTooltip layerId={hoveredId} containerRef={containerRef} />
      )}

      {/* Inline SVG container */}
      <div ref={containerRef} style={{ maxWidth: '100%', display: 'block' }} />

      {/* Style editor popover */}
      {editingLayer && (
        <LayerStyleEditor
          layer={editingLayer}
          onSave={saveEdit}
          onClose={() => setEditingLayer(null)}
        />
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

function LayerStyleEditor({ layer, onSave, onClose }) {
  const [form, setForm] = useState({
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

  const set = (key, val) => setForm((prev) => ({ ...prev, [key]: val }))
  const toggle = (key) => setForm((prev) => ({ ...prev, [key]: !prev[key] }))

  return (
    <div
      className="position-absolute bg-white shadow-lg rounded border"
      style={{ top: 0, right: 0, zIndex: 100, width: 340, maxHeight: '90vh', overflowY: 'auto' }}
      onMouseDown={(e) => e.stopPropagation()}
    >
      <div className="d-flex align-items-center justify-content-between px-3 py-2 border-bottom bg-light">
        <span className="fw-semibold small text-uppercase" style={{ letterSpacing: '0.06em' }}>Edit Text</span>
        <button className="btn btn-sm btn-link p-0 text-muted" onClick={onClose}>
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

        {/* Actions */}
        <div className="d-flex gap-2 justify-content-end">
          <button className="btn btn-sm btn-outline-secondary" onClick={onClose}>Cancel</button>
          <button className="btn btn-sm btn-danger" onClick={() => onSave(form)}>Save</button>
        </div>
      </div>
    </div>
  )
}
