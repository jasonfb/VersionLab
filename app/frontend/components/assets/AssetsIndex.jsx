import React, { useState, useEffect, useCallback, useRef } from 'react'
import { apiFetch, apiUpload } from '~/lib/api'

const RATIO_LABELS = {
  hero_3_1:        '3:1 Hero',
  banner_2_1:      '2:1 Banner',
  widescreen_16_9: '16:9 Widescreen',
  square_1_1:      '1:1 Square',
  portrait_4_5:    '4:5 Portrait',
}

const SIZE_OPTIONS = [
  { label: 'Full', value: 1 },
  { label: '75%', value: 0.75 },
  { label: '50%', value: 0.5 },
  { label: '25%', value: 0.25 },
]

function AssetModal({ asset, onClose }) {
  const [scale, setScale] = useState(1)
  const [naturalSize, setNaturalSize] = useState(
    asset.width && asset.height ? { w: asset.width, h: asset.height } : null
  )

  const handleImageLoad = (e) => {
    if (!naturalSize) {
      setNaturalSize({ w: e.target.naturalWidth, h: e.target.naturalHeight })
    }
  }

  // Close on backdrop click
  const handleBackdrop = (e) => {
    if (e.target === e.currentTarget) onClose()
  }

  // Close on Escape
  useEffect(() => {
    const handler = (e) => { if (e.key === 'Escape') onClose() }
    window.addEventListener('keydown', handler)
    return () => window.removeEventListener('keydown', handler)
  }, [onClose])

  const displayW = naturalSize ? Math.round(naturalSize.w * scale) : null
  const displayH = naturalSize ? Math.round(naturalSize.h * scale) : null

  return (
    <div
      className="position-fixed top-0 start-0 w-100 h-100 d-flex align-items-center justify-content-center"
      style={{ background: 'rgba(0,0,0,0.75)', zIndex: 1055 }}
      onClick={handleBackdrop}
    >
      <div
        className="position-relative bg-dark rounded shadow-lg d-flex flex-column"
        style={{ maxWidth: '90vw', maxHeight: '90vh' }}
        onClick={(e) => e.stopPropagation()}
      >
        {/* Header */}
        <div className="d-flex align-items-center justify-content-between px-3 py-2 border-bottom border-secondary">
          <span className="small text-truncate me-3" style={{ maxWidth: 300 }}>{asset.name}</span>
          <div className="d-flex align-items-center gap-2">
            {/* Size selector */}
            <div className="btn-group btn-group-sm">
              {SIZE_OPTIONS.map((opt) => (
                <button
                  key={opt.value}
                  className={`btn ${scale === opt.value ? 'btn-danger' : 'btn-outline-secondary'}`}
                  onClick={() => setScale(opt.value)}
                >
                  {opt.label}
                </button>
              ))}
            </div>
            <button className="btn btn-sm btn-outline-secondary ms-1" onClick={onClose}>
              <i className="bi bi-x-lg" />
            </button>
          </div>
        </div>

        {/* Image area */}
        <div className="overflow-auto p-3 flex-grow-1 position-relative" style={{ minHeight: 0 }}>
          <img
            src={asset.url}
            alt={asset.name}
            onLoad={handleImageLoad}
            style={{
              width: displayW ?? 'auto',
              height: displayH ?? 'auto',
              maxWidth: 'none',
              display: 'block',
            }}
          />

          {/* Dimensions badge */}
          {naturalSize && (
            <div
              className="position-absolute bottom-0 end-0 m-3 px-2 py-1 rounded small text-white"
              style={{ background: 'rgba(0,0,0,0.55)', pointerEvents: 'none' }}
            >
              {displayW} × {displayH}px
            </div>
          )}
        </div>
      </div>
    </div>
  )
}

