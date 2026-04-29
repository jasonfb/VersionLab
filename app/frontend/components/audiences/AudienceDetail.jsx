import React, { useState, useEffect, useRef } from 'react'
import { useParams, useNavigate, Link } from 'react-router-dom'
import { apiFetch, apiUpload } from '~/lib/api'
import { useAccount } from '../layout/AccountContext'
import {
  INDUSTRIES,
  INTERACTION_RECENCIES,
  PURCHASE_CADENCES,
  RELATIONSHIP_STATUSES,
  OUTCOMES,
  PRIMARY_ACTIONS,
  ORDER_VALUE_BANDS,
  PURCHASE_DRIVERS,
  PROMOTION_SENSITIVITIES,
  ACTION_PREVENTIONS,
  CHECKOUT_FRICTIONS,
  COMMUNICATION_FREQUENCIES,
  CHANNELS,
  LIFECYCLE_MESSAGES,
  PRODUCT_VISUAL_IMPACTS,
} from './audienceOptions'

const INTELLIGENCE_FIELDS = [
  { key: 'executive_summary',                           label: 'Executive Summary' },
  { key: 'demographics_and_financial_capacity',         label: 'Demographics and Financial Capacity' },
  { key: 'lapse_diagnosis',                             label: 'Lapse Diagnosis' },
  { key: 'relationship_state_and_pre_lapse_indicators', label: 'Relationship State and Pre-Lapse Indicators' },
  { key: 'motivational_drivers_and_messaging_framework',label: 'Motivational Drivers and Messaging Framework' },
  { key: 'strategic_reactivation_and_upgrade_cadence',  label: 'Strategic Reactivation and Upgrade Cadence' },
  { key: 'creative_and_imagery_rules',                  label: 'Creative and Imagery Rules' },
  { key: 'risk_scoring_model',                          label: 'Risk Scoring Model (1-100)' },
  { key: 'prohibited_patterns',                         label: 'Prohibited Patterns' },
  { key: 'success_indicators_and_macro_trends',         label: 'Success Indicators and Macro-Trends' },
]

const PROFILE_FIELDS = [
  'client_url', 'industry', 'industry_other',
  'interaction_recency', 'interaction_recency_other',
  'purchase_cadence', 'purchase_cadence_other',
  'relationship_status',
  'primary_action', 'primary_action_other',
  'order_value_band', 'order_value_band_other',
  'promotion_sensitivity', 'promotion_sensitivity_other',
  'communication_frequency', 'communication_frequency_other',
  'product_visuals_impact',
  'general_insights', 'product_categories_themes',
  'supporting_sites',
  'outcomes_that_matter', 'outcomes_that_matter_other',
  'top_purchase_drivers', 'top_purchase_drivers_other',
  'action_prevention_factors', 'action_prevention_factors_other',
  'checkout_friction_points', 'checkout_friction_points_other',
  'communication_channels', 'communication_channels_other',
  'lifecycle_messages', 'lifecycle_messages_other',
]

const ARRAY_FIELDS = [
  'supporting_sites', 'outcomes_that_matter', 'top_purchase_drivers',
  'action_prevention_factors', 'checkout_friction_points',
  'communication_channels', 'lifecycle_messages',
]

function buildEmptyForm() {
  const form = { name: '', details: '' }
  INTELLIGENCE_FIELDS.forEach(({ key }) => { form[key] = '' })
  PROFILE_FIELDS.forEach((key) => {
    form[key] = ARRAY_FIELDS.includes(key) ? [] : ''
  })
  return form
}

function formFromAudience(a) {
  const form = { name: a.name || '', details: a.details || '' }
  INTELLIGENCE_FIELDS.forEach(({ key }) => { form[key] = a[key] || '' })
  PROFILE_FIELDS.forEach((key) => {
    if (ARRAY_FIELDS.includes(key)) {
      form[key] = a[key] || []
    } else {
      form[key] = a[key] || ''
    }
  })
  return form
}

