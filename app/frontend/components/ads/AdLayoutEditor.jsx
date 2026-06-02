import React, { useState, useMemo, useRef, useCallback } from 'react'
import { apiFetch } from '~/lib/api'

export default function AdLayoutEditor({
  ad,
  clientId,
  resizes,
  exclusionZones,
  onExclusionZonesChange,
  smartPlacement,
  onContinue,
  onBack,
  transitioning,
}) {
  const [drawing, setDrawing] = useState(false) // is the user currently dragging a new box
  const [drawStart, setDrawStart] = useState(null) // { x, y } in canvas coords
  const [drawCurrent, setDrawCurrent] = useState(null)
  const [selectedZoneIdx, setSelectedZoneIdx] = useState(null)
  const [labelInput, setLabelInput] = useState('')
  const svgRef = useRef(null)

  const bgLayer = useMemo(() => {
    return (ad.classified_layers || []).find((l) => l.type === 'background')
  }, [ad.classified_layers])

  const zones = exclusionZones?.['original'] || []
  const canvasW = ad.width || 300
  const canvasH = ad.height || 250
  const bgSrc = bgLayer?.href || null

  // Convert mouse event to SVG canvas coordinates
  const toCanvasCoords = useCallback((e) => {
    const svg = svgRef.current
    if (!svg) return { x: 0, y: 0 }
    const rect = svg.getBoundingClientRect()
    const scaleX = canvasW / rect.width
    const scaleY = canvasH / rect.height
    return {
      x: Math.round((e.clientX - rect.left) * scaleX),
      y: Math.round((e.clientY - rect.top) * scaleY),
    }
  }, [canvasW, canvasH])

  const handleMouseDown = (e) => {
    if (e.button !== 0) return
    const coords = toCanvasCoords(e)
    setDrawStart(coords)
    setDrawCurrent(coords)
    setDrawing(true)
    setSelectedZoneIdx(null)
  }

  const handleMouseMove = (e) => {
    if (!drawing) return
    setDrawCurrent(toCanvasCoords(e))
  }

  const handleMouseUp = () => {
    if (!drawing || !drawStart || !drawCurrent) {
      setDrawing(false)
      return
    }

    const x = Math.min(drawStart.x, drawCurrent.x)
    const y = Math.min(drawStart.y, drawCurrent.y)
    const w = Math.abs(drawCurrent.x - drawStart.x)
    const h = Math.abs(drawCurrent.y - drawStart.y)

    setDrawing(false)
    setDrawStart(null)
    setDrawCurrent(null)

    // Ignore tiny accidental drags
    if (w < 15 || h < 15) return

    // Add new zone
    const newZone = { x, y, width: w, height: h, label: 'custom zone' }
    const updated = { ...exclusionZones, original: [...zones, newZone] }
    onExclusionZonesChange(updated)
    setSelectedZoneIdx(zones.length) // select the new one
    setLabelInput('custom zone')
  }

  const handleZoneClick = (e, idx) => {
    e.stopPropagation()
    setSelectedZoneIdx(idx === selectedZoneIdx ? null : idx)
    setLabelInput(zones[idx]?.label || '')
  }

  const handleDeleteZone = (idx) => {
    const updated = { ...exclusionZones, original: zones.filter((_, i) => i !== idx) }
    onExclusionZonesChange(updated)
    setSelectedZoneIdx(null)
  }

  const handleUpdateLabel = (idx, newLabel) => {
    const updatedZones = zones.map((z, i) => i === idx ? { ...z, label: newLabel } : z)
    onExclusionZonesChange({ ...exclusionZones, original: updatedZones })
    setLabelInput(newLabel)
  }

  // Draw preview rect while dragging
  const drawRect = drawing && drawStart && drawCurrent ? {
    x: Math.min(drawStart.x, drawCurrent.x),
    y: Math.min(drawStart.y, drawCurrent.y),
    width: Math.abs(drawCurrent.x - drawStart.x),
    height: Math.abs(drawCurrent.y - drawStart.y),
  } : null

  return (
    <div>
      {/* Info */}
      {smartPlacement && (
        <div className="alert alert-info mb-4">
          <div className="d-flex align-items-center gap-2 mb-1">
            <i className="bi bi-shield-check"></i>
            <strong>Exclusion Zones</strong>
            <span className="badge bg-info-subtle text-info border border-info-subtle">
              {zones.length} zone{zones.length !== 1 ? 's' : ''}
            </span>
          </div>
          <p className="small mb-0">
            Red boxes mark areas where text should NOT be placed (faces, logos, key subjects).
            AI detected {zones.length} zone{zones.length !== 1 ? 's' : ''}.
            <strong> Click and drag on the image to add more zones.</strong> Click a zone to select, rename, or delete it.
          </p>
        </div>
      )}

      {!smartPlacement && (
        <div className="alert alert-secondary mb-4">
          <p className="small mb-0">
            <i className="bi bi-info-circle me-1"></i>
            No exclusion zones detected. Go back to Backgrounds and enable "Smart text placement" to auto-detect faces,
            or draw zones manually below.
          </p>
        </div>
      )}

      <div className="row g-4 mb-4">
        {/* Canvas */}
        <div className="col-lg-8">
          <div className="d-flex align-items-center justify-content-between mb-2">
            <label className="form-label fw-semibold small text-uppercase text-muted mb-0">
              Mark Exclusion Zones
            </label>
            <span className="small text-muted">Click + drag to add a zone</span>
          </div>
          <div
            className="position-relative border rounded overflow-hidden"
            style={{ background: '#1a1a1a', cursor: 'crosshair', userSelect: 'none' }}
          >
            <svg
              ref={svgRef}
              viewBox={`0 0 ${canvasW} ${canvasH}`}
              style={{ display: 'block', width: '100%', height: 'auto' }}
              onMouseDown={handleMouseDown}
              onMouseMove={handleMouseMove}
              onMouseUp={handleMouseUp}
              onMouseLeave={() => { if (drawing) { setDrawing(false); setDrawStart(null); setDrawCurrent(null) } }}
            >
              {/* Background image */}
              {bgSrc && (
                <image href={bgSrc} x="0" y="0" width={canvasW} height={canvasH} style={{ pointerEvents: 'none' }} />
              )}

              {/* Existing exclusion zones */}
              {zones.map((z, i) => {
                const isSelected = selectedZoneIdx === i
                return (
                  <g key={`zone-${i}`} onClick={(e) => handleZoneClick(e, i)} style={{ cursor: 'pointer' }}>
                    <rect
                      x={z.x} y={z.y} width={z.width} height={z.height}
                      fill={isSelected ? 'rgba(255, 0, 0, 0.3)' : 'rgba(255, 0, 0, 0.15)'}
                      stroke={isSelected ? '#ff0000' : '#ff4444'}
                      strokeWidth={isSelected ? 2 : 1.5}
                      strokeDasharray={isSelected ? 'none' : '4,3'}
                      rx={2}
                    />
                    <text
                      x={z.x + 3} y={z.y + 10}
                      fill="#ff0000" fontSize="7" fontWeight="bold"
                      opacity={0.9}
                      style={{ pointerEvents: 'none' }}
                    >
                      {z.label}
                    </text>
                  </g>
                )
              })}

              {/* Drawing preview */}
              {drawRect && drawRect.width > 5 && drawRect.height > 5 && (
                <rect
                  x={drawRect.x} y={drawRect.y}
                  width={drawRect.width} height={drawRect.height}
                  fill="rgba(255, 0, 0, 0.2)"
                  stroke="#ff0000"
                  strokeWidth={2}
                  strokeDasharray="6,3"
                  rx={2}
                />
              )}
            </svg>
          </div>
        </div>

        {/* Zone list */}
        <div className="col-lg-4">
          <label className="form-label fw-semibold small text-uppercase text-muted mb-2">
            Zones ({zones.length})
          </label>
          <div className="border rounded" style={{ maxHeight: 400, overflowY: 'auto' }}>
            {zones.length === 0 && (
              <div className="p-3 text-muted small text-center">
                No exclusion zones. Draw on the image to add one.
              </div>
            )}
            {zones.map((z, i) => {
              const isSelected = selectedZoneIdx === i
              return (
                <div
                  key={i}
                  className={`p-2 d-flex align-items-center gap-2 ${i < zones.length - 1 ? 'border-bottom' : ''}`}
                  style={{
                    cursor: 'pointer',
                    backgroundColor: isSelected ? 'rgba(255, 0, 0, 0.05)' : 'transparent',
                    borderLeft: isSelected ? '3px solid #ff0000' : '3px solid transparent',
                  }}
                  onClick={() => { setSelectedZoneIdx(i === selectedZoneIdx ? null : i); setLabelInput(z.label || '') }}
                >
                  <div className="flex-grow-1 min-width-0">
                    {isSelected ? (
                      <input
                        type="text"
                        className="form-control form-control-sm"
                        style={{ fontSize: '0.8rem' }}
                        value={labelInput}
                        onChange={(e) => handleUpdateLabel(i, e.target.value)}
                        onClick={(e) => e.stopPropagation()}
                        placeholder="Zone label"
                      />
                    ) : (
                      <span className="small fw-semibold">{z.label || 'Unnamed zone'}</span>
                    )}
                    <div className="small text-muted" style={{ fontSize: '0.7rem' }}>
                      ({z.x}, {z.y}) {z.width}&times;{z.height}
                    </div>
                  </div>
                  <button
                    className="btn btn-sm btn-outline-danger flex-shrink-0"
                    style={{ padding: '0.1rem 0.4rem', fontSize: '0.7rem' }}
                    onClick={(e) => { e.stopPropagation(); handleDeleteZone(i) }}
                    title="Remove zone"
                  >
                    <i className="bi bi-trash"></i>
                  </button>
                </div>
              )
            })}
          </div>
        </div>
      </div>

      {/* Continue */}
      <div className="d-flex gap-2">
        <button className="btn btn-primary" onClick={onContinue} disabled={transitioning}>
          {transitioning ? (
            <><span className="spinner-border spinner-border-sm me-2" />Reflowing text around faces...</>
          ) : (
            <>Continue to Style <i className="bi bi-arrow-right ms-1"></i></>
          )}
        </button>
      </div>
    </div>
  )
}
