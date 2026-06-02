import React, { useState, useMemo } from 'react'
import { apiFetch } from '~/lib/api'

export default function AdBackgroundPicker({
  ad,
  clientId,
  resizes,
  smartPlacement,
  onSmartPlacementChange,
  onContinue,
  onBack,
}) {
  const [detecting, setDetecting] = useState(false)
  const [detectError, setDetectError] = useState(null)
  const bgLayer = useMemo(() => {
    return (ad.classified_layers || []).find((l) => l.type === 'background')
  }, [ad.classified_layers])

  const bgSrc = bgLayer?.href || null
  const bgWidth = parseInt(bgLayer?.width) || ad.width || 0
  const bgHeight = parseInt(bgLayer?.height) || ad.height || 0

  // For each resize, determine if the background fits (center-crop possible)
  // Fits = both resize dimensions <= background dimensions
  const resizeStatuses = useMemo(() => {
    return resizes.map((r) => {
      const fits = r.width <= bgWidth && r.height <= bgHeight
      return { ...r, bgFits: fits }
    })
  }, [resizes, bgWidth, bgHeight])

  const fittingCount = resizeStatuses.filter((r) => r.bgFits).length
  const needsAltCount = resizeStatuses.filter((r) => !r.bgFits).length

  if (!bgSrc && resizes.length === 0) {
    return (
      <div className="text-center py-5 text-muted">
        <p>No background image detected and no resizes selected.</p>
        <button className="btn btn-primary" onClick={onContinue}>
          Continue to Layout
        </button>
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
            style={{ maxWidth: 300, background: '#1a1a1a' }}
          >
            <img
              src={bgSrc}
              alt="Original background"
              style={{ display: 'block', width: '100%', height: 'auto' }}
            />
          </div>
        </div>
      )}

      {/* Per-resize background previews */}
      {resizes.length > 0 && (
        <div className="mb-4">
          <h6 className="text-uppercase text-muted small fw-semibold mb-2">
            Background per Size
          </h6>
          {fittingCount > 0 && needsAltCount > 0 && (
            <p className="small text-muted mb-3">
              {fittingCount} size{fittingCount !== 1 ? 's' : ''} can use the original background (center-cropped).{' '}
              {needsAltCount} size{needsAltCount !== 1 ? 's' : ''} need{needsAltCount === 1 ? 's' : ''} an alternative.
            </p>
          )}

          <div className="row g-3">
            {resizeStatuses.map((r) => (
              <div key={r.id} className="col-sm-6 col-md-4 col-lg-3">
                <ResizeBackgroundCard
                  resize={r}
                  bgSrc={bgSrc}
                  bgWidth={bgWidth}
                  bgHeight={bgHeight}
                />
              </div>
            ))}
          </div>
        </div>
      )}

      {/* Smart text placement checkbox */}
      <div className="border rounded p-3 mb-4 bg-light">
        <div className="form-check">
          <input
            className="form-check-input"
            type="checkbox"
            id="smart-placement"
            checked={smartPlacement}
            onChange={(e) => onSmartPlacementChange(e.target.checked)}
          />
          <label className="form-check-label fw-semibold" htmlFor="smart-placement">
            Smart text placement
          </label>
        </div>
        <p className="small text-muted mb-0 mt-1 ms-4">
          Uses AI to detect faces and busy areas in each background, then places text only
          in clean regions. Avoids overlaying text on people or important visual elements.
        </p>
      </div>

      {/* Detection error */}
      {detectError && (
        <div className="alert alert-warning mb-3">
          <i className="bi bi-exclamation-triangle me-2"></i>
          {detectError}
          <button className="btn btn-sm btn-outline-warning ms-2" onClick={() => { setDetectError(null); onContinue({}) }}>
            Continue without smart placement
          </button>
        </div>
      )}

      {/* Continue button */}
      <div className="d-flex gap-2">
        <button
          className="btn btn-primary"
          disabled={detecting}
          onClick={handleContinue}
        >
          {detecting ? (
            <><span className="spinner-border spinner-border-sm me-2" />Detecting faces &amp; subjects...</>
          ) : (
            <>Continue to Layout <i className="bi bi-arrow-right ms-1"></i></>
          )}
        </button>
      </div>
    </div>
  )

  async function handleContinue() {
    if (!smartPlacement) {
      onContinue({})
      return
    }

    // Run exclusion zone detection for each resize with a fitting background
    setDetecting(true)
    setDetectError(null)
    const exclusionMap = {}

    try {
      const fittingResizes = resizeStatuses.filter((r) => r.bgFits)
      const results = await Promise.allSettled(
        fittingResizes.map(async (r) => {
          const data = await apiFetch(
            `/api/clients/${clientId}/ads/${ad.id}/detect_exclusion_zones`,
            {
              method: 'POST',
              body: JSON.stringify({ target_width: r.width, target_height: r.height }),
            }
          )
          return { resizeId: r.id, ...data }
        })
      )

      results.forEach((r) => {
        if (r.status === 'fulfilled') {
          exclusionMap[r.value.resizeId] = r.value.exclusion_zones || []
        }
      })

      // Also detect for the original ad dimensions (no resize)
      try {
        const origData = await apiFetch(
          `/api/clients/${clientId}/ads/${ad.id}/detect_exclusion_zones`,
          {
            method: 'POST',
            body: JSON.stringify({ target_width: ad.width, target_height: ad.height }),
          }
        )
        exclusionMap['original'] = origData.exclusion_zones || []
      } catch (_) {}

      onContinue(exclusionMap)
    } catch (e) {
      setDetectError(e.message || 'Failed to detect exclusion zones')
    } finally {
      setDetecting(false)
    }
  }
}

