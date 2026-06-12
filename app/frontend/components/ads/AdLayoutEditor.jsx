import React, { useState, useMemo, useRef, useCallback, useEffect } from 'react'
import { apiFetch } from '~/lib/api'

export default function AdLayoutEditor({
  ad,
  clientId,
  resizes,
  exclusionZones,
  onExclusionZonesChange,
  smartPlacement,
  onResizeUpdate,
}) {
  const [activeResizeId, setActiveResizeId] = useState(null)
  const [cropModalOpen, setCropModalOpen] = useState(false)
  const [drawing, setDrawing] = useState(false)
  const [drawStart, setDrawStart] = useState(null)
  const [drawCurrent, setDrawCurrent] = useState(null)
  const [selectedZoneIdx, setSelectedZoneIdx] = useState(null)
  const [labelInput, setLabelInput] = useState('')
  const [detecting, setDetecting] = useState(false)
  const svgRef = useRef(null)
  const autoDetectedRef = useRef(new Set())

  useEffect(() => {
    if (!activeResizeId && resizes.length > 0) setActiveResizeId(resizes[0].id)
  }, [resizes, activeResizeId])

  const activeResize = resizes.find((r) => r.id === activeResizeId) || resizes[0]
  const zoneKey = activeResize?.id || 'original'
  const zones = exclusionZones?.[zoneKey] || []
  const canvasW = activeResize?.width || 300
  const canvasH = activeResize?.height || 250

  const bgLayer = useMemo(() => {
    return (ad.classified_layers || []).find((l) => l.type === 'background')
  }, [ad.classified_layers])

  const bgSrc = activeResize?.background_asset_url || bgLayer?.href || null
  const bgNatW = activeResize?.background_asset_width || parseInt(bgLayer?.width) || ad.width || canvasW
  const bgNatH = activeResize?.background_asset_height || parseInt(bgLayer?.height) || ad.height || canvasH

  // Crop position: {x: 0.5, y: 0.5} = center (default)
  const crop = activeResize?.background_crop || { x: 0.5, y: 0.5 }

  // Auto-detect when switching to a resize that hasn't been detected yet
  useEffect(() => {
    if (!smartPlacement || !activeResize) return
    if (autoDetectedRef.current.has(activeResize.id)) return
    const existing = exclusionZones?.[activeResize.id]
    if (existing && existing.length > 0) return
    autoDetectedRef.current.add(activeResize.id)
    runDetection()
  }, [smartPlacement, activeResize?.id])

  useEffect(() => {
    setSelectedZoneIdx(null)
    setLabelInput('')
  }, [activeResizeId])

  const saveCrop = async (newCrop) => {
    if (!activeResize) return
    try {
      const data = await apiFetch(
        `/api/clients/${clientId}/ads/${ad.id}/ad_resizes/${activeResize.id}`,
        { method: 'PATCH', body: JSON.stringify({ background_crop: newCrop }) }
      )
      onResizeUpdate(data)
      // Wipe zones since crop changed
      onExclusionZonesChange({ ...exclusionZones, [activeResize.id]: [] })
      autoDetectedRef.current.delete(activeResize.id)
    } catch (e) {
      console.error('Failed to save crop:', e)
    }
  }

  const runDetection = async () => {
    if (!activeResize) return
    setDetecting(true)
    try {
      const body = {
        target_width: activeResize.width,
        target_height: activeResize.height,
        crop_x: crop.x,
        crop_y: crop.y,
      }
      if (activeResize.background_asset_id) {
        body.background_asset_id = activeResize.background_asset_id
      }
      const data = await apiFetch(
        `/api/clients/${clientId}/ads/${ad.id}/detect_exclusion_zones`,
        { method: 'POST', body: JSON.stringify(body) }
      )
      onExclusionZonesChange({
        ...exclusionZones,
        [activeResize.id]: data.exclusion_zones || [],
      })
    } catch (e) {
      console.error('Detection failed:', e)
    } finally {
      setDetecting(false)
    }
  }

  // --- Zone drawing ---
  const toCanvasCoords = useCallback((e) => {
    const svg = svgRef.current
    if (!svg) return { x: 0, y: 0 }
    const rect = svg.getBoundingClientRect()
    return {
      x: Math.round((e.clientX - rect.left) * (canvasW / rect.width)),
      y: Math.round((e.clientY - rect.top) * (canvasH / rect.height)),
    }
  }, [canvasW, canvasH])

  const handleMouseDown = (e) => {
    if (e.button !== 0) return
    const coords = toCanvasCoords(e)
    setDrawStart(coords); setDrawCurrent(coords); setDrawing(true); setSelectedZoneIdx(null)
  }
  const handleMouseMove = (e) => { if (drawing) setDrawCurrent(toCanvasCoords(e)) }
  const handleMouseUp = () => {
    if (!drawing || !drawStart || !drawCurrent) { setDrawing(false); return }
    const x = Math.min(drawStart.x, drawCurrent.x), y = Math.min(drawStart.y, drawCurrent.y)
    const w = Math.abs(drawCurrent.x - drawStart.x), h = Math.abs(drawCurrent.y - drawStart.y)
    setDrawing(false); setDrawStart(null); setDrawCurrent(null)
    if (w < 15 || h < 15) return
    const newZone = { x, y, width: w, height: h, label: 'custom zone' }
    onExclusionZonesChange({ ...exclusionZones, [zoneKey]: [...zones, newZone] })
    setSelectedZoneIdx(zones.length); setLabelInput('custom zone')
  }
  const handleZoneClick = (e, idx) => {
    e.stopPropagation()
    setSelectedZoneIdx(idx === selectedZoneIdx ? null : idx)
    setLabelInput(zones[idx]?.label || '')
  }
  const handleDeleteZone = (idx) => {
    onExclusionZonesChange({ ...exclusionZones, [zoneKey]: zones.filter((_, i) => i !== idx) })
    setSelectedZoneIdx(null)
  }
  const handleUpdateLabel = (idx, newLabel) => {
    onExclusionZonesChange({ ...exclusionZones, [zoneKey]: zones.map((z, i) => i === idx ? { ...z, label: newLabel } : z) })
    setLabelInput(newLabel)
  }

  const drawRect = drawing && drawStart && drawCurrent ? {
    x: Math.min(drawStart.x, drawCurrent.x), y: Math.min(drawStart.y, drawCurrent.y),
    width: Math.abs(drawCurrent.x - drawStart.x), height: Math.abs(drawCurrent.y - drawStart.y),
  } : null

  // Compute background position for the preview canvas (cover + crop offset)
  const bgPosition = useMemo(() => {
    return `${(crop.x * 100).toFixed(1)}% ${(crop.y * 100).toFixed(1)}%`
  }, [crop.x, crop.y])

  if (resizes.length === 0) {
    return <div className="text-center py-5 text-muted"><p>No resizes generated yet.</p></div>
  }

  return (
    <>
      <div className="row g-3">
        {/* Left: resize list */}
        <div className="col-lg-3">
          <label className="form-label fw-semibold small text-uppercase text-muted mb-2">Sizes</label>
          <div className="border rounded" style={{ maxHeight: 500, overflowY: 'auto' }}>
            {resizes.map((r) => {
              const isActive = r.id === activeResizeId
              const rZones = exclusionZones?.[r.id] || []
              const hasCrop = r.background_crop && (r.background_crop.x !== 0.5 || r.background_crop.y !== 0.5)
              const displayLabel = r.platform_labels?.map((pl) => `${pl.platform} ${pl.size_name}`).join(', ') || r.dimensions
              return (
                <div
                  key={r.id}
                  className="p-2 border-bottom"
                  style={{
                    cursor: 'pointer',
                    backgroundColor: isActive ? 'rgba(220, 53, 69, 0.06)' : 'transparent',
                    borderLeft: isActive ? '3px solid #dc3545' : '3px solid transparent',
                  }}
                  onClick={() => setActiveResizeId(r.id)}
                >
                  <div className="small fw-semibold text-truncate" title={displayLabel}>{displayLabel}</div>
                  <div className="d-flex align-items-center justify-content-between">
                    <span className="small text-muted">{r.dimensions}</span>
                    <div className="d-flex gap-1">
                      {hasCrop && (
                        <span className="badge bg-info-subtle text-info border" style={{ fontSize: '0.55rem' }}>cropped</span>
                      )}
                      {rZones.length > 0 ? (
                        <span className="badge bg-danger-subtle text-danger border border-danger-subtle" style={{ fontSize: '0.55rem' }}>
                          {rZones.length} zone{rZones.length !== 1 ? 's' : ''}
                        </span>
                      ) : (
                        <span className="badge bg-secondary-subtle text-secondary border" style={{ fontSize: '0.55rem' }}>no zones</span>
                      )}
                    </div>
                  </div>
                </div>
              )
            })}
          </div>
        </div>

        {/* Center: canvas */}
        <div className="col-lg-6">
          <div className="d-flex align-items-center justify-content-between mb-2">
            <label className="form-label fw-semibold small text-uppercase text-muted mb-0">
              {activeResize?.dimensions || ''} — Exclusion Zones
            </label>
            <div className="d-flex gap-2">
              <button
                className="btn btn-outline-secondary btn-sm"
                style={{ fontSize: '0.7rem' }}
                onClick={() => setCropModalOpen(true)}
              >
                <i className="bi bi-crop me-1"></i>Position Background
              </button>
              <button
                className="btn btn-outline-danger btn-sm"
                style={{ fontSize: '0.7rem' }}
                onClick={runDetection}
                disabled={detecting}
              >
                {detecting ? (
                  <><span className="spinner-border spinner-border-sm me-1" />Detecting…</>
                ) : (
                  <><i className="bi bi-eye me-1"></i>Detect Faces</>
                )}
              </button>
            </div>
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
              {/* Background: use a foreignObject with CSS cover+position for crop offset */}
              {bgSrc && (
                <foreignObject x="0" y="0" width={canvasW} height={canvasH} style={{ pointerEvents: 'none' }}>
                  <div xmlns="http://www.w3.org/1999/xhtml" style={{ width: '100%', height: '100%', overflow: 'hidden' }}>
                    <img
                      src={bgSrc}
                      alt=""
                      style={{
                        width: '100%',
                        height: '100%',
                        objectFit: 'cover',
                        objectPosition: bgPosition,
                        display: 'block',
                      }}
                    />
                  </div>
                </foreignObject>
              )}

              {zones.map((z, i) => {
                const isSelected = selectedZoneIdx === i
                return (
                  <g key={`zone-${i}`} onClick={(e) => handleZoneClick(e, i)} style={{ cursor: 'pointer' }}>
                    <rect x={z.x} y={z.y} width={z.width} height={z.height}
                      fill={isSelected ? 'rgba(255,0,0,0.3)' : 'rgba(255,0,0,0.15)'}
                      stroke={isSelected ? '#ff0000' : '#ff4444'}
                      strokeWidth={isSelected ? 2 : 1.5}
                      strokeDasharray={isSelected ? 'none' : '4,3'} rx={2}
                    />
                    <text x={z.x + 3} y={z.y + 10} fill="#ff0000" fontSize="7" fontWeight="bold" opacity={0.9} style={{ pointerEvents: 'none' }}>
                      {z.label}
                    </text>
                  </g>
                )
              })}

              {drawRect && drawRect.width > 5 && drawRect.height > 5 && (
                <rect x={drawRect.x} y={drawRect.y} width={drawRect.width} height={drawRect.height}
                  fill="rgba(255,0,0,0.2)" stroke="#ff0000" strokeWidth={2} strokeDasharray="6,3" rx={2} />
              )}
            </svg>
          </div>
          <div className="small text-muted mt-1">Draw on the image to add exclusion zones manually.</div>
        </div>

        {/* Right: zone list */}
        <div className="col-lg-3">
          <label className="form-label fw-semibold small text-uppercase text-muted mb-2">Zones ({zones.length})</label>
          <div className="border rounded" style={{ maxHeight: 400, overflowY: 'auto' }}>
            {zones.length === 0 && (
              <div className="p-3 text-muted small text-center">No exclusion zones. Click "Detect Faces" or draw on the image.</div>
            )}
            {zones.map((z, i) => {
              const isSelected = selectedZoneIdx === i
              return (
                <div
                  key={i}
                  className={`p-2 d-flex align-items-center gap-2 ${i < zones.length - 1 ? 'border-bottom' : ''}`}
                  style={{
                    cursor: 'pointer',
                    backgroundColor: isSelected ? 'rgba(255,0,0,0.05)' : 'transparent',
                    borderLeft: isSelected ? '3px solid #ff0000' : '3px solid transparent',
                  }}
                  onClick={() => { setSelectedZoneIdx(i === selectedZoneIdx ? null : i); setLabelInput(z.label || '') }}
                >
                  <div className="flex-grow-1 min-width-0">
                    {isSelected ? (
                      <input type="text" className="form-control form-control-sm" style={{ fontSize: '0.8rem' }}
                        value={labelInput} onChange={(e) => handleUpdateLabel(i, e.target.value)}
                        onClick={(e) => e.stopPropagation()} placeholder="Zone label" />
                    ) : (
                      <span className="small fw-semibold">{z.label || 'Unnamed zone'}</span>
                    )}
                    <div className="small text-muted" style={{ fontSize: '0.7rem' }}>({z.x}, {z.y}) {z.width}&times;{z.height}</div>
                  </div>
                  <button className="btn btn-sm btn-outline-danger flex-shrink-0"
                    style={{ padding: '0.1rem 0.4rem', fontSize: '0.7rem' }}
                    onClick={(e) => { e.stopPropagation(); handleDeleteZone(i) }} title="Remove zone">
                    <i className="bi bi-trash"></i>
                  </button>
                </div>
              )
            })}
          </div>
        </div>
      </div>

      {/* Crop/position modal */}
      {cropModalOpen && activeResize && (
        <CropModal
          bgSrc={bgSrc}
          bgNatW={bgNatW}
          bgNatH={bgNatH}
          targetW={activeResize.width}
          targetH={activeResize.height}
          initialCrop={crop}
          onSave={(newCrop) => { saveCrop(newCrop); setCropModalOpen(false) }}
          onClose={() => setCropModalOpen(false)}
        />
      )}
    </>
  )
}

