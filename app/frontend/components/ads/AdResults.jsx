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
  const [rejectForm, setRejectForm] = useState(null) // { mode, audienceId?, versionId?, comment }
  const [rejecting, setRejecting] = useState(false)
  const [selectedVersions, setSelectedVersions] = useState({}) // { "audienceId-resizeId": versionIndex }

  // Filters
  const [sizeFilter, setSizeFilter] = useState('all')
  const [audienceFilter, setAudienceFilter] = useState('all')

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

  const openRejectVersion = (versionId) => {
    setRejectForm({ mode: 'version', versionId, comment: '' })
  }

  const openRejectAudience = (audienceId) => {
    setRejectForm({ mode: 'audience', audienceId, comment: '' })
  }

  const submitReject = async () => {
    if (!rejectForm?.comment?.trim()) return
    setRejecting(true)
    try {
      const body = { rejection_comment: rejectForm.comment }
      if (rejectForm.mode === 'version') {
        body.version_id = rejectForm.versionId
      } else {
        body.audience_id = rejectForm.audienceId
      }

      await apiFetch(`/api/clients/${clientId}/ads/${adId}/reject`, {
        method: 'POST',
        body: JSON.stringify(body),
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
    const colors = { setup: 'secondary', resizing: 'info', pending: 'warning text-dark', merged: 'success', regenerating: 'warning text-dark' }
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

  const hasResizes = data.resizes && data.resizes.length > 0

  // Build filtered view
  const filteredAudiences = data.audiences
    .filter((a) => audienceFilter === 'all' || a.id === audienceFilter)
    .map((a) => ({
      ...a,
      versions: a.versions.filter((v) => {
        if (sizeFilter === 'all') return true
        if (sizeFilter === 'original') return !v.ad_resize_id
        return v.ad_resize_id === sizeFilter
      }),
    }))

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
              {hasResizes && (
                <small className="text-muted">{data.resizes.length} resize{data.resizes.length !== 1 ? 's' : ''}</small>
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

      {/* Filter bar */}
      {(hasResizes || data.audiences.length > 1) && (
        <div className="d-flex align-items-center gap-3 mb-4 p-3 bg-light rounded">
          {hasResizes && (
            <div className="d-flex align-items-center gap-2">
              <label className="form-label small fw-semibold mb-0">Size:</label>
              <select
                className="form-select form-select-sm"
                style={{ width: 'auto' }}
                value={sizeFilter}
                onChange={(e) => setSizeFilter(e.target.value)}
              >
                <option value="all">All Sizes</option>
                {data.resizes.map((r) => (
                  <option key={r.id} value={r.id}>
                    {r.dimensions} — {r.platform_labels.map((pl) => `${pl.platform} ${pl.size_name}`).join(', ')}
                  </option>
                ))}
              </select>
            </div>
          )}
          {data.audiences.length > 1 && (
            <div className="d-flex align-items-center gap-2">
              <label className="form-label small fw-semibold mb-0">Audience:</label>
              <select
                className="form-select form-select-sm"
                style={{ width: 'auto' }}
                value={audienceFilter}
                onChange={(e) => setAudienceFilter(e.target.value)}
              >
                <option value="all">All Audiences</option>
                {data.audiences.map((a) => (
                  <option key={a.id} value={a.id}>{a.name}</option>
                ))}
              </select>
            </div>
          )}
        </div>
      )}

      {/* Per-audience results */}
      {filteredAudiences.length === 0 ? (
        <div className="text-center text-muted py-5">
          <i className="bi bi-people fs-1 d-block mb-3"></i>
          <p>No results match the current filters.</p>
        </div>
      ) : (
        filteredAudiences.map((audience) => {
          // Group versions by resize for display
          const versionsByResize = groupVersionsByResize(audience.versions, data.resizes)
          const hasActiveVersions = audience.versions.some((v) => v.state === 'active')

          return (
            <div key={audience.id} className="card mb-4">
              <div className="card-header d-flex justify-content-between align-items-center">
                <div className="d-flex align-items-center gap-2">
                  <i className="bi bi-person-circle text-muted"></i>
                  <strong>{audience.name}</strong>
                  <small className="text-muted">
                    {audience.versions.filter((v) => v.state === 'active').length} active version{audience.versions.filter((v) => v.state === 'active').length !== 1 ? 's' : ''}
                  </small>
                </div>
                {hasActiveVersions && hasResizes && (
                  <button
                    className="btn btn-sm btn-outline-danger"
                    onClick={() => openRejectAudience(audience.id)}
                    title="Reject all sizes for this audience"
                  >
                    <i className="bi bi-x-circle me-1"></i>Reject All Sizes
                  </button>
                )}
              </div>

              <div className="card-body">
                {audience.versions.length === 0 ? (
                  <p className="text-muted small mb-0">No versions match the current filters.</p>
                ) : (
                  <div className="row g-3">
                    {versionsByResize.map((group) => {
                      const groupKey = `${audience.id}-${group.resizeId || 'original'}`
                      const latestIdx = group.versions.length - 1
                      const selectedIdx = selectedVersions[groupKey] ?? latestIdx
                      const version = group.versions[selectedIdx]
                      const latestVersion = group.versions[latestIdx]
                      const isLatest = selectedIdx === latestIdx
                      const hasActive = latestVersion?.state === 'active'

                      return (
                        <div key={groupKey} className={hasResizes ? 'col-lg-6' : 'col-12'}>
                          <div className="border rounded p-3">
                            {/* Resize dimensions header */}
                            {group.resizeDimensions && (
                              <div className="d-flex align-items-center gap-2 mb-2">
                                <span className="badge bg-info text-white">{group.resizeDimensions}</span>
                                {group.resizeLabel && (
                                  <small className="text-muted" style={{ fontSize: '0.7rem' }}>{group.resizeLabel}</small>
                                )}
                              </div>
                            )}

                            {/* Version selector + actions */}
                            <div className="d-flex align-items-center justify-content-between mb-2">
                              <div className="d-flex align-items-center gap-2">
                                {version && stateBadge(version.state)}
                                {group.versions.length > 1 ? (
                                  <select
                                    className="form-select form-select-sm"
                                    style={{ width: 'auto' }}
                                    value={selectedIdx}
                                    onChange={(e) => setSelectedVersions((prev) => ({ ...prev, [groupKey]: Number(e.target.value) }))}
                                  >
                                    {group.versions.map((v, i) => (
                                      <option key={v.id} value={i}>
                                        v{v.version_number}{i === latestIdx ? ' (Current)' : ''}
                                      </option>
                                    ))}
                                  </select>
                                ) : version && (
                                  <small className="text-muted">v{version.version_number}</small>
                                )}
                              </div>
                              <div className="d-flex align-items-center gap-1">
                                {version?.rendered_image_url && (
                                  <a
                                    href={`/api/clients/${clientId}/ads/${adId}/download_version?version_id=${version.id}`}
                                    className="btn btn-sm btn-outline-primary"
                                    download
                                    title="Download"
                                  >
                                    <i className="bi bi-download"></i>
                                  </a>
                                )}
                                {hasActive && isLatest && (
                                  <button
                                    className="btn btn-sm btn-outline-danger"
                                    onClick={() => openRejectVersion(latestVersion.id)}
                                    title="Reject this version"
                                  >
                                    <i className="bi bi-x-circle"></i>
                                  </button>
                                )}
                                {latestVersion?.state === 'generating' && isLatest && (
                                  <span className="spinner-border spinner-border-sm text-warning" />
                                )}
                              </div>
                            </div>

                            {/* Version content */}
                            {version && (
                              <>
                                {version.state === 'rejected' && version.rejection_comment && (
                                  <div className="alert alert-danger alert-sm py-1 px-2 mb-2">
                                    <small><strong>Rejected:</strong> "{version.rejection_comment}"</small>
                                  </div>
                                )}
                                {version.rendered_image_url && (
                                  <div className="mb-2 text-center">
                                    <img
                                      src={version.rendered_image_url}
                                      alt={`${data.ad_name} - ${audience.name} v${version.version_number}`}
                                      className="img-fluid rounded border"
                                      style={{ maxHeight: hasResizes ? 300 : 500 }}
                                    />
                                  </div>
                                )}
                                {version.generated_layers?.length > 0 && (
                                  <div className="table-responsive">
                                    <table className="table table-sm table-bordered mb-0">
                                      <thead className="table-light">
                                        <tr>
                                          <th style={{ width: '25%' }}>Layer</th>
                                          <th>Original</th>
                                          <th>Generated</th>
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
                                  <small className="text-muted">
                                    {version.ai_service_name} · {version.ai_model_name}
                                  </small>
                                </div>
                              </>
                            )}
                          </div>
                        </div>
                      )
                    })}
                  </div>
                )}
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
                <h5 className="modal-title">
                  {rejectForm.mode === 'audience' ? 'Reject All Sizes for Audience' : 'Reject Version'}
                </h5>
                <button type="button" className="btn-close" onClick={() => setRejectForm(null)} />
              </div>
              <div className="modal-body">
                <p className="text-muted small mb-2">
                  {rejectForm.mode === 'audience'
                    ? 'All active versions for this audience (across all sizes) will be rejected and regenerated.'
                    : 'Provide feedback so the AI can improve the next version.'}
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

// Group versions by resize ID for card layout
function groupVersionsByResize(versions, resizes) {
  const groups = {}

  versions.forEach((v) => {
    const key = v.ad_resize_id || 'original'
    if (!groups[key]) {
      groups[key] = {
        resizeId: v.ad_resize_id,
        resizeDimensions: v.resize_dimensions,
        resizeLabel: v.resize_label,
        versions: [],
      }
    }
    groups[key].versions.push(v)
  })

  // If there are no resizes, return a single group
  if (Object.keys(groups).length === 0) {
    return []
  }

  // Sort groups: original first, then by dimensions
  return Object.values(groups).sort((a, b) => {
    if (!a.resizeId) return -1
    if (!b.resizeId) return 1
    return (a.resizeDimensions || '').localeCompare(b.resizeDimensions || '')
  })
}
