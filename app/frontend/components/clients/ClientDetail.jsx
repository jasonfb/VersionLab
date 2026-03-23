import React, { useState, useEffect, useCallback } from 'react'
import { useParams, Link, useNavigate } from 'react-router-dom'
import { apiFetch } from '~/lib/api'
import { useAccount } from '../layout/AccountContext'

// ─── Main ─────────────────────────────────────────────────────────────────────

export default function ClientDetail() {
  const { clientId } = useParams()
  const ctx = useAccount()
  const [client, setClient] = useState(null)
  const [tab, setTab] = useState('campaigns')
  const [loading, setLoading] = useState(true)
  const canManageUsers = ctx?.is_owner || ctx?.is_admin

  useEffect(() => {
    apiFetch('/api/clients')
      .then((clients) => {
        const found = clients.find((c) => c.id === clientId)
        setClient(found || null)
      })
      .finally(() => setLoading(false))
  }, [clientId])

  if (loading) return <Spinner />

  if (!client) {
    return (
      <div className="p-4">
        <div className="alert alert-danger">Client not found.</div>
      </div>
    )
  }

  return (
    <div className="p-4">
      <div className="mb-3">
        <Link to="/clients" className="text-muted small">
          <i className="bi bi-arrow-left me-1"></i>All Clients
        </Link>
      </div>
      <h4 className="mb-4">{client.name}</h4>

      <ul className="nav nav-tabs mb-4">
        {[
          { key: 'campaigns', label: 'Campaigns' },
          { key: 'brand_profile', label: 'Brand Profile' },
          ...(canManageUsers ? [{ key: 'users', label: 'Users' }] : []),
        ].map(({ key, label }) => (
          <li key={key} className="nav-item">
            <button
              className={`nav-link ${tab === key ? 'active' : ''}`}
              onClick={() => setTab(key)}
            >
              {label}
            </button>
          </li>
        ))}
      </ul>

      {tab === 'campaigns' && <CampaignsTab clientId={clientId} />}
      {tab === 'brand_profile' && <BrandProfileTab clientId={clientId} />}
      {tab === 'users' && canManageUsers && <ClientUsersTab clientId={clientId} />}
    </div>
  )
}

// ─── Campaigns Tab ────────────────────────────────────────────────────────────

const STATUS_COLORS = { draft: 'secondary', active: 'success', completed: 'primary', archived: 'dark' }

