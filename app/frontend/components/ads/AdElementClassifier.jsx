import React, { useState, useEffect } from 'react'
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
  const [hoveredLayerId, setHoveredLayerId] = useState(null)

  useEffect(() => {
    if (!ad?.id) return
    apiFetch(`/api/clients/${clientId}/ads/${ad.id}/classifications`)
      .then((data) => {
        setLayers(data.classified_layers || [])
      })
      .catch(() => {})
      .finally(() => setLoading(false))
  }, [ad?.id, clientId])

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
  const otherLayers = layers.filter((l) => l.type !== 'text' || !l.content)
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
        <label className="form-label fw-semibold small text-uppercase text-muted mb-2">
          Element Preview
        </label>
        {ad.svg_url ? (
          <div className="position-relative border rounded overflow-hidden" style={{ background: '#1a1a1a' }}>
            <img
              src={ad.svg_url}
              alt={ad.name}
              style={{ display: 'block', width: '100%', height: 'auto', opacity: 0.4 }}
            />
            {/* Overlay layer highlights */}
            <svg
              viewBox={`0 0 ${ad.width || 100} ${ad.height || 100}`}
              style={{ position: 'absolute', inset: 0, width: '100%', height: '100%' }}
            >
              {textLayers.map((layer, i) => {
                const x = parseFloat(layer.x) || 0
                const y = parseFloat(layer.y) || 0
                const w = parseFloat(layer.width) || (ad.width * 0.4)
                const h = parseFloat(layer.height) || (parseFloat(layer.font_size) || 20) * 1.5
                const isHovered = hoveredLayerId === layer.id
                const color = roleColor(layer.role)
                return (
                  <g key={layer.id || i}>
                    <rect
                      x={x}
                      y={y - h + (parseFloat(layer.font_size) || 20) * 0.3}
                      width={w}
                      height={h}
                      fill={color}
                      fillOpacity={isHovered ? 0.4 : 0.2}
                      stroke={color}
                      strokeWidth={isHovered ? 3 : 1.5}
                      strokeDasharray={isHovered ? 'none' : '4 2'}
                      rx={3}
                    />
                    <text
                      x={x + 4}
                      y={y - h + (parseFloat(layer.font_size) || 20) * 0.3 + 12}
                      fill={color}
                      fontSize="11"
                      fontWeight="600"
                      fontFamily="sans-serif"
                    >
                      {layer.role?.toUpperCase()}
                    </text>
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
            return (
              <div
                key={layer.id || i}
                className={`d-flex align-items-start gap-3 p-3 ${i < textLayers.length - 1 ? 'border-bottom' : ''}`}
                style={{ cursor: 'pointer' }}
                onMouseEnter={() => setHoveredLayerId(layer.id)}
                onMouseLeave={() => setHoveredLayerId(null)}
              >
                {/* Role color indicator */}
                <div
                  className="rounded-circle flex-shrink-0 mt-1"
                  style={{ width: 12, height: 12, backgroundColor: roleColor(layer.role) }}
                />

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
                  style={{ width: 130, borderColor: roleColor(layer.role) }}
                  value={layer.role || ''}
                  onChange={(e) => updateRole(globalIndex, e.target.value)}
                >
                  {ROLE_OPTIONS.map((opt) => (
                    <option key={opt.value} value={opt.value}>{opt.label}</option>
                  ))}
                </select>
              </div>
            )
          })}

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
