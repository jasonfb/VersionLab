import React, { useState } from 'react'
import { PLATFORMS, PLATFORM_NAMES, deduplicatedSizes } from '~/lib/platformSizes'

export default function AdResizePicker({
  ad,
  selectedPlatforms,
  onPlatformsChange,
  customSizes,
  onCustomSizesChange,
  resizes,
  onGenerateResizes,
  onEditResize,
  onRebuildResize,
  onContinue,
  onSkip,
  resizing,
}) {
  const [expandedPlatform, setExpandedPlatform] = useState(null)

  // selectedPlatforms is { [platformName]: sizeName[] }
  // e.g. { "Facebook (Meta)": ["Feed Image", "Story"], "Google Display": ["Leaderboard"] }

  const allSizeNames = (platformName) => (PLATFORMS[platformName] || []).map((s) => s.name)

  const selectedSizes = (platformName) => selectedPlatforms[platformName] || []

  const isFullySelected = (platformName) => {
    const sel = selectedSizes(platformName)
    const all = allSizeNames(platformName)
    return all.length > 0 && sel.length === all.length
  }

  const isPartiallySelected = (platformName) => {
    const sel = selectedSizes(platformName)
    return sel.length > 0 && sel.length < allSizeNames(platformName).length
  }

  const togglePlatform = (name) => {
    const next = { ...selectedPlatforms }
    if (isFullySelected(name) || isPartiallySelected(name)) {
      // Turn off entirely
      delete next[name]
    } else {
      // Turn on all sizes
      next[name] = allSizeNames(name)
    }
    onPlatformsChange(next)
  }

  const toggleSize = (platformName, sizeName) => {
    const current = selectedSizes(platformName)
    const next = { ...selectedPlatforms }
    if (current.includes(sizeName)) {
      const remaining = current.filter((s) => s !== sizeName)
      if (remaining.length === 0) {
        delete next[platformName]
      } else {
        next[platformName] = remaining
      }
    } else {
      next[platformName] = [...current, sizeName]
    }
    onPlatformsChange(next)
  }

  const addCustomSize = () => {
    onCustomSizesChange([...customSizes, { label: '', width: '', height: '' }])
  }

  const updateCustomSize = (index, field, value) => {
    const updated = customSizes.map((cs, i) =>
      i === index ? { ...cs, [field]: field === 'label' ? value : (parseInt(value, 10) || '') } : cs
    )
    onCustomSizesChange(updated)
  }

  const removeCustomSize = (index) => {
    onCustomSizesChange(customSizes.filter((_, i) => i !== index))
  }

  const validCustomSizes = customSizes.filter((cs) => cs.width > 0 && cs.height > 0)

  const deduped = deduplicatedSizes(selectedPlatforms, validCustomSizes)
  const resizedCount = resizes.filter((r) => r.state === 'resized').length
  const allResized = resizes.length > 0 && resizedCount === resizes.length

  return (
    <div className="row g-4">
      {/* Left panel: Platform selection */}
      <div className="col-lg-5">
        <label className="form-label fw-semibold small text-uppercase text-muted">
          Select Platforms
        </label>

        <div className="border rounded p-3 mb-3" style={{ maxHeight: 400, overflowY: 'auto' }}>
          {PLATFORM_NAMES.map((name) => {
            const sizes = PLATFORMS[name]
            const isExpanded = expandedPlatform === name
            const full = isFullySelected(name)
            const partial = isPartiallySelected(name)
            const hasSel = full || partial

            return (
              <div key={name} className="mb-2">
                <div className="d-flex align-items-center gap-2">
                  <div className="form-check mb-0">
                    <input
                      className="form-check-input"
                      type="checkbox"
                      id={`plat-${name}`}
                      checked={hasSel}
                      ref={(el) => { if (el) el.indeterminate = partial }}
                      onChange={() => togglePlatform(name)}
                    />
                    <label className="form-check-label fw-medium" htmlFor={`plat-${name}`}>
                      {name}
                    </label>
                  </div>
                  <button
                    className="btn btn-sm btn-link p-0 text-muted"
                    onClick={() => setExpandedPlatform(isExpanded ? null : name)}
                    title="Show sizes"
                  >
                    <i className={`bi bi-chevron-${isExpanded ? 'up' : 'down'}`}></i>
                  </button>
                </div>
                {isExpanded && (
                  <div className="ms-4 mt-1">
                    {sizes.map((s) => {
                      const sizeSelected = selectedSizes(name).includes(s.name)
                      const sizeId = `size-${name}-${s.name}`
                      return (
                        <div key={sizeId} className="d-flex align-items-center justify-content-between">
                          <div className="form-check mb-0">
                            <input
                              className="form-check-input"
                              type="checkbox"
                              id={sizeId}
                              checked={sizeSelected}
                              onChange={() => toggleSize(name, s.name)}
                            />
                            <label className="form-check-label" htmlFor={sizeId}>
                              <small className="text-muted">{s.name}</small>
                            </label>
                          </div>
                          <small className="text-muted">{s.width}x{s.height}</small>
                        </div>
                      )
                    })}
                  </div>
                )}
              </div>
            )
          })}
        </div>

        <div className="mb-3">
          <label className="form-label fw-semibold small text-uppercase text-muted">
            Custom Sizes
          </label>
          {customSizes.map((cs, i) => (
            <div key={i} className="d-flex align-items-center gap-2 mb-2">
              <input
                type="text"
                className="form-control form-control-sm"
                placeholder="Label (optional)"
                value={cs.label}
                onChange={(e) => updateCustomSize(i, 'label', e.target.value)}
                style={{ flex: 2 }}
              />
              <input
                type="number"
                className="form-control form-control-sm"
                placeholder="Width"
                value={cs.width}
                onChange={(e) => updateCustomSize(i, 'width', e.target.value)}
                min="1"
                style={{ flex: 1 }}
              />
              <span className="text-muted small">x</span>
              <input
                type="number"
                className="form-control form-control-sm"
                placeholder="Height"
                value={cs.height}
                onChange={(e) => updateCustomSize(i, 'height', e.target.value)}
                min="1"
                style={{ flex: 1 }}
              />
              <button
                className="btn btn-sm btn-outline-secondary p-1"
                onClick={() => removeCustomSize(i)}
                title="Remove"
              >
                <i className="bi bi-x"></i>
              </button>
            </div>
          ))}
          <button className="btn btn-sm btn-outline-secondary" onClick={addCustomSize}>
            <i className="bi bi-plus me-1"></i>Add Custom Size
          </button>
        </div>

        {(Object.keys(selectedPlatforms).length > 0 || validCustomSizes.length > 0) && (
          <div className="mb-3">
            <small className="text-muted">
              {deduped.length} unique size{deduped.length !== 1 ? 's' : ''} will be generated
              {deduped.length < Object.entries(selectedPlatforms).reduce((n, [, sizes]) => n + sizes.length, 0) + validCustomSizes.length && (
                <span> (duplicates merged)</span>
              )}
            </small>
          </div>
        )}

        <div className="d-flex flex-column gap-2">
          <button
            className="btn btn-danger btn-sm"
            onClick={onGenerateResizes}
            disabled={resizing || (Object.keys(selectedPlatforms).length === 0 && validCustomSizes.length === 0)}
          >
            {resizing ? (
              <><span className="spinner-border spinner-border-sm me-1" />Generating Resizes…</>
            ) : (
              <><i className="bi bi-aspect-ratio me-1"></i>Generate Resizes</>
            )}
          </button>

          {allResized && (
            <button className="btn btn-success btn-sm" onClick={onContinue}>
              <i className="bi bi-arrow-right me-1"></i>Continue to Styling
            </button>
          )}

          <button className="btn btn-link btn-sm text-muted p-0 text-start" onClick={onSkip}>
            Skip Resizing
          </button>
        </div>
      </div>

      {/* Right panel: Resize thumbnails */}
      <div className="col-lg-7">
        <label className="form-label fw-semibold small text-uppercase text-muted mb-2">
          Resize Previews
        </label>

        {resizes.length === 0 ? (
          <div
            className="border rounded d-flex align-items-center justify-content-center text-muted"
            style={{ minHeight: 300 }}
          >
            <div className="text-center">
              <i className="bi bi-aspect-ratio fs-2 d-block mb-2"></i>
              <small>Select platforms and generate resizes to see previews</small>
            </div>
          </div>
        ) : (
          <div className="row g-3">
            {resizes.map((resize) => (
              <div key={resize.id} className="col-sm-6 col-md-4">
                <div
                  className="card h-100 border"
                  style={{ cursor: resize.state === 'resized' ? 'pointer' : 'default' }}
                  onClick={() => resize.state === 'resized' && onEditResize(resize)}
                >
                  <div
                    className="card-img-top bg-dark d-flex align-items-center justify-content-center"
                    style={{ height: 120, overflow: 'hidden' }}
                  >
                    {resize.preview_image_url ? (
                      <img
                        src={resize.preview_image_url}
                        alt={resize.dimensions}
                        style={{ maxWidth: '100%', maxHeight: '100%', objectFit: 'contain' }}
                      />
                    ) : (
                      <div className="text-muted small">
                        {resize.state === 'pending' && (
                          <span className="spinner-border spinner-border-sm" />
                        )}
                        {resize.state === 'failed' && (
                          <i className="bi bi-exclamation-triangle text-danger"></i>
                        )}
                      </div>
                    )}
                  </div>
                  <div className="card-body p-2">
                    <div className="d-flex align-items-center justify-content-between mb-1">
                      <span className="fw-semibold small">{resize.dimensions}</span>
                      <ResizeStateBadge state={resize.state} />
                    </div>
                    <div className="text-muted" style={{ fontSize: '0.7rem', lineHeight: 1.3 }}>
                      {resize.platform_labels.map((pl, i) => (
                        <span key={i}>
                          {i > 0 && ', '}
                          {pl.platform} {pl.size_name}
                        </span>
                      ))}
                    </div>
                    {resize.state === 'resized' && (
                      <small className="text-primary d-block mt-1">
                        <i className="bi bi-pencil me-1"></i>Click to adjust
                      </small>
                    )}
                    {onRebuildResize && resize.state !== 'pending' && (
                      <button
                        type="button"
                        className="btn btn-link btn-sm p-0 mt-1 text-muted"
                        style={{ fontSize: '0.7rem' }}
                        title="Destroy and rebuild this size from current classifications"
                        onClick={(e) => {
                          e.stopPropagation()
                          onRebuildResize(resize)
                        }}
                      >
                        <i className="bi bi-arrow-clockwise me-1"></i>Rebuild
                      </button>
                    )}
                  </div>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  )
}

function ResizeStateBadge({ state }) {
  const colors = { pending: 'warning text-dark', resized: 'success', failed: 'danger' }
  return <span className={`badge bg-${colors[state] || 'secondary'}`} style={{ fontSize: '0.65rem' }}>{state}</span>
}