function CampaignsTab({ clientId }) {
  const navigate = useNavigate()
  const [campaigns, setCampaigns] = useState([])
  const [loading, setLoading] = useState(true)
  const [newName, setNewName] = useState('')
  const [creating, setCreating] = useState(false)
  const [error, setError] = useState(null)

  useEffect(() => {
    apiFetch(`/api/clients/${clientId}/campaigns`)
      .then(setCampaigns)
      .finally(() => setLoading(false))
  }, [clientId])

  const handleCreate = async (e) => {
    e.preventDefault()
    if (!newName.trim()) return
    setCreating(true)
    setError(null)
    try {
      const campaign = await apiFetch(`/api/clients/${clientId}/campaigns`, {
        method: 'POST',
        body: JSON.stringify({ campaign: { name: newName.trim() } }),
      })
      setCampaigns((prev) => [...prev, campaign])
      setNewName('')
      navigate(`/clients/${clientId}/campaigns/${campaign.id}`)
    } catch (err) {
      setError(err.message)
    } finally {
      setCreating(false)
    }
  }

  const handleDelete = async (e, id) => {
    e.stopPropagation()
    if (!confirm('Delete this campaign?')) return
    try {
      await apiFetch(`/api/clients/${clientId}/campaigns/${id}`, { method: 'DELETE' })
      setCampaigns((prev) => prev.filter((c) => c.id !== id))
    } catch (err) {
      setError(err.message)
    }
  }

  if (loading) return <Spinner />

  return (
    <div style={{ maxWidth: 640 }}>
      {error && <div className="alert alert-danger">{error}</div>}

      <form onSubmit={handleCreate} className="mb-4">
        <div className="input-group">
          <input
            type="text"
            className="form-control"
            placeholder="New campaign name..."
            value={newName}
            onChange={(e) => setNewName(e.target.value)}
            required
          />
          <button className="btn btn-danger" type="submit" disabled={creating}>
            {creating ? 'Creating...' : 'Add Campaign'}
          </button>
        </div>
      </form>

      {campaigns.length === 0 ? (
        <div className="text-center text-muted py-4">
          <i className="bi bi-megaphone fs-1 d-block mb-2"></i>
          <p>No campaigns yet.</p>
        </div>
      ) : (
        <div className="list-group">
          {campaigns.map((c) => (
            <div
              key={c.id}
              className="list-group-item list-group-item-action d-flex justify-content-between align-items-center"
              style={{ cursor: 'pointer' }}
              onClick={() => navigate(`/clients/${clientId}/campaigns/${c.id}`)}
            >
              <div>
                <div className="d-flex align-items-center gap-2">
                  <i className="bi bi-megaphone text-muted"></i>
                  <strong>{c.name}</strong>
                  <span className={`badge bg-${STATUS_COLORS[c.status] || 'secondary'}`}>{c.status}</span>
                  {c.ai_summary_state === 'generated' && (
                    <span className="badge bg-info text-dark" title="AI summary ready">
                      <i className="bi bi-stars"></i>
                    </span>
                  )}
                  {c.ai_summary_state === 'generating' && (
                    <span className="spinner-border spinner-border-sm text-info" role="status" title="Generating summary..." />
                  )}
                </div>
                {(c.start_date || c.end_date) && (
                  <small className="text-muted d-block mt-1">
                    {[c.start_date, c.end_date].filter(Boolean).join(' → ')}
                  </small>
                )}
              </div>
              <button
                className="btn btn-sm btn-outline-danger"
                onClick={(e) => handleDelete(e, c.id)}
              >
                <i className="bi bi-trash"></i>
              </button>
            </div>
          ))}
        </div>
      )}
    </div>
  )
}

// ─── Brand Profile Tab ────────────────────────────────────────────────────────