export default function AudienceDetail() {
  const { audienceId } = useParams()
  const navigate = useNavigate()
  const ctx = useAccount()
  const clientId = ctx?.current_client_id

  const [audience, setAudience] = useState(null)
  const [loading, setLoading] = useState(true)
  const [form, setForm] = useState(null)
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState(null)
  const [activeTab, setActiveTab] = useState('profile')
  const [documents, setDocuments] = useState([])

  const pollRef = useRef(null)

  // Fetch audience
  useEffect(() => {
    if (!clientId || !audienceId) return
    setLoading(true)
    apiFetch(`/api/clients/${clientId}/audiences/${audienceId}`)
      .then((a) => {
        setAudience(a)
        setForm(formFromAudience(a))
      })
      .catch(() => setError('Audience not found.'))
      .finally(() => setLoading(false))
  }, [clientId, audienceId])

  // Fetch documents
  useEffect(() => {
    if (!clientId || !audienceId) return
    apiFetch(`/api/clients/${clientId}/audiences/${audienceId}/documents`)
      .then(setDocuments)
      .catch(() => {})
  }, [clientId, audienceId])

  // Poll while generating
  useEffect(() => {
    clearTimeout(pollRef.current)
    if (audience?.ai_summary_state !== 'generating') return
    pollRef.current = setTimeout(() => {
      apiFetch(`/api/clients/${clientId}/audiences/${audienceId}`)
        .then((a) => {
          setAudience(a)
          // Update summary fields in form when generation completes
          if (a.ai_summary_state !== 'generating') {
            setForm((prev) => {
              const updated = { ...prev }
              INTELLIGENCE_FIELDS.forEach(({ key }) => {
                if (a[key]) updated[key] = a[key]
              })
              return updated
            })
            if (a.ai_summary_state === 'generated') {
              setActiveTab('summary')
            }
          }
        })
        .catch(() => {})
    }, 3000)
    return () => clearTimeout(pollRef.current)
  }, [audience, clientId, audienceId])

  const save = async () => {
    setSaving(true)
    setError(null)
    try {
      const updated = await apiFetch(`/api/clients/${clientId}/audiences/${audienceId}`, {
        method: 'PATCH',
        body: JSON.stringify({ audience: form }),
      })
      setAudience(updated)
    } catch (e) {
      setError(e.message || 'Save failed.')
    } finally {
      setSaving(false)
    }
  }

  const buildSummary = async () => {
    setError(null)
    try {
      // Save first, then trigger summary
      await apiFetch(`/api/clients/${clientId}/audiences/${audienceId}`, {
        method: 'PATCH',
        body: JSON.stringify({ audience: form }),
      })
      const updated = await apiFetch(`/api/clients/${clientId}/audiences/${audienceId}/summarize`, {
        method: 'POST',
      })
      setAudience(updated)
    } catch (e) {
      setError(e.message || 'Failed to build summary.')
    }
  }

  const deleteAudience = async () => {
    if (!confirm('Delete this audience?')) return
    await apiFetch(`/api/clients/${clientId}/audiences/${audienceId}`, { method: 'DELETE' })
    navigate('/audiences')
  }

  const set = (key, value) => setForm((prev) => ({ ...prev, [key]: value }))

  if (!ctx || loading) {
    return (
      <div className="p-4">
        <div className="spinner-border spinner-border-sm" role="status">
          <span className="visually-hidden">Loading...</span>
        </div>
      </div>
    )
  }

  if (error && !audience) {
    return <div className="p-4"><div className="alert alert-danger">{error}</div></div>
  }

  const isGenerating = audience?.ai_summary_state === 'generating'

  return (
    <div className="p-4" style={{ maxWidth: 800 }}>
      {/* Back */}
      <div className="mb-3">
        <Link to="/audiences" className="text-muted small text-decoration-none">
          <i className="bi bi-arrow-left me-1"></i>Back to Audiences
        </Link>
      </div>

      {/* Header */}
      <div className="d-flex align-items-center justify-content-between mb-3">
        <h5 className="mb-0">{audience?.name}</h5>
        <button className="btn btn-outline-danger btn-sm" onClick={deleteAudience} title="Delete">
          <i className="bi bi-trash"></i>
        </button>
      </div>

      {error && <div className="alert alert-danger py-2 mb-3">{error}</div>}

      {/* Tab Navigation */}
      <ul className="nav nav-pills mb-4">
        <li className="nav-item">
          <button
            className={`nav-link ${activeTab === 'profile' ? 'active' : ''}`}
            onClick={() => setActiveTab('profile')}
          >
            Audience Profile
          </button>
        </li>
        <li className="nav-item">
          <button
            className={`nav-link ${activeTab === 'summary' ? 'active' : ''}`}
            onClick={() => setActiveTab('summary')}
          >
            Audience Summary
            {isGenerating && (
              <span className="spinner-border spinner-border-sm ms-2" style={{ width: '0.75rem', height: '0.75rem' }} />
            )}
          </button>
        </li>
      </ul>

      {/* Profile Tab */}
      {activeTab === 'profile' && (
        <div>
          {/* Name */}
          <div className="mb-3">
            <label className="form-label fw-semibold">Audience Name <span className="text-danger">*</span></label>
            <input
              type="text"
              className="form-control"
              value={form.name}
              onChange={(e) => set('name', e.target.value)}
              placeholder="e.g. Lapsed Buyers Q1"
            />
          </div>

          {/* Client URL */}
          <div className="mb-3">
            <label className="form-label fw-semibold">Client URL</label>
            <input
              type="url"
              className="form-control"
              value={form.client_url}
              onChange={(e) => set('client_url', e.target.value)}
              placeholder="https://example.com"
            />
          </div>

          {/* Supporting Sites */}
          <div className="mb-3">
            <label className="form-label fw-semibold">Other supporting sites</label>
            <DynamicUrlList
              urls={form.supporting_sites}
              onChange={(urls) => set('supporting_sites', urls)}
            />
          </div>

          {/* Industry */}
          <DropdownField
            label="Industry"
            value={form.industry}
            otherValue={form.industry_other}
            options={INDUSTRIES}
            onChange={(v) => set('industry', v)}
            onOtherChange={(v) => set('industry_other', v)}
          />

          {/* General Insights */}
          <div className="mb-4">
            <label className="form-label fw-semibold">
              Please share as much insight as possible to help the AI build an audience profile
            </label>
            <textarea
              className="form-control"
              rows={4}
              value={form.general_insights}
              onChange={(e) => set('general_insights', e.target.value)}
              placeholder="Describe the audience, their behaviors, preferences, pain points, and any other relevant information."
            />
          </div>

          {/* Document Upload */}
          <div className="mb-4">
            <label className="form-label fw-semibold">Upload supporting documents</label>
            <DocumentUploadZone
              clientId={clientId}
              audienceId={audienceId}
              documents={documents}
              setDocuments={setDocuments}
            />
          </div>

          <hr className="my-4" />
          <h6 className="text-uppercase text-muted fw-semibold mb-3" style={{ fontSize: '0.72rem', letterSpacing: '0.08em' }}>
            Recency and Lifecycle Context
          </h6>

          {/* Interaction Recency */}
          <DropdownField
            label="How recently has this audience interacted with you?"
            value={form.interaction_recency}
            otherValue={form.interaction_recency_other}
            options={INTERACTION_RECENCIES}
            onChange={(v) => set('interaction_recency', v)}
            onOtherChange={(v) => set('interaction_recency_other', v)}
          />

          {/* Purchase Cadence */}
          <DropdownField
            label="Typical purchase cadence?"
            value={form.purchase_cadence}
            otherValue={form.purchase_cadence_other}
            options={PURCHASE_CADENCES}
            onChange={(v) => set('purchase_cadence', v)}
            onOtherChange={(v) => set('purchase_cadence_other', v)}
          />

          {/* Relationship Status */}
          <div className="mb-3">
            <label className="form-label fw-semibold">What is this audience's relationship status?</label>
            <select
              className="form-select"
              value={form.relationship_status}
              onChange={(e) => set('relationship_status', e.target.value)}
            >
              <option value="">Select...</option>
              {RELATIONSHIP_STATUSES.map((o) => <option key={o} value={o}>{o}</option>)}
            </select>
          </div>

          <hr className="my-4" />
          <h6 className="text-uppercase text-muted fw-semibold mb-3" style={{ fontSize: '0.72rem', letterSpacing: '0.08em' }}>
            Intent, Motivations, and Decision Drivers
          </h6>

          {/* Outcomes That Matter */}
          <MultiSelectField
            label="What outcomes matter most to this audience?"
            values={form.outcomes_that_matter}
            otherValue={form.outcomes_that_matter_other}
            options={OUTCOMES}
            onChange={(v) => set('outcomes_that_matter', v)}
            onOtherChange={(v) => set('outcomes_that_matter_other', v)}
          />

          {/* Primary Action */}
          <DropdownField
            label="What is the primary action you want this audience to take next?"
            value={form.primary_action}
            otherValue={form.primary_action_other}
            options={PRIMARY_ACTIONS}
            onChange={(v) => set('primary_action', v)}
            onOtherChange={(v) => set('primary_action_other', v)}
          />

          {/* Order Value Band */}
          <DropdownField
            label="Average order value band?"
            value={form.order_value_band}
            otherValue={form.order_value_band_other}
            options={ORDER_VALUE_BANDS}
            onChange={(v) => set('order_value_band', v)}
            onOtherChange={(v) => set('order_value_band_other', v)}
          />

          {/* Top Purchase Drivers */}
          <MultiSelectField
            label="Top purchase drivers?"
            values={form.top_purchase_drivers}
            otherValue={form.top_purchase_drivers_other}
            options={PURCHASE_DRIVERS}
            onChange={(v) => set('top_purchase_drivers', v)}
            onOtherChange={(v) => set('top_purchase_drivers_other', v)}
          />

          {/* Promotion Sensitivity */}
          <DropdownField
            label="Promotion sensitivity?"
            value={form.promotion_sensitivity}
            otherValue={form.promotion_sensitivity_other}
            options={PROMOTION_SENSITIVITIES}
            onChange={(v) => set('promotion_sensitivity', v)}
            onOtherChange={(v) => set('promotion_sensitivity_other', v)}
          />

          <hr className="my-4" />
          <h6 className="text-uppercase text-muted fw-semibold mb-3" style={{ fontSize: '0.72rem', letterSpacing: '0.08em' }}>
            Friction and Barriers
          </h6>

          {/* Action Prevention Factors */}
          <MultiSelectField
            label="What commonly prevents this audience from taking action?"
            values={form.action_prevention_factors}
            otherValue={form.action_prevention_factors_other}
            options={ACTION_PREVENTIONS}
            onChange={(v) => set('action_prevention_factors', v)}
            onOtherChange={(v) => set('action_prevention_factors_other', v)}
          />

          {/* Checkout Friction Points */}
          <MultiSelectField
            label="Most common checkout friction points?"
            values={form.checkout_friction_points}
            otherValue={form.checkout_friction_points_other}
            options={CHECKOUT_FRICTIONS}
            onChange={(v) => set('checkout_friction_points', v)}
            onOtherChange={(v) => set('checkout_friction_points_other', v)}
          />

          <hr className="my-4" />
          <h6 className="text-uppercase text-muted fw-semibold mb-3" style={{ fontSize: '0.72rem', letterSpacing: '0.08em' }}>
            Channel Behavior and Content Preferences
          </h6>

          {/* Communication Frequency */}
          <DropdownField
            label="How often do you communicate with this audience?"
            value={form.communication_frequency}
            otherValue={form.communication_frequency_other}
            options={COMMUNICATION_FREQUENCIES}
            onChange={(v) => set('communication_frequency', v)}
            onOtherChange={(v) => set('communication_frequency_other', v)}
          />

          {/* Communication Channels */}
          <MultiSelectField
            label="Which channels does this audience use most?"
            values={form.communication_channels}
            otherValue={form.communication_channels_other}
            options={CHANNELS}
            onChange={(v) => set('communication_channels', v)}
            onOtherChange={(v) => set('communication_channels_other', v)}
          />

          {/* Lifecycle Messages */}
          <MultiSelectField
            label="Highest-value lifecycle messages for this audience?"
            values={form.lifecycle_messages}
            otherValue={form.lifecycle_messages_other}
            options={LIFECYCLE_MESSAGES}
            onChange={(v) => set('lifecycle_messages', v)}
            onOtherChange={(v) => set('lifecycle_messages_other', v)}
          />

          {/* Product Visuals Impact */}
          <div className="mb-3">
            <label className="form-label fw-semibold">Do product visuals meaningfully impact conversion?</label>
            <select
              className="form-select"
              value={form.product_visuals_impact}
              onChange={(e) => set('product_visuals_impact', e.target.value)}
            >
              <option value="">Select...</option>
              {PRODUCT_VISUAL_IMPACTS.map((o) => <option key={o} value={o}>{o}</option>)}
            </select>
          </div>

          {/* Product Categories/Themes */}
          <div className="mb-4">
            <label className="form-label fw-semibold">
              What product categories, themes, or seasonal moments define this audience?
            </label>
            <textarea
              className="form-control"
              rows={3}
              value={form.product_categories_themes}
              onChange={(e) => set('product_categories_themes', e.target.value)}
              placeholder="Enter your answer..."
            />
          </div>

          {/* Actions */}
          <div className="d-flex gap-2 mt-2 mb-4">
            <button className="btn btn-danger btn-sm" onClick={save} disabled={saving || !form.name.trim()}>
              {saving ? 'Saving...' : 'Save'}
            </button>
            <button
              className="btn btn-outline-primary btn-sm"
              onClick={buildSummary}
              disabled={isGenerating || !form.name.trim()}
            >
              {isGenerating ? (
                <><span className="spinner-border spinner-border-sm me-1" />Building Summary...</>
              ) : (
                <><i className="bi bi-stars me-1"></i>Build Summary</>
              )}
            </button>
            <Link to="/audiences" className="btn btn-outline-secondary btn-sm">Cancel</Link>
          </div>
        </div>
      )}

      {/* Summary Tab */}
      {activeTab === 'summary' && (
        <div>
          {/* Summary State */}
          {audience?.ai_summary_state === 'generated' && audience?.ai_summary_generated_at && (
            <div className="alert alert-success py-2 mb-3 d-flex align-items-center gap-2">
              <i className="bi bi-check-circle"></i>
              <span className="small">
                Summary generated {new Date(audience.ai_summary_generated_at).toLocaleString()}
              </span>
            </div>
          )}
          {audience?.ai_summary_state === 'failed' && (
            <div className="alert alert-danger py-2 mb-3">
              Summary generation failed. Please try again.
            </div>
          )}
          {isGenerating && (
            <div className="alert alert-info py-2 mb-3 d-flex align-items-center gap-2">
              <span className="spinner-border spinner-border-sm" />
              <span className="small">Generating audience summary...</span>
            </div>
          )}

          {/* Intelligence fields */}
          {INTELLIGENCE_FIELDS.map(({ key, label }) => (
            <div key={key} className="mb-4">
              <label className="form-label fw-semibold mb-1">{label}</label>
              <textarea
                className="form-control"
                rows={4}
                value={form[key]}
                onChange={(e) => set(key, e.target.value)}
                placeholder={`Enter ${label.toLowerCase()}...`}
                disabled={isGenerating}
              />
            </div>
          ))}

          {/* Actions */}
          <div className="d-flex gap-2 mt-2 mb-4">
            <button className="btn btn-danger btn-sm" onClick={save} disabled={saving || !form.name.trim()}>
              {saving ? 'Saving...' : 'Save'}
            </button>
            <button
              className="btn btn-outline-primary btn-sm"
              onClick={buildSummary}
              disabled={isGenerating || !form.name.trim()}
            >
              {isGenerating ? (
                <><span className="spinner-border spinner-border-sm me-1" />Building Summary...</>
              ) : audience?.ai_summary_state === 'generated' ? (
                <><i className="bi bi-arrow-repeat me-1"></i>Rebuild Summary</>
              ) : (
                <><i className="bi bi-stars me-1"></i>Build Summary</>
              )}
            </button>
            <Link to="/audiences" className="btn btn-outline-secondary btn-sm">Cancel</Link>
          </div>
        </div>
      )}
    </div>
  )
}

