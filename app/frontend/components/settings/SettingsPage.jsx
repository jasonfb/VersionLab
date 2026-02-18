import React, { useState, useEffect } from 'react'
import { apiFetch } from '~/lib/api'

export default function SettingsPage() {
  const [services, setServices] = useState([])
  const [keys, setKeys] = useState([])
  const [loading, setLoading] = useState(true)
  const [form, setForm] = useState({ ai_service_id: '', api_key: '', label: '' })
  const [editingId, setEditingId] = useState(null)
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState(null)

  useEffect(() => {
    Promise.all([
      apiFetch('/api/ai_services?all=true'),
      apiFetch('/api/ai_keys'),
    ]).then(([s, k]) => {
      setServices(s)
      setKeys(k)
    }).finally(() => setLoading(false))
  }, [])

  const resetForm = () => {
    setForm({ ai_service_id: '', api_key: '', label: '' })
    setEditingId(null)
    setError(null)
  }

  const startEditing = (key) => {
    setEditingId(key.id)
    setForm({ ai_service_id: key.ai_service_id, api_key: '', label: key.label || '' })
    setError(null)
  }

  const save = async () => {
    setSaving(true)
    setError(null)
    try {
      if (editingId) {
        const body = { ai_key: { label: form.label } }
        if (form.api_key) body.ai_key.api_key = form.api_key
        const updated = await apiFetch(`/api/ai_keys/${editingId}`, {
          method: 'PATCH',
          body: JSON.stringify(body),
        })
        setKeys((prev) => prev.map((k) => (k.id === editingId ? updated : k)))
      } else {
        const created = await apiFetch('/api/ai_keys', {
          method: 'POST',
          body: JSON.stringify({ ai_key: form }),
        })
        setKeys((prev) => [created, ...prev])
      }
      resetForm()
    } catch (err) {
      setError(err.message || 'Failed to save')
    } finally {
      setSaving(false)
    }
  }

  const deleteKey = async (id) => {
    if (!confirm('Delete this API key?')) return
    await apiFetch(`/api/ai_keys/${id}`, { method: 'DELETE' })
    setKeys((prev) => prev.filter((k) => k.id !== id))
    if (editingId === id) resetForm()
  }

  // Services that already have a key (exclude from dropdown when adding new)
  const usedServiceIds = keys.map((k) => k.ai_service_id)
  const availableServices = editingId
    ? services
    : services.filter((s) => !usedServiceIds.includes(s.id))

  if (loading) {
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
      <h4 className="mb-4">Settings</h4>

      <ul className="nav nav-tabs mb-4">
        <li className="nav-item">
          <button className="nav-link active">AI Keys</button>
        </li>
      </ul>

      <div style={{ maxWidth: 600 }}>
        <div className="card mb-4">
          <div className="card-header fw-semibold">
            {editingId ? 'Edit API Key' : 'Add API Key'}
          </div>
          <div className="card-body">
            {error && (
              <div className="alert alert-danger py-2 small">{error}</div>
            )}
            <div className="mb-3">
              <label className="form-label fw-semibold">AI Service</label>
              <select
                className="form-select"
                value={form.ai_service_id}
                onChange={(e) => setForm({ ...form, ai_service_id: e.target.value })}
                disabled={!!editingId}
              >
                <option value="">Select a service...</option>
                {availableServices.map((s) => (
                  <option key={s.id} value={s.id}>{s.name}</option>
                ))}
              </select>
            </div>
            <div className="mb-3">
              <label className="form-label fw-semibold">API Key</label>
              <input
                type="password"
                className="form-control"
                value={form.api_key}
                onChange={(e) => setForm({ ...form, api_key: e.target.value })}
                placeholder={editingId ? 'Leave blank to keep current key' : 'Enter your API key'}
              />
            </div>
            <div className="mb-3">
              <label className="form-label fw-semibold">Label <span className="text-muted fw-normal">(optional)</span></label>
              <input
                type="text"
                className="form-control"
                value={form.label}
                onChange={(e) => setForm({ ...form, label: e.target.value })}
                placeholder="e.g. Production, Personal"
              />
            </div>
            <div className="d-flex gap-2">
              <button
                className="btn btn-danger btn-sm"
                onClick={save}
                disabled={saving || (!editingId && (!form.ai_service_id || !form.api_key))}
              >
                {saving ? 'Saving...' : editingId ? 'Update' : 'Save'}
              </button>
              {editingId && (
                <button className="btn btn-outline-secondary btn-sm" onClick={resetForm}>
                  Cancel
                </button>
              )}
            </div>
          </div>
        </div>

        {keys.length === 0 ? (
          <div className="text-center text-muted py-4">
            <i className="bi bi-key fs-1 d-block mb-3"></i>
            <p>No API keys configured yet. Add one above to get started.</p>
          </div>
        ) : (
          <div className="list-group">
            {keys.map((k) => (
              <div key={k.id} className="list-group-item d-flex justify-content-between align-items-start">
                <div>
                  <div className="fw-semibold">{k.ai_service_name}</div>
                  <small className="text-muted">
                    {k.masked_key}
                    {k.label && <span className="ms-2 badge bg-secondary">{k.label}</span>}
                  </small>
                </div>
                <div className="d-flex gap-2">
                  <button
                    className="btn btn-outline-secondary btn-sm"
                    onClick={() => startEditing(k)}
                    title="Edit"
                  >
                    <i className="bi bi-pencil"></i>
                  </button>
                  <button
                    className="btn btn-outline-danger btn-sm"
                    onClick={() => deleteKey(k.id)}
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
    </div>
  )
}
