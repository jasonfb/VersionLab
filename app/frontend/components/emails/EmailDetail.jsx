import React, { useState, useEffect, useRef } from 'react'
import { useParams, useNavigate, Link } from 'react-router-dom'
import { apiFetch, apiUpload } from '~/lib/api'
import { subscribeEmailChannel } from '~/lib/cable'
import { useAccount } from '../layout/AccountContext'

export default function EmailDetail() {
  const { clientId, emailId } = useParams()
  const navigate = useNavigate()
  const ctx = useAccount()

  const [email, setEmail] = useState(null)
  const [loading, setLoading] = useState(true)
  const [audiences, setAudiences] = useState([])
  const [campaigns, setCampaigns] = useState([])
  const [aiServices, setAiServices] = useState([])
  const [documents, setDocuments] = useState([])
  const [form, setForm] = useState(null)
  const [saving, setSaving] = useState(false)
  const [running, setRunning] = useState(false)
  const [campaignSummaryOpen, setCampaignSummaryOpen] = useState(false)
  const [campaignSummaryData, setCampaignSummaryData] = useState(null)
  const [campaignSummaryLoading, setCampaignSummaryLoading] = useState(false)
  const [jobError, setJobError] = useState(null)

  useEffect(() => {
    if (!clientId || !emailId) return
    setLoading(true)
    Promise.all([
      apiFetch(`/api/clients/${clientId}/emails/${emailId}`),
      apiFetch(`/api/clients/${clientId}/audiences`),
      apiFetch(`/api/clients/${clientId}/campaigns`),
      apiFetch('/api/ai_services'),
      apiFetch(`/api/clients/${clientId}/emails/${emailId}/email_documents`),
    ]).then(([e, a, c, s, d]) => {
      setEmail(e)
      setAudiences(a)
      setCampaigns(c)
      setAiServices(s)
      setDocuments(d)
      setForm({
        audience_ids: e.audience_ids || [],
        ai_service_id: e.ai_service_id || '',
        ai_model_id: e.ai_model_id || '',
        campaign_id: e.campaign_id || '',
        context: e.context || '',
      })
    }).catch(() => {}).finally(() => setLoading(false))
  }, [clientId, emailId])

  // Real-time state updates while running
  useEffect(() => {
    if (!emailId) return
    return subscribeEmailChannel(emailId, {
      received(data) {
        setEmail((prev) => prev ? { ...prev, state: data.state } : prev)
        if (data.error) {
          setJobError(data.error)
        }
      },
    })
  }, [emailId])

  // Poll while AI summary is generating
  const pollRef = useRef(null)
  useEffect(() => {
    clearTimeout(pollRef.current)
    if (email?.ai_summary_state !== 'generating') return
    pollRef.current = setTimeout(() => {
      apiFetch(`/api/clients/${clientId}/emails/${emailId}`)
        .then(setEmail)
        .catch(() => {})
    }, 3000)
    return () => clearTimeout(pollRef.current)
  }, [email, clientId, emailId])

  const saveEdit = async () => {
    setSaving(true)
    try {
      const updated = await apiFetch(`/api/clients/${clientId}/emails/${emailId}`, {
        method: 'PATCH',
        body: JSON.stringify({ email: form }),
      })
      setEmail(updated)
    } finally {
      setSaving(false)
    }
  }

  const runEmail = async () => {
    setRunning(true)
    setJobError(null)
    try {
      const updated = await apiFetch(`/api/clients/${clientId}/emails/${emailId}/run`, { method: 'POST' })
      setEmail(updated)
    } catch (e) {
      alert(e.message || 'Failed to run merge')
    } finally {
      setRunning(false)
    }
  }

  const deleteEmail = async () => {
    if (!confirm('Delete this email?')) return
    await apiFetch(`/api/clients/${clientId}/emails/${emailId}`, { method: 'DELETE' })
    navigate('/emails')
  }

  const handleSummarize = async () => {
    await apiFetch(`/api/clients/${clientId}/emails/${emailId}/summarize`, { method: 'POST' })
    setEmail((prev) => ({ ...prev, ai_summary_state: 'generating' }))
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

  if (loading || !form) {
    return (
      <div className="p-4">
        <div className="spinner-border spinner-border-sm" role="status">
          <span className="visually-hidden">Loading…</span>
        </div>
      </div>
    )
  }

  if (!email) {
    return (
      <div className="p-4">
        <div className="alert alert-danger">Email not found.</div>
      </div>
    )
  }

  const isRunning = email.state === 'pending' || email.state === 'regenerating'
  const hasResults = email.state === 'merged' || email.state === 'regenerating'
  const isSetup = email.state === 'setup'
  const canRun = isSetup && form.ai_service_id && form.ai_model_id && form.audience_ids?.length > 0
  const runBlockedReason = isSetup && !canRun
    ? (!form.audience_ids?.length ? 'Add an audience to run'
      : !form.ai_service_id ? 'Select an AI service to run'
      : 'Select an AI model to run')
    : null

  const stateColors = { setup: 'secondary', pending: 'warning', merged: 'success', regenerating: 'warning' }

  return (
    <div className="p-4" style={{ maxWidth: 680 }}>
      {/* Back */}
      <div className="mb-3">
        <Link to="/emails" className="text-muted small text-decoration-none">
          <i className="bi bi-arrow-left me-1"></i>Back to Emails
        </Link>
      </div>

      {/* Job error */}
      {jobError && (
        <div className="alert alert-danger alert-dismissible mb-3" role="alert">
          <strong>Run failed:</strong> {jobError}
          <button type="button" className="btn-close" onClick={() => setJobError(null)} />
        </div>
      )}

      {/* Header */}
      <div className="d-flex align-items-center justify-content-between mb-4">
        <div className="d-flex align-items-center gap-2">
          <h5 className="mb-0">{email.email_template_name}</h5>
          <span className={`badge bg-${stateColors[email.state] || 'secondary'}`}>{email.state}</span>
        </div>
        <div className="d-flex align-items-center gap-2">
          {isRunning && (
            <span className="d-flex align-items-center gap-1 text-warning">
              <span className="spinner-border spinner-border-sm" role="status" />
              <small>{email.state === 'regenerating' ? 'Regenerating…' : 'Processing…'}</small>
            </span>
          )}
          {hasResults && (
            <button
              className="btn btn-outline-success btn-sm"
              onClick={() => navigate(`/clients/${clientId}/emails/${emailId}/results`)}
            >
              <i className="bi bi-table me-1"></i>Go to Results
            </button>
          )}
          <button className="btn btn-outline-danger btn-sm" onClick={deleteEmail} title="Delete">
            <i className="bi bi-trash"></i>
          </button>
        </div>
      </div>

      {/* Audiences */}
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
                id={`aud-${a.id}`}
                checked={form.audience_ids.includes(a.id)}
                onChange={() => toggleAudience(a.id)}
              />
              <label className="form-check-label" htmlFor={`aud-${a.id}`}>{a.name}</label>
            </div>
          ))
        )}
      </div>

      {/* AI Service / Model */}
      <div className="row mb-3">
        <div className="col-6">
          <label className="form-label fw-semibold">AI Service</label>
          <select
            className="form-select"
            value={form.ai_service_id}
            onChange={(e) => setForm({ ...form, ai_service_id: e.target.value, ai_model_id: '' })}
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
            <option value="">Select a model…</option>
            {modelsForService(form.ai_service_id).map((m) => (
              <option key={m.id} value={m.id}>{m.name}</option>
            ))}
          </select>
        </div>
      </div>

      {/* Campaign */}
      <div className="mb-3">
        <div className="d-flex align-items-baseline justify-content-between mb-1">
          <label className="form-label fw-semibold mb-0">
            Campaign <span className="text-muted fw-normal">(optional)</span>
          </label>
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

      {/* Context */}
      <div className="mb-3">
        <label className="form-label fw-semibold">
          Context
        </label>
        <textarea
          className="form-control"
          rows={3}
          value={form.context}
          onChange={(e) => setForm({ ...form, context: e.target.value })}
          placeholder="Additional context or instructions for the AI…"
        />
      </div>

      {/* Save / Run / Results */}
      <div className="d-flex align-items-center gap-2 mb-4">
        <button className="btn btn-danger btn-sm" onClick={saveEdit} disabled={saving}>
          {saving ? 'Saving…' : 'Save'}
        </button>
        {(canRun || runBlockedReason) && (
          <button
            className="btn btn-success btn-sm"
            onClick={canRun ? runEmail : undefined}
            disabled={!canRun || running}
            title={runBlockedReason || undefined}
          >
            {running
              ? <span className="spinner-border spinner-border-sm" role="status" />
              : <><i className="bi bi-play-fill me-1"></i>Run Email</>}
          </button>
        )}
        {runBlockedReason && (
          <small className="text-muted">{runBlockedReason}</small>
        )}
        {hasResults && (
          <button
            className="btn btn-outline-success btn-sm"
            onClick={() => navigate(`/clients/${clientId}/emails/${emailId}/results`)}
          >
            <i className="bi bi-table me-1"></i>Go to Results
          </button>
        )}
        {isRunning && (
          <span className="d-flex align-items-center gap-1 text-warning ms-1">
            <span className="spinner-border spinner-border-sm" role="status" />
            <small>{email.state === 'regenerating' ? 'Regenerating…' : 'Processing…'}</small>
          </span>
        )}
      </div>

      <hr className="my-4" />
      <SectionLabel icon="bi-link-45deg">Sections</SectionLabel>
      <AutolinkingSection clientId={clientId} emailId={emailId} />

      <hr className="my-4" />
      <SectionLabel icon="bi-file-earmark-text">Reference Documents</SectionLabel>
      <EmailDocumentsSection
        clientId={clientId}
        emailId={emailId}
        documents={documents}
        setDocuments={setDocuments}
      />

      <hr className="my-4" />
      <SectionLabel icon="bi-stars">AI Document Summary</SectionLabel>
      <EmailAiSummarySection email={email} onSummarize={handleSummarize} />

      <CampaignSummaryModal
        open={campaignSummaryOpen}
        loading={campaignSummaryLoading}
        campaign={campaignSummaryData}
        onClose={() => setCampaignSummaryOpen(false)}
      />
    </div>
  )
}

