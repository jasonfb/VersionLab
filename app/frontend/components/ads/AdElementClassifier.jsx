import React, { useState, useEffect, useRef } from 'react'
import { apiFetch } from '~/lib/api'

const ROLE_OPTIONS = [
  { value: 'headline', label: 'Headline', color: '#dc3545' },
  { value: 'subhead', label: 'Subhead', color: '#fd7e14' },
  { value: 'body', label: 'Body', color: '#6c757d' },
  { value: 'cta', label: 'CTA', color: '#198754' },
  { value: 'logo', label: 'Logo', color: '#0d6efd' },
  { value: 'background', label: 'Background', color: '#6f42c1' },
  { value: 'decoration', label: 'Decoration', color: '#adb5bd' },
]

const CONFIDENCE_THRESHOLDS = { high: 0.8, medium: 0.6 }

function confidenceLabel(score) {
  if (score >= CONFIDENCE_THRESHOLDS.high) return { text: 'High', className: 'text-success' }
  if (score >= CONFIDENCE_THRESHOLDS.medium) return { text: 'Medium', className: 'text-warning' }
  return { text: 'Low', className: 'text-danger' }
}

function roleColor(role) {
  return ROLE_OPTIONS.find((r) => r.value === role)?.color || '#adb5bd'
}

export default function AdElementClassifier({ ad, clientId, onConfirm }) {
  const [layers, setLayers] = useState([])
  const [loading, setLoading] = useState(true)
  const [confirming, setConfirming] = useState(false)
  const [selectedLayerId, setSelectedLayerId] = useState(null)
  const [svgMarkup, setSvgMarkup] = useState(null)
  const [viewMode, setViewMode] = useState('fit') // 'fit' or 'natural'
  const svgContainerRef = useRef(null)

  useEffect(() => {
    if (!ad?.id) return
    apiFetch(`/api/clients/${clientId}/ads/${ad.id}/classifications`)
      .then((data) => {
        setLayers(data.classified_layers || [])
      })
      .catch(() => {})
      .finally(() => setLoading(false))
  }, [ad?.id, clientId])

  // Fetch raw SVG content once
  const [rawSvg, setRawSvg] = useState(null)
  useEffect(() => {
    if (!ad?.svg_url) return
    fetch(ad.svg_url)
      .then((res) => res.text())
      .then((text) => setRawSvg(text))
      .catch(() => {})
  }, [ad?.svg_url])

  // Pre-process SVG markup string to set sizing before it hits the DOM.
  // This avoids the race condition where dangerouslySetInnerHTML renders
  // the SVG at native size before a useEffect can adjust attributes.
  useEffect(() => {
    if (!rawSvg) return
    const parser = new DOMParser()
    const doc = parser.parseFromString(rawSvg, 'image/svg+xml')
    const svg = doc.querySelector('svg')
    if (!svg) { setSvgMarkup(rawSvg); return }

    svg.style.display = 'block'
    svg.style.opacity = '0.4'

    if (viewMode === 'fit') {
      svg.setAttribute('width', '100%')
      svg.removeAttribute('height')
    } else {
      svg.setAttribute('width', ad.width || svg.getAttribute('viewBox')?.split(' ')[2] || '100%')
      svg.setAttribute('height', ad.height || svg.getAttribute('viewBox')?.split(' ')[3] || 'auto')
    }

    setSvgMarkup(svg.outerHTML)
  }, [rawSvg, viewMode])

  const updateRole = (index, newRole) => {
    setLayers((prev) => prev.map((l, i) =>
      i === index ? { ...l, role: newRole, confidence: 1.0 } : l
    ))
  }

  const handleConfirm = async () => {
    setConfirming(true)
    try {
      await apiFetch(`/api/clients/${clientId}/ads/${ad.id}/confirm_classifications`, {
        method: 'POST',
        body: JSON.stringify({ classified_layers: layers }),
      })
      onConfirm()
    } catch (e) {
      alert(e.message || 'Failed to confirm classifications')
    } finally {
      setConfirming(false)
    }
  }

  const textLayers = layers.filter((l) => l.type === 'text' && l.content)
  const imageLayers = layers.filter((l) => l.type === 'image')
  const otherLayers = layers.filter((l) => (l.type !== 'text' || !l.content) && l.type !== 'image')
  const hasLowConfidence = layers.some((l) => (l.confidence || 0) < CONFIDENCE_THRESHOLDS.medium)

  if (loading) {
    return (
      <div className="text-center py-5">
        <div className="spinner-border spinner-border-sm" role="status" />
        <div className="small text-muted mt-2">Loading classifications…</div>
      </div>
    )
  }

  if (layers.length === 0) {
    return (
      <div className="text-center py-5 text-muted">
        <i className="bi bi-layers fs-2 d-block mb-2"></i>
        <p>No layers detected. Upload a PDF or SVG with live text to classify elements.</p>
        <button className="btn btn-outline-secondary btn-sm" onClick={onConfirm}>
          Skip Classification
        </button>
      </div>
    )
  }

  return (
    <div className="row g-4">
      {/* Left: SVG preview with highlighted elements */}
      <div className="col-lg-6">
        <div className="d-flex align-items-center justify-content-between mb-2">
          <label className="form-label fw-semibold small text-uppercase text-muted mb-0">
            Element Preview
          </label>
          <div className="btn-group btn-group-sm">
            <button
              className={`btn ${viewMode === 'fit' ? 'btn-dark' : 'btn-outline-secondary'}`}
              onClick={() => setViewMode('fit')}
            >
              Fit
            </button>
            <button
              className={`btn ${viewMode === 'natural' ? 'btn-dark' : 'btn-outline-secondary'}`}
              onClick={() => setViewMode('natural')}
            >
              100%
            </button>
          </div>
        </div>
        {ad.svg_url ? (
          <div
            className="position-relative border rounded"
            style={{
              background: '#1a1a1a',
              ...(viewMode === 'natural'
                ? { overflow: 'auto', maxHeight: 600 }
                : { overflow: 'hidden' }),
            }}
          >
            <div ref={svgContainerRef} dangerouslySetInnerHTML={{ __html: svgMarkup || '' }} />
            {/* Overlay layer highlights */}
            <svg
              viewBox={`0 0 ${ad.width || 100} ${ad.height || 100}`}
              style={{
                position: 'absolute',
                inset: 0,
                ...(viewMode === 'fit'
                  ? { width: '100%', height: '100%' }
                  : { width: ad.width || 100, height: ad.height || 100 }),
              }}
            >
              {textLayers.map((layer, i) => {
                const x = parseFloat(layer.x) || 0
                const y = parseFloat(layer.y) || 0
                const w = parseFloat(layer.width) || (ad.width * 0.4)
                const h = parseFloat(layer.height) || (parseFloat(layer.font_size) || 20) * 1.5
                const isSelected = selectedLayerId === layer.id
                return (
                  <g
                    key={layer.id || i}
                    style={{ cursor: 'pointer' }}
                    onClick={() => setSelectedLayerId(isSelected ? null : layer.id)}
                  >
                    <rect
                      x={x}
                      y={y}
                      width={w}
                      height={h}
                      fill="#00b4d8"
                      fillOpacity={isSelected ? 0.35 : 0.12}
                      stroke={isSelected ? '#00b4d8' : 'rgba(255,255,255,0.6)'}
                      strokeWidth={isSelected ? 3 : 1.5}
                      strokeDasharray={isSelected ? 'none' : '6 3'}
                      rx={3}
                    />
                    {isSelected && (
                      <text
                        x={x + 4}
                        y={y + 14}
                        fill="#00b4d8"
                        fontSize="11"
                        fontWeight="600"
                        fontFamily="sans-serif"
                      >
                        {layer.role?.toUpperCase()}
                      </text>
                    )}
                  </g>
                )
              })}
              {imageLayers.map((layer, i) => {
                const x = parseFloat(layer.x) || 0
                const y = parseFloat(layer.y) || 0
                const w = parseFloat(layer.width) || 60
                const h = parseFloat(layer.height) || 60
                const isSelected = selectedLayerId === layer.id
                return (
                  <g
                    key={layer.id || `img-${i}`}
                    style={{ cursor: 'pointer' }}
                    onClick={() => setSelectedLayerId(isSelected ? null : layer.id)}
                  >
                    <rect
                      x={x}
                      y={y}
                      width={w}
                      height={h}
                      fill="#0d6efd"
                      fillOpacity={isSelected ? 0.35 : 0.12}
                      stroke={isSelected ? '#0d6efd' : 'rgba(255,255,255,0.6)'}
                      strokeWidth={isSelected ? 3 : 1.5}
                      strokeDasharray={isSelected ? 'none' : '6 3'}
                      rx={3}
                    />
                    {isSelected && (
                      <text
                        x={x + 4}
                        y={y + 14}
                        fill="#0d6efd"
                        fontSize="11"
                        fontWeight="600"
                        fontFamily="sans-serif"
                      >
                        {layer.role?.toUpperCase() || 'LOGO'}
                      </text>
                    )}
                  </g>
                )
              })}
            </svg>
          </div>
        ) : (
          <div className="border rounded d-flex align-items-center justify-content-center text-muted" style={{ minHeight: 300 }}>
            <div className="text-center">
              <i className="bi bi-image fs-2 d-block mb-2"></i>
              <small>No SVG preview available</small>
            </div>
          </div>
        )}
      </div>

      {/* Right: classification controls */}
      <div className="col-lg-6">
        <div className="d-flex align-items-center justify-content-between mb-2">
          <label className="form-label fw-semibold small text-uppercase text-muted mb-0">
            Element Roles
          </label>
          {hasLowConfidence && (
            <span className="badge bg-warning text-dark">
              <i className="bi bi-exclamation-triangle me-1"></i>
              Some elements need review
            </span>
          )}
        </div>

        <div className="border rounded" style={{ maxHeight: 500, overflowY: 'auto' }}>
          {textLayers.map((layer, i) => {
            const globalIndex = layers.indexOf(layer)
            const conf = confidenceLabel(layer.confidence || 0)
            const isSelected = selectedLayerId === layer.id
            return (
              <div
                key={layer.id || i}
                className={`d-flex align-items-start gap-3 p-3 ${i < textLayers.length - 1 ? 'border-bottom' : ''}`}
                style={{
                  cursor: 'pointer',
                  backgroundColor: isSelected ? 'rgba(0, 180, 216, 0.08)' : 'transparent',
                  borderLeft: isSelected ? '3px solid #00b4d8' : '3px solid transparent',
                  transition: 'background-color 0.15s, border-color 0.15s',
                }}
                onClick={() => setSelectedLayerId(isSelected ? null : layer.id)}
              >
                {/* Content + metadata */}
                <div className="flex-grow-1 min-width-0">
                  <div className="d-flex align-items-center gap-2 mb-1">
                    <span className="small fw-semibold text-truncate" style={{ maxWidth: 200 }}>
                      {layer.content}
                    </span>
                    {layer.font_size && (
                      <span className="badge bg-light text-dark border" style={{ fontSize: '0.65rem' }}>
                        {layer.font_size}px
                      </span>
                    )}
                    <span className={`small ${conf.className}`} style={{ fontSize: '0.7rem' }}>
                      {conf.text}
                    </span>
                  </div>
                  <small className="text-muted d-block" style={{ fontSize: '0.75rem' }}>
                    {layer.id}
                    {layer.x && layer.y && ` · (${layer.x}, ${layer.y})`}
                  </small>
                </div>

                {/* Role dropdown */}
                <select
                  className="form-select form-select-sm flex-shrink-0"
                  style={{ width: 130 }}
                  value={layer.role || ''}
                  onChange={(e) => { e.stopPropagation(); updateRole(globalIndex, e.target.value) }}
                >
                  {ROLE_OPTIONS.map((opt) => (
                    <option key={opt.value} value={opt.value}>{opt.label}</option>
                  ))}
                </select>
              </div>
            )
          })}

          {imageLayers.length > 0 && (
            <>
              <div className="px-3 py-2 bg-light border-bottom border-top">
                <small className="text-muted fw-semibold">Image Elements</small>
              </div>
              {imageLayers.map((layer, i) => {
                const globalIndex = layers.indexOf(layer)
                const isSelected = selectedLayerId === layer.id
                return (
                  <div
                    key={layer.id || `img-${i}`}
                    className="d-flex align-items-center gap-3 p-3 border-bottom"
                    style={{
                      cursor: 'pointer',
                      backgroundColor: isSelected ? 'rgba(13, 110, 253, 0.08)' : 'transparent',
                      borderLeft: isSelected ? '3px solid #0d6efd' : '3px solid transparent',
                      transition: 'background-color 0.15s, border-color 0.15s',
                    }}
                    onClick={() => setSelectedLayerId(isSelected ? null : layer.id)}
                  >
                    <div
                      className="rounded-circle flex-shrink-0"
                      style={{ width: 12, height: 12, backgroundColor: roleColor(layer.role) }}
                    />
                    <div className="flex-grow-1">
                      <div className="d-flex align-items-center gap-2 mb-1">
                        <span className="small fw-semibold">
                          <i className="bi bi-image me-1"></i>Image
                        </span>
                        {layer.width && layer.height && (
                          <span className="badge bg-light text-dark border" style={{ fontSize: '0.65rem' }}>
                            {layer.width}×{layer.height}
                          </span>
                        )}
                      </div>
                      <small className="text-muted d-block" style={{ fontSize: '0.75rem' }}>
                        {layer.id}
                        {layer.x && layer.y && ` · (${layer.x}, ${layer.y})`}
                      </small>
                    </div>
                    <select
                      className="form-select form-select-sm flex-shrink-0"
                      style={{ width: 130 }}
                      value={layer.role || 'logo'}
                      onChange={(e) => { e.stopPropagation(); updateRole(globalIndex, e.target.value) }}
                    >
                      {ROLE_OPTIONS.map((opt) => (
                        <option key={opt.value} value={opt.value}>{opt.label}</option>
                      ))}
                    </select>
                  </div>
                )
              })}
            </>
          )}

          {otherLayers.length > 0 && (
            <>
              <div className="px-3 py-2 bg-light border-bottom border-top">
                <small className="text-muted fw-semibold">Non-text Elements</small>
              </div>
              {otherLayers.map((layer, i) => {
                const globalIndex = layers.indexOf(layer)
                return (
                  <div key={layer.id || `other-${i}`} className="d-flex align-items-center gap-3 p-3 border-bottom">
                    <div
                      className="rounded-circle flex-shrink-0"
                      style={{ width: 12, height: 12, backgroundColor: roleColor(layer.role) }}
                    />
                    <div className="flex-grow-1">
                      <small className="text-muted">{layer.id} · {layer.type}</small>
                    </div>
                    <select
                      className="form-select form-select-sm flex-shrink-0"
                      style={{ width: 130 }}
                      value={layer.role || 'decoration'}
                      onChange={(e) => updateRole(globalIndex, e.target.value)}
                    >
                      {ROLE_OPTIONS.map((opt) => (
                        <option key={opt.value} value={opt.value}>{opt.label}</option>
                      ))}
                    </select>
                  </div>
                )
              })}
            </>
          )}
        </div>

        {/* Ask AI stub */}
        <div className="mt-3 d-flex align-items-center gap-2">
          <button className="btn btn-outline-secondary btn-sm" disabled title="Coming soon — AI-assisted classification">
            <i className="bi bi-stars me-1"></i>Ask AI
          </button>
          <small className="text-muted">AI-assisted classification coming soon</small>
        </div>

        {/* Confirm button */}
        <div className="mt-4">
          <button
            className="btn btn-danger"
            onClick={handleConfirm}
            disabled={confirming}
          >
            {confirming ? (
              <><span className="spinner-border spinner-border-sm me-1" />Confirming…</>
            ) : (
              <><i className="bi bi-check-lg me-1"></i>Confirm &amp; Continue</>
            )}
          </button>
        </div>
      </div>
    </div>
  )
}