export function BrandProfileTab({ clientId }) {
  const [profile, setProfile] = useState(null)
  const [lookups, setLookups] = useState(null)
  const [loading, setLoading] = useState(true)
  const [saving, setSaving] = useState(false)
  const [saved, setSaved] = useState(false)
  const [error, setError] = useState(null)

  // Form state
  const [form, setForm] = useState({
    organization_name: '',
    primary_domain: '',
    organization_type_id: '',
    industry_id: '',
    mission_statement: '',
    core_programs: [],
    approved_vocabulary: [],
    blocked_vocabulary: [],
    color_palette: [],
    link_color: '',
    underline_links: false,
    italic_links: false,
    bold_links: false,
    primary_audience_ids: [],
    tone_rule_ids: [],
    geography_ids: [],
  })

  useEffect(() => {
    Promise.all([
      apiFetch('/api/lookups'),
      apiFetch(`/api/clients/${clientId}/brand_profile`).catch(() => null),
    ]).then(([lkp, bp]) => {
      setLookups(lkp)
      if (bp) {
        setProfile(bp)
        setForm({
          organization_name: bp.organization_name || '',
          primary_domain: bp.primary_domain || '',
          organization_type_id: bp.organization_type_id || '',
          industry_id: bp.industry_id || '',
          mission_statement: bp.mission_statement || '',
          core_programs: bp.core_programs || [],
          approved_vocabulary: bp.approved_vocabulary || [],
          blocked_vocabulary: bp.blocked_vocabulary || [],
          color_palette: bp.color_palette || [],
          link_color: bp.link_color || '',
          underline_links: bp.underline_links || false,
          italic_links: bp.italic_links || false,
          bold_links: bp.bold_links || false,
          primary_audience_ids: bp.primary_audience_ids || [],
          tone_rule_ids: bp.tone_rule_ids || [],
          geography_ids: bp.geography_ids || [],
        })
      }
    }).finally(() => setLoading(false))
  }, [clientId])

  const setField = (key, value) => setForm((f) => ({ ...f, [key]: value }))

  const handleSubmit = async (e) => {
    e.preventDefault()
    setSaving(true)
    setSaved(false)
    setError(null)
    try {
      const bp = await apiFetch(`/api/clients/${clientId}/brand_profile/upsert`, {
        method: 'POST',
        body: JSON.stringify(form),
      })
      setProfile(bp)
      setSaved(true)
      setTimeout(() => setSaved(false), 3000)
    } catch (err) {
      setError(err.message)
    } finally {
      setSaving(false)
    }
  }

  if (loading) return <Spinner />

  return (
    <form onSubmit={handleSubmit} style={{ maxWidth: 760 }}>
      {error && <div className="alert alert-danger">{error}</div>}

      {/* IDENTITY */}
      <SectionHeading>Identity</SectionHeading>
      <div className="row mb-3">
        <div className="col-md-6">
          <label className="form-label">Organization Name</label>
          <input
            type="text"
            className="form-control"
            value={form.organization_name}
            onChange={(e) => setField('organization_name', e.target.value)}
            placeholder="e.g. Acme Nonprofit"
          />
        </div>
        <div className="col-md-6">
          <label className="form-label">Primary Domain</label>
          <input
            type="text"
            className="form-control"
            value={form.primary_domain}
            onChange={(e) => setField('primary_domain', e.target.value)}
            placeholder="e.g. acme.org"
          />
        </div>
      </div>
      <div className="row mb-3">
        <div className="col-md-6">
          <label className="form-label">Organization Type</label>
          <select
            className="form-select"
            value={form.organization_type_id}
            onChange={(e) => setField('organization_type_id', e.target.value)}
          >
            <option value="">— Select —</option>
            {lookups?.organization_types?.map((o) => (
              <option key={o.id} value={o.id}>{o.name}</option>
            ))}
          </select>
        </div>
        <div className="col-md-6">
          <label className="form-label">Industry</label>
          <select
            className="form-select"
            value={form.industry_id}
            onChange={(e) => setField('industry_id', e.target.value)}
          >
            <option value="">— Select —</option>
            {lookups?.industries?.map((o) => (
              <option key={o.id} value={o.id}>{o.name}</option>
            ))}
          </select>
        </div>
      </div>

      {/* MISSION & PROGRAMS */}
      <SectionHeading>Mission &amp; Programs</SectionHeading>
      <div className="mb-3">
        <label className="form-label">Mission Statement</label>
        <textarea
          className="form-control"
          rows={3}
          value={form.mission_statement}
          onChange={(e) => setField('mission_statement', e.target.value)}
          placeholder="Brief description of the organization's mission..."
        />
      </div>
      <div className="mb-3">
        <label className="form-label">Core Programs</label>
        <TagInput
          tags={form.core_programs}
          onChange={(tags) => setField('core_programs', tags)}
          placeholder="Type a program name and press Enter..."
        />
      </div>

      {/* AUDIENCE & TONE */}
      <SectionHeading>Audience &amp; Tone</SectionHeading>
      <div className="row mb-3">
        <div className="col-md-6">
          <label className="form-label">Primary Audiences</label>
          <MultiCheckbox
            options={lookups?.primary_audiences || []}
            selected={form.primary_audience_ids}
            onChange={(ids) => setField('primary_audience_ids', ids)}
          />
        </div>
        <div className="col-md-6">
          <label className="form-label">Tone Rules</label>
          <MultiCheckbox
            options={lookups?.tone_rules || []}
            selected={form.tone_rule_ids}
            onChange={(ids) => setField('tone_rule_ids', ids)}
          />
        </div>
      </div>

      {/* VOCABULARY */}
      <SectionHeading>Vocabulary</SectionHeading>
      <div className="row mb-3">
        <div className="col-md-6">
          <label className="form-label">Approved Vocabulary</label>
          <TagInput
            tags={form.approved_vocabulary}
            onChange={(tags) => setField('approved_vocabulary', tags)}
            placeholder="Add an approved word/phrase..."
          />
        </div>
        <div className="col-md-6">
          <label className="form-label">Blocked Vocabulary</label>
          <TagInput
            tags={form.blocked_vocabulary}
            onChange={(tags) => setField('blocked_vocabulary', tags)}
            placeholder="Add a blocked word/phrase..."
          />
        </div>
      </div>

      {/* COLOR PALETTE */}
      <SectionHeading>Color Palette</SectionHeading>
      <div className="mb-3">
        <ColorPaletteInput
          colors={form.color_palette}
          onChange={(colors) => setField('color_palette', colors)}
        />
      </div>

      {/* DEFAULT LINK STYLING */}
      <SectionHeading>Default Link Styling</SectionHeading>
      <p className="text-muted small mb-3">Configure how hyperlinks appear in emails by default. Individual sections can override these settings.</p>
      <div className="mb-2 d-flex align-items-center gap-2">
        <label className="mb-0 form-label">Link Color</label>
        <div
          className="rounded flex-shrink-0"
          style={{ width: 24, height: 24, background: form.link_color || '#000000', border: '1px solid #ccc' }}
        />
        <input
          type="text"
          className="form-control"
          style={{ maxWidth: 120 }}
          placeholder="#000000"
          value={form.link_color}
          onChange={(e) => setField('link_color', e.target.value)}
          maxLength={7}
        />
      </div>
      {[
        { field: 'underline_links', label: 'Underline links' },
        { field: 'italic_links', label: 'Italic links' },
        { field: 'bold_links', label: 'Bold links' },
      ].map(({ field, label }) => (
        <div key={field} className="form-check form-switch mb-2">
          <input
            className="form-check-input"
            type="checkbox"
            role="switch"
            id={`brand-${field}`}
            checked={!!form[field]}
            onChange={(e) => setField(field, e.target.checked)}
          />
          <label className="form-check-label" htmlFor={`brand-${field}`}>{label}</label>
        </div>
      ))}

      {/* GEOGRAPHY */}
      <SectionHeading>Geography</SectionHeading>
      <div className="mb-4">
        <MultiCheckbox
          options={lookups?.geographies || []}
          selected={form.geography_ids}
          onChange={(ids) => setField('geography_ids', ids)}
          columns={3}
        />
      </div>

      <div className="d-flex align-items-center gap-3">
        <button className="btn btn-danger" type="submit" disabled={saving}>
          {saving ? 'Saving...' : 'Save Brand Profile'}
        </button>
        {saved && <span className="text-success"><i className="bi bi-check-circle me-1"></i>Saved</span>}
      </div>
    </form>
  )
}

