import React, { useState } from 'react'
import { PLATFORMS, PLATFORM_NAMES, deduplicatedSizes } from '~/lib/platformSizes'

export default function AdResizePicker({
  ad,
  selectedPlatforms,
  onPlatformsChange,
  resizes,
  onGenerateResizes,
  onEditResize,
  onContinue,
  onSkip,
  resizing,
}) {
  const [expandedPlatform, setExpandedPlatform] = useState(null)

  const togglePlatform = (name) => {
    const next = selectedPlatforms.includes(name)
      ? selectedPlatforms.filter((p) => p !== name)
      : [...selectedPlatforms, name]
    onPlatformsChange(next)
  }

  const deduped = deduplicatedSizes(selectedPlatforms)
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
            const isSelected = selectedPlatforms.includes(name)

            return (
              <div key={name} className="mb-2">
                <div className="d-flex align-items-center gap-2">
                  <div className="form-check mb-0">
                    <input
                      className="form-check-input"
                      type="checkbox"
                      id={`plat-${name}`}
                      checked={isSelected}
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
                    {sizes.map((s) => (
                      <div key={`${name}-${s.name}`} className="d-flex justify-content-between">
                        <small className="text-muted">{s.name}</small>
                        <small className="text-muted">{s.width}x{s.height}</small>
                      </div>
                    ))}
                  </div>
                )}
              </div>
            )
          })}
        </div>

        {selectedPlatforms.length > 0 && (
          <div className="mb-3">
            <small className="text-muted">
              {deduped.length} unique size{deduped.length !== 1 ? 's' : ''} will be generated
              {deduped.length < selectedPlatforms.reduce((n, p) => n + (PLATFORMS[p]?.length || 0), 0) && (
                <span> (duplicates merged)</span>
              )}
            </small>
          </div>
        )}

        <div className="d-flex flex-column gap-2">
          <button
            className="btn btn-danger btn-sm"
            onClick={onGenerateResizes}
            disabled={resizing || selectedPlatforms.length === 0}
          >
            {resizing ? (
              <><span className="spinner-border spinner-border-sm me-1" />Generating Resizes…</>
            ) : (
              <><i className="bi bi-aspect-ratio me-1"></i>Generate Resizes</>
            )}
          </button>

          {allResized && (
            <button className="btn btn-success btn-sm" onClick={onContinue}>
              <i className="bi bi-arrow-right me-1"></i>Continue to Versioning
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
