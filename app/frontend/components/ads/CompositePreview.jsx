import React, { useState, useEffect, useRef, useCallback } from 'react'

/**
 * CompositePreview renders an ad preview entirely from metadata — no PDF/SVG source.
 * It loads embedded fonts via @font-face, then renders text layers as live SVG <text>.
 * This is the "reconstructed composite" view used on the Style step.
 */
export default function CompositePreview({
  width,
  height,
  layers,
  fonts,
  layerOverrides,
  onLayerOverridesChange,
  onEditLayer,
  showOutlines = true,
  onClick,
}) {
  const svgRef = useRef(null)
  const [fontsLoaded, setFontsLoaded] = useState(false)

  // Load embedded fonts via @font-face
  useEffect(() => {
    if (!fonts?.length) { setFontsLoaded(true); return }

    let styleEl = document.getElementById('vl-ad-fonts')
    if (!styleEl) {
      styleEl = document.createElement('style')
      styleEl.id = 'vl-ad-fonts'
      document.head.appendChild(styleEl)
    }

    const rules = fonts.map((f) =>
      `@font-face { font-family: '${f.name}'; src: url('${f.url}') format('truetype'); font-display: swap; }`
    ).join('\n')
    styleEl.textContent = rules

    // Wait for fonts to load
    Promise.all(
      fonts.map((f) => document.fonts.load(`16px '${f.name}'`).catch(() => {}))
    ).then(() => setFontsLoaded(true))

    return () => { /* leave style in place for other instances */ }
  }, [fonts])

  const getLayerProps = useCallback((layer) => {
    const overrides = layerOverrides?.[layer.id] || {}
    return {
      content: overrides.content || layer.content || '',
      font_family: overrides.font_family || layer.font_family || 'sans-serif',
      font_size: parseFloat(overrides.font_size || layer.font_size) || 24,
      fill: overrides.fill || layer.fill || layer.color || '#FFFFFF',
      is_bold: overrides.is_bold ?? layer.is_bold ?? false,
      is_italic: overrides.is_italic ?? layer.is_italic ?? false,
      text_align: overrides.text_align || layer.text_align || layer.align || 'left',
      letter_spacing: overrides.letter_spacing || layer.letter_spacing || '0',
      line_height: parseFloat(overrides.line_height || layer.line_height) || 1.3,
    }
  }, [layerOverrides])

  // Drag state
  const dragRef = useRef(null)

  const onDragStart = (e, layerId) => {
    e.preventDefault()
    e.stopPropagation()
    const svg = svgRef.current
    if (!svg) return
    const pt = svg.createSVGPoint()
    pt.x = e.clientX; pt.y = e.clientY
    const svgPt = pt.matrixTransform(svg.getScreenCTM().inverse())
    const cur = layerOverrides?.[layerId] || {}
    dragRef.current = {
      layerId,
      startX: svgPt.x,
      startY: svgPt.y,
      origOffsetX: parseFloat(cur.x_offset) || 0,
      origOffsetY: parseFloat(cur.y_offset) || 0,
    }

    const onMove = (ev) => {
      if (!dragRef.current) return
      const mvPt = svg.createSVGPoint()
      mvPt.x = ev.clientX; mvPt.y = ev.clientY
      const mvSvg = mvPt.matrixTransform(svg.getScreenCTM().inverse())
      const dx = mvSvg.x - dragRef.current.startX
      const dy = mvSvg.y - dragRef.current.startY
      onLayerOverridesChange?.(dragRef.current.layerId, {
        x_offset: dragRef.current.origOffsetX + dx,
        y_offset: dragRef.current.origOffsetY + dy,
      })
    }
    const onUp = () => {
      dragRef.current = null
      document.removeEventListener('mousemove', onMove)
      document.removeEventListener('mouseup', onUp)
    }
    document.addEventListener('mousemove', onMove)
    document.addEventListener('mouseup', onUp)
  }

  if (!fontsLoaded) {
    return (
      <div className="d-flex align-items-center justify-content-center text-muted" style={{ aspectRatio: `${width}/${height}`, background: '#1a1a1a' }}>
        <small>Loading fonts…</small>
      </div>
    )
  }

  const textLayers = (layers || []).filter((l) => l.type === 'text' && l.content)

  return (
    <svg
      ref={svgRef}
      xmlns="http://www.w3.org/2000/svg"
      viewBox={`0 0 ${width} ${height}`}
      style={{ display: 'block', width: '100%', height: '100%' }}
    >
      {textLayers.map((layer) => {
        const props = getLayerProps(layer)
        const overrides = layerOverrides?.[layer.id] || {}
        const ox = parseFloat(overrides.x_offset) || 0
        const oy = parseFloat(overrides.y_offset) || 0
        const x = parseFloat(layer.x) || 0
        const y = parseFloat(layer.y) || 0
        const w = parseFloat(layer.width) || (width * 0.8)
        const h = parseFloat(layer.height) || 100

        const anchor = props.text_align === 'center' ? 'middle' : props.text_align === 'right' ? 'end' : 'start'
        let textX = x + ox
        if (anchor === 'middle') textX = x + w / 2 + ox
        else if (anchor === 'end') textX = x + w + ox

        // Word wrap
        const charW = props.font_size * 0.55
        const charsPerLine = Math.max(1, Math.floor(w / charW))
        const words = props.content.split(/\s+/)
        const lines = []
        let cur = [], curLen = 0
        words.forEach((word) => {
          if (cur.length === 0 || curLen + 1 + word.length <= charsPerLine) {
            cur.push(word)
            curLen += (cur.length === 1 ? 0 : 1) + word.length
          } else {
            lines.push(cur.join(' '))
            cur = [word]; curLen = word.length
          }
        })
        if (cur.length) lines.push(cur.join(' '))

        const lineH = props.font_size * props.line_height

        return (
          <g key={layer.id}>
            {/* Hit area for drag + click */}
            <rect
              x={x + ox}
              y={y + oy}
              width={w}
              height={h}
              fill="transparent"
              stroke={showOutlines ? "#dc3545" : "transparent"}
              strokeWidth={showOutlines ? 2 : 0}
              strokeDasharray={showOutlines ? "8 4" : undefined}
              rx={3}
              style={{ cursor: onClick ? 'pointer' : 'move' }}
              onMouseDown={(e) => !onClick && onDragStart(e, layer.id)}
              onClick={() => onClick?.()}
              onDoubleClick={() => !onClick && onEditLayer?.(layer)}
            />
            {/* Rendered text */}
            <text
              x={textX}
              y={y + props.font_size + oy}
              fill={props.fill}
              fontSize={props.font_size}
              fontFamily={`'${props.font_family}', sans-serif`}
              fontWeight={props.is_bold ? 'bold' : 'normal'}
              fontStyle={props.is_italic ? 'italic' : 'normal'}
              textAnchor={anchor}
              letterSpacing={props.letter_spacing}
              style={{ pointerEvents: 'none' }}
            >
              {lines.map((line, i) => (
                <tspan key={i} x={textX} dy={i === 0 ? 0 : lineH}>
                  {line}
                </tspan>
              ))}
            </text>
          </g>
        )
      })}
    </svg>
  )
}