export default function AssetsIndex() {
  const [assets, setAssets] = useState([])
  const [loading, setLoading] = useState(true)
  const [uploading, setUploading] = useState(false)
  const [dragOver, setDragOver] = useState(false)
  const [selectedAsset, setSelectedAsset] = useState(null)

  useEffect(() => {
    apiFetch('/api/assets')
      .then(setAssets)
      .finally(() => setLoading(false))
  }, [])

  const handleUpload = useCallback(async (file) => {
    setUploading(true)
    try {
      const formData = new FormData()
      formData.append('file', file)
      const asset = await apiUpload('/api/assets', formData)
      setAssets((prev) => [asset, ...prev])
    } catch (err) {
      alert(err.message)
    } finally {
      setUploading(false)
    }
  }, [])

  const handleDrop = useCallback((e) => {
    e.preventDefault()
    setDragOver(false)
    const file = e.dataTransfer.files[0]
    if (file) handleUpload(file)
  }, [handleUpload])

  const handleDragOver = useCallback((e) => {
    e.preventDefault()
    setDragOver(true)
  }, [])

  const handleDragLeave = useCallback((e) => {
    e.preventDefault()
    setDragOver(false)
  }, [])

  const handleDelete = useCallback(async (id) => {
    if (!confirm('Delete this asset?')) return
    await apiFetch(`/api/assets/${id}`, { method: 'DELETE' })
    setAssets((prev) => prev.filter((a) => a.id !== id))
    setSelectedAsset((prev) => (prev?.id === id ? null : prev))
  }, [])

  if (loading) {
    return (
      <div className="p-4">
        <div className="spinner-border spinner-border-sm" role="status">
          <span className="visually-hidden">Loading...</span>
        </div>
      </div>
    )
  }

  return (
    <>
      <div
        className="p-4 h-100"
        onDrop={handleDrop}
        onDragOver={handleDragOver}
        onDragLeave={handleDragLeave}
        style={{
          outline: dragOver ? '3px dashed #dc3545' : '3px dashed transparent',
          outlineOffset: '-8px',
          transition: 'outline-color 0.15s',
          minHeight: '100%',
        }}
      >
        <div className="d-flex justify-content-between align-items-center mb-4">
          <h4 className="mb-0">Assets</h4>
          {uploading && (
            <div className="spinner-border spinner-border-sm text-danger" role="status">
              <span className="visually-hidden">Uploading...</span>
            </div>
          )}
        </div>

        {assets.length === 0 && !uploading ? (
          <div className="text-center text-muted py-5">
            <i className="bi bi-image fs-1 d-block mb-3"></i>
            <p>No assets yet. Drag and drop an image here to upload.</p>
          </div>
        ) : (
          <div className="row row-cols-2 row-cols-md-3 row-cols-lg-4 g-3">
            {assets.map((asset) => (
              <div key={asset.id} className="col">
                <div
                  className="card h-100"
                  style={{ cursor: asset.url ? 'pointer' : 'default' }}
                  onClick={() => asset.url && setSelectedAsset(asset)}
                >
                  {asset.url && (
                    <img
                      src={asset.url}
                      alt={asset.name}
                      className="card-img-top"
                      style={{ objectFit: 'cover', height: 160 }}
                    />
                  )}
                  <div className="card-body p-2">
                    <p className="card-text small text-truncate mb-1" title={asset.name}>
                      {asset.name}
                    </p>
                    <div className="d-flex justify-content-between align-items-center">
                      <div>
                        {asset.width && asset.height && (
                          <small className="text-muted d-block">{asset.width} × {asset.height}</small>
                        )}
                        {asset.standardized_ratio && (
                          <small className="text-muted">{RATIO_LABELS[asset.standardized_ratio] ?? asset.standardized_ratio}</small>
                        )}
                      </div>
                      <button
                        className="btn btn-sm btn-outline-danger"
                        onClick={(e) => { e.stopPropagation(); handleDelete(asset.id) }}
                      >
                        <i className="bi bi-trash"></i>
                      </button>
                    </div>
                  </div>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>

      {selectedAsset && (
        <AssetModal asset={selectedAsset} onClose={() => setSelectedAsset(null)} />
      )}
    </>
  )
}