// ─── Sub-components ───────────────────────────────────────────────────────────

function SectionHeading({ children }) {
  return (
    <h6
      className="text-uppercase text-muted fw-semibold mb-3 mt-4 pb-2"
      style={{ letterSpacing: '0.08em', borderBottom: '1px solid #dee2e6', fontSize: '0.72rem' }}
    >
      {children}
    </h6>
  )
}

function MultiCheckbox({ options, selected, onChange, columns = 2 }) {
  const toggle = (id) => {
    const next = selected.includes(id)
      ? selected.filter((x) => x !== id)
      : [...selected, id]
    onChange(next)
  }

  const colClass = columns === 3 ? 'col-4' : 'col-6'

  return (
    <div className="border rounded p-3" style={{ background: '#fafafa' }}>
      <div className="row g-2">
        {options.map((o) => (
          <div key={o.id} className={colClass}>
            <div className="form-check">
              <input
                className="form-check-input"
                type="checkbox"
                id={`chk-${o.id}`}
                checked={selected.includes(o.id)}
                onChange={() => toggle(o.id)}
              />
              <label className="form-check-label" htmlFor={`chk-${o.id}`}>
                {o.name}
              </label>
            </div>
          </div>
        ))}
      </div>
    </div>
  )
}

function TagInput({ tags, onChange, placeholder }) {
  const [inputVal, setInputVal] = useState('')

  const addTag = () => {
    const val = inputVal.trim()
    if (!val || tags.includes(val)) return
    onChange([...tags, val])
    setInputVal('')
  }

  const handleKeyDown = (e) => {
    if (e.key === 'Enter') {
      e.preventDefault()
      addTag()
    }
  }

  const removeTag = (tag) => onChange(tags.filter((t) => t !== tag))

  return (
    <div>
      <div className="d-flex gap-2 mb-2">
        <input
          type="text"
          className="form-control form-control-sm"
          placeholder={placeholder}
          value={inputVal}
          onChange={(e) => setInputVal(e.target.value)}
          onKeyDown={handleKeyDown}
        />
        <button type="button" className="btn btn-sm btn-outline-secondary" onClick={addTag}>
          Add
        </button>
      </div>
      {tags.length > 0 && (
        <div className="d-flex flex-wrap gap-1">
          {tags.map((tag) => (
            <span key={tag} className="badge bg-secondary d-flex align-items-center gap-1" style={{ fontSize: '0.8rem' }}>
              {tag}
              <button
                type="button"
                className="btn-close btn-close-white"
                style={{ fontSize: '0.5rem' }}
                onClick={() => removeTag(tag)}
              />
            </span>
          ))}
        </div>
      )}
    </div>
  )
}

