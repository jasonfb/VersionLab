import React, { useState, useEffect, useRef } from 'react'
import { useNavigate } from 'react-router-dom'
import { apiFetch, apiUpload } from '~/lib/api'
import { subscribeEmailChannel } from '~/lib/cable'
import { useAccount } from '../layout/AccountContext'

export default function EmailsIndex() {
  const navigate = useNavigate()
  const ctx = useAccount()
  const clientId = ctx?.current_client_id
  const [emails, setEmails] = useState([])
  const [templates, setTemplates] = useState([])
  const [audiences, setAudiences] = useState([])
  const [campaigns, setCampaigns] = useState([])
  const [loading, setLoading] = useState(true)
  const [newForm, setNewForm] = useState(null)
  const [editingId, setEditingId] = useState(null)
  const [editForm, setEditForm] = useState({ audience_ids: [], campaign_id: '', context: '' })
  const [editEmailData, setEditEmailData] = useState(null)
  const [editDocuments, setEditDocuments] = useState([])
  const [saving, setSaving] = useState(false)
  const [runningIds, setRunningIds] = useState(new Set())
  const [aiServices, setAiServices] = useState([])
  const [campaignSummaryOpen, setCampaignSummaryOpen] = useState(false)
  const [campaignSummaryData, setCampaignSummaryData] = useState(null)
  const [campaignSummaryLoading, setCampaignSummaryLoading] = useState(false)

  useEffect(() => {
    apiFetch('/api/ai_services').then(setAiServices)
  }, [])

  useEffect(() => {
    if (!clientId) return
    setLoading(true)
    setEditingId(null)
    setNewForm(null)

    Promise.allSettled([
      apiFetch(`/api/clients/${clientId}/emails`),
      apiFetch(`/api/clients/${clientId}/email_templates`),
      apiFetch(`/api/clients/${clientId}/audiences`),
      apiFetch(`/api/clients/${clientId}/campaigns`),
    ]).then(([e, t, a, c]) => {
      if (e.status === 'fulfilled') setEmails(e.value)
      if (t.status === 'fulfilled') setTemplates(t.value)
      if (a.status === 'fulfilled') setAudiences(a.value)
      if (c.status === 'fulfilled') setCampaigns(c.value)
    }).finally(() => setLoading(false))
  }, [clientId])

  // Track cable subscriptions by emailId
  const subscriptionsRef = useRef({})

  // Subscribe to any pending/regenerating emails for real-time state updates
  useEffect(() => {
    const inProgress = emails.filter((e) => e.state === 'pending' || e.state === 'regenerating')
    const inProgressIds = new Set(inProgress.map((e) => e.id))

    // Subscribe to newly-active emails
    inProgress.forEach((e) => {
      if (subscriptionsRef.current[e.id]) return
      subscriptionsRef.current[e.id] = subscribeEmailChannel(e.id, {
        received(data) {
          setEmails((prev) => prev.map((email) =>
            email.id === data.email_id ? { ...email, state: data.state } : email
          ))
          if (data.state !== 'pending' && data.state !== 'regenerating') {
            subscriptionsRef.current[data.email_id]?.()
            delete subscriptionsRef.current[data.email_id]
          }
        },
      })
    })

    // Unsubscribe from emails that are no longer in-progress
    Object.keys(subscriptionsRef.current).forEach((id) => {
      if (!inProgressIds.has(id)) {
        subscriptionsRef.current[id]?.()
        delete subscriptionsRef.current[id]
      }
    })
  }, [emails])

  // Unsubscribe all on unmount
  useEffect(() => {
    return () => {
      Object.values(subscriptionsRef.current).forEach((unsub) => unsub?.())
    }
  }, [])

  // Load documents when an email is opened for editing
  useEffect(() => {
    if (!editingId || !clientId) { setEditDocuments([]); return }
    apiFetch(`/api/clients/${clientId}/emails/${editingId}/email_documents`)
      .then(setEditDocuments)
      .catch(() => setEditDocuments([]))
  }, [editingId, clientId])

  // Poll while AI summary is generating for the email being edited
  const pollRef = useRef(null)
  useEffect(() => {
    clearTimeout(pollRef.current)
    if (!editingId || !clientId || editEmailData?.ai_summary_state !== 'generating') return
    pollRef.current = setTimeout(() => {
      apiFetch(`/api/clients/${clientId}/emails`)
        .then((list) => {
          const updated = list.find((e) => e.id === editingId)
          if (updated) setEditEmailData(updated)
        })
    }, 3000)
    return () => clearTimeout(pollRef.current)
  }, [editEmailData, editingId, clientId])

  const startNew = () => {
    setNewForm({ email_template_id: '', audience_ids: [], ai_service_id: '', ai_model_id: '', campaign_id: '', context: '' })
    setEditingId(null)
  }

  const cancelNew = () => setNewForm(null)

  const saveNew = async () => {
    setSaving(true)
    try {
      const created = await apiFetch(`/api/clients/${clientId}/emails`, {
        method: 'POST',
        body: JSON.stringify({ email: newForm }),
      })
      setEmails((prev) => [created, ...prev])
      setNewForm(null)
    } finally {
      setSaving(false)
    }
  }

  const startEditing = (email) => {
    setEditingId(email.id)
    setEditEmailData(email)
    setEditForm({
      audience_ids: email.audience_ids || [],
      ai_service_id: email.ai_service_id || '',
      ai_model_id: email.ai_model_id || '',
      campaign_id: email.campaign_id || '',
      context: email.context || '',
    })
    setNewForm(null)
  }

  const cancelEditing = () => {
    setEditingId(null)
    setEditEmailData(null)
    setEditDocuments([])
    setEditForm({ audience_ids: [], campaign_id: '', context: '' })
  }

  const saveEdit = async () => {
    setSaving(true)
    try {
      const updated = await apiFetch(`/api/clients/${clientId}/emails/${editingId}`, {
        method: 'PATCH',
        body: JSON.stringify({ email: editForm }),
      })
      setEmails((prev) => prev.map((e) => (e.id === editingId ? updated : e)))
      setEditingId(null)
    } finally {
      setSaving(false)
    }
  }

  const deleteEmail = async (id) => {
    if (!confirm('Delete this email?')) return
    await apiFetch(`/api/clients/${clientId}/emails/${id}`, { method: 'DELETE' })
    setEmails((prev) => prev.filter((e) => e.id !== id))
    if (editingId === id) setEditingId(null)
  }

  const runEmail = async (email) => {
    setRunningIds((prev) => new Set([...prev, email.id]))
    try {
      const updated = await apiFetch(`/api/clients/${clientId}/emails/${email.id}/run`, {
        method: 'POST',
      })
      setEmails((prev) => prev.map((e) => (e.id === email.id ? updated : e)))
    } catch (e) {
      alert(e.message || 'Failed to run merge')
    } finally {
      setRunningIds((prev) => {
        const next = new Set(prev)
        next.delete(email.id)
        return next
      })
    }
  }

  const handleSummarize = async () => {
    if (!editingId) return
    await apiFetch(`/api/clients/${clientId}/emails/${editingId}/summarize`, { method: 'POST' })
    setEditEmailData((prev) => ({ ...prev, ai_summary_state: 'generating' }))
  }

  const openCampaignSummary = async (campaignId) => {
    setCampaignSummaryOpen(true)
    setCampaignSummaryData(null)
    setCampaignSummaryLoading(true)
    try {
      const data = await apiFetch(`/api/clients/${clientId}/campaigns/${campaignId}`)
      setCampaignSummaryData(data)
    } finally {
      setCampaignSummaryLoading(false)
    }
  }

  const toggleAudience = (audienceId, form, setForm) => {
    const ids = form.audience_ids.includes(audienceId)
      ? form.audience_ids.filter((id) => id !== audienceId)
      : [...form.audience_ids, audienceId]
    setForm({ ...form, audience_ids: ids })
  }

  const modelsForService = (serviceId) => {
    if (!serviceId) return []
    const service = aiServices.find((s) => s.id === serviceId)
    return service ? service.models : []
  }

  const handleServiceChange = (serviceId, form, setForm) => {
    setForm({ ...form, ai_service_id: serviceId, ai_model_id: '' })
  }

  const aiDropdowns = (form, setForm) => (
    <div className="row mb-3">
      <div className="col-6">
        <label className="form-label fw-semibold">AI Service</label>
        <select
          className="form-select"
          value={form.ai_service_id}
          onChange={(e) => handleServiceChange(e.target.value, form, setForm)}
        >
          <option value="">None</option>
          {aiServices.map((s) => (
            <option key={s.id} value={s.id}>{s.name}</option>
          ))}
        </select>
      </div>
      <div className="col-6">
        <label className="form-label fw-semibold">AI Model</label>
        <select
          className="form-select"
          value={form.ai_model_id}
          onChange={(e) => setForm({ ...form, ai_model_id: e.target.value })}
          disabled={!form.ai_service_id}
        >
          <option value="">Select a model...</option>
          {modelsForService(form.ai_service_id).map((m) => (
            <option key={m.id} value={m.id}>{m.name}</option>
          ))}
        </select>
      </div>
    </div>
  )

  const campaignAndContextFields = (form, setForm) => (
    <>
      <div className="mb-3">
        <div className="d-flex align-items-baseline justify-content-between mb-1">
          <label className="form-label fw-semibold mb-0">Campaign <span className="text-muted fw-normal">(optional)</span></label>
          {form.campaign_id && (
            <button
              type="button"
              className="btn btn-link btn-sm p-0 text-decoration-none"
              style={{ fontSize: '0.8rem' }}
              onClick={() => openCampaignSummary(form.campaign_id)}
            >
              <i className="bi bi-info-circle me-1"></i>Show campaign summary
            </button>
          )}
        </div>
        <select
          className="form-select"
          value={form.campaign_id}
          onChange={(e) => setForm({ ...form, campaign_id: e.target.value })}
        >
          <option value="">No campaign</option>
          {campaigns.map((c) => (
            <option key={c.id} value={c.id}>{c.name}</option>
          ))}
        </select>
      </div>
      <div className="mb-3">
        <label className="form-label fw-semibold">Context <span className="text-muted fw-normal">(optional)</span></label>
        <textarea
          className="form-control"
          rows={3}
          value={form.context}
          onChange={(e) => setForm({ ...form, context: e.target.value })}
          placeholder="Additional context or instructions for the AI..."
        />
      </div>
    </>
  )

  const stateBadge = (state) => {
    const colors = { setup: 'secondary', pending: 'warning', merged: 'success', regenerating: 'warning' }
    return <span className={`badge bg-${colors[state] || 'secondary'}`}>{state}</span>
  }

  if (!ctx || loading) {
    return (
      <div className="p-4">
        <div className="spinner-border spinner-border-sm" role="status">
          <span className="visually-hidden">Loading...</span>
        </div>
      </div>
    )
  }

  return (
    <div className="p-4">
      <div className="d-flex justify-content-between align-items-center mb-4">
        <h4 className="mb-0">Emails</h4>
        {clientId && (
          <button className="btn btn-danger" onClick={startNew} disabled={!!newForm}>
            <i className="bi bi-plus-lg me-1"></i> New Email
          </button>
        )}
      </div>

      {newForm && (
        <div className="card mb-3">
          <div className="card-body">
            <div className="mb-3">
              <label className="form-label fw-semibold">Email Template</label>
              <select
                className="form-select"
                value={newForm.email_template_id}
                onChange={(e) => setNewForm({ ...newForm, email_template_id: e.target.value })}
              >
                <option value="">Select a template...</option>
                {templates.map((t) => (
                  <option key={t.id} value={t.id}>{t.name}</option>
                ))}
              </select>
            </div>
            {newForm.email_template_id && (
              <>
                <div className="mb-3">
                  <label className="form-label fw-semibold">Audiences</label>
                  {audiences.length === 0 ? (
                    <p className="text-muted small">No audiences for this client.</p>
                  ) : (
                    audiences.map((a) => (
                      <div key={a.id} className="form-check">
                        <input
                          className="form-check-input"
                          type="checkbox"
                          id={`new-aud-${a.id}`}
                          checked={newForm.audience_ids.includes(a.id)}
                          onChange={() => toggleAudience(a.id, newForm, setNewForm)}
                        />
                        <label className="form-check-label" htmlFor={`new-aud-${a.id}`}>
                          {a.name}
                        </label>
                      </div>
                    ))
                  )}
                </div>
                {aiDropdowns(newForm, setNewForm)}
                {campaignAndContextFields(newForm, setNewForm)}
                <div className="d-flex gap-2">
                  <button
                    className="btn btn-danger btn-sm"
                    onClick={saveNew}
                    disabled={saving}
                  >
                    {saving ? 'Saving...' : 'Save'}
                  </button>
                  <button className="btn btn-outline-secondary btn-sm" onClick={cancelNew}>Cancel</button>
                </div>
              </>
            )}
            {!newForm.email_template_id && (
              <button className="btn btn-outline-secondary btn-sm" onClick={cancelNew}>Cancel</button>
            )}
          </div>
        </div>
      )}

      <CampaignSummaryModal
        open={campaignSummaryOpen}
        loading={campaignSummaryLoading}
        campaign={campaignSummaryData}
        onClose={() => setCampaignSummaryOpen(false)}
      />

      {emails.length === 0 && !newForm ? (
        <div className="text-center text-muted py-5">
          <i className="bi bi-intersect fs-1 d-block mb-3"></i>
          <p>No emails yet. Create your first email to get started.</p>
          <button className="btn btn-outline-danger" onClick={startNew}>
            Create Email
          </button>
        </div>
      ) : (
        <div className="list-group">
          {emails.map((e) =>
            editingId === e.id ? (
              <div key={e.id} className="list-group-item">
                <div className="mb-3">
                  <label className="form-label text-muted small fw-semibold text-uppercase mb-1" style={{ letterSpacing: '0.05em' }}>Template</label>
                  <div className="d-flex align-items-center gap-2">
                    <strong>{e.email_template_name}</strong>
                    {stateBadge(e.state)}
                  </div>
                </div>
                <div className="mb-3">
                  <label className="form-label fw-semibold">Audiences</label>
                  {audiences.map((a) => (
                    <div key={a.id} className="form-check">
                      <input
                        className="form-check-input"
                        type="checkbox"
                        id={`edit-aud-${a.id}`}
                        checked={editForm.audience_ids.includes(a.id)}
                        onChange={() => toggleAudience(a.id, editForm, setEditForm)}
                      />
                      <label className="form-check-label" htmlFor={`edit-aud-${a.id}`}>
                        {a.name}
                      </label>
                    </div>
                  ))}
                </div>
                {aiDropdowns(editForm, setEditForm)}
                {campaignAndContextFields(editForm, setEditForm)}
                <div className="d-flex gap-2 mb-4">
                  <button className="btn btn-danger btn-sm" onClick={saveEdit} disabled={saving}>
                    {saving ? 'Saving...' : 'Save'}
                  </button>
                  <button className="btn btn-outline-secondary btn-sm" onClick={cancelEditing}>Cancel</button>
                </div>

                <hr className="my-3" />
                <SectionLabel icon="bi-file-earmark-text">Reference Documents</SectionLabel>
                <EmailDocumentsSection
                  clientId={clientId}
                  emailId={e.id}
                  documents={editDocuments}
                  setDocuments={setEditDocuments}
                />

                <hr className="my-3" />
                <SectionLabel icon="bi-stars">AI Document Summary</SectionLabel>
                <EmailAiSummarySection email={editEmailData} onSummarize={handleSummarize} />
              </div>
            ) : (
              <div
                key={e.id}
                className="list-group-item list-group-item-action d-flex justify-content-between align-items-start"
              >
                <div className="cursor-pointer flex-grow-1" onClick={() => startEditing(e)}>
                  <div className="d-flex align-items-center gap-2">
                    <i className="bi bi-intersect me-1 text-muted"></i>
                    <strong>{e.email_template_name}</strong>
                    {stateBadge(e.state)}
                  </div>
                  <small className="text-muted d-block mt-1">
                    {e.audience_names.length > 0
                      ? `Audiences: ${e.audience_names.join(', ')}`
                      : 'No audiences selected'}
                    {e.campaign_name && (
                      <span className="ms-2 text-muted">· Campaign: {e.campaign_name}</span>
                    )}
                  </small>
                </div>
                <div className="d-flex align-items-center gap-2 ms-3">
                  <small className="text-muted">{new Date(e.updated_at).toLocaleDateString()}</small>
                  {e.state === 'setup' && e.ai_service_id && e.ai_model_id && e.audience_ids?.length > 0 && (
                    <button
                      className="btn btn-success btn-sm"
                      onClick={(ev) => { ev.stopPropagation(); runEmail(e) }}
                      disabled={runningIds.has(e.id)}
                      title="Run Merge"
                    >
                      {runningIds.has(e.id) ? (
                        <span className="spinner-border spinner-border-sm" role="status" />
                      ) : (
                        <><i className="bi bi-play-fill me-1"></i>Run</>
                      )}
                    </button>
                  )}
                  {(e.state === 'pending' || e.state === 'regenerating') && (
                    <span className="d-flex align-items-center gap-1 text-warning">
                      <span className="spinner-border spinner-border-sm" role="status" />
                      <small>{e.state === 'regenerating' ? 'Regenerating...' : 'Processing...'}</small>
                    </span>
                  )}
                  {(e.state === 'merged' || e.state === 'regenerating') && (
                    <button
                      className="btn btn-outline-success btn-sm"
                      onClick={(ev) => { ev.stopPropagation(); navigate(`/clients/${clientId}/emails/${e.id}/results`) }}
                      title="View Results"
                    >
                      <i className="bi bi-table me-1"></i>Results
                    </button>
                  )}
                  <button
                    className="btn btn-outline-danger btn-sm"
                    onClick={(ev) => { ev.stopPropagation(); deleteEmail(e.id) }}
                    title="Delete"
                  >
                    <i className="bi bi-trash"></i>
                  </button>
                </div>
              </div>
            )
          )}
        </div>
      )}
    </div>
  )
}

