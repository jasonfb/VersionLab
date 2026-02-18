import React, { useState, useEffect, useRef, useCallback } from 'react'
import { useParams, useNavigate } from 'react-router-dom'
import { apiFetch, csrfToken } from '~/lib/api'
import { subscribeMergeChannel } from '~/lib/cable'

export default function MergeResultsPage() {
  const { projectId, mergeId } = useParams()
  const navigate = useNavigate()
  const [data, setData] = useState(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)
  const [activeTab, setActiveTab] = useState('table')

  const fetchResults = useCallback(() => {
    return apiFetch(`/api/projects/${projectId}/merges/${mergeId}/results`)
      .then(setData)
      .catch((e) => setError(e.message))
  }, [projectId, mergeId])

  useEffect(() => {
    fetchResults().finally(() => setLoading(false))
  }, [fetchResults])

  // Subscribe via Action Cable for real-time updates
  useEffect(() => {
    return subscribeMergeChannel(mergeId, {
      received() { fetchResults() },
    })
  }, [mergeId, fetchResults])

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

  return (
    <div className="p-4">
      <div className="d-flex align-items-center gap-3 mb-4">
        <button className="btn btn-outline-secondary btn-sm" onClick={() => navigate('/merge')}>
          <i className="bi bi-arrow-left me-1"></i>Back
        </button>
        <div>
          <h4 className="mb-0">
            Merge Results
            {state === 'regenerating' && (
              <span className="ms-2 badge bg-warning text-dark fs-6 fw-normal">
                <span className="spinner-border spinner-border-sm me-1" role="status" />
                Regenerating…
              </span>
            )}
          </h4>
          <small className="text-muted">{email_template_name}</small>
        </div>
      </div>

      <ul className="nav nav-tabs mb-4">
        <li className="nav-item">
          <button className={`nav-link ${activeTab === 'table' ? 'active' : ''}`} onClick={() => setActiveTab('table')}>
            Variables Table
          </button>
        </li>
        <li className="nav-item">
          <button className={`nav-link ${activeTab === 'preview' ? 'active' : ''}`} onClick={() => setActiveTab('preview')}>
            Preview
          </button>
        </li>
        <li className="nav-item">
          <button className={`nav-link ${activeTab === 'export' ? 'active' : ''}`} onClick={() => setActiveTab('export')}>
            Export
          </button>
        </li>
      </ul>

      {activeTab === 'table' && (
        <VariablesTable audiences={audiences} variables={variables} />
      )}
      {activeTab === 'preview' && (
        <MergePreview
          projectId={projectId}
          mergeId={mergeId}
          audiences={audiences}
          onRejected={fetchResults}
        />
      )}
      {activeTab === 'export' && (
        <ExportTab projectId={projectId} mergeId={mergeId} audiences={audiences} />
      )}
    </div>
  )
}

// ─── Variables Table ────────────────────────────────────────────────────────

