import React, { useState, useEffect, useRef } from 'react'
import { useNavigate } from 'react-router-dom'
import { apiFetch } from '~/lib/api'
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

  useEffect(() => {
    const inProgress = emails.filter((e) => e.state === 'pending' || e.state === 'regenerating')
    const inProgressIds = new Set(inProgress.map((e) => e.id))

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

    Object.keys(subscriptionsRef.current).forEach((id) => {
      if (!inProgressIds.has(id)) {
        subscriptionsRef.current[id]?.()
        delete subscriptionsRef.current[id]
      }
    })
  }, [emails])

  useEffect(() => {
    return () => {
      Object.values(subscriptionsRef.current).forEach((unsub) => unsub?.())
    }
  }, [])

  const startNew = () => {
    setNewForm({ email_template_id: '', audience_ids: [], ai_service_id: '', ai_model_id: '', campaign_id: '', context: '' })
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
      navigate(`/clients/${clientId}/emails/${created.id}`)
    } catch (e) {
      alert(e.message || 'Failed to save email')
    } finally {
      setSaving(false)
    }
  }

  const deleteEmail = async (id) => {
    if (!confirm('Delete this email?')) return
    await apiFetch(`/api/clients/${clientId}/emails/${id}`, { method: 'DELETE' })
    setEmails((prev) => prev.filter((e) => e.id !== id))
  }

  const runEmail = async (email) => {
    setRunningIds((prev) => new Set([...prev, email.id]))
    try {
      const updated = await apiFetch(`/api/clients/${clientId}/emails/${email.id}/run`, { method: 'POST' })
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

  const toggleAudience = (audienceId) => {
    const ids = newForm.audience_ids.includes(audienceId)
      ? newForm.audience_ids.filter((id) => id !== audienceId)
      : [...newForm.audience_ids, audienceId]
    setNewForm({ ...newForm, audience_ids: ids })
  }

  const modelsForService = (serviceId) => {
    if (!serviceId) return []
    const service = aiServices.find((s) => s.id === serviceId)
    return service ? service.models.filter((m) => m.for_text) : []
  }

  const stateBadge = (state) => {
    const colors = { setup: 'secondary', pending: 'warning', merged: 'success', regenerating: 'warning' }
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
        <h4 className="mb-0">Emails</h4>
        {clientId && (
          <button className="btn btn-danger" onClick={startNew} disabled={!!newForm}>
            <i className="bi bi-plus-lg me-1"></i> New Email
          </button>
        )}
      </div>

      {/* New email form */}
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
                <option value="">Select a template…</option>
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
                          onChange={() => toggleAudience(a.id)}
                        />
                        <label className="form-check-label" htmlFor={`new-aud-${a.id}`}>{a.name}</label>
                      </div>
                    ))
                  )}
                </div>

                {/* AI Service / Model — only shown when customer chooses AI */}
                {ctx?.customer_chooses_ai !== false && (
                  <div className="row mb-3">
                    <div className="col-6">
                      <label className="form-label fw-semibold">AI Service</label>
                      <select
                        className="form-select"
                        value={newForm.ai_service_id}
                        onChange={(e) => setNewForm({ ...newForm, ai_service_id: e.target.value, ai_model_id: '' })}
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
                        value={newForm.ai_model_id}
                        onChange={(e) => setNewForm({ ...newForm, ai_model_id: e.target.value })}
                        disabled={!newForm.ai_service_id}
                      >
                        <option value="">Select a model…</option>
                        {modelsForService(newForm.ai_service_id).map((m) => (
                          <option key={m.id} value={m.id}>{m.name}</option>
                        ))}
                      </select>
                    </div>
                  </div>
                )}

                {/* Campaign */}
                <div className="mb-3">
                  <div className="d-flex align-items-baseline justify-content-between mb-1">
                    <label className="form-label fw-semibold mb-0">
                      Campaign <span className="text-muted fw-normal">(optional)</span>
                    </label>
                    {newForm.campaign_id && (
                      <button
                        type="button"
                        className="btn btn-link btn-sm p-0 text-decoration-none"
                        style={{ fontSize: '0.8rem' }}
                        onClick={() => openCampaignSummary(newForm.campaign_id)}
                      >
                        <i className="bi bi-info-circle me-1"></i>Show campaign summary
                      </button>
                    )}
                  </div>
                  <select
                    className="form-select"
                    value={newForm.campaign_id}
                    onChange={(e) => setNewForm({ ...newForm, campaign_id: e.target.value })}
                  >
                    <option value="">No campaign</option>
                    {campaigns.map((c) => (
                      <option key={c.id} value={c.id}>{c.name}</option>
                    ))}
                  </select>
                </div>

                {/* Context */}
                <div className="mb-3">
                  <label className="form-label fw-semibold">
                    Context
                  </label>
                  <textarea
                    className="form-control"
                    rows={3}
                    value={newForm.context}
                    onChange={(e) => setNewForm({ ...newForm, context: e.target.value })}
                    placeholder="Additional context or instructions for the AI…"
                  />
                </div>

                <div className="d-flex gap-2">
                  <button className="btn btn-danger btn-sm" onClick={saveNew} disabled={saving}>
                    {saving ? 'Saving…' : 'Save'}
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
          <button className="btn btn-outline-danger" onClick={startNew}>Create Email</button>
        </div>
      ) : (
        <div className="list-group">
          {emails.map((e) => (
            <div
              key={e.id}
              className="list-group-item list-group-item-action d-flex justify-content-between align-items-start"
            >
              <div
                className="cursor-pointer flex-grow-1"
                onClick={() => navigate(`/clients/${clientId}/emails/${e.id}`)}
              >
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
                {e.state === 'setup' && (() => {
                  const aiReady = ctx?.customer_chooses_ai === false || (e.ai_service_id && e.ai_model_id)
                  const ready = aiReady && e.audience_ids?.length > 0
                  const reason = !e.audience_ids?.length ? 'Add an audience to run'
                    : !e.ai_service_id ? 'Select an AI service to run'
                    : 'Select an AI model to run'
                  return (
                    <button
                      className="btn btn-success btn-sm"
                      onClick={ready ? (ev) => { ev.stopPropagation(); runEmail(e) } : (ev) => ev.stopPropagation()}
                      disabled={!ready || runningIds.has(e.id)}
                      title={ready ? undefined : reason}
                    >
                      {runningIds.has(e.id) ? (
                        <span className="spinner-border spinner-border-sm" role="status" />
                      ) : (
                        <><i className="bi bi-play-fill me-1"></i>Run</>
                      )}
                    </button>
                  )
                })()}
                {(e.state === 'pending' || e.state === 'regenerating') && (
                  <span className="d-flex align-items-center gap-1 text-warning">
                    <span className="spinner-border spinner-border-sm" role="status" />
                    <small>{e.state === 'regenerating' ? 'Regenerating…' : 'Processing…'}</small>
                  </span>
                )}
                {(e.state === 'merged' || e.state === 'regenerating') && (
                  <button
                    className="btn btn-outline-success btn-sm"
                    onClick={(ev) => { ev.stopPropagation(); navigate(`/clients/${clientId}/emails/${e.id}/results`) }}
                    title="View Results"
                  >
                    <i className="bi bi-table me-1"></i>Go to Results
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
          ))}
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
                      <div className="border rounded p-3" style={{ background: '#f8f9fa', whiteSpace: 'pre-wrap', fontSize: '0.85rem', lineHeight: 1.6 }}>
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
  )
}