// ─── Campaign Summary Modal ───────────────────────────────────────────────────

function CampaignSummaryModal({ open, loading, campaign, onClose }) {
  if (!open) return null

  const statusColors = { draft: 'secondary', active: 'success', completed: 'primary', archived: 'dark' }

  const formatDate = (d) => d ? new Date(d).toLocaleDateString() : null

  return (
    <>
      <div className="modal d-block" tabIndex="-1" style={{ backgroundColor: 'rgba(0,0,0,0.5)' }} onClick={onClose}>
        <div className="modal-dialog modal-lg modal-dialog-scrollable" onClick={(e) => e.stopPropagation()}>
          <div className="modal-content">
            <div className="modal-header">
              <h5 className="modal-title d-flex align-items-center gap-2">
                <i className="bi bi-megaphone text-muted"></i>
                {loading ? 'Loading campaign…' : (campaign?.name || 'Campaign Summary')}
              </h5>
              <button type="button" className="btn-close" onClick={onClose} />
            </div>
            <div className="modal-body">
              {loading && (
                <div className="d-flex align-items-center gap-2 text-muted py-4 justify-content-center">
                  <span className="spinner-border spinner-border-sm" />
                  <span>Loading…</span>
                </div>
              )}

              {!loading && campaign && (
                <>
                  <div className="d-flex flex-wrap gap-2 mb-4">
                    <span className={`badge bg-${statusColors[campaign.status] || 'secondary'} text-capitalize`}>
                      {campaign.status}
                    </span>
                    {(campaign.start_date || campaign.end_date) && (
                      <span className="text-muted small d-flex align-items-center gap-1">
                        <i className="bi bi-calendar3"></i>
                        {[formatDate(campaign.start_date), formatDate(campaign.end_date)].filter(Boolean).join(' – ')}
                      </span>
                    )}
                  </div>

                  {campaign.description && (
                    <div className="mb-4">
                      <h6 className="text-uppercase text-muted fw-semibold mb-2" style={{ fontSize: '0.72rem', letterSpacing: '0.08em' }}>Description</h6>
                      <p className="mb-0" style={{ fontSize: '0.9rem', whiteSpace: 'pre-wrap' }}>{campaign.description}</p>
                    </div>
                  )}

                  {campaign.goals && (
                    <div className="mb-4">
                      <h6 className="text-uppercase text-muted fw-semibold mb-2" style={{ fontSize: '0.72rem', letterSpacing: '0.08em' }}>Goals</h6>
                      <p className="mb-0" style={{ fontSize: '0.9rem', whiteSpace: 'pre-wrap' }}>{campaign.goals}</p>
                    </div>
                  )}

                  <div>
                    <h6 className="text-uppercase text-muted fw-semibold mb-2" style={{ fontSize: '0.72rem', letterSpacing: '0.08em' }}>
                      <i className="bi bi-stars me-1"></i>AI Campaign Summary
                    </h6>
                    {campaign.ai_summary_state === 'generated' && campaign.ai_summary && (
                      <>
                        <div
                          className="border rounded p-3"
                          style={{ background: '#f8f9fa', whiteSpace: 'pre-wrap', fontSize: '0.85rem', lineHeight: 1.6 }}
                        >
                          {campaign.ai_summary}
                        </div>
                        {campaign.ai_summary_generated_at && (
                          <small className="text-muted d-block mt-1">
                            Generated {new Date(campaign.ai_summary_generated_at).toLocaleDateString()}
                          </small>
                        )}
                      </>
                    )}
                    {campaign.ai_summary_state === 'generating' && (
                      <div className="d-flex align-items-center gap-2 text-muted">
                        <span className="spinner-border spinner-border-sm text-info" />
                        <span className="small">Generating summary…</span>
                      </div>
                    )}
                    {campaign.ai_summary_state === 'idle' && (
                      <p className="text-muted small mb-0">No summary generated yet.</p>
                    )}
                    {campaign.ai_summary_state === 'failed' && (
                      <p className="text-warning small mb-0"><i className="bi bi-exclamation-triangle me-1"></i>Summary generation failed.</p>
                    )}
                  </div>
                </>
              )}
            </div>
            <div className="modal-footer">
              <button type="button" className="btn btn-secondary" onClick={onClose}>Close</button>
            </div>
          </div>
        </div>
      </div>
    </>
  )
}