// ─── Section Label ────────────────────────────────────────────────────────────

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

// ─── Autolinking Section ──────────────────────────────────────────────────────

const DEFAULT_AUTOLINK = {
  autolink_mode: 'none',
  link_mode: null,
  url: '',
  group_purpose: '',
  override_brand_link_styling: false,
  link_color: '',
  underline_links: false,
  italic_links: false,
  bold_links: false,
}

function AutolinkingSection({ clientId, emailId }) {
  const [sections, setSections] = useState([])
  const [loading, setLoading] = useState(false)
  const [activeSectionId, setActiveSectionId] = useState(null)
  const [activeSubsectionId, setActiveSubsectionId] = useState(null)

  useEffect(() => {
    if (!clientId || !emailId) return
    setLoading(true)
    apiFetch(`/api/clients/${clientId}/emails/${emailId}/autolink_settings`)
      .then((data) => {
        setSections(data)
        if (data.length > 0) {
          setActiveSectionId(data[0].id)
          setActiveSubsectionId(null)
        }
      })
      .catch(() => {})
      .finally(() => setLoading(false))
  }, [clientId, emailId])

  const getActiveSetting = () => {
    const section = sections.find((s) => s.id === activeSectionId)
    if (!section) return DEFAULT_AUTOLINK
    if (activeSubsectionId) {
      const sub = section.subsections?.find((s) => s.id === activeSubsectionId)
      return sub?.autolink_setting || DEFAULT_AUTOLINK
    }
    return section.autolink_setting || DEFAULT_AUTOLINK
  }

  const updateSetting = async (field, value) => {
    const sectionId = activeSubsectionId || activeSectionId
    if (!sectionId) return

    const current = getActiveSetting()
    const updated = { ...current, [field]: value }

    // Optimistic update
    setSections((prev) => prev.map((s) => {
      if (!activeSubsectionId && s.id === activeSectionId) {
        return { ...s, autolink_setting: updated }
      }
      if (activeSubsectionId && s.id === activeSectionId) {
        return {
          ...s,
          subsections: s.subsections.map((sub) =>
            sub.id === activeSubsectionId ? { ...sub, autolink_setting: updated } : sub
          ),
        }
      }
      return s
    }))

    await apiFetch(`/api/clients/${clientId}/emails/${emailId}/autolink_settings/${sectionId}`, {
      method: 'PATCH',
      body: JSON.stringify({ autolink_setting: updated }),
    }).catch(() => {})
  }

  if (loading) {
    return (
      <div className="mb-3 text-muted small d-flex align-items-center gap-2">
        <span className="spinner-border spinner-border-sm" />
        Loading sections…
      </div>
    )
  }

  if (sections.length === 0) {
    return (
      <p className="text-muted small mb-3">
        No sections defined on this template. Define sections in the template editor first.
      </p>
    )
  }

  const setting = getActiveSetting()
  const autolinkingOn = setting.autolink_mode === 'link_relevant_text'
  const activeSection = sections.find((s) => s.id === activeSectionId)
  const activeSubs = activeSection?.subsections || []

  return (
    <div className="mb-3">
      {/* Section tabs */}
      <ul className="nav nav-tabs mb-0" style={{ fontSize: '0.8rem' }}>
        {sections.map((s, idx) => (
          <li key={s.id} className="nav-item">
            <button
              className={`nav-link py-1 px-2 ${activeSectionId === s.id && !activeSubsectionId ? 'active' : ''}`}
              onClick={() => { setActiveSectionId(s.id); setActiveSubsectionId(null) }}
            >
              {s.name || `Section ${idx + 1}`}
            </button>
          </li>
        ))}
      </ul>

      {/* Subsection tabs */}
      {activeSubs.length > 0 && (
        <ul className="nav nav-tabs border-top-0" style={{ fontSize: '0.75rem', background: '#f8f9fa' }}>
          <li className="nav-item">
            <button
              className={`nav-link py-1 px-2 ${!activeSubsectionId ? 'active' : ''}`}
              onClick={() => setActiveSubsectionId(null)}
            >
              {activeSection?.name || 'Section'} (whole)
            </button>
          </li>
          {activeSubs.map((sub) => (
            <li key={sub.id} className="nav-item">
              <button
                className={`nav-link py-1 px-2 ${activeSubsectionId === sub.id ? 'active' : ''}`}
                onClick={() => { setActiveSectionId(activeSection.id); setActiveSubsectionId(sub.id) }}
              >
                {sub.name}
              </button>
            </li>
          ))}
        </ul>
      )}

      {/* Settings panel */}
      <div className="border border-top-0 rounded-bottom p-3">
        {/* (1) Section Purpose — always visible, at top */}
        <div className="mb-3">
          <label className="form-label fw-semibold mb-1" style={{ fontSize: '0.85rem' }}>
            Section purpose <span className="text-muted fw-normal">(optional)</span>
          </label>
          <textarea
            className="form-control form-control-sm"
            rows={2}
            placeholder="e.g. Include an impact statement linking to a relevant article to motivate clicks."
            value={setting.group_purpose || ''}
            onChange={(e) => updateSetting('group_purpose', e.target.value)}
            onBlur={(e) => updateSetting('group_purpose', e.target.value)}
          />
        </div>

        {/* (2) Link Mode — always visible */}
        <div className="mb-3">
          <label className="form-label fw-semibold mb-1" style={{ fontSize: '0.85rem' }}>Link Mode</label>
          <p className="text-muted mb-1" style={{ fontSize: '0.75rem' }}>Choose how link destinations are determined for this section.</p>
          <div className="d-flex gap-3">
            {[
              { value: 'user_url', label: "I'll provide the URL" },
              { value: 'ai_decide', label: 'Let AI decide' },
            ].map(({ value, label }) => (
              <div key={value} className="form-check">
                <input
                  className="form-check-input"
                  type="radio"
                  name={`link-mode-${activeSectionId}-${activeSubsectionId}`}
                  id={`link-mode-${value}-${activeSectionId}-${activeSubsectionId}`}
                  checked={setting.link_mode === value}
                  onChange={() => updateSetting('link_mode', value)}
                />
                <label
                  className="form-check-label"
                  style={{ fontSize: '0.85rem' }}
                  htmlFor={`link-mode-${value}-${activeSectionId}-${activeSubsectionId}`}
                >
                  {label}
                </label>
              </div>
            ))}
          </div>
        </div>

        {/* URL — only when user_url */}
        {setting.link_mode === 'user_url' && (
          <div className="mb-3">
            <label className="form-label fw-semibold mb-1" style={{ fontSize: '0.85rem' }}>URL</label>
            <input
              type="url"
              className="form-control form-control-sm"
              placeholder="https://example.com"
              value={setting.url || ''}
              onChange={(e) => updateSetting('url', e.target.value)}
              onBlur={(e) => updateSetting('url', e.target.value)}
            />
          </div>
        )}

        {/* (3) Subheading/body Auto-linking — YES/NO */}
        <div className="mb-3">
          <label className="form-label fw-semibold mb-1" style={{ fontSize: '0.85rem' }}>Subheading/body Auto-linking</label>
          <div className="d-flex gap-3 mb-1">
            {[
              { value: 'link_relevant_text', label: 'Yes' },
              { value: 'none', label: 'No' },
            ].map(({ value, label }) => (
              <div key={value} className="form-check">
                <input
                  className="form-check-input"
                  type="radio"
                  name={`autolink-mode-${activeSectionId}-${activeSubsectionId}`}
                  id={`autolink-mode-${value}-${activeSectionId}-${activeSubsectionId}`}
                  checked={setting.autolink_mode === value}
                  onChange={() => updateSetting('autolink_mode', value)}
                />
                <label
                  className="form-check-label"
                  style={{ fontSize: '0.85rem' }}
                  htmlFor={`autolink-mode-${value}-${activeSectionId}-${activeSubsectionId}`}
                >
                  {label}
                </label>
              </div>
            ))}
          </div>
          <p className="text-muted mb-0" style={{ fontSize: '0.75rem' }}>
            {autolinkingOn
              ? 'Autolinking will be applied to body, subheading, buttons, and images in this section.'
              : 'Autolinking will be applied to buttons and images in this section.'}
          </p>
        </div>

        {/* Override Brand Link Styling toggle */}
        <div className="mb-2">
          <div className="form-check form-switch">
            <input
              className="form-check-input"
              type="checkbox"
              role="switch"
              id={`override-brand-link-styling-${activeSectionId}-${activeSubsectionId}`}
              checked={!!setting.override_brand_link_styling}
              onChange={(e) => updateSetting('override_brand_link_styling', e.target.checked)}
            />
            <label
              className="form-check-label fw-semibold"
              style={{ fontSize: '0.85rem' }}
              htmlFor={`override-brand-link-styling-${activeSectionId}-${activeSubsectionId}`}
            >
              Override Brand Link Styling
            </label>
          </div>
        </div>

        {/* Link Styling — shown only when override is on */}
        {setting.override_brand_link_styling && (
          <div className="mb-1 ps-2 border-start border-2">
            <p className="text-muted mb-2" style={{ fontSize: '0.75rem' }}>Configure how hyperlinks appear in this section's content.</p>

            {/* Link Color */}
            <div className="mb-2 d-flex align-items-center gap-2">
              <label className="mb-0" style={{ fontSize: '0.82rem', minWidth: 90 }}>Link Color</label>
              <div
                className="rounded flex-shrink-0"
                style={{ width: 24, height: 24, background: setting.link_color || '#000000', border: '1px solid #ccc' }}
              />
              <input
                type="text"
                className="form-control form-control-sm"
                style={{ maxWidth: 110 }}
                placeholder="#000000"
                value={setting.link_color || ''}
                onChange={(e) => updateSetting('link_color', e.target.value)}
                onBlur={(e) => updateSetting('link_color', e.target.value)}
                maxLength={7}
              />
            </div>

            {/* Toggles */}
            {[
              { field: 'underline_links', label: 'Underline links' },
              { field: 'italic_links', label: 'Italic links' },
              { field: 'bold_links', label: 'Bold links' },
            ].map(({ field, label }) => (
              <div key={field} className="form-check form-switch mb-1">
                <input
                  className="form-check-input"
                  type="checkbox"
                  role="switch"
                  id={`${field}-${activeSectionId}-${activeSubsectionId}`}
                  checked={!!setting[field]}
                  onChange={(e) => updateSetting(field, e.target.checked)}
                />
                <label
                  className="form-check-label"
                  style={{ fontSize: '0.82rem' }}
                  htmlFor={`${field}-${activeSectionId}-${activeSubsectionId}`}
                >
                  {label}
                </label>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
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