function ColorPaletteInput({ colors, onChange }) {
  const [inputVal, setInputVal] = useState('')
  const [inputError, setInputError] = useState(null)

  const isValidHex = (val) => /^#([0-9a-fA-F]{3}|[0-9a-fA-F]{6})$/.test(val)

  const addColor = () => {
    const val = inputVal.trim()
    if (!val) return
    const hex = val.startsWith('#') ? val : `#${val}`
    if (!isValidHex(hex)) {
      setInputError('Enter a valid hex color (e.g. #FF5733)')
      return
    }
    if (colors.includes(hex.toUpperCase())) return
    onChange([...colors, hex.toUpperCase()])
    setInputVal('')
    setInputError(null)
  }

  const handleKeyDown = (e) => {
    if (e.key === 'Enter') {
      e.preventDefault()
      addColor()
    }
  }

  const removeColor = (color) => onChange(colors.filter((c) => c !== color))

  return (
    <div>
      <div className="d-flex gap-2 mb-2">
        <input
          type="text"
          className={`form-control form-control-sm ${inputError ? 'is-invalid' : ''}`}
          placeholder="#FF5733 or FF5733"
          value={inputVal}
          onChange={(e) => { setInputVal(e.target.value); setInputError(null) }}
          onKeyDown={handleKeyDown}
          style={{ maxWidth: 200 }}
        />
        <button type="button" className="btn btn-sm btn-outline-secondary" onClick={addColor}>
          Add Color
        </button>
        {inputError && <div className="invalid-feedback d-block">{inputError}</div>}
      </div>
      {colors.length > 0 && (
        <div className="d-flex flex-wrap gap-2">
          {colors.map((color) => (
            <div key={color} className="d-flex align-items-center gap-1 border rounded px-2 py-1" style={{ background: '#fff' }}>
              <div
                style={{
                  width: 20,
                  height: 20,
                  borderRadius: 4,
                  background: color,
                  border: '1px solid #ccc',
                  flexShrink: 0,
                }}
              />
              <span className="small text-monospace">{color}</span>
              <button
                type="button"
                className="btn-close"
                style={{ fontSize: '0.5rem' }}
                onClick={() => removeColor(color)}
              />
            </div>
          ))}
        </div>
      )}
    </div>
  )
}

