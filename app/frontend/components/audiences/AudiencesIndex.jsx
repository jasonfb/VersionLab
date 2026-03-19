import React, { useState, useEffect } from 'react'
import { useNavigate } from 'react-router-dom'
import { apiFetch } from '~/lib/api'
import { useAccount } from '../layout/AccountContext'

export default function AudiencesIndex() {
  const navigate = useNavigate()
  const ctx = useAccount()
  const clientId = ctx?.current_client_id
  const [audiences, setAudiences] = useState([])
  const [loading, setLoading] = useState(true)
  const [newName, setNewName] = useState(null) // null = hidden, string = shown
  const [saving, setSaving] = useState(false)

  useEffect(() => {
    if (!clientId) return
    setLoading(true)
    setNewName(null)
    apiFetch(`/api/clients/${clientId}/audiences`)
      .then(setAudiences)
      .finally(() => setLoading(false))
  }, [clientId])

  const saveNew = async () => {
    if (!newName?.trim()) return
    setSaving(true)
    try {
      const created = await apiFetch(`/api/clients/${clientId}/audiences`, {
        method: 'POST',
        body: JSON.stringify({ audience: { name: newName.trim() } }),
      })
      setAudiences((prev) => [created, ...prev])
      setNewName(null)
      navigate(`/audiences/${created.id}`)
    } finally {
      setSaving(false)
    }
  }

  const deleteAudience = async (id) => {
    if (!confirm('Delete this audience?')) return
    await apiFetch(`/api/clients/${clientId}/audiences/${id}`, { method: 'DELETE' })
    setAudiences((prev) => prev.filter((a) => a.id !== id))
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
        <h4 className="mb-0">Audiences</h4>
        {clientId && (
          <button className="btn btn-danger" onClick={() => setNewName('')} disabled={newName !== null}>
            <i className="bi bi-plus-lg me-1"></i> New Audience
          </button>
        )}
      </div>

      {/* Quick-create form (name only — full detail on the next page) */}
      {newName !== null && (
        <div className="card mb-3">
          <div className="card-body">
            <div className="mb-2">
              <input
                type="text"
                className="form-control"
                placeholder="Audience name"
                value={newName}
                onChange={(e) => setNewName(e.target.value)}
                onKeyDown={(e) => e.key === 'Enter' && saveNew()}
                autoFocus
              />
            </div>
            <div className="d-flex gap-2">
              <button className="btn btn-danger btn-sm" onClick={saveNew} disabled={saving || !newName.trim()}>
                {saving ? 'Saving…' : 'Create'}
              </button>
              <button className="btn btn-outline-secondary btn-sm" onClick={() => setNewName(null)}>Cancel</button>
            </div>
          </div>
        </div>
      )}

      {audiences.length === 0 && newName === null ? (
        <div className="text-center text-muted py-5">
          <i className="bi bi-people fs-1 d-block mb-3"></i>
          <p>No audiences yet. Create your first audience to get started.</p>
          <button className="btn btn-outline-danger" onClick={() => setNewName('')}>
            Create Audience
          </button>
        </div>
      ) : (
        <div className="list-group">
          {audiences.map((a) => (
            <div
              key={a.id}
              className="list-group-item list-group-item-action d-flex justify-content-between align-items-start"
            >
              <div className="cursor-pointer flex-grow-1" onClick={() => navigate(`/audiences/${a.id}`)}>
                <div className="d-flex align-items-center">
                  <i className="bi bi-people me-2 text-muted"></i>
                  <strong>{a.name}</strong>
                </div>
                {a.details && <small className="text-muted d-block mt-1">{a.details}</small>}
              </div>
              <div className="d-flex align-items-center gap-2 ms-3">
                <small className="text-muted">{new Date(a.updated_at).toLocaleDateString()}</small>
                <button
                  className="btn btn-outline-danger btn-sm"
                  onClick={(e) => { e.stopPropagation(); deleteAudience(a.id) }}
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
