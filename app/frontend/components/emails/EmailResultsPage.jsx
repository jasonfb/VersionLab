import React, { useState, useEffect, useRef, useCallback } from 'react'
import { useParams, useNavigate } from 'react-router-dom'
import { apiFetch, csrfToken } from '~/lib/api'
import { subscribeEmailChannel } from '~/lib/cable'

export default function EmailResultsPage() {
  const { clientId, emailId } = useParams()
  const navigate = useNavigate()
  const [data, setData] = useState(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)
  const [selectedAudienceId, setSelectedAudienceId] = useState(null)
  const [viewMode, setViewMode] = useState('preview') // 'preview' or 'table'

  // Preview state
  const [html, setHtml] = useState(null)
  const [loadingPreview, setLoadingPreview] = useState(false)
  const iframeRef = useRef(null)

  // Rejection state
  const [rejectModal, setRejectModal] = useState(null)
  const [rejectionComment, setRejectionComment] = useState('')
  const [rejecting, setRejecting] = useState(false)
  const [rejectError, setRejectError] = useState(null)

  const fetchResults = useCallback(() => {
    return apiFetch(`/api/clients/${clientId}/emails/${emailId}/results`)
      .then(setData)
      .catch((e) => setError(e.message))
  }, [clientId, emailId])

  useEffect(() => {
    fetchResults().finally(() => setLoading(false))
  }, [fetchResults])

  // Auto-select first audience
  useEffect(() => {
    if (data?.audiences?.length && !selectedAudienceId) {
      setSelectedAudienceId(data.audiences[0].id)
    }
  }, [data, selectedAudienceId])

  // Subscribe via Action Cable for real-time updates
  useEffect(() => {
    return subscribeEmailChannel(emailId, {
      received() { fetchResults() },
    })
  }, [emailId, fetchResults])

  // Fetch preview when audience changes
  useEffect(() => {
    if (!selectedAudienceId || !data) return
    const audience = data.audiences.find((a) => a.id === selectedAudienceId)
    const activeVersion = [...(audience?.versions ?? [])].reverse().find((v) => v.state === 'active')
    if (!activeVersion) { setHtml(null); return }

    setLoadingPreview(true)
    fetch(`/api/clients/${clientId}/emails/${emailId}/preview?audience_id=${selectedAudienceId}`, {
      headers: { 'X-CSRF-Token': csrfToken() },
    })
      .then((r) => r.text())
      .then(setHtml)
      .finally(() => setLoadingPreview(false))
  }, [clientId, emailId, selectedAudienceId, data])

  // Write HTML into iframe
  useEffect(() => {
    const iframe = iframeRef.current
    if (!iframe || html === null) return
    const doc = iframe.contentDocument || iframe.contentWindow.document
    doc.open(); doc.write(html); doc.close()
  }, [html])

  const openRejectModal = (audience) => {
    setRejectModal(audience)
    setRejectionComment('')
    setRejectError(null)
  }

  const submitRejection = async () => {
    if (!rejectionComment.trim()) { setRejectError('Rejection comment is required'); return }
    setRejecting(true)
    setRejectError(null)
    try {
      await apiFetch(`/api/clients/${clientId}/emails/${emailId}/reject`, {
        method: 'POST',
        body: JSON.stringify({ audience_id: rejectModal.id, rejection_comment: rejectionComment }),
      })
      setRejectModal(null)
      await fetchResults()
    } catch (e) {
      setRejectError(e.message || 'Failed to reject')
    } finally {
      setRejecting(false)
    }
  }

  if (loading) {
    return (
      <div className="p-4">
        <div className="spinner-border spinner-border-sm" role="status" />
      </div>
    )
  }

  if (error) {
    return <div className="p-4"><div className="alert alert-danger">{error}</div></div>
  }

  const { email_template_name, audiences, variables, state } = data
  const selectedAudience = audiences.find((a) => a.id === selectedAudienceId)
  const activeVersion = selectedAudience
    ? [...(selectedAudience.versions ?? [])].reverse().find((v) => v.state === 'active')
    : null
  const generatingVersion = selectedAudience?.versions.find((v) => v.state === 'generating')

  return (
    <div className="p-4 d-flex flex-column" style={{ height: 'calc(100vh - 60px)' }}>
      {/* Header */}
      <div className="d-flex align-items-center justify-content-between mb-3 flex-shrink-0">
        <div className="d-flex align-items-center gap-3">
          <button className="btn btn-outline-secondary btn-sm" onClick={() => navigate('/emails')}>
            <i className="bi bi-arrow-left me-1"></i>Back
          </button>
          <div>
            <h5 className="mb-0">
              Merge Results
              {state === 'regenerating' && (
                <span className="ms-2 badge bg-warning text-dark fs-6 fw-normal">
                  <span className="spinner-border spinner-border-sm me-1" role="status" />
                  Regenerating…
                </span>
              )}
            </h5>
            <small className="text-muted">{email_template_name}</small>
          </div>
        </div>
        <div className="d-flex align-items-center gap-2">
          <a
            href={`/api/clients/${clientId}/emails/${emailId}/export`}
            className="btn btn-outline-primary btn-sm"
            download
          >
            <i className="bi bi-download me-1"></i>Export ZIP
          </a>
          <button
            className={`btn btn-sm ${viewMode === 'table' ? 'btn-secondary' : 'btn-outline-secondary'}`}
            onClick={() => setViewMode(viewMode === 'preview' ? 'table' : 'preview')}
            title={viewMode === 'preview' ? 'Switch to table view' : 'Switch to preview'}
          >
            <i className={`bi ${viewMode === 'preview' ? 'bi-table' : 'bi-eye'} me-1`}></i>
            {viewMode === 'preview' ? 'Table View' : 'Preview'}
          </button>
        </div>
      </div>

      {/* Audience tabs */}
      <div className="d-flex align-items-center gap-2 mb-3 flex-shrink-0 flex-wrap">
        {audiences.map((a) => {
          const isSelected = selectedAudienceId === a.id
          const isGenerating = a.versions.some((v) => v.state === 'generating')
          return (
            <button
              key={a.id}
              className={`btn btn-sm ${isSelected ? 'btn-primary' : 'btn-outline-primary'}`}
              onClick={() => setSelectedAudienceId(a.id)}
            >
              {isGenerating && (
                <span className="spinner-border spinner-border-sm me-1" style={{ width: '0.6rem', height: '0.6rem' }} />
              )}
              {a.name}
            </button>
          )
        })}
      </div>

      {/* Content area */}
      <div className="flex-grow-1" style={{ minHeight: 0 }}>
        {viewMode === 'preview' ? (
          <PreviewView
            audience={selectedAudience}
            activeVersion={activeVersion}
            generatingVersion={generatingVersion}
            html={html}
            loadingPreview={loadingPreview}
            iframeRef={iframeRef}
            onReject={openRejectModal}
          />
        ) : (
          <TableView
            audiences={audiences}
            variables={variables}
            selectedAudienceId={selectedAudienceId}
            onSelectAudience={setSelectedAudienceId}
            onReject={openRejectModal}
          />
        )}
      </div>

      {/* Rejection modal */}
      {rejectModal && (
        <div className="modal d-block" tabIndex="-1" style={{ backgroundColor: 'rgba(0,0,0,0.5)' }}>
          <div className="modal-dialog">
            <div className="modal-content">
              <div className="modal-header">
                <h5 className="modal-title">Reject &amp; Regenerate — {rejectModal.name}</h5>
                <button className="btn-close" onClick={() => setRejectModal(null)} disabled={rejecting} />
              </div>
              <div className="modal-body">
                <p className="text-muted small mb-3">
                  The current version will be rejected and new content will be generated for this audience.
                  Your feedback will be sent to the AI.
                </p>
                {rejectError && <div className="alert alert-danger py-2 small">{rejectError}</div>}
                <label className="form-label fw-semibold">Rejection reason</label>
                <textarea
                  className="form-control"
                  rows={4}
                  value={rejectionComment}
                  onChange={(e) => setRejectionComment(e.target.value)}
                  placeholder="What should be improved? e.g. 'Too formal, needs to feel more conversational'"
                  autoFocus
                />
              </div>
              <div className="modal-footer">
                <button className="btn btn-outline-secondary" onClick={() => setRejectModal(null)} disabled={rejecting}>
                  Cancel
                </button>
                <button className="btn btn-danger" onClick={submitRejection} disabled={rejecting || !rejectionComment.trim()}>
                  {rejecting ? 'Submitting…' : 'Reject & Regenerate'}
                </button>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}

// ─── Preview View (default) ─────────────────────────────────────────────────

function PreviewView({ audience, activeVersion, generatingVersion, html, loadingPreview, iframeRef, onReject }) {
  return (
    <div className="d-flex flex-column h-100">
      {/* Audience toolbar with reject button */}
      {audience && (
        <div className="d-flex align-items-center justify-content-between mb-2 flex-shrink-0">
          <div className="d-flex align-items-center gap-2">
            <span className="fw-semibold">{audience.name}</span>
            {activeVersion && (
              <span className="badge bg-light text-muted border">v{activeVersion.version_number}</span>
            )}
            {generatingVersion && (
              <span className="badge bg-warning text-dark">
                <span className="spinner-border spinner-border-sm me-1" style={{ width: '0.6rem', height: '0.6rem' }} />
                v{generatingVersion.version_number} generating
              </span>
            )}
            {loadingPreview && (
              <div className="spinner-border spinner-border-sm text-secondary" role="status" />
            )}
          </div>
          {activeVersion && !generatingVersion && (
            <button
              className="btn btn-outline-danger btn-sm"
              onClick={() => onReject(audience)}
            >
              <i className="bi bi-arrow-repeat me-1"></i>Reject &amp; Regenerate
            </button>
          )}
        </div>
      )}

      {/* Full-width preview */}
      <div className="border rounded flex-grow-1 bg-white" style={{ minHeight: 0 }}>
        {generatingVersion ? (
          <div className="d-flex align-items-center justify-content-center h-100 text-muted flex-column gap-2">
            <div className="spinner-border" role="status" />
            <p className="mb-0 small">Generating v{generatingVersion.version_number}…</p>
          </div>
        ) : html === null ? (
          <div className="d-flex align-items-center justify-content-center h-100 text-muted">
            <small>No active version to preview</small>
          </div>
        ) : (
          <iframe
            ref={iframeRef}
            style={{ width: '100%', height: '100%', border: 'none' }}
            title="Email Preview"
          />
        )}
      </div>
    </div>
  )
}

// ─── Table View ─────────────────────────────────────────────────────────────

function TableView({ audiences, variables, selectedAudienceId, onSelectAudience, onReject }) {
  const defaultSelected = Object.fromEntries(
    audiences.map((a) => {
      const active = [...a.versions].reverse().find((v) => v.state === 'active')
      const latest = a.versions[a.versions.length - 1]
      return [a.id, (active || latest)?.id ?? null]
    })
  )
  const [selectedVersionIds, setSelectedVersionIds] = useState(defaultSelected)

  useEffect(() => {
    setSelectedVersionIds(Object.fromEntries(
      audiences.map((a) => {
        const active = [...a.versions].reverse().find((v) => v.state === 'active')
        const latest = a.versions[a.versions.length - 1]
        return [a.id, (active || latest)?.id ?? null]
      })
    ))
  }, [audiences])

  if (variables.length === 0) {
    return <p className="text-muted">No text variables found in this email.</p>
  }

  return (
    <div style={{ overflowX: 'auto', height: '100%' }}>
      <table className="table table-bordered table-sm align-top mb-0" style={{ tableLayout: 'fixed', minWidth: 300 + audiences.length * 260 }}>
        <thead className="table-light" style={{ position: 'sticky', top: 0, zIndex: 2 }}>
          <tr>
            <th style={{ width: 240 }} className="align-top">
              <span className="text-muted small text-uppercase fw-semibold">Original</span>
            </th>
            {audiences.map((a) => {
              const isSelected = selectedAudienceId === a.id
              const activeVer = [...a.versions].reverse().find((v) => v.state === 'active')
              const generatingVer = a.versions.find((v) => v.state === 'generating')
              return (
                <th
                  key={a.id}
                  style={{
                    width: 260,
                    cursor: 'pointer',
                    backgroundColor: isSelected ? '#fff3f3' : undefined,
                    borderBottom: isSelected ? '3px solid #dc3545' : undefined,
                  }}
                  onClick={() => onSelectAudience(a.id)}
                  className="align-top"
                >
                  <div className="d-flex align-items-start justify-content-between">
                    <div>
                      <div className="fw-semibold">{a.name}</div>
                      {generatingVer && (
                        <small className="text-warning">
                          <span className="spinner-border spinner-border-sm me-1" style={{ width: '0.6rem', height: '0.6rem' }} />
                          v{generatingVer.version_number} generating
                        </small>
                      )}
                    </div>
                    {activeVer && !generatingVer && (
                      <button
                        className="btn btn-outline-danger btn-sm py-0 px-1"
                        style={{ fontSize: '0.7rem', lineHeight: 1.4 }}
                        onClick={(e) => { e.stopPropagation(); onReject(a) }}
                        title="Reject & regenerate"
                      >
                        <i className="bi bi-arrow-repeat me-1"></i>Reject
                      </button>
                    )}
                  </div>
                  <VersionSelector
                    versions={a.versions}
                    selectedId={selectedVersionIds[a.id]}
                    onChange={(id) => setSelectedVersionIds((prev) => ({ ...prev, [a.id]: id }))}
                  />
                </th>
              )
            })}
          </tr>
        </thead>
        <tbody>
          {variables.map((v) => (
            <tr key={v.id}>
              <td className="text-muted small" style={{ whiteSpace: 'pre-wrap', wordBreak: 'break-word' }}>{v.default_value}</td>
              {audiences.map((a) => {
                const isSelected = selectedAudienceId === a.id
                const version = a.versions.find((ver) => ver.id === selectedVersionIds[a.id])
                const value = version?.values?.[v.id]
                return (
                  <td
                    key={a.id}
                    style={{
                      whiteSpace: 'pre-wrap',
                      cursor: 'pointer',
                      backgroundColor: isSelected ? '#fff9f9' : undefined,
                    }}
                    onClick={() => onSelectAudience(a.id)}
                  >
                    {version?.state === 'generating' ? (
                      <span className="text-warning fst-italic small">
                        <span className="spinner-border spinner-border-sm me-1" />Generating…
                      </span>
                    ) : value != null ? (
                      <span className="small">{value}</span>
                    ) : (
                      <span className="text-danger fst-italic small">missing</span>
                    )}
                  </td>
                )
              })}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  )
}

function VersionSelector({ versions, selectedId, onChange }) {
  if (versions.length === 0) return <span className="text-muted small">No versions</span>
  return (
    <select
      className="form-select form-select-sm mt-1"
      value={selectedId ?? ''}
      onChange={(e) => { e.stopPropagation(); onChange(e.target.value) }}
      onClick={(e) => e.stopPropagation()}
      style={{ fontSize: '0.75rem' }}
    >
      {[...versions].reverse().map((v) => (
        <option key={v.id} value={v.id}>
          v{v.version_number} — {v.state}
          {v.state === 'rejected' ? ' ✕' : v.state === 'active' ? ' ✓' : ' ⟳'}
        </option>
      ))}
    </select>
  )
}