// ─── Client Users Tab ─────────────────────────────────────────────────────────

function ClientUsersTab({ clientId }) {
  const [users, setUsers] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)
  const [toggling, setToggling] = useState(null)

  const load = useCallback(() => {
    setLoading(true)
    apiFetch(`/api/clients/${clientId}/client_users`)
      .then(setUsers)
      .catch((e) => setError(e.message))
      .finally(() => setLoading(false))
  }, [clientId])

  useEffect(() => { load() }, [load])

  const assign = async (userId) => {
    setToggling(userId)
    setError(null)
    try {
      const result = await apiFetch(`/api/clients/${clientId}/client_users`, {
        method: 'POST',
        body: JSON.stringify({ user_id: userId }),
      })
      setUsers((prev) =>
        prev.map((u) =>
          u.user_id === userId
            ? { ...u, assigned: true, client_user_id: result.client_user_id }
            : u
        )
      )
    } catch (e) {
      setError(e.message)
    } finally {
      setToggling(null)
    }
  }

  const unassign = async (clientUserId, userId) => {
    setToggling(userId)
    setError(null)
    try {
      await apiFetch(`/api/clients/${clientId}/client_users/${clientUserId}`, { method: 'DELETE' })
      setUsers((prev) =>
        prev.map((u) =>
          u.user_id === userId
            ? { ...u, assigned: false, client_user_id: null }
            : u
        )
      )
    } catch (e) {
      setError(e.message)
    } finally {
      setToggling(null)
    }
  }

  if (loading) return <Spinner />

  return (
    <div style={{ maxWidth: 600 }}>
      <div className="alert alert-info d-flex align-items-start gap-2 mb-4" style={{ fontSize: '0.9rem' }}>
        <i className="bi bi-info-circle-fill flex-shrink-0 mt-1"></i>
        <span>
          <strong>Owners</strong> and <strong>Admins</strong> automatically have access to all clients.
          Use this tab to grant access to other team members on a client-by-client basis.
        </span>
      </div>

      {error && <div className="alert alert-danger">{error}</div>}

      {users.length === 0 ? (
        <p className="text-muted">No team members on this account yet.</p>
      ) : (
        <div className="list-group">
          {users.map((u) => (
            <div
              key={u.account_user_id}
              className="list-group-item d-flex justify-content-between align-items-center"
            >
              <div>
                <div className="fw-semibold">{u.email}</div>
                <div className="d-flex gap-1 mt-1">
                  {u.is_owner && <span className="badge bg-danger">Owner</span>}
                  {u.is_admin && !u.is_owner && <span className="badge bg-warning text-dark">Admin</span>}
                  {!u.is_owner && !u.is_admin && <span className="badge bg-secondary">Member</span>}
                </div>
              </div>

              {u.always_has_access ? (
                <span className="text-muted small fst-italic">Always has access</span>
              ) : (
                <div className="d-flex align-items-center gap-2">
                  {u.assigned ? (
                    <>
                      <span className="text-success small">
                        <i className="bi bi-check-circle-fill me-1"></i>Assigned
                      </span>
                      <button
                        className="btn btn-sm btn-outline-danger"
                        disabled={toggling === u.user_id}
                        onClick={() => unassign(u.client_user_id, u.user_id)}
                      >
                        {toggling === u.user_id ? '...' : 'Remove'}
                      </button>
                    </>
                  ) : (
                    <button
                      className="btn btn-sm btn-outline-primary"
                      disabled={toggling === u.user_id}
                      onClick={() => assign(u.user_id)}
                    >
                      {toggling === u.user_id ? '...' : 'Assign'}
                    </button>
                  )}
                </div>
              )}
            </div>
          ))}
        </div>
      )}
    </div>
  )
}

function Spinner() {
  return (
    <div className="p-4">
      <div className="spinner-border spinner-border-sm" role="status">
        <span className="visually-hidden">Loading...</span>
      </div>
    </div>
  )
}
