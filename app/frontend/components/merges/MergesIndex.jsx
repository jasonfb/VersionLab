import React, { useState, useEffect, useRef } from 'react'
import { useNavigate } from 'react-router-dom'
import { apiFetch } from '~/lib/api'
import { subscribeMergeChannel } from '~/lib/cable'

export default function MergesIndex() {
  const navigate = useNavigate()
  const [projects, setProjects] = useState([])
  const [selectedProjectId, setSelectedProjectId] = useState('')
  const [merges, setMerges] = useState([])
  const [templates, setTemplates] = useState([])
  const [audiences, setAudiences] = useState([])
  const [loadingProjects, setLoadingProjects] = useState(true)
  const [loadingMerges, setLoadingMerges] = useState(false)
  const [newForm, setNewForm] = useState(null)
  const [editingId, setEditingId] = useState(null)
  const [editForm, setEditForm] = useState({ audience_ids: [] })
  const [saving, setSaving] = useState(false)
  const [runningIds, setRunningIds] = useState(new Set())
  const [aiServices, setAiServices] = useState([])

  useEffect(() => {
    Promise.all([
      apiFetch('/api/projects'),
      apiFetch('/api/ai_services'),
    ]).then(([p, s]) => {
      setProjects(p)
      setAiServices(s)
    }).finally(() => setLoadingProjects(false))
  }, [])

  useEffect(() => {
    if (!selectedProjectId) {
      setMerges([])
      setTemplates([])
      setAudiences([])
      return
    }
    setLoadingMerges(true)
    setEditingId(null)
    setNewForm(null)

    Promise.all([
      apiFetch(`/api/projects/${selectedProjectId}/merges`),
      apiFetch(`/api/projects/${selectedProjectId}/email_templates`),
      apiFetch(`/api/projects/${selectedProjectId}/audiences`),
    ]).then(([m, t, a]) => {
      setMerges(m)
      setTemplates(t)
      setAudiences(a)
    }).finally(() => setLoadingMerges(false))
  }, [selectedProjectId])

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
    setNewForm({ email_template_id: '', audience_ids: [], ai_service_id: '', ai_model_id: '' })
    setEditingId(null)
  }

  const cancelNew = () => setNewForm(null)

  const saveNew = async () => {
    setSaving(true)
    try {
      const created = await apiFetch(`/api/projects/${selectedProjectId}/merges`, {
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
    setEditForm({ audience_ids: merge.audience_ids || [], ai_service_id: merge.ai_service_id || '', ai_model_id: merge.ai_model_id || '' })
    setNewForm(null)
  }

  const cancelEditing = () => {
    setEditingId(null)
    setEditForm({ audience_ids: [] })
  }

  const saveEdit = async () => {
    setSaving(true)
    try {
      const updated = await apiFetch(`/api/projects/${selectedProjectId}/merges/${editingId}`, {
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
    await apiFetch(`/api/projects/${selectedProjectId}/merges/${id}`, { method: 'DELETE' })
    setMerges((prev) => prev.filter((m) => m.id !== id))
    if (editingId === id) setEditingId(null)
  }

  const runMerge = async (merge) => {
    setRunningIds((prev) => new Set([...prev, merge.id]))
    try {
      const updated = await apiFetch(`/api/projects/${selectedProjectId}/merges/${merge.id}/run`, {
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

  const stateBadge = (state) => {
    const colors = { setup: 'secondary', pending: 'warning', merged: 'success', regenerating: 'warning' }
    return <span className={`badge bg-${colors[state] || 'secondary'}`}>{state}</span>
  }

  if (loadingProjects) {
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
        {selectedProjectId && (
          <button className="btn btn-danger" onClick={startNew} disabled={!!newForm}>
            <i className="bi bi-plus-lg me-1"></i> New Merge
          </button>
        )}
      </div>

      <div className="mb-4" style={{ maxWidth: 400 }}>
        <label className="form-label fw-semibold">Project</label>
        <select
          className="form-select"
          value={selectedProjectId}
          onChange={(e) => setSelectedProjectId(e.target.value)}
        >
          <option value="">Select a project...</option>
          {projects.map((p) => (
            <option key={p.id} value={p.id}>{p.name}</option>
          ))}
        </select>
      </div>

      {!selectedProjectId ? (
        <div className="text-center text-muted py-5">
          <i className="bi bi-intersect fs-1 d-block mb-3"></i>
          <p>Select a project to view its merges.</p>
        </div>
      ) : loadingMerges ? (
        <div className="p-4">
          <div className="spinner-border spinner-border-sm" role="status">
            <span className="visually-hidden">Loading...</span>
          </div>
        </div>
      ) : (
        <>
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
                    <p className="text-muted small">No audiences in this project.</p>
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
                          onClick={(e) => { e.stopPropagation(); navigate(`/projects/${selectedProjectId}/merges/${m.id}/results`) }}
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
        </>
      )}
    </div>
  )
}
