import React, { useState, useEffect, useCallback } from 'react'
import { apiFetch, apiUpload } from '~/lib/api'

export default function AssetsIndex() {
  const [assets, setAssets] = useState([])
  const [loading, setLoading] = useState(true)
  const [uploading, setUploading] = useState(false)
  const [dragOver, setDragOver] = useState(false)

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
              <div className="card h-100">
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
                    {asset.width && asset.height ? (
                      <small className="text-muted">{asset.width} × {asset.height}</small>
                    ) : (
                      <small className="text-muted"></small>
                    )}
                    <button
                      className="btn btn-sm btn-outline-danger"
                      onClick={() => handleDelete(asset.id)}
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
  )
}
