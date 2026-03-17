import React, { useState, useEffect, useRef } from 'react'
import { useNavigate } from 'react-router-dom'
import { apiFetch } from '~/lib/api'
import { subscribeMergeChannel } from '~/lib/cable'
import { useAccount } from '../layout/AccountContext'

export default function MergesIndex() {
  const navigate = useNavigate()
  const ctx = useAccount()
  const clientId = ctx?.current_client_id
  const [merges, setMerges] = useState([])
  const [templates, setTemplates] = useState([])
  const [audiences, setAudiences] = useState([])
  const [campaigns, setCampaigns] = useState([])
  const [loading, setLoading] = useState(true)
  const [newForm, setNewForm] = useState(null)
  const [editingId, setEditingId] = useState(null)
  const [editForm, setEditForm] = useState({ audience_ids: [], campaign_id: '', context: '' })
  const [saving, setSaving] = useState(false)
  const [runningIds, setRunningIds] = useState(new Set())
  const [aiServices, setAiServices] = useState([])

  useEffect(() => {
    apiFetch('/api/ai_services').then(setAiServices)
  }, [])

  useEffect(() => {
    if (!clientId) return
    setLoading(true)
    setEditingId(null)
    setNewForm(null)

    Promise.all([
      apiFetch(`/api/clients/${clientId}/merges`),
      apiFetch(`/api/clients/${clientId}/email_templates`),
      apiFetch(`/api/clients/${clientId}/audiences`),
      apiFetch(`/api/clients/${clientId}/campaigns`),
    ]).then(([m, t, a, c]) => {
      setMerges(m)
      setTemplates(t)
      setAudiences(a)
      setCampaigns(c)
    }).finally(() => setLoading(false))
  }, [clientId])

  // Track cable subscriptions by mergeId
  const subscriptionsRef = useRef({})

  // Subscribe to any pending/regenerating merges for real-time state updates
  useEffect(() => {
    const inProgress = merges.filter((m) => m.state === 'pending' || m.state === 'regenerating')
    const inProgressIds = new Set(inProgress.map((m) => m.id))

    // Subscribe to newly-active merges
    inProgress.forEach((m) => {
      if (subscriptionsRef.current[m.id]) return
      subscriptionsRef.current[m.id] = subscribeMergeChannel(m.id, {
        received(data) {
          setMerges((prev) => prev.map((merge) =>
            merge.id === data.merge_id ? { ...merge, state: data.state } : merge
          ))
          if (data.state !== 'pending' && data.state !== 'regenerating') {
            subscriptionsRef.current[data.merge_id]?.()
            delete subscriptionsRef.current[data.merge_id]
          }
        },
      })
    })

    // Unsubscribe from merges that are no longer in-progress
    Object.keys(subscriptionsRef.current).forEach((id) => {
      if (!inProgressIds.has(id)) {
        subscriptionsRef.current[id]?.()
        delete subscriptionsRef.current[id]
      }
    })
  }, [merges])

  // Unsubscribe all on unmount
  useEffect(() => {
    return () => {
      Object.values(subscriptionsRef.current).forEach((unsub) => unsub?.())
    }
  }, [])

  const startNew = () => {
    setNewForm({ email_template_id: '', audience_ids: [], ai_service_id: '', ai_model_id: '', campaign_id: '', context: '' })
    setEditingId(null)
  }

  const cancelNew = () => setNewForm(null)

  const saveNew = async () => {
    setSaving(true)
    try {
      const created = await apiFetch(`/api/clients/${clientId}/merges`, {
        method: 'POST',
        body: JSON.stringify({ merge: newForm }),
      })
      setMerges((prev) => [created, ...prev])
      setNewForm(null)
    } finally {
      setSaving(false)
    }
  }

  const startEditing = (merge) => {
    setEditingId(merge.id)
    setEditForm({
      audience_ids: merge.audience_ids || [],
      ai_service_id: merge.ai_service_id || '',
      ai_model_id: merge.ai_model_id || '',
      campaign_id: merge.campaign_id || '',
      context: merge.context || '',
    })
    setNewForm(null)
  }

  const cancelEditing = () => {
    setEditingId(null)
    setEditForm({ audience_ids: [], campaign_id: '', context: '' })
  }

  const saveEdit = async () => {
    setSaving(true)
    try {
      const updated = await apiFetch(`/api/clients/${clientId}/merges/${editingId}`, {
        method: 'PATCH',
        body: JSON.stringify({ merge: editForm }),
      })
      setMerges((prev) => prev.map((m) => (m.id === editingId ? updated : m)))
      setEditingId(null)
    } finally {
      setSaving(false)
    }
  }

  const deleteMerge = async (id) => {
    if (!confirm('Delete this merge?')) return
    await apiFetch(`/api/clients/${clientId}/merges/${id}`, { method: 'DELETE' })
    setMerges((prev) => prev.filter((m) => m.id !== id))
    if (editingId === id) setEditingId(null)
  }

  const runMerge = async (merge) => {
    setRunningIds((prev) => new Set([...prev, merge.id]))
    try {
      const updated = await apiFetch(`/api/clients/${clientId}/merges/${merge.id}/run`, {
        method: 'POST',
      })
      setMerges((prev) => prev.map((m) => (m.id === merge.id ? updated : m)))
    } catch (e) {
      alert(e.message || 'Failed to run merge')
    } finally {
      setRunningIds((prev) => {
        const next = new Set(prev)
        next.delete(merge.id)
        return next
      })
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
        <label className="form-label fw-semibold">Campaign <span className="text-muted fw-normal">(optional)</span></label>
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
        <h4 className="mb-0">Merges</h4>
        {clientId && (
          <button className="btn btn-danger" onClick={startNew} disabled={!!newForm}>
            <i className="bi bi-plus-lg me-1"></i> New Merge
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
                disabled={saving || !newForm.email_template_id}
              >
                {saving ? 'Saving...' : 'Save'}
              </button>
              <button className="btn btn-outline-secondary btn-sm" onClick={cancelNew}>Cancel</button>
            </div>
          </div>
        </div>
      )}

      {merges.length === 0 && !newForm ? (
        <div className="text-center text-muted py-5">
          <i className="bi bi-intersect fs-1 d-block mb-3"></i>
          <p>No merges yet. Create your first merge to get started.</p>
          <button className="btn btn-outline-danger" onClick={startNew}>
            Create Merge
          </button>
        </div>
      ) : (
        <div className="list-group">
          {merges.map((m) =>
            editingId === m.id ? (
              <div key={m.id} className="list-group-item">
                <div className="mb-2">
                  <strong>{m.email_template_name}</strong> {stateBadge(m.state)}
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
                <div className="d-flex gap-2">
                  <button className="btn btn-danger btn-sm" onClick={saveEdit} disabled={saving}>
                    {saving ? 'Saving...' : 'Save'}
                  </button>
                  <button className="btn btn-outline-secondary btn-sm" onClick={cancelEditing}>Cancel</button>
                </div>
              </div>
            ) : (
              <div
                key={m.id}
                className="list-group-item list-group-item-action d-flex justify-content-between align-items-start"
              >
                <div className="cursor-pointer flex-grow-1" onClick={() => startEditing(m)}>
                  <div className="d-flex align-items-center gap-2">
                    <i className="bi bi-intersect me-1 text-muted"></i>
                    <strong>{m.email_template_name}</strong>
                    {stateBadge(m.state)}
                  </div>
                  <small className="text-muted d-block mt-1">
                    {m.audience_names.length > 0
                      ? `Audiences: ${m.audience_names.join(', ')}`
                      : 'No audiences selected'}
                    {m.campaign_name && (
                      <span className="ms-2 text-muted">· Campaign: {m.campaign_name}</span>
                    )}
                  </small>
                </div>
                <div className="d-flex align-items-center gap-2 ms-3">
                  <small className="text-muted">{new Date(m.updated_at).toLocaleDateString()}</small>
                  {m.state === 'setup' && m.ai_service_id && m.ai_model_id && m.audience_ids?.length > 0 && (
                    <button
                      className="btn btn-success btn-sm"
                      onClick={(e) => { e.stopPropagation(); runMerge(m) }}
                      disabled={runningIds.has(m.id)}
                      title="Run Merge"
                    >
                      {runningIds.has(m.id) ? (
                        <span className="spinner-border spinner-border-sm" role="status" />
                      ) : (
                        <><i className="bi bi-play-fill me-1"></i>Run</>
                      )}
                    </button>
                  )}
                  {(m.state === 'pending' || m.state === 'regenerating') && (
                    <span className="d-flex align-items-center gap-1 text-warning">
                      <span className="spinner-border spinner-border-sm" role="status" />
                      <small>{m.state === 'regenerating' ? 'Regenerating...' : 'Processing...'}</small>
                    </span>
                  )}
                  {(m.state === 'merged' || m.state === 'regenerating') && (
                    <button
                      className="btn btn-outline-success btn-sm"
                      onClick={(e) => { e.stopPropagation(); navigate(`/clients/${clientId}/merges/${m.id}/results`) }}
                      title="View Results"
                    >
                      <i className="bi bi-table me-1"></i>Results
                    </button>
                  )}
                  <button
                    className="btn btn-outline-danger btn-sm"
                    onClick={(e) => { e.stopPropagation(); deleteMerge(m.id) }}
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
