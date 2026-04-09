import React, { useState, useEffect, useRef } from 'react'
import { apiFetch, apiUpload } from '~/lib/api'

const ROLE_OPTIONS = [
  { value: 'headline', label: 'Headline', color: '#dc3545' },
  { value: 'subhead', label: 'Subhead', color: '#fd7e14' },
  { value: 'body', label: 'Body', color: '#6c757d' },
  { value: 'cta', label: 'CTA', color: '#198754' },
  { value: 'wordmark', label: 'Wordmark', color: '#20c997' },
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
  const [bboxByLayerId, setBboxByLayerId] = useState({})
  const [viewMode, setViewMode] = useState('fit') // 'fit' or 'natural'
  const [uploadingLogo, setUploadingLogo] = useState(false)
  const [logoUrl, setLogoUrl] = useState(ad?.logo_url || null)
  const [askingAi, setAskingAi] = useState(false)
  const [aiError, setAiError] = useState(null)
  const svgContainerRef = useRef(null)
  const logoInputRef = useRef(null)

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

    if (viewMode === 'fit') {
      svg.setAttribute('width', '100%')
      svg.removeAttribute('height')
    } else {
      svg.setAttribute('width', ad.width || svg.getAttribute('viewBox')?.split(' ')[2] || '100%')
      svg.setAttribute('height', ad.height || svg.getAttribute('viewBox')?.split(' ')[3] || 'auto')
    }

    setSvgMarkup(svg.outerHTML)
  }, [rawSvg, viewMode])

  // After the SVG markup is mounted, compute actual bounding boxes for each text/image
  // element. Using getBBox() handles text-anchor, font metrics, and transforms correctly,
  // avoiding the offset bug where centered button labels appear shifted because the parser
  // stores the raw x attribute (which for text-anchor="middle" is the center, not left edge).
  useEffect(() => {
    if (!svgMarkup || !svgContainerRef.current || layers.length === 0) return
    const svgEl = svgContainerRef.current.querySelector('svg')
    if (!svgEl) return

    const textNodes = Array.from(svgEl.querySelectorAll('text'))
    const imageNodes = Array.from(svgEl.querySelectorAll('image'))
    const map = {}

    // Match by id when available; otherwise fall back to content+order for text.
    const usedTextNodes = new Set()
    layers.forEach((layer) => {
      if (layer.type !== 'text' || !layer.content) return
      let node = null
      if (layer.id) node = svgEl.querySelector(`#${CSS.escape(layer.id)}`)
      if (!node) {
        node = textNodes.find(
          (n) => !usedTextNodes.has(n) && n.textContent.trim() === layer.content.trim()
        )
      }
      if (!node) return
      usedTextNodes.add(node)
      try {
        const b = node.getBBox()
        map[layer.id] = { x: b.x, y: b.y, width: b.width, height: b.height }
      } catch (_) {}
    })

    const usedImageNodes = new Set()
    layers.forEach((layer) => {
      if (layer.type !== 'image') return
      let node = null
      if (layer.id) node = svgEl.querySelector(`#${CSS.escape(layer.id)}`)
      if (!node) {
        node = imageNodes.find((n) => !usedImageNodes.has(n))
      }
      if (!node) return
      usedImageNodes.add(node)
      try {
        const b = node.getBBox()
        map[layer.id] = { x: b.x, y: b.y, width: b.width, height: b.height }
      } catch (_) {}
    })

    setBboxByLayerId(map)
  }, [svgMarkup, layers])

  const updateRole = (index, newRole) => {
    setLayers((prev) => prev.map((l, i) => {
      if (i !== index) return l
      const next = { ...l, role: newRole, confidence: 1.0 }
      // Joining the wordmark family: default to a solo group (self-id) so
      // the layer is laid out as a wordmark even before being grouped.
      if (newRole === 'wordmark' && !next.wordmark_group_id) {
        next.wordmark_group_id = next.id
      }
      // Leaving the wordmark family: drop the group membership so we don't
      // ship stale group_ids on non-wordmark roles.
      if (newRole !== 'wordmark' && next.wordmark_group_id) {
        delete next.wordmark_group_id
      }
      return next
    }))
  }

  const setWordmarkGroup = (index, groupId) => {
    setLayers((prev) => prev.map((l, i) =>
      i === index ? { ...l, wordmark_group_id: groupId } : l
    ))
  }

  const toggleContinuation = (index) => {
    setLayers((prev) => {
      const target = prev[index]
      const isContinuation = !!target.continuation_of
      if (isContinuation) {
        return prev.map((l, i) => {
          if (i !== index) return l
          const { continuation_of, ...rest } = l
          return rest
        })
      }
      // Default to the immediately preceding text layer
      let prevTextLayer = null
      for (let i = index - 1; i >= 0; i--) {
        if (prev[i].type === 'text' && prev[i].content) {
          prevTextLayer = prev[i]
          break
        }
      }
      if (!prevTextLayer) return prev
      return prev.map((l, i) =>
        i === index
          ? { ...l, continuation_of: prevTextLayer.id, role: prevTextLayer.role || l.role }
          : l
      )
    })
  }

  const setContinuationOf = (index, parentId) => {
    setLayers((prev) => {
      const parent = prev.find((l) => l.id === parentId)
      if (!parent) return prev
      return prev.map((l, i) =>
        i === index
          ? { ...l, continuation_of: parentId, role: parent.role || l.role }
          : l
      )
    })
  }

  const handleAskAi = async () => {
    setAskingAi(true)
    setAiError(null)
    try {
      const data = await apiFetch(`/api/clients/${clientId}/ads/${ad.id}/ai_classify`, {
        method: 'POST',
      })
      setLayers(data.classified_layers || [])
    } catch (e) {
      setAiError(e.message || 'AI classification failed')
    } finally {
      setAskingAi(false)
    }
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

  const handleLogoUpload = async (e) => {
    const file = e.target.files?.[0]
    if (!file) return

    if (!file.type.includes('png')) {
      alert('Please upload a PNG file (transparent PNG recommended)')
      return
    }

    setUploadingLogo(true)
    try {
      const formData = new FormData()
      formData.append('logo', file)
      const data = await apiUpload(`/api/clients/${clientId}/ads/${ad.id}/upload_logo`, formData)
      setLayers(data.classified_layers || [])
      setLogoUrl(data.logo_url || null)
    } catch (err) {
      alert(err.message || 'Failed to upload logo')
    } finally {
      setUploadingLogo(false)
      if (logoInputRef.current) logoInputRef.current.value = ''
    }
  }

  const handleRemoveLogo = async () => {
    try {
      const data = await apiFetch(`/api/clients/${clientId}/ads/${ad.id}/remove_logo`, {
        method: 'DELETE',
      })
      setLayers(data.classified_layers || [])
      setLogoUrl(null)
    } catch (err) {
      alert(err.message || 'Failed to remove logo')
    }
  }

  const textLayers = layers.filter((l) => l.type === 'text' && l.content)
  const imageLayers = layers.filter((l) => l.type === 'image')
  const otherLayers = layers.filter((l) => (l.type !== 'text' || !l.content) && l.type !== 'image')
  const hasLogo = layers.some((l) => l.role === 'logo' || l.type === 'image')
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
                // Prefer the actual rendered bbox (handles text-anchor, fonts, transforms).
                const bbox = bboxByLayerId[layer.id]
                let x, y, w, h
                if (bbox) {
                  x = bbox.x; y = bbox.y; w = bbox.width; h = bbox.height
                } else {
                  x = parseFloat(layer.x) || 0
                  const fontSize = parseFloat(layer.font_size) || 20
                  const hasExplicitHeight = !!layer.height
                  h = hasExplicitHeight ? parseFloat(layer.height) : fontSize * 1.4
                  y = hasExplicitHeight ? parseFloat(layer.y) || 0 : (parseFloat(layer.y) || 0) - fontSize
                  w = parseFloat(layer.width) || Math.max(fontSize * 0.6 * (layer.content?.length || 5), 30)
                }
                const isSelected = selectedLayerId === layer.id
                const pad = 3
                return (
                  <g
                    key={layer.id || i}
                    style={{ cursor: 'pointer' }}
                    onClick={() => setSelectedLayerId(isSelected ? null : layer.id)}
                  >
                    <rect
                      x={x - pad}
                      y={y - pad}
                      width={w + pad * 2}
                      height={h + pad * 2}
                      fill="transparent"
                      stroke={isSelected ? '#00b4d8' : 'none'}
                      strokeWidth={isSelected ? 2 : 0}
                      rx={2}
                    />
                  </g>
                )
              })}
              {imageLayers.map((layer, i) => {
                const bbox = bboxByLayerId[layer.id]
                const x = bbox ? bbox.x : (parseFloat(layer.x) || 0)
                const y = bbox ? bbox.y : (parseFloat(layer.y) || 0)
                const w = bbox ? bbox.width : (parseFloat(layer.width) || 60)
                const h = bbox ? bbox.height : (parseFloat(layer.height) || 60)
                const isSelected = selectedLayerId === layer.id
                const isUploaded = layer.id === 'uploaded_logo'
                const pad = 3
                return (
                  <g
                    key={layer.id || `img-${i}`}
                    style={{ cursor: 'pointer' }}
                    onClick={() => setSelectedLayerId(isSelected ? null : layer.id)}
                  >
                    {isUploaded && logoUrl && (
                      <image
                        href={logoUrl}
                        x={x}
                        y={y}
                        width={w}
                        height={h}
                        preserveAspectRatio="xMidYMid meet"
                        style={{ pointerEvents: 'none' }}
                      />
                    )}
                    <rect
                      x={x - pad}
                      y={y - pad}
                      width={w + pad * 2}
                      height={h + pad * 2}
                      fill="transparent"
                      stroke={isSelected ? '#0d6efd' : 'none'}
                      strokeWidth={isSelected ? 2 : 0}
                      rx={2}
                    />
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
            const isContinuation = !!layer.continuation_of
            // All preceding text layers are eligible parents
            const candidateParents = []
            for (let j = 0; j < globalIndex; j++) {
              if (layers[j].type === 'text' && layers[j].content) {
                candidateParents.push(layers[j])
              }
            }
            const canContinue = candidateParents.length > 0
            const currentParent = isContinuation
              ? candidateParents.find((p) => p.id === layer.continuation_of)
              : null
            return (
              <div
                key={layer.id || i}
                className={`d-flex align-items-start gap-3 p-3 ${i < textLayers.length - 1 ? 'border-bottom' : ''}`}
                style={{
                  cursor: 'pointer',
                  backgroundColor: isSelected ? 'rgba(0, 180, 216, 0.08)' : 'transparent',
                  borderLeft: isSelected ? '3px solid #00b4d8' : '3px solid transparent',
                  paddingLeft: isContinuation ? '2.25rem' : undefined,
                  transition: 'background-color 0.15s, border-color 0.15s',
                }}
                onClick={() => setSelectedLayerId(isSelected ? null : layer.id)}
              >
                {/* Content + metadata */}
                <div className="flex-grow-1 min-width-0">
                  <div className="d-flex align-items-center gap-2 mb-1">
                    {isContinuation && (
                      <span className="text-muted" style={{ fontSize: '0.85rem' }} title="Continuation of previous element">↳</span>
                    )}
                    <span className="small fw-semibold text-truncate" style={{ maxWidth: 200 }}>
                      {layer.content}
                    </span>
                    {layer.font_size && (
                      <span className="badge bg-light text-dark border" style={{ fontSize: '0.65rem' }}>
                        {layer.font_size}px
                      </span>
                    )}
                    {!isContinuation && (
                      <span className={`small ${conf.className}`} style={{ fontSize: '0.7rem' }}>
                        {conf.text}
                      </span>
                    )}
                  </div>
                  <small className="text-muted d-block" style={{ fontSize: '0.75rem' }}>
                    {layer.id}
                    {layer.x && layer.y && ` · (${layer.x}, ${layer.y})`}
                  </small>
                  {canContinue && (
                    <div className="mt-1" onClick={(e) => e.stopPropagation()}>
                      <div className="form-check d-inline-block me-2">
                        <input
                          className="form-check-input"
                          type="checkbox"
                          id={`continues-${layer.id}`}
                          checked={isContinuation}
                          onChange={() => toggleContinuation(globalIndex)}
                        />
                        <label
                          className="form-check-label text-muted"
                          htmlFor={`continues-${layer.id}`}
                          style={{ fontSize: '0.7rem' }}
                        >
                          Continues from
                        </label>
                      </div>
                      {isContinuation && (
                        <select
                          className="form-select form-select-sm d-inline-block"
                          style={{ width: 'auto', maxWidth: 220, fontSize: '0.7rem' }}
                          value={layer.continuation_of || ''}
                          onChange={(e) => setContinuationOf(globalIndex, e.target.value)}
                        >
                          {!currentParent && layer.continuation_of && (
                            <option value={layer.continuation_of}>(unknown)</option>
                          )}
                          {candidateParents.map((p) => {
                            const label = (p.content || '').slice(0, 40)
                            return (
                              <option key={p.id} value={p.id}>
                                {label}{(p.content || '').length > 40 ? '…' : ''}
                              </option>
                            )
                          })}
                        </select>
                      )}
                    </div>
                  )}
                </div>

                {/* Wordmark group control — visible only for wordmark layers */}
                {layer.role === 'wordmark' && (
                  <div onClick={(e) => e.stopPropagation()} className="flex-shrink-0">
                    <select
                      className="form-select form-select-sm"
                      style={{ width: 140, fontSize: '0.7rem' }}
                      title="Wordmark group — members lay out together"
                      value={layer.wordmark_group_id || layer.id}
                      onChange={(e) => setWordmarkGroup(globalIndex, e.target.value)}
                    >
                      <option value={layer.id}>Solo group</option>
                      {textLayers
                        .filter((tl) => tl.id !== layer.id && tl.role === 'wordmark')
                        .map((tl) => (
                          <option key={tl.id} value={tl.wordmark_group_id || tl.id}>
                            Join: {(tl.content || '').slice(0, 18)}
                          </option>
                        ))}
                    </select>
                  </div>
                )}

                {/* Role dropdown — disabled when this row inherits role from chain head */}
                <select
                  className="form-select form-select-sm flex-shrink-0"
                  style={{ width: 130, opacity: isContinuation ? 0.5 : 1 }}
                  value={layer.role || ''}
                  disabled={isContinuation}
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

        {/* Logo upload */}
        <div className="mt-3">
          {!hasLogo ? (
            <div className="border rounded p-3 text-center" style={{ borderStyle: 'dashed !important', background: '#f8f9fa' }}>
              <i className="bi bi-image fs-4 d-block mb-2 text-muted"></i>
              <p className="small text-muted mb-2">
                No logo detected in this file. If your logo is part of the background, it will be replaced when the background is swapped.
              </p>
              <input
                ref={logoInputRef}
                type="file"
                accept="image/png"
                className="d-none"
                onChange={handleLogoUpload}
              />
              <button
                className="btn btn-outline-primary btn-sm"
                onClick={() => logoInputRef.current?.click()}
                disabled={uploadingLogo}
              >
                {uploadingLogo ? (
                  <><span className="spinner-border spinner-border-sm me-1" />Uploading…</>
                ) : (
                  <><i className="bi bi-upload me-1"></i>Upload Logo (PNG)</>
                )}
              </button>
            </div>
          ) : (
            <div className="d-flex align-items-center gap-2">
              <input
                ref={logoInputRef}
                type="file"
                accept="image/png"
                className="d-none"
                onChange={handleLogoUpload}
              />
              <button
                className="btn btn-outline-secondary btn-sm"
                onClick={() => logoInputRef.current?.click()}
                disabled={uploadingLogo}
              >
                <i className="bi bi-arrow-repeat me-1"></i>Replace Logo
              </button>
              {layers.some((l) => l.id === 'uploaded_logo') && (
                <button
                  className="btn btn-outline-danger btn-sm"
                  onClick={handleRemoveLogo}
                >
                  <i className="bi bi-trash me-1"></i>Remove
                </button>
              )}
            </div>
          )}
        </div>

        {/* Ask AI */}
        <div className="mt-3">
          <div className="d-flex align-items-center gap-2">
            <button
              className="btn btn-outline-secondary btn-sm"
              onClick={handleAskAi}
              disabled={askingAi}
              title="Use AI to classify roles and detect continuation chains"
            >
              {askingAi ? (
                <><span className="spinner-border spinner-border-sm me-1" />Asking AI…</>
              ) : (
                <><i className="bi bi-stars me-1"></i>Ask AI</>
              )}
            </button>
            <small className="text-muted">
              Re-classify roles and detect multi-line sentence continuations
            </small>
          </div>
          {aiError && (
            <div className="alert alert-warning py-2 px-3 mt-2 mb-0 small">
              {aiError}
            </div>
          )}
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
