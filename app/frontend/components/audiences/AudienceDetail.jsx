import React, { useState, useEffect } from 'react'
import { useParams, useNavigate, Link } from 'react-router-dom'
import { apiFetch } from '~/lib/api'
import { useAccount } from '../layout/AccountContext'

const INTELLIGENCE_FIELDS = [
  { key: 'executive_summary',                           label: 'Executive Summary' },
  { key: 'demographics_and_financial_capacity',         label: 'Demographics and Financial Capacity' },
  { key: 'lapse_diagnosis',                             label: 'Lapse Diagnosis' },
  { key: 'relationship_state_and_pre_lapse_indicators', label: 'Relationship State and Pre-Lapse Indicators' },
  { key: 'motivational_drivers_and_messaging_framework',label: 'Motivational Drivers and Messaging Framework' },
  { key: 'strategic_reactivation_and_upgrade_cadence',  label: 'Strategic Reactivation and Upgrade Cadence' },
  { key: 'creative_and_imagery_rules',                  label: 'Creative and Imagery Rules — Visual Guardrails' },
  { key: 'risk_scoring_model',                          label: 'Risk Scoring Model (1–100)' },
  { key: 'prohibited_patterns',                         label: 'Prohibited Patterns — Language and Framing Prohibitions' },
  { key: 'success_indicators_and_macro_trends',         label: 'Success Indicators and Macro-Trends' },
]

const EMPTY_FORM = {
  name: '',
  details: '',
  executive_summary: '',
  demographics_and_financial_capacity: '',
  lapse_diagnosis: '',
  relationship_state_and_pre_lapse_indicators: '',
  motivational_drivers_and_messaging_framework: '',
  strategic_reactivation_and_upgrade_cadence: '',
  creative_and_imagery_rules: '',
  risk_scoring_model: '',
  prohibited_patterns: '',
  success_indicators_and_macro_trends: '',
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

  useEffect(() => {
    if (!clientId || !audienceId) return
    setLoading(true)
    apiFetch(`/api/clients/${clientId}/audiences/${audienceId}`)
      .then((a) => {
        setAudience(a)
        setForm({
          name: a.name || '',
          details: a.details || '',
          executive_summary: a.executive_summary || '',
          demographics_and_financial_capacity: a.demographics_and_financial_capacity || '',
          lapse_diagnosis: a.lapse_diagnosis || '',
          relationship_state_and_pre_lapse_indicators: a.relationship_state_and_pre_lapse_indicators || '',
          motivational_drivers_and_messaging_framework: a.motivational_drivers_and_messaging_framework || '',
          strategic_reactivation_and_upgrade_cadence: a.strategic_reactivation_and_upgrade_cadence || '',
          creative_and_imagery_rules: a.creative_and_imagery_rules || '',
          risk_scoring_model: a.risk_scoring_model || '',
          prohibited_patterns: a.prohibited_patterns || '',
          success_indicators_and_macro_trends: a.success_indicators_and_macro_trends || '',
        })
      })
      .catch(() => setError('Audience not found.'))
      .finally(() => setLoading(false))
  }, [clientId, audienceId])

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
          <span className="visually-hidden">Loading…</span>
        </div>
      </div>
    )
  }

  if (error && !audience) {
    return <div className="p-4"><div className="alert alert-danger">{error}</div></div>
  }

  return (
    <div className="p-4" style={{ maxWidth: 720 }}>
      {/* Back */}
      <div className="mb-3">
        <Link to="/audiences" className="text-muted small text-decoration-none">
          <i className="bi bi-arrow-left me-1"></i>Back to Audiences
        </Link>
      </div>

      {/* Header */}
      <div className="d-flex align-items-center justify-content-between mb-4">
        <h5 className="mb-0">{audience?.name}</h5>
        <button className="btn btn-outline-danger btn-sm" onClick={deleteAudience} title="Delete">
          <i className="bi bi-trash"></i>
        </button>
      </div>

      {error && <div className="alert alert-danger py-2 mb-3">{error}</div>}

      {/* Name */}
      <div className="mb-3">
        <label className="form-label fw-semibold">Name</label>
        <input
          type="text"
          className="form-control"
          value={form.name}
          onChange={(e) => set('name', e.target.value)}
        />
      </div>

      {/* Details (legacy short description) */}
      <div className="mb-4">
        <label className="form-label fw-semibold">
          Details <span className="text-muted fw-normal">(optional)</span>
        </label>
        <textarea
          className="form-control"
          rows={2}
          value={form.details}
          onChange={(e) => set('details', e.target.value)}
          placeholder="Brief description of this audience…"
        />
      </div>

      <hr className="mb-4" />

      <h6
        className="text-uppercase text-muted fw-semibold mb-3"
        style={{ fontSize: '0.72rem', letterSpacing: '0.08em' }}
      >
        Audience Intelligence
      </h6>

      {/* Intelligence fields */}
      {INTELLIGENCE_FIELDS.map(({ key, label }) => (
        <div key={key} className="mb-4">
          <label className="form-label fw-semibold mb-1">{label}</label>
          <textarea
            className="form-control"
            rows={4}
            value={form[key]}
            onChange={(e) => set(key, e.target.value)}
            placeholder={`Enter ${label.toLowerCase()}…`}
          />
        </div>
      ))}

      {/* Save */}
      <div className="d-flex gap-2 mt-2">
        <button className="btn btn-danger btn-sm" onClick={save} disabled={saving || !form.name.trim()}>
          {saving ? 'Saving…' : 'Save'}
        </button>
        <Link to="/audiences" className="btn btn-outline-secondary btn-sm">Cancel</Link>
      </div>
    </div>
  )
}
