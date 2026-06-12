import React, { useState, useMemo } from 'react'
import { apiFetch } from '~/lib/api'

function AdBackgroundPicker({ ad, clientId, resizes, assets, onResizeUpdate }) {
  const [pickerOpenFor, setPickerOpenFor] = useState(null) // resize id

  const bgLayer = useMemo(() => {
    return (ad.classified_layers || []).find((l) => l.type === 'background')
  }, [ad.classified_layers])

  const bgSrc = bgLayer?.href || null
  const bgWidth = parseInt(bgLayer?.width) || ad.width || 0
  const bgHeight = parseInt(bgLayer?.height) || ad.height || 0

  const imageAssets = useMemo(() => {
    return (assets || []).filter((a) => a.url && a.width && a.height)
  }, [assets])

  const assignBackground = async (resize, assetId) => {
    try {
      const data = await apiFetch(
        `/api/clients/${clientId}/ads/${ad.id}/ad_resizes/${resize.id}`,
        { method: 'PATCH', body: JSON.stringify({ background_asset_id: assetId }) }
      )
      onResizeUpdate(data)
    } catch (e) {
      console.error('Failed to assign background:', e)
    }
    setPickerOpenFor(null)
  }

  const clearBackground = async (resize) => {
    try {
      const data = await apiFetch(
        `/api/clients/${clientId}/ads/${ad.id}/ad_resizes/${resize.id}`,
        { method: 'PATCH', body: JSON.stringify({ background_asset_id: null }) }
      )
      onResizeUpdate(data)
    } catch (e) {
      console.error('Failed to clear background:', e)
    }
  }

  if (resizes.length === 0) {
    return (
      <div className="text-center py-5 text-muted">
        <p>No resizes generated yet. Go back and generate resizes first.</p>
      </div>
    )
  }

  return (
    <div>
      {/* Original background reference */}
      {bgSrc && (
        <div className="mb-4">
          <h6 className="text-uppercase text-muted small fw-semibold mb-2">
            Original Background ({bgWidth}&times;{bgHeight})
          </h6>
          <div
            className="border rounded overflow-hidden d-inline-block"
            style={{ maxWidth: 200, background: '#1a1a1a' }}
          >
            <img
              src={bgSrc}
              alt="Original background"
              style={{ display: 'block', width: '100%', height: 'auto' }}
            />
          </div>
        </div>
      )}

      {/* Per-resize background assignment */}
      <h6 className="text-uppercase text-muted small fw-semibold mb-2">
        Background per Size
      </h6>

      <div className="row g-3">
        {resizes.map((resize) => {
          const isPickerOpen = pickerOpenFor === resize.id
          const eligible = imageAssets.filter(
            (a) => a.width >= resize.width && a.height >= resize.height
          )
          const originalFits = resize.width <= bgWidth && resize.height <= bgHeight
          const hasAssigned = !!resize.background_asset_id
          const assignedAsset = hasAssigned
            ? imageAssets.find((a) => a.id === resize.background_asset_id)
            : null

          // Display label
          const displayLabel = resize.platform_labels?.map(
            (pl) => `${pl.platform} ${pl.size_name}`
          ).join(', ') || resize.dimensions

          // Preview box sizing
          const maxW = 200, maxH = 140
          const aspect = resize.width / resize.height
          const boxW = aspect >= maxW / maxH ? maxW : Math.round(maxH * aspect)
          const boxH = aspect >= maxW / maxH ? Math.round(maxW / aspect) : maxH

          // Background preview style
          let previewStyle = { width: boxW, height: boxH, backgroundColor: '#111', borderRadius: 2 }
          const previewSrc = resize.background_asset_url
            || (originalFits ? bgSrc : null)

          if (previewSrc) {
            previewStyle = {
              ...previewStyle,
              backgroundImage: `url(${previewSrc})`,
              backgroundSize: 'cover',
              backgroundPosition: 'center',
              backgroundColor: '#1a1a1a',
            }
          }

          return (
            <div key={resize.id} className="col-sm-6 col-lg-3">
              <div className="border rounded p-2 h-100">
                <div className="small fw-semibold mb-1 text-truncate" title={displayLabel}>
                  {displayLabel}
                </div>
                <div className="small text-muted mb-2">{resize.dimensions}</div>

                {/* Preview */}
                <div
                  className="mx-auto mb-2"
                  style={previewStyle}
                />

                {/* Status + action */}
                <div className="d-flex align-items-center justify-content-between gap-1">
                  {hasAssigned ? (
                    <span className="badge bg-success-subtle text-success border border-success-subtle" style={{ fontSize: '0.65rem' }}>
                      <i className="bi bi-check-circle me-1"></i>Assigned
                    </span>
                  ) : originalFits ? (
                    <span className="badge bg-success-subtle text-success border border-success-subtle" style={{ fontSize: '0.65rem' }}>
                      <i className="bi bi-check-circle me-1"></i>Original
                    </span>
                  ) : (
                    <span className="badge bg-warning-subtle text-warning border border-warning-subtle" style={{ fontSize: '0.65rem' }}>
                      <i className="bi bi-exclamation-triangle me-1"></i>Needs background
                    </span>
                  )}
                  <div className="d-flex gap-1">
                    <button
                      className="btn btn-outline-secondary btn-sm py-0 px-1"
                      style={{ fontSize: '0.65rem' }}
                      onClick={() => setPickerOpenFor(isPickerOpen ? null : resize.id)}
                    >
                      <i className="bi bi-image me-1"></i>{hasAssigned ? 'Change' : 'Pick'}
                    </button>
                    {hasAssigned && (
                      <button
                        className="btn btn-outline-danger btn-sm py-0 px-1"
                        style={{ fontSize: '0.65rem' }}
                        onClick={() => clearBackground(resize)}
                        title="Remove assigned background"
                      >
                        <i className="bi bi-x"></i>
                      </button>
                    )}
                  </div>
                </div>

                {/* Inline asset picker */}
                {isPickerOpen && (
                  <div className="mt-2 border-top pt-2">
                    <div className="small text-muted mb-1">
                      Eligible assets ({eligible.length}) — {resize.width}&times;{resize.height} or larger
                    </div>
                    {eligible.length === 0 ? (
                      <div className="text-muted small py-2 text-center">
                        No assets large enough. Upload a {resize.width}&times;{resize.height}+ image.
                      </div>
                    ) : (
                      <div className="d-flex flex-wrap gap-1" style={{ maxHeight: 200, overflowY: 'auto' }}>
                        {eligible.map((asset) => {
                          const isSelected = resize.background_asset_id === asset.id
                          return (
                            <div
                              key={asset.id}
                              className="border rounded overflow-hidden"
                              style={{
                                width: 60,
                                height: 60,
                                cursor: 'pointer',
                                outline: isSelected ? '2px solid #198754' : 'none',
                                outlineOffset: -2,
                                opacity: isSelected ? 1 : 0.8,
                              }}
                              onClick={() => assignBackground(resize, asset.id)}
                              title={`${asset.name} (${asset.width}×${asset.height})`}
                            >
                              <img
                                src={asset.url}
                                alt={asset.name}
                                style={{ width: '100%', height: '100%', objectFit: 'cover' }}
                              />
                            </div>
                          )
                        })}
                      </div>
                    )}
                  </div>
                )}
              </div>
            </div>
          )
        })}
      </div>
    </div>
  )
}

export default AdBackgroundPicker