// ─── Section label ────────────────────────────────────────────────────────────

function SectionLabel({ icon, children }) {
  return (
    <h6
      className="d-flex align-items-center gap-2 text-uppercase text-muted fw-semibold mb-3"
      style={{ letterSpacing: '0.08em', borderBottom: '1px solid #dee2e6', paddingBottom: '0.5rem', fontSize: '0.72rem' }}
    >
      {icon && <i className={`bi ${icon}`}></i>}
      {children}
    </h6>
  )
}

// ─── Email Documents Section ──────────────────────────────────────────────────

function EmailDocumentsSection({ clientId, emailId, documents, setDocuments }) {
  const [uploading, setUploading] = useState(false)
  const [dragOver, setDragOver] = useState(false)
  const [error, setError] = useState(null)
  const inputRef = useRef(null)

  const uploadFile = async (file) => {
    setUploading(true)
    setError(null)
    try {
      const formData = new FormData()
      formData.append('file', file)
      const doc = await apiUpload(`/api/clients/${clientId}/emails/${emailId}/email_documents`, formData)
      setDocuments((prev) => [...prev, doc])
    } catch (err) {
      setError(err.message)
    } finally {
      setUploading(false)
    }
  }

  const handleDrop = (e) => {
    e.preventDefault()
    setDragOver(false)
    Array.from(e.dataTransfer.files).forEach(uploadFile)
  }

  const handleFileInput = (e) => {
    Array.from(e.target.files).forEach(uploadFile)
    e.target.value = ''
  }

  const handleDelete = async (id) => {
    if (!confirm('Remove this document?')) return
    try {
      await apiFetch(`/api/clients/${clientId}/emails/${emailId}/email_documents/${id}`, { method: 'DELETE' })
      setDocuments((prev) => prev.filter((d) => d.id !== id))
    } catch (err) {
      setError(err.message)
    }
  }

  const docIcon = (contentType) => {
    if (!contentType) return 'bi-file-earmark'
    if (contentType.includes('pdf')) return 'bi-file-earmark-pdf text-danger'
    if (contentType.includes('word') || contentType.includes('document')) return 'bi-file-earmark-word text-primary'
    if (contentType.includes('image')) return 'bi-file-earmark-image text-success'
    if (contentType.includes('spreadsheet') || contentType.includes('excel')) return 'bi-file-earmark-spreadsheet text-success'
    return 'bi-file-earmark text-secondary'
  }

  const formatBytes = (bytes) => {
    if (!bytes) return ''
    if (bytes < 1024) return `${bytes} B`
    if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`
    return `${(bytes / (1024 * 1024)).toFixed(1)} MB`
  }

  return (
    <div className="mb-3">
      <p className="text-muted small mb-2">
        Upload PDFs or Word docs that provide context for this email — they will be summarized by AI and used during the merge.
      </p>

      {error && (
        <div className="alert alert-danger alert-dismissible py-2 mb-2">
          {error}
          <button type="button" className="btn-close" onClick={() => setError(null)} />
        </div>
      )}

      <div
        className={`rounded d-flex align-items-center justify-content-center mb-3 ${dragOver ? 'bg-danger bg-opacity-10' : ''}`}
        style={{ border: '2px dashed #ccc', minHeight: 80, cursor: 'pointer', transition: 'all 0.15s' }}
        onDragOver={(e) => { e.preventDefault(); setDragOver(true) }}
        onDragLeave={() => setDragOver(false)}
        onDrop={handleDrop}
        onClick={() => inputRef.current?.click()}
      >
        <input ref={inputRef} type="file" multiple className="d-none" accept=".pdf,.doc,.docx" onChange={handleFileInput} />
        {uploading ? (
          <span className="text-muted d-flex align-items-center gap-2">
            <span className="spinner-border spinner-border-sm" />
            Uploading...
          </span>
        ) : (
          <span className="text-muted small text-center">
            <i className="bi bi-cloud-upload me-1 fs-5 d-block mb-1"></i>
            Drop files or click to browse
            <small className="d-block" style={{ fontSize: '0.7rem' }}>PDF, Word</small>
          </span>
        )}
      </div>

      {documents.length > 0 && (
        <div className="list-group">
          {documents.map((doc) => (
            <div key={doc.id} className="list-group-item d-flex align-items-center gap-3 py-2">
              <i className={`bi ${docIcon(doc.content_type)} fs-5 flex-shrink-0`}></i>
              <div className="flex-grow-1 overflow-hidden">
                <div className="fw-semibold text-truncate" style={{ fontSize: '0.875rem' }}>{doc.display_name}</div>
                <div className="d-flex gap-2">
                  {doc.byte_size && <small className="text-muted">{formatBytes(doc.byte_size)}</small>}
                  {doc.has_extracted_text && (
                    <small className="text-success"><i className="bi bi-check-circle me-1"></i>Text extracted</small>
                  )}
                </div>
              </div>
              <button className="btn btn-sm btn-outline-danger flex-shrink-0" onClick={() => handleDelete(doc.id)}>
                <i className="bi bi-trash"></i>
              </button>
            </div>
          ))}
        </div>
      )}
    </div>
  )
}

// ─── Email AI Summary Section ─────────────────────────────────────────────────

function EmailAiSummarySection({ email, onSummarize }) {
  const state = email?.ai_summary_state
  const summary = email?.ai_summary
  const generatedAt = email?.ai_summary_generated_at

  return (
    <div className="mb-3">
      <p className="text-muted small mb-3">
        The AI summary is generated from your uploaded reference documents and will be included as context during the email merge.
      </p>

      {state === 'idle' && (
        <div className="d-flex align-items-center gap-3">
          <button className="btn btn-outline-secondary btn-sm" onClick={onSummarize}>
            <i className="bi bi-stars me-1"></i>Generate Summary
          </button>
          <span className="text-muted small">Upload documents first, then generate.</span>
        </div>
      )}

      {state === 'generating' && (
        <div className="d-flex align-items-center gap-2 text-muted">
          <span className="spinner-border spinner-border-sm text-info" />
          <span className="small">Generating summary… this may take a moment.</span>
        </div>
      )}

      {state === 'failed' && (
        <div className="alert alert-warning d-flex align-items-center gap-3 py-2">
          <i className="bi bi-exclamation-triangle"></i>
          <span className="small">Summary generation failed. Check that an AI key is configured for this account.</span>
          <button className="btn btn-sm btn-outline-warning ms-auto" onClick={onSummarize}>Retry</button>
        </div>
      )}

      {state === 'generated' && summary && (
        <div>
          <div
            className="border rounded p-3 mb-2"
            style={{ background: '#f8f9fa', whiteSpace: 'pre-wrap', fontSize: '0.85rem', lineHeight: 1.6, maxHeight: 300, overflowY: 'auto' }}
          >
            {summary}
          </div>
          <div className="d-flex align-items-center gap-3">
            <button className="btn btn-outline-secondary btn-sm" onClick={onSummarize}>
              <i className="bi bi-arrow-clockwise me-1"></i>Regenerate
            </button>
            {generatedAt && (
              <span className="text-muted small">
                Generated {new Date(generatedAt).toLocaleDateString()}
              </span>
            )}
          </div>
        </div>
      )}
    </div>
  )
}