// ─── Helper Components ──────────────────────────────────────────────────────

function DropdownField({ label, value, otherValue, options, onChange, onOtherChange }) {
  const hasOther = options.includes('Other')
  const showOtherInput = hasOther && value === 'Other'

  return (
    <div className="mb-3">
      <label className="form-label fw-semibold">{label}</label>
      <select
        className="form-select"
        value={value}
        onChange={(e) => onChange(e.target.value)}
      >
        <option value="">Select...</option>
        {options.map((o) => <option key={o} value={o}>{o}</option>)}
      </select>
      {showOtherInput && (
        <input
          type="text"
          className="form-control mt-2"
          value={otherValue}
          onChange={(e) => onOtherChange(e.target.value)}
          placeholder="Please specify..."
        />
      )}
    </div>
  )
}

function MultiSelectField({ label, values, otherValue, options, onChange, onOtherChange }) {
  const toggle = (option) => {
    if (values.includes(option)) {
      onChange(values.filter((v) => v !== option))
    } else {
      onChange([...values, option])
    }
  }

  const hasOther = options.includes('Other')
  const showOtherInput = hasOther && values.includes('Other')

  return (
    <div className="mb-3">
      <label className="form-label fw-semibold">{label}</label>
      <div className="row">
        {options.map((o) => (
          <div key={o} className="col-6">
            <div className="form-check">
              <input
                className="form-check-input"
                type="checkbox"
                id={`${label}-${o}`}
                checked={values.includes(o)}
                onChange={() => toggle(o)}
              />
              <label className="form-check-label" htmlFor={`${label}-${o}`}>
                {o}
              </label>
            </div>
          </div>
        ))}
      </div>
      {showOtherInput && (
        <input
          type="text"
          className="form-control mt-2"
          value={otherValue}
          onChange={(e) => onOtherChange(e.target.value)}
          placeholder="Please specify..."
        />
      )}
    </div>
  )
}

