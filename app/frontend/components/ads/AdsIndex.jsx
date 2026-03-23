import React, { useState, useEffect, useRef } from 'react'
import { useNavigate } from 'react-router-dom'
import { apiFetch, apiUpload } from '~/lib/api'
import { subscribeAdChannel } from '~/lib/cable'
import { useAccount } from '../layout/AccountContext'
import AdStyleGuideModal from './AdStyleGuideModal'

export default function AdsIndex() {
  const navigate = useNavigate()
  const ctx = useAccount()
  const clientId = ctx?.current_client_id
  const [ads, setAds] = useState([])
  const [loading, setLoading] = useState(true)
  const [uploading, setUploading] = useState(false)
  const [dragOver, setDragOver] = useState(false)
  const [styleGuideOpen, setStyleGuideOpen] = useState(false)
  const fileInputRef = useRef(null)
  const subscriptionsRef = useRef({})

  useEffect(() => {
    if (!clientId) return
    setLoading(true)
    apiFetch(`/api/clients/${clientId}/ads`)
      .then(setAds)
      .catch(() => {})
      .finally(() => setLoading(false))
  }, [clientId])

  // Cable subscriptions for in-progress ads
  useEffect(() => {
    const inProgress = ads.filter((a) => a.state === 'pending' || a.state === 'regenerating')
    const inProgressIds = new Set(inProgress.map((a) => a.id))

    inProgress.forEach((a) => {
      if (subscriptionsRef.current[a.id]) return
      subscriptionsRef.current[a.id] = subscribeAdChannel(a.id, {
        received(data) {
          setAds((prev) => prev.map((ad) =>
            ad.id === data.ad_id ? { ...ad, state: data.state } : ad
          ))
          if (data.state !== 'pending' && data.state !== 'regenerating') {
            subscriptionsRef.current[data.ad_id]?.()
            delete subscriptionsRef.current[data.ad_id]
          }
        },
      })
    })

    Object.keys(subscriptionsRef.current).forEach((id) => {
      if (!inProgressIds.has(id)) {
        subscriptionsRef.current[id]?.()
        delete subscriptionsRef.current[id]
      }
    })
  }, [ads])

  useEffect(() => {
    return () => {
      Object.values(subscriptionsRef.current).forEach((unsub) => unsub?.())
    }
  }, [])

  const uploadFile = async (file) => {
    if (!clientId) return
    if (!file.name.match(/\.(pdf|svg)$/i)) {
      alert('Only PDF and SVG files are supported.')
      return
    }

    setUploading(true)
    try {
      const formData = new FormData()
      formData.append('file', file)
      formData.append('name', file.name.replace(/\.(pdf|svg)$/i, ''))
      const created = await apiUpload(`/api/clients/${clientId}/ads`, formData)
      navigate(`/clients/${clientId}/ads/${created.id}`)
    } catch (e) {
      alert(e.message || 'Upload failed')
    } finally {
      setUploading(false)
    }
  }

  const handleDrop = (e) => {
    e.preventDefault()
    setDragOver(false)
    const file = e.dataTransfer.files[0]
    if (file) uploadFile(file)
  }

  const handleFileSelect = (e) => {
    const file = e.target.files[0]
    if (file) uploadFile(file)
    e.target.value = ''
  }

  const deleteAd = async (id) => {
    if (!confirm('Delete this ad?')) return
    await apiFetch(`/api/clients/${clientId}/ads/${id}`, { method: 'DELETE' })
    setAds((prev) => prev.filter((a) => a.id !== id))
  }

  const stateBadge = (state) => {
    const colors = { setup: 'secondary', pending: 'warning text-dark', merged: 'success', regenerating: 'warning text-dark' }
    return <span className={`badge bg-${colors[state] || 'secondary'}`}>{state}</span>
  }

  if (!ctx || loading) {
    return (
      <div className="p-4">
        <div className="spinner-border spinner-border-sm" role="status">
          <span className="visually-hidden">Loading…</span>
        </div>
      </div>
    )
  }

  return (
    <div className="p-4">
      <div className="d-flex justify-content-between align-items-center mb-4">
        <h4 className="mb-0">Ads</h4>
        <a
          href="#"
          className="small text-muted text-decoration-none"
          onClick={(e) => { e.preventDefault(); setStyleGuideOpen(true) }}
        >
          <i className="bi bi-info-circle me-1"></i>Style Guide
        </a>
      </div>

      {/* Upload area */}
      {clientId && (
        <div
          className={`border-2 rounded mb-4 p-4 text-center ${dragOver ? 'border-danger bg-danger bg-opacity-10' : 'border-dashed'}`}
          style={{ borderStyle: 'dashed', cursor: 'pointer' }}
          onDragOver={(e) => { e.preventDefault(); setDragOver(true) }}
          onDragLeave={() => setDragOver(false)}
          onDrop={handleDrop}
          onClick={() => fileInputRef.current?.click()}
        >
          <input
            ref={fileInputRef}
            type="file"
            accept=".pdf,.svg"
            className="d-none"
            onChange={handleFileSelect}
          />
          {uploading ? (
            <div className="d-flex align-items-center justify-content-center gap-2 text-muted">
              <span className="spinner-border spinner-border-sm" />
              <span>Uploading and parsing…</span>
            </div>
          ) : (
            <>
              <i className="bi bi-cloud-upload fs-2 text-muted d-block mb-2"></i>
              <p className="mb-1 fw-semibold">Upload an ad creative</p>
              <p className="text-muted small mb-0">Drop a PDF or SVG file here, or click to browse</p>
            </>
          )}
        </div>
      )}

      {ads.length === 0 && !uploading ? (
        <div className="text-center text-muted py-4">
          <i className="bi bi-megaphone fs-1 d-block mb-3"></i>
          <p>No ads yet. Upload a PDF or SVG to get started.</p>
        </div>
      ) : (
        <div className="list-group">
          {ads.map((ad) => (
            <div
              key={ad.id}
              className="list-group-item list-group-item-action d-flex justify-content-between align-items-start"
            >
              <div
                className="flex-grow-1"
                style={{ cursor: 'pointer' }}
                onClick={() => navigate(`/clients/${clientId}/ads/${ad.id}`)}
              >
                <div className="d-flex align-items-center gap-2">
                  <i className="bi bi-megaphone me-1 text-muted"></i>
                  <strong>{ad.name}</strong>
                  {stateBadge(ad.state)}
                  {ad.aspect_ratio && (
                    <span className="badge bg-light text-dark border">{ad.aspect_ratio}</span>
                  )}
                </div>
                <small className="text-muted d-block mt-1">
                  {ad.audience_names?.length > 0
                    ? `Audiences: ${ad.audience_names.join(', ')}`
                    : 'No audiences selected'}
                  {ad.width && ad.height && (
                    <span className="ms-2">· {ad.width}×{ad.height}px</span>
                  )}
                </small>
              </div>
              <div className="d-flex align-items-center gap-2 ms-3">
                <small className="text-muted">{new Date(ad.updated_at).toLocaleDateString()}</small>
                {(ad.state === 'pending' || ad.state === 'regenerating') && (
                  <span className="d-flex align-items-center gap-1 text-warning">
                    <span className="spinner-border spinner-border-sm" role="status" />
                    <small>{ad.state === 'regenerating' ? 'Regenerating…' : 'Processing…'}</small>
                  </span>
                )}
                {(ad.state === 'merged' || ad.state === 'regenerating') && (
                  <button
                    className="btn btn-outline-success btn-sm"
                    onClick={(e) => { e.stopPropagation(); navigate(`/clients/${clientId}/ads/${ad.id}/results`) }}
                    title="View Results"
                  >
                    <i className="bi bi-table me-1"></i>Results
                  </button>
                )}
                <button
                  className="btn btn-outline-danger btn-sm"
                  onClick={(e) => { e.stopPropagation(); deleteAd(ad.id) }}
                  title="Delete"
                >
                  <i className="bi bi-trash"></i>
                </button>
              </div>
            </div>
          ))}
        </div>
      )}
      <AdStyleGuideModal
        open={styleGuideOpen}
        onClose={() => setStyleGuideOpen(false)}
      />
    </div>
  )
}