// Modal with a fixed viewport where you drag the background image behind it
function CropModal({ bgSrc, bgNatW, bgNatH, targetW, targetH, initialCrop, onSave, onClose }) {
  // Scale the viewport to fit in the modal (max ~500px wide)
  const maxViewW = 500
  const viewScale = Math.min(maxViewW / targetW, 400 / targetH, 1)
  const viewW = Math.round(targetW * viewScale)
  const viewH = Math.round(targetH * viewScale)

  // The background image is scaled to "cover" the viewport
  const coverScale = Math.max(targetW / bgNatW, targetH / bgNatH)
  const scaledBgW = Math.round(bgNatW * coverScale * viewScale)
  const scaledBgH = Math.round(bgNatH * coverScale * viewScale)

  // Pan range in display pixels
  const panRangeX = scaledBgW - viewW
  const panRangeY = scaledBgH - viewH

  // Convert crop focal point (0-1) to display offset
  const initialOffsetX = -(initialCrop.x * panRangeX)
  const initialOffsetY = -(initialCrop.y * panRangeY)

  const [offset, setOffset] = useState({ x: initialOffsetX, y: initialOffsetY })
  const [dragging, setDragging] = useState(false)
  const dragStartRef = useRef(null)

  const clampOffset = (ox, oy) => ({
    x: Math.min(0, Math.max(-panRangeX, ox)),
    y: Math.min(0, Math.max(-panRangeY, oy)),
  })

  const handleMouseDown = (e) => {
    if (e.button !== 0) return
    e.preventDefault()
    setDragging(true)
    dragStartRef.current = { mx: e.clientX, my: e.clientY, ox: offset.x, oy: offset.y }
  }

  const handleMouseMove = useCallback((e) => {
    if (!dragging || !dragStartRef.current) return
    const dx = e.clientX - dragStartRef.current.mx
    const dy = e.clientY - dragStartRef.current.my
    setOffset(clampOffset(dragStartRef.current.ox + dx, dragStartRef.current.oy + dy))
  }, [dragging, panRangeX, panRangeY])

  const handleMouseUp = useCallback(() => {
    setDragging(false)
    dragStartRef.current = null
  }, [])

  useEffect(() => {
    if (dragging) {
      window.addEventListener('mousemove', handleMouseMove)
      window.addEventListener('mouseup', handleMouseUp)
      return () => {
        window.removeEventListener('mousemove', handleMouseMove)
        window.removeEventListener('mouseup', handleMouseUp)
      }
    }
  }, [dragging, handleMouseMove, handleMouseUp])

  const handleSave = () => {
    // Convert offset back to focal point (0-1)
    const fx = panRangeX > 0 ? Math.abs(offset.x) / panRangeX : 0.5
    const fy = panRangeY > 0 ? Math.abs(offset.y) / panRangeY : 0.5
    onSave({ x: Math.round(fx * 1000) / 1000, y: Math.round(fy * 1000) / 1000 })
  }

  const handleReset = () => {
    setOffset(clampOffset(-panRangeX / 2, -panRangeY / 2))
  }

  return (
    <div className="modal d-block" style={{ backgroundColor: 'rgba(0,0,0,0.6)' }} onClick={onClose}>
      <div className="modal-dialog modal-dialog-centered" style={{ maxWidth: viewW + 80 }} onClick={(e) => e.stopPropagation()}>
        <div className="modal-content">
          <div className="modal-header py-2">
            <h6 className="modal-title small fw-semibold">Position Background — {targetW}&times;{targetH}</h6>
            <button type="button" className="btn-close btn-close-sm" onClick={onClose}></button>
          </div>
          <div className="modal-body d-flex justify-content-center" style={{ background: '#222', padding: '1rem' }}>
            <div
              style={{
                width: viewW,
                height: viewH,
                overflow: 'hidden',
                position: 'relative',
                cursor: dragging ? 'grabbing' : 'grab',
                borderRadius: 4,
                border: '2px solid rgba(255,255,255,0.3)',
              }}
              onMouseDown={handleMouseDown}
            >
              <img
                src={bgSrc}
                alt="Background"
                draggable={false}
                style={{
                  position: 'absolute',
                  left: offset.x,
                  top: offset.y,
                  width: scaledBgW,
                  height: scaledBgH,
                  pointerEvents: 'none',
                  userSelect: 'none',
                }}
              />
            </div>
          </div>
          <div className="modal-footer py-2">
            <button className="btn btn-sm btn-outline-secondary" onClick={handleReset}>Reset to Center</button>
            <button className="btn btn-sm btn-primary" onClick={handleSave}>
              <i className="bi bi-check-lg me-1"></i>Apply Position
            </button>
          </div>
        </div>
      </div>
    </div>
  )
}