function DynamicUrlList({ urls, onChange }) {
  const addUrl = () => onChange([...urls, ''])
  const removeUrl = (index) => onChange(urls.filter((_, i) => i !== index))
  const updateUrl = (index, value) => {
    const updated = [...urls]
    updated[index] = value
    onChange(updated)
  }

  return (
    <div>
      {urls.map((url, i) => (
        <div key={i} className="d-flex gap-2 mb-2">
          <input
            type="url"
            className="form-control"
            value={url}
            onChange={(e) => updateUrl(i, e.target.value)}
            placeholder="https://..."
          />
          <button
            className="btn btn-outline-danger btn-sm flex-shrink-0"
            onClick={() => removeUrl(i)}
            type="button"
          >
            <i className="bi bi-x-lg"></i>
          </button>
        </div>
      ))}
      <button className="btn btn-outline-primary btn-sm" onClick={addUrl} type="button">
        <i className="bi bi-plus me-1"></i>Add Site
      </button>
    </div>
  )
}

function DocumentUploadZone({ clientId, audienceId, documents, setDocuments }) {
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
      const doc = await apiUpload(`/api/clients/${clientId}/audiences/${audienceId}/upload_document`, formData)
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
      await apiFetch(`/api/clients/${clientId}/audiences/${audienceId}/documents/${id}`, { method: 'DELETE' })
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
    return 'bi-file-earmark text-secondary'
  }

  const formatBytes = (bytes) => {
    if (!bytes) return ''
    if (bytes < 1024) return `${bytes} B`
    if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`
    return `${(bytes / (1024 * 1024)).toFixed(1)} MB`
  }

  return (
    <div>
      <p className="text-muted small mb-2">
        Upload PDFs or Word docs that provide context about this audience — they will be analyzed and used when building the summary.
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
                  {doc.has_text && (
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