function ResizeBackgroundCard({ resize, bgSrc, bgWidth, bgHeight }) {
  const { width, height, bgFits, label, platform_labels } = resize
  const displayLabel = label || platform_labels?.join(', ') || `${width}×${height}`

  // Calculate center-crop positioning (CSS object-fit: cover simulation)
  const cropStyle = useMemo(() => {
    if (!bgSrc || !bgFits) return null

    // Scale factor: fill the target dimensions
    const scaleX = width / bgWidth
    const scaleY = height / bgHeight
    const scale = Math.max(scaleX, scaleY)

    const scaledW = bgWidth * scale
    const scaledH = bgHeight * scale

    // Center offset
    const offsetX = (scaledW - width) / 2
    const offsetY = (scaledH - height) / 2

    // Express as percentage for background-position
    return {
      backgroundImage: `url(${bgSrc})`,
      backgroundSize: `${scaledW}px ${scaledH}px`,
      backgroundPosition: `-${offsetX}px -${offsetY}px`,
      backgroundRepeat: 'no-repeat',
    }
  }, [bgSrc, bgFits, width, height, bgWidth, bgHeight])

  // Preview fits in a max 200px wide box, aspect-ratio preserved
  const maxPreviewW = 200
  const aspect = width / height
  const previewW = Math.min(maxPreviewW, width)
  const previewH = previewW / aspect

  return (
    <div className="border rounded p-2 h-100">
      <div className="small fw-semibold mb-1 text-truncate" title={displayLabel}>
        {displayLabel}
      </div>
      <div className="small text-muted mb-2">{width}&times;{height}</div>

      {/* Preview */}
      <div
        className="rounded overflow-hidden mx-auto"
        style={{
          width: previewW,
          height: previewH,
          ...(bgFits && cropStyle
            ? cropStyle
            : { background: '#000' }),
        }}
      />

      {/* Status badge */}
      <div className="mt-2">
        {bgFits ? (
          <span className="badge bg-success-subtle text-success border border-success-subtle">
            <i className="bi bi-check-circle me-1"></i>Center-cropped
          </span>
        ) : (
          <span className="badge bg-warning-subtle text-warning border border-warning-subtle">
            <i className="bi bi-exclamation-triangle me-1"></i>Needs background
          </span>
        )}
      </div>
    </div>
  )
}
