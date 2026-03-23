import React, { useState, useEffect } from 'react'
import { useParams, useNavigate } from 'react-router-dom'
import { apiFetch } from '~/lib/api'
import { subscribeAdChannel } from '~/lib/cable'
import { useAccount } from '../layout/AccountContext'

export default function AdResults() {
  const { clientId, adId } = useParams()
  const navigate = useNavigate()
  const ctx = useAccount()

  const [data, setData] = useState(null)
  const [loading, setLoading] = useState(true)
  const [rejectForm, setRejectForm] = useState(null) // { audienceId, comment }
  const [rejecting, setRejecting] = useState(false)

  const fetchResults = () => {
    apiFetch(`/api/clients/${clientId}/ads/${adId}/results`)
      .then(setData)
      .catch(() => {})
      .finally(() => setLoading(false))
  }

  useEffect(() => {
    if (!clientId || !adId) return
    fetchResults()
  }, [clientId, adId])

  // Live updates during regeneration
  useEffect(() => {
    if (!adId) return
    return subscribeAdChannel(adId, {
      received(update) {
        if (data) {
          setData((prev) => prev ? { ...prev, state: update.state } : prev)
        }
        if (update.state === 'merged') {
          fetchResults()
        }
      },
    })
  }, [adId, data])

  const openReject = (audienceId) => {
    setRejectForm({ audienceId, comment: '' })
  }

  const submitReject = async () => {
    if (!rejectForm?.comment?.trim()) return
    setRejecting(true)
    try {
      await apiFetch(`/api/clients/${clientId}/ads/${adId}/reject`, {
        method: 'POST',
        body: JSON.stringify({
          audience_id: rejectForm.audienceId,
          rejection_comment: rejectForm.comment,
        }),
      })
      setRejectForm(null)
      fetchResults()
    } catch (e) {
      alert(e.message || 'Rejection failed')
    } finally {
      setRejecting(false)
    }
  }

  const stateBadge = (state) => {
    const colors = { generating: 'warning text-dark', active: 'success', rejected: 'danger' }
    return <span className={`badge bg-${colors[state] || 'secondary'} text-capitalize`}>{state}</span>
  }

  const adStateBadge = (state) => {
    const colors = { setup: 'secondary', pending: 'warning text-dark', merged: 'success', regenerating: 'warning text-dark' }
    return <span className={`badge bg-${colors[state] || 'secondary'} text-capitalize`}>{state}</span>
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

  if (!data) {
    return (
      <div className="p-4">
        <p className="text-muted">Could not load results.</p>
      </div>
    )
  }

  return (
    <div className="p-4">
      {/* Header */}
      <div className="d-flex align-items-center justify-content-between mb-4">
        <div className="d-flex align-items-center gap-3">
          <button className="btn btn-sm btn-outline-secondary" onClick={() => navigate(`/clients/${clientId}/ads/${adId}`)}>
            <i className="bi bi-arrow-left"></i>
          </button>
          <div>
            <h5 className="mb-0">{data.ad_name}</h5>
            <div className="d-flex align-items-center gap-2 mt-1">
              {adStateBadge(data.state)}
              {data.aspect_ratio && (
                <span className="badge bg-light text-dark border">{data.aspect_ratio}</span>
              )}
            </div>
          </div>
        </div>
        {(data.state === 'pending' || data.state === 'regenerating') && (
          <div className="d-flex align-items-center gap-2 text-warning">
            <span className="spinner-border spinner-border-sm" />
            <small>{data.state === 'regenerating' ? 'Regenerating…' : 'Generating…'}</small>
          </div>
        )}
      </div>

      {/* Per-audience results */}
      {data.audiences.length === 0 ? (
        <div className="text-center text-muted py-5">
          <i className="bi bi-people fs-1 d-block mb-3"></i>
          <p>No audiences found for this ad.</p>
        </div>
      ) : (
        data.audiences.map((audience) => {
          const latestVersion = audience.versions[audience.versions.length - 1]
          const hasActive = latestVersion?.state === 'active'

          return (
            <div key={audience.id} className="card mb-4">
              <div className="card-header d-flex justify-content-between align-items-center">
                <div className="d-flex align-items-center gap-2">
                  <i className="bi bi-person-circle text-muted"></i>
                  <strong>{audience.name}</strong>
                  {latestVersion && stateBadge(latestVersion.state)}
                  {latestVersion && (
                    <small className="text-muted">v{latestVersion.version_number}</small>
                  )}
                </div>
                {hasActive && (
                  <button
                    className="btn btn-sm btn-outline-danger"
                    onClick={() => openReject(audience.id)}
                  >
                    <i className="bi bi-x-circle me-1"></i>Reject
                  </button>
                )}
                {latestVersion?.state === 'generating' && (
                  <span className="d-flex align-items-center gap-1 text-warning">
                    <span className="spinner-border spinner-border-sm" />
                    <small>Generating…</small>
                  </span>
                )}
              </div>

              <div className="card-body">
                {/* Version history */}
                {audience.versions.length === 0 && (
                  <p className="text-muted small mb-0">No versions generated yet.</p>
                )}

                {audience.versions.map((version) => (
                  <div key={version.id} className={`mb-3 ${version.state === 'rejected' ? 'opacity-50' : ''}`}>
                    {version.state === 'rejected' && version.rejection_comment && (
                      <div className="alert alert-danger alert-sm py-2 px-3 mb-2 d-flex align-items-start gap-2">
                        <i className="bi bi-x-circle mt-1 small"></i>
                        <div>
                          <small className="fw-semibold d-block">Rejected (v{version.version_number})</small>
                          <small>"{version.rejection_comment}"</small>
                        </div>
                      </div>
                    )}
                    {version.generated_layers?.length > 0 && (
                      <div className="table-responsive">
                        <table className="table table-sm table-bordered mb-0">
                          <thead className="table-light">
                            <tr>
                              <th style={{ width: '30%' }}>Layer</th>
                              <th>Original</th>
                              <th>Generated{version.state === 'active' ? ' ✓' : ''}</th>
                            </tr>
                          </thead>
                          <tbody>
                            {version.generated_layers.map((layer, i) => {
                              const original = data.parsed_layers?.find((l) => l.id === layer.id)
                              return (
                                <tr key={i}>
                                  <td className="text-muted small">{layer.id}</td>
                                  <td className="small" style={{ whiteSpace: 'pre-wrap' }}>
                                    {layer.original_content || original?.content || '–'}
                                  </td>
                                  <td className="small" style={{ whiteSpace: 'pre-wrap' }}>
                                    {layer.content}
                                  </td>
                                </tr>
                              )
                            })}
                          </tbody>
                        </table>
                      </div>
                    )}
                    <div className="d-flex align-items-center gap-2 mt-1">
                      {stateBadge(version.state)}
                      <small className="text-muted">
                        {version.ai_service_name} · {version.ai_model_name}
                      </small>
                    </div>
                  </div>
                ))}
              </div>
            </div>
          )
        })
      )}

      {/* Rejection modal */}
      {rejectForm && (
        <div className="modal d-block" tabIndex="-1" style={{ backgroundColor: 'rgba(0,0,0,0.5)' }}>
          <div className="modal-dialog" onClick={(e) => e.stopPropagation()}>
            <div className="modal-content">
              <div className="modal-header">
                <h5 className="modal-title">Reject Version</h5>
                <button type="button" className="btn-close" onClick={() => setRejectForm(null)} />
              </div>
              <div className="modal-body">
                <p className="text-muted small mb-2">
                  Provide feedback so the AI can improve the next version.
                </p>
                <textarea
                  className="form-control"
                  rows={4}
                  value={rejectForm.comment}
                  onChange={(e) => setRejectForm({ ...rejectForm, comment: e.target.value })}
                  placeholder="Explain why this version was rejected and what should change…"
                  autoFocus
                />
              </div>
              <div className="modal-footer">
                <button
                  className="btn btn-secondary"
                  onClick={() => setRejectForm(null)}
                  disabled={rejecting}
                >
                  Cancel
                </button>
                <button
                  className="btn btn-danger"
                  onClick={submitReject}
                  disabled={rejecting || !rejectForm.comment?.trim()}
                >
                  {rejecting ? 'Rejecting…' : 'Reject & Regenerate'}
                </button>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