function VariablesTable({ audiences, variables }) {
  // selectedVersionId per audience — default to latest active version
  const defaultSelected = Object.fromEntries(
    audiences.map((a) => {
      const active = [...a.versions].reverse().find((v) => v.state === 'active')
      const latest = a.versions[a.versions.length - 1]
      return [a.id, (active || latest)?.id ?? null]
    })
  )
  const [selectedVersionIds, setSelectedVersionIds] = useState(defaultSelected)

  // Update defaults when audience versions change (e.g. after regeneration)
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
    return <p className="text-muted">No text variables found in this merge.</p>
  }

  return (
    <div style={{ overflowX: 'auto' }}>
      <table className="table table-bordered table-sm align-top" style={{ tableLayout: 'fixed', width: '100%' }}>
        <thead className="table-light">
          <tr>
            <th style={{ width: 300 }}>Original</th>
            {audiences.map((a) => (
              <th key={a.id} style={{ width: 240 }}>
                <div className="fw-semibold mb-1">{a.name}</div>
                <VersionSelector
                  versions={a.versions}
                  selectedId={selectedVersionIds[a.id]}
                  onChange={(id) => setSelectedVersionIds((prev) => ({ ...prev, [a.id]: id }))}
                />
              </th>
            ))}
          </tr>
        </thead>
        <tbody>
          {variables.map((v) => (
            <tr key={v.id}>
              <td className="text-muted small" style={{ whiteSpace: 'pre-wrap', wordBreak: 'break-word' }}>{v.default_value}</td>
              {audiences.map((a) => {
                const version = a.versions.find((ver) => ver.id === selectedVersionIds[a.id])
                const value = version?.values?.[v.id]
                return (
                  <td key={a.id} style={{ whiteSpace: 'pre-wrap' }}>
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
      className="form-select form-select-sm"
      value={selectedId ?? ''}
      onChange={(e) => onChange(e.target.value)}
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

// ─── Export ─────────────────────────────────────────────────────────────────

function ExportTab({ projectId, mergeId, audiences }) {
  const activeCount = audiences.filter((a) =>
    a.versions.some((v) => v.state === 'active')
  ).length

  return (
    <div className="py-2" style={{ maxWidth: 480 }}>
      <p className="text-muted mb-4">
        Download a ZIP file containing one HTML file per audience, with all variable values
        substituted into the final template.
        {activeCount < audiences.length && (
          <span className="d-block mt-2 text-warning">
            <i className="bi bi-exclamation-triangle me-1"></i>
            {audiences.length - activeCount} audience{audiences.length - activeCount !== 1 ? 's' : ''} without
            an active version will be excluded.
          </span>
        )}
      </p>
      <a
        href={`/api/projects/${projectId}/merges/${mergeId}/export`}
        className="btn btn-primary"
        download
      >
        <i className="bi bi-download me-2"></i>Download ZIP ({activeCount} file{activeCount !== 1 ? 's' : ''})
      </a>
    </div>
  )
}

// ─── Preview ────────────────────────────────────────────────────────────────

function MergePreview({ projectId, mergeId, audiences, onRejected }) {
  const [selectedAudienceId, setSelectedAudienceId] = useState(audiences[0]?.id ?? null)
  const [html, setHtml] = useState(null)
  const [loadingPreview, setLoadingPreview] = useState(false)
  const [rejectModal, setRejectModal] = useState(null) // { audience } | null
  const [rejectionComment, setRejectionComment] = useState('')
  const [rejecting, setRejecting] = useState(false)
  const [rejectError, setRejectError] = useState(null)
  const iframeRef = useRef(null)

  useEffect(() => {
    if (!selectedAudienceId) return
    const audience = audiences.find((a) => a.id === selectedAudienceId)
    const activeVersion = [...(audience?.versions ?? [])].reverse().find((v) => v.state === 'active')
    if (!activeVersion) { setHtml(null); return }

    setLoadingPreview(true)
    fetch(`/api/projects/${projectId}/merges/${mergeId}/preview?audience_id=${selectedAudienceId}`, {
      headers: { 'X-CSRF-Token': csrfToken() },
    })
      .then((r) => r.text())
      .then(setHtml)
      .finally(() => setLoadingPreview(false))
  }, [projectId, mergeId, selectedAudienceId, audiences])

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
      await apiFetch(`/api/projects/${projectId}/merges/${mergeId}/reject`, {
        method: 'POST',
        body: JSON.stringify({ audience_id: rejectModal.id, rejection_comment: rejectionComment }),
      })
      setRejectModal(null)
      await onRejected()
    } catch (e) {
      setRejectError(e.message || 'Failed to reject')
    } finally {
      setRejecting(false)
    }
  }

  return (
    <>
      <div className="d-flex gap-0" style={{ minHeight: 600 }}>
        {/* Sidebar */}
        <div className="border-end pe-3 me-3 flex-shrink-0" style={{ width: 200 }}>
          <p className="text-muted small fw-semibold mb-2 text-uppercase" style={{ letterSpacing: '0.05em' }}>Audience</p>
          <div className="d-flex flex-column gap-2">
            {audiences.map((a) => {
              const activeVersion = [...a.versions].reverse().find((v) => v.state === 'active')
              const generatingVersion = a.versions.find((v) => v.state === 'generating')
              const isSelected = selectedAudienceId === a.id

              return (
                <div key={a.id}>
                  <button
                    className={`btn btn-sm text-start w-100 ${isSelected ? 'btn-danger' : 'btn-outline-secondary'}`}
                    onClick={() => setSelectedAudienceId(a.id)}
                  >
                    <div>{a.name}</div>
                    <small className="opacity-75">
                      {generatingVersion ? (
                        <><span className="spinner-border spinner-border-sm me-1" style={{ width: '0.6rem', height: '0.6rem' }} />v{generatingVersion.version_number} generating</>
                      ) : activeVersion ? (
                        <>v{activeVersion.version_number} active</>
                      ) : '—'}
                    </small>
                  </button>
                  {activeVersion && !generatingVersion && (
                    <button
                      className="btn btn-outline-danger btn-sm w-100 mt-1"
                      onClick={() => openRejectModal(a)}
                      title="Reject this version and regenerate"
                    >
                      <i className="bi bi-x-circle me-1"></i>Reject
                    </button>
                  )}
                </div>
              )
            })}
          </div>
        </div>

        {/* Preview pane */}
        <div className="flex-grow-1 position-relative">
          {loadingPreview && (
            <div className="position-absolute top-0 start-0 w-100 h-100 d-flex align-items-center justify-content-center bg-white bg-opacity-75" style={{ zIndex: 1 }}>
              <div className="spinner-border spinner-border-sm text-secondary" role="status" />
            </div>
          )}
          {(() => {
            const audience = audiences.find((a) => a.id === selectedAudienceId)
            const generating = audience?.versions.find((v) => v.state === 'generating')
            if (generating) {
              return (
                <div className="d-flex align-items-center justify-content-center h-100 text-muted flex-column gap-2" style={{ minHeight: 300 }}>
                  <div className="spinner-border" role="status" />
                  <p className="mb-0">Generating v{generating.version_number}…</p>
                </div>
              )
            }
          })()}
          <iframe
            ref={iframeRef}
            style={{ width: '100%', height: '100%', minHeight: 600, border: '1px solid #dee2e6', borderRadius: 4 }}
            title="Merge Preview"
          />
        </div>
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
    </>
  )
}
